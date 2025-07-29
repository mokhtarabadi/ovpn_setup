#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# This script runs on the HOST and manages container-based VPN port forwarding
# It copies the container script into the container and executes it

# Load configuration from .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Configuration
CONTAINER_NAME="openvpn-server"
CONTAINER_SCRIPT="/tmp/container-forwarding.sh"
HOST_SCRIPT="./container-forwarding.sh"

# Default values
VPN_SERVER_IP=${VPN_SERVER_IP:-10.8.0.1}
VPN_FORWARD_PORTS=${VPN_FORWARD_PORTS:-""}

echo -e "${BLUE}🚀 Host-Based VPN Port Forwarding Manager${NC}"
echo -e "${BLUE}===========================================${NC}"
echo -e "${YELLOW}Managing container: $CONTAINER_NAME${NC}"
echo -e "${YELLOW}VPN Server IP: $VPN_SERVER_IP${NC}"
echo -e "${YELLOW}Forward Ports: ${VPN_FORWARD_PORTS:-"(none configured)"}${NC}"
echo ""

# Function to check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}❌ OpenVPN container '${CONTAINER_NAME}' is not running${NC}"
        echo -e "${YELLOW}Start it with: docker compose up -d${NC}"
        exit 1
    fi
}

# Function to copy script to container
copy_script_to_container() {
    if [ ! -f "$HOST_SCRIPT" ]; then
        echo -e "${RED}❌ Container script '${HOST_SCRIPT}' not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📋 Copying container script to OpenVPN container...${NC}"
    docker cp "$HOST_SCRIPT" "$CONTAINER_NAME:$CONTAINER_SCRIPT"
    docker exec "$CONTAINER_NAME" chmod +x "$CONTAINER_SCRIPT"
    echo -e "${GREEN}✅ Script copied to container${NC}"
}

# Function to execute command in container
execute_in_container() {
    local command="$1"
    local port="$2"
    
    check_container
    copy_script_to_container
    
    echo -e "${BLUE}🔧 Executing command inside container: $command${NC}"
    echo ""
    
    # Set environment variables and execute command in container
    if [ -n "$port" ]; then
        docker exec -e VPN_SERVER_IP="$VPN_SERVER_IP" \
                   -e VPN_FORWARD_PORTS="$VPN_FORWARD_PORTS" \
                   "$CONTAINER_NAME" "$CONTAINER_SCRIPT" "$command" "$port"
    else
        docker exec -e VPN_SERVER_IP="$VPN_SERVER_IP" \
                   -e VPN_FORWARD_PORTS="$VPN_FORWARD_PORTS" \
                   "$CONTAINER_NAME" "$CONTAINER_SCRIPT" "$command"
    fi
}

# Function to show status
show_status() {
    check_container
    
    echo -e "${BLUE}📊 VPN Port Forwarding Status${NC}"
    echo ""
    echo -e "${YELLOW}Container Status:${NC}"
    echo -e "  Container: $CONTAINER_NAME"
    echo -e "  Status: $(docker inspect --format='{{.State.Status}}' $CONTAINER_NAME 2>/dev/null || echo 'Unknown')"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "  VPN Server IP: $VPN_SERVER_IP"
    echo -e "  Forward Ports: ${VPN_FORWARD_PORTS:-"(none configured)"}"
    echo ""
    
    execute_in_container "show"
}

# Main function
main() {
    case "${1:-apply}" in
        "apply"|"")
            execute_in_container "apply"
            ;;
        "clean")
            execute_in_container "clean"
            ;;
        "show"|"status")
            show_status
            ;;
        "test")
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Please specify a port to test${NC}"
                echo -e "${YELLOW}Usage: $0 test <port>${NC}"
                exit 1
            fi
            execute_in_container "test" "$2"
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}VPN Port Forwarding Manager (Container-Based)${NC}"
            echo ""
            echo -e "${YELLOW}This script manages port forwarding INSIDE the OpenVPN container.${NC}"
            echo -e "${YELLOW}It forwards traffic from VPN server IP (10.8.0.1) to Docker host services.${NC}"
            echo ""
            echo -e "${YELLOW}Usage:${NC}"
            echo -e "  $0 [command] [options]"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo -e "  apply          Apply port forwarding rules from .env (default)"
            echo -e "  clean          Remove all VPN forwarding rules"
            echo -e "  show           Show current forwarding rules and status"
            echo -e "  test <port>    Test forwarding for specific port"
            echo -e "  help           Show this help message"
            echo ""
            echo -e "${YELLOW}Configuration:${NC}"
            echo -e "  Configure VPN_FORWARD_PORTS in .env file (comma-separated)"
            echo -e "  Example: VPN_FORWARD_PORTS=80,443,8080,3000"
            echo ""
            echo -e "${GREEN}How it works:${NC}"
            echo -e "  1. VPN clients connect to OpenVPN container (10.8.0.1)"
            echo -e "  2. iptables inside container forwards 10.8.0.1:PORT → Docker host:PORT"
            echo -e "  3. VPN clients can access host services via VPN server IP"
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