#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLIENT=$1
ACTION=${2:-add} # add, revoke, list, or show

show_usage() {
    echo -e "${BLUE}OpenVPN Client Management Script${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 <client-name> [add|revoke|show]"
    echo -e "  $0 list"
    echo ""
    echo -e "${YELLOW}Actions:${NC}"
    echo -e "  add     - Add a new client certificate (default)"
    echo -e "  revoke  - Revoke an existing client certificate"
    echo -e "  show    - Show existing client certificate"
    echo -e "  list    - List all clients"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 alice                 # Add client 'alice'"
    echo -e "  $0 alice add             # Add client 'alice'"
    echo -e "  $0 alice revoke          # Revoke client 'alice'"
    echo -e "  $0 alice show            # Show client 'alice' config"
    echo -e "  $0 list                  # List all clients"
}

check_volume() {
    if ! docker volume inspect openvpn-data >/dev/null 2>&1; then
        echo -e "${RED}❌ OpenVPN volume 'openvpn-data' not found${NC}"
        echo -e "${YELLOW}Run ./init-openvpn.sh first to initialize the server${NC}"
        exit 1
    fi
}

check_pki() {
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/pki/ca.crt; then
        echo -e "${RED}❌ OpenVPN PKI not initialized${NC}"
        echo -e "${YELLOW}Run ./init-openvpn.sh first to initialize the server${NC}"
        exit 1
    fi
}

list_clients() {
    echo -e "${BLUE}📋 Listing OpenVPN clients...${NC}"
    check_volume
    check_pki
    
    echo -e "${YELLOW}Active Clients:${NC}"
    CLIENTS=$(docker run -v openvpn-data:/etc/openvpn --rm alpine find /etc/openvpn/pki/issued -name "*.crt" -exec basename {} \; 2>/dev/null | sed 's/\.crt$//' | grep -v "^server$" | sort || echo "")
    
    if [ -z "$CLIENTS" ]; then
        echo "  No clients found"
    else
        echo "$CLIENTS" | sed 's/^/  - /'
    fi
    
    echo ""
    echo -e "${YELLOW}Revoked Clients:${NC}"
    if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/pki/crl.pem 2>/dev/null; then
        echo "  (CRL exists - some clients may have been revoked)"
    else
        echo "  No revoked clients"
    fi
}

add_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}👤 Adding OpenVPN client: $client_name${NC}"
    check_volume
    check_pki
    
    # Check if client already exists
    if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Client '$client_name' already exists${NC}"
        echo -e "${YELLOW}Use 'show' action to display the configuration${NC}"
        exit 1
    fi
    
    # Generate client certificate
    echo -e "${BLUE}🔐 Generating client certificate...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn easyrsa build-client-full $client_name nopass
    
    # Extract client configuration
    echo -e "${BLUE}📄 Generating client configuration...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $client_name > ${client_name}.ovpn
    
    echo -e "${GREEN}✅ Client '$client_name' added successfully!${NC}"
    echo -e "${YELLOW}Configuration saved to: ${client_name}.ovpn${NC}"
    echo ""
    echo -e "${BLUE}📊 Client Information:${NC}"
    echo -e "  File: ${client_name}.ovpn"
    echo -e "  Size: $(du -h ${client_name}.ovpn | cut -f1)"
    echo -e "  Client IP will be assigned automatically from the VPN pool"
    echo ""
    echo -e "${YELLOW}📱 Distribution Instructions:${NC}"
    echo -e "  1. Securely share the ${client_name}.ovpn file with the user"
    echo -e "  2. User imports this file into their OpenVPN client"
    echo -e "  3. Once connected, they can communicate with other VPN clients"
    echo -e "  4. Internet traffic will NOT be routed through the VPN"
}

revoke_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}🚫 Revoking OpenVPN client: $client_name${NC}"
    check_volume
    check_pki
    
    # Check if client exists
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${RED}❌ Client '$client_name' does not exist${NC}"
        exit 1
    fi
    
    # Confirm revocation
    echo -e "${YELLOW}⚠️  Are you sure you want to revoke client '$client_name'? (y/N)${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Revocation cancelled${NC}"
        exit 0
    fi
    
    # Revoke the certificate
    echo -e "${BLUE}🔐 Revoking certificate...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn easyrsa revoke $client_name
    
    # Generate new CRL
    echo -e "${BLUE}📋 Generating new Certificate Revocation List...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn easyrsa gen-crl
    
    # Restart server if running
    if docker compose ps 2>/dev/null | grep -q "running"; then
        echo -e "${BLUE}🔄 Restarting OpenVPN server...${NC}"
        docker compose restart
    else
        echo -e "${YELLOW}⚠️  Server not running via docker-compose, restart manually if needed${NC}"
    fi
    
    # Remove local .ovpn file if it exists
    if [ -f "${client_name}.ovpn" ]; then
        rm -f "${client_name}.ovpn"
        echo -e "${BLUE}🗑️  Removed local ${client_name}.ovpn file${NC}"
    fi
    
    echo -e "${GREEN}✅ Client '$client_name' revoked successfully!${NC}"
    echo -e "${YELLOW}The client can no longer connect to the VPN${NC}"
}

show_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}👁️  Showing OpenVPN client: $client_name${NC}"
    check_volume
    check_pki
    
    # Check if client exists
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${RED}❌ Client '$client_name' does not exist${NC}"
        exit 1
    fi
    
    # Generate and display client configuration
    echo -e "${BLUE}📄 Generating client configuration...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $client_name > ${client_name}.ovpn
    
    echo -e "${GREEN}✅ Client configuration saved to: ${client_name}.ovpn${NC}"
    echo -e "${BLUE}📊 Certificate Information:${NC}"
    
    # Show certificate details
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn openssl x509 -in /etc/openvpn/pki/issued/${client_name}.crt -noout -subject -dates -fingerprint
    
    echo ""
    echo -e "${YELLOW}📱 File ready for distribution: ${client_name}.ovpn${NC}"
}

# Main script logic
case "$1" in
    "list")
        list_clients
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        case "$ACTION" in
            "add")
                add_client $CLIENT
                ;;
            "revoke")
                revoke_client $CLIENT
                ;;
            "show")
                show_client $CLIENT
                ;;
            *)
                echo -e "${RED}❌ Unknown action: $ACTION${NC}"
                show_usage
                exit 1
                ;;
        esac
        ;;
esac