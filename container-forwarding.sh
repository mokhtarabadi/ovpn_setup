#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# This script runs INSIDE the OpenVPN container
# It sets up iptables rules to forward traffic from VPN server IP to Docker host

# Get configuration from environment variables (passed from host)
VPN_SERVER_IP=${VPN_SERVER_IP:-10.8.0.1}
VPN_FORWARD_PORTS=${VPN_FORWARD_PORTS:-""}

# Auto-detect Docker host IP from inside container
# From container perspective, Docker host is accessible via default gateway
DOCKER_HOST_IP=$(ip route | grep default | awk '{print $3}' | head -1)

if [ -z "$DOCKER_HOST_IP" ]; then
    echo -e "${RED}❌ Could not detect Docker host IP from container${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Container-Based VPN Port Forwarding${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${YELLOW}Running inside container: $(hostname)${NC}"
echo -e "${YELLOW}VPN Server IP: $VPN_SERVER_IP${NC}"
echo -e "${YELLOW}Docker Host IP (gateway): $DOCKER_HOST_IP${NC}"
echo -e "${YELLOW}Forward Ports: ${VPN_FORWARD_PORTS:-"(none configured)"}${NC}"
echo ""

# Function to clean existing forwarding rules
clean_forwarding_rules() {
    echo -e "${BLUE}🧹 Cleaning existing VPN forwarding rules inside container...${NC}"
    
    # Remove PREROUTING DNAT rules for VPN server IP
    iptables -t nat -S PREROUTING 2>/dev/null | grep "\-d $VPN_SERVER_IP" | while read -r rule; do
        rule_delete=$(echo "$rule" | sed 's/^-A/-D/')
        iptables -t nat $rule_delete 2>/dev/null || true
    done
    
    # Remove POSTROUTING masquerade rules
    iptables -t nat -S POSTROUTING 2>/dev/null | grep "\-s $DOCKER_HOST_IP" | while read -r rule; do
        rule_delete=$(echo "$rule" | sed 's/^-A/-D/')
        iptables -t nat $rule_delete 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ Container iptables rules cleaned${NC}"
}

# Function to add forwarding rules
add_forwarding_rules() {
    local ports="$1"
    
    if [ -z "$ports" ]; then
        echo -e "${YELLOW}⚠️  No ports specified for forwarding${NC}"
        return 0
    fi
    
    echo -e "${BLUE}➕ Adding container-based VPN port forwarding rules...${NC}"
    
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
        if [ "$port" = "1194" ]; then
            echo -e "${YELLOW}⚠️  Skipping OpenVPN port $port to avoid conflicts${NC}"
            continue
        fi
        
        echo -e "${BLUE}   🔄 Configuring port $port forwarding inside container...${NC}"
        
        # Add DNAT rule for TCP traffic from VPN server IP to Docker host
        iptables -t nat -A PREROUTING -d "$VPN_SERVER_IP" -p tcp --dport "$port" \
            -j DNAT --to-destination "$DOCKER_HOST_IP:$port" 2>/dev/null || {
            echo -e "${RED}❌ Failed to add TCP DNAT rule for port $port${NC}"
            continue
        }
        
        # Add DNAT rule for UDP traffic
        iptables -t nat -A PREROUTING -d "$VPN_SERVER_IP" -p udp --dport "$port" \
            -j DNAT --to-destination "$DOCKER_HOST_IP:$port" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not add UDP DNAT rule for port $port (TCP rule added)${NC}"
        }
        
        echo -e "${GREEN}   ✅ Port $port forwarding configured${NC}"
    done
    
    # Add masquerade rule for return traffic
    iptables -t nat -A POSTROUTING -d "$DOCKER_HOST_IP" -j MASQUERADE 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Could not add masquerade rule (may already exist)${NC}"
    }
    
    echo -e "${GREEN}✅ Container-based VPN port forwarding rules added${NC}"
}

# Function to show current forwarding rules
show_forwarding_rules() {
    echo -e "${BLUE}📋 Current container iptables rules:${NC}"
    echo ""
    
    echo -e "${YELLOW}PREROUTING (DNAT) rules:${NC}"
    iptables -t nat -L PREROUTING -n --line-numbers | grep "$VPN_SERVER_IP" || echo "   No DNAT rules found"
    
    echo ""
    echo -e "${YELLOW}POSTROUTING (Masquerade) rules:${NC}"
    iptables -t nat -L POSTROUTING -n --line-numbers | grep "MASQUERADE" || echo "   No masquerade rules found"
}

# Function to test connectivity
test_connectivity() {
    local test_port="$1"
    
    if [ -z "$test_port" ]; then
        echo -e "${RED}❌ Please specify a port to test${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🧪 Testing port $test_port connectivity from inside container...${NC}"
    
    # Test if Docker host port is reachable from container
    if timeout 3 nc -z "$DOCKER_HOST_IP" "$test_port" 2>/dev/null; then
        echo -e "${GREEN}✅ Docker host port $test_port is reachable from container${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker host port $test_port is not reachable (may be normal if no service running)${NC}"
    fi
    
    # Check if DNAT rule exists
    if iptables -t nat -C PREROUTING -d "$VPN_SERVER_IP" -p tcp --dport "$test_port" \
        -j DNAT --to-destination "$DOCKER_HOST_IP:$test_port" 2>/dev/null; then
        echo -e "${GREEN}✅ DNAT rule exists for port $test_port${NC}"
    else
        echo -e "${RED}❌ DNAT rule missing for port $test_port${NC}"
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
            test_connectivity "$2"
            ;;
        "apply"|"")
            clean_forwarding_rules
            add_forwarding_rules "$VPN_FORWARD_PORTS"
            echo ""
            echo -e "${GREEN}🎉 Container-based VPN port forwarding complete!${NC}"
            echo ""
            echo -e "${BLUE}VPN clients can now access:${NC}"
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
            echo -e "${BLUE}Container-Based VPN Port Forwarding${NC}"
            echo ""
            echo -e "${YELLOW}This script runs INSIDE the OpenVPN container${NC}"
            echo -e "${YELLOW}It forwards traffic from VPN server IP to Docker host${NC}"
            echo ""
            echo -e "${YELLOW}Usage:${NC}"
            echo -e "  $0 [command] [options]"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo -e "  apply          Apply port forwarding rules (default)"
            echo -e "  clean          Remove all forwarding rules"
            echo -e "  show           Show current iptables rules"
            echo -e "  test <port>    Test connectivity for specific port"
            echo -e "  help           Show this help message"
            echo ""
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo -e "${YELLOW}Use '$0 help' for usage information${NC}"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"