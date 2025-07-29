#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration from .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Default values
VPN_NETWORK=${VPN_NETWORK:-10.8.0.0}
VPN_SERVER_IP=${VPN_SERVER_IP:-10.8.0.1}
VPN_FORWARD_PORTS=${VPN_FORWARD_PORTS:-""}
DOCKER_HOST_IP=${DOCKER_HOST_IP:-172.17.0.1}

# Auto-detect Docker host IP if not set or default
if [ "$DOCKER_HOST_IP" = "172.17.0.1" ]; then
    echo -e "${BLUE}🔍 Auto-detecting Docker host IP...${NC}"
    DETECTED_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "")
    if [ -n "$DETECTED_IP" ] && [ "$DETECTED_IP" != "172.17.0.1" ]; then
        echo -e "${YELLOW}⚠️  Detected Docker host IP: $DETECTED_IP (different from default)${NC}"
        DOCKER_HOST_IP="$DETECTED_IP"
    fi
fi

echo -e "${BLUE}🚀 VPN Port Forwarding Manager${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${YELLOW}VPN Server IP: $VPN_SERVER_IP${NC}"
echo -e "${YELLOW}Docker Host IP: $DOCKER_HOST_IP${NC}"
echo -e "${YELLOW}Forward Ports: ${VPN_FORWARD_PORTS:-"(none configured)"}${NC}"
echo ""

# Function to clean all existing VPN forwarding rules
clean_forwarding_rules() {
    echo -e "${BLUE}🧹 Cleaning existing VPN forwarding rules...${NC}"
    
    # Remove PREROUTING DNAT rules for VPN server IP
    iptables -t nat -S PREROUTING | grep "\-d $VPN_SERVER_IP" | while read -r rule; do
        # Convert -S output to -D format
        rule_delete=$(echo "$rule" | sed 's/^-A/-D/')
        iptables -t nat $rule_delete 2>/dev/null || true
    done
    
    # Remove POSTROUTING masquerade rules for Docker host
    iptables -t nat -S POSTROUTING | grep "\-s $DOCKER_HOST_IP" | grep "tun0" | while read -r rule; do
        rule_delete=$(echo "$rule" | sed 's/^-A/-D/')
        iptables -t nat $rule_delete 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ Existing rules cleaned${NC}"
}

# Function to add forwarding rules for specified ports
add_forwarding_rules() {
    local ports="$1"
    
    if [ -z "$ports" ]; then
        echo -e "${YELLOW}⚠️  No ports specified for forwarding${NC}"
        return 0
    fi
    
    echo -e "${BLUE}➕ Adding VPN port forwarding rules...${NC}"
    
    # Convert comma-separated ports to array
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    
    for port in "${PORT_ARRAY[@]}"; do
        # Trim whitespace
        port=$(echo "$port" | xargs)
        
        # Validate port number
        if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}❌ Invalid port: $port (skipping)${NC}"
            continue
        fi
        
        # Skip OpenVPN port to avoid conflicts
        if [ "$port" = "${OPENVPN_PORT:-1194}" ]; then
            echo -e "${YELLOW}⚠️  Skipping OpenVPN port $port to avoid conflicts${NC}"
            continue
        fi
        
        echo -e "${BLUE}   🔄 Configuring port $port...${NC}"
        
        # Add DNAT rule for TCP traffic from VPN interface to Docker host
        iptables -t nat -A PREROUTING -i tun0 -d "$VPN_SERVER_IP" -p tcp --dport "$port" \
            -j DNAT --to-destination "$DOCKER_HOST_IP:$port" 2>/dev/null || {
            echo -e "${RED}❌ Failed to add DNAT rule for port $port${NC}"
            continue
        }
        
        # Add DNAT rule for UDP traffic (for services that use UDP)
        iptables -t nat -A PREROUTING -i tun0 -d "$VPN_SERVER_IP" -p udp --dport "$port" \
            -j DNAT --to-destination "$DOCKER_HOST_IP:$port" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not add UDP DNAT rule for port $port (TCP rule added)${NC}"
        }
        
        echo -e "${GREEN}   ✅ Port $port forwarding configured${NC}"
    done
    
    # Add masquerade rule for return traffic
    iptables -t nat -A POSTROUTING -s "$DOCKER_HOST_IP" -o tun0 -j MASQUERADE 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Could not add masquerade rule (may already exist)${NC}"
    }
    
    echo -e "${GREEN}✅ VPN port forwarding rules added${NC}"
}

# Function to show current forwarding rules
show_forwarding_rules() {
    echo -e "${BLUE}📋 Current VPN forwarding rules:${NC}"
    echo ""
    
    echo -e "${YELLOW}PREROUTING (DNAT) rules:${NC}"
    iptables -t nat -L PREROUTING -n | grep "$VPN_SERVER_IP" || echo "   No DNAT rules found"
    
    echo ""
    echo -e "${YELLOW}POSTROUTING (Masquerade) rules:${NC}"
    iptables -t nat -L POSTROUTING -n | grep "tun0" || echo "   No masquerade rules found"
}

# Function to test port forwarding
test_forwarding() {
    local test_port="$1"
    
    if [ -z "$test_port" ]; then
        echo -e "${RED}❌ Please specify a port to test${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🧪 Testing port $test_port forwarding...${NC}"
    
    # Check if port is in forwarding list
    if [[ ",$VPN_FORWARD_PORTS," != *",$test_port,"* ]]; then
        echo -e "${YELLOW}⚠️  Port $test_port is not in VPN_FORWARD_PORTS list${NC}"
    fi
    
    # Check if DNAT rule exists
    if iptables -t nat -C PREROUTING -i tun0 -d "$VPN_SERVER_IP" -p tcp --dport "$test_port" \
        -j DNAT --to-destination "$DOCKER_HOST_IP:$test_port" 2>/dev/null; then
        echo -e "${GREEN}✅ DNAT rule exists for port $test_port${NC}"
    else
        echo -e "${RED}❌ DNAT rule missing for port $test_port${NC}"
    fi
    
    # Test connectivity from container (if possible)
    if command -v docker >/dev/null && docker ps --format '{{.Names}}' | grep -q openvpn; then
        echo -e "${BLUE}   Testing connectivity from VPN container...${NC}"
        if docker exec openvpn-server timeout 3 nc -z "$DOCKER_HOST_IP" "$test_port" 2>/dev/null; then
            echo -e "${GREEN}   ✅ Docker host port $test_port is reachable${NC}"
        else
            echo -e "${YELLOW}   ⚠️  Docker host port $test_port is not reachable (may be normal if no service running)${NC}"
        fi
    fi
}

# Main function
main() {
    case "${1:-apply}" in
        "clean")
            clean_forwarding_rules
            ;;
        "show")
            show_forwarding_rules
            ;;
        "test")
            test_forwarding "$2"
            ;;
        "apply"|"")
            clean_forwarding_rules
            add_forwarding_rules "$VPN_FORWARD_PORTS"
            echo ""
            echo -e "${GREEN}🎉 VPN port forwarding configuration complete!${NC}"
            echo ""
            echo -e "${BLUE}Usage from VPN clients:${NC}"
            if [ -n "$VPN_FORWARD_PORTS" ]; then
                IFS=',' read -ra PORT_ARRAY <<< "$VPN_FORWARD_PORTS"
                for port in "${PORT_ARRAY[@]}"; do
                    port=$(echo "$port" | xargs)
                    echo -e "  ${YELLOW}http://$VPN_SERVER_IP:$port${NC} → Docker host:$port"
                done
            else
                echo -e "  ${YELLOW}No ports configured for forwarding${NC}"
            fi
            echo ""
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}VPN Port Forwarding Manager${NC}"
            echo ""
            echo -e "${YELLOW}Usage:${NC}"
            echo -e "  $0 [command] [options]"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo -e "  apply          Apply port forwarding rules from .env (default)"
            echo -e "  clean          Remove all VPN forwarding rules"
            echo -e "  show           Show current forwarding rules"
            echo -e "  test <port>    Test forwarding for specific port"
            echo -e "  help           Show this help message"
            echo ""
            echo -e "${YELLOW}Configuration:${NC}"
            echo -e "  Configure VPN_FORWARD_PORTS in .env file (comma-separated)"
            echo -e "  Example: VPN_FORWARD_PORTS=80,443,8080,3000"
            echo ""
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo -e "${YELLOW}Use '$0 help' for usage information${NC}"
            exit 1
            ;;
    esac
}

# Check if script is run as root (required for iptables)
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script requires root privileges to modify iptables rules${NC}"
    echo -e "${YELLOW}Please run with: sudo $0 $*${NC}"
    exit 1
fi

# Run main function with all arguments
main "$@"