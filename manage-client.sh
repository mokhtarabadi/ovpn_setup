#!/bin/bash

set -e

# Load configuration from .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Static IP configuration with defaults
STATIC_IP_RANGE_START=${STATIC_IP_RANGE_START:-10.8.0.50}
STATIC_IP_RANGE_END=${STATIC_IP_RANGE_END:-10.8.0.200}
DYNAMIC_IP_RANGE_START=${DYNAMIC_IP_RANGE_START:-10.8.0.10}
DYNAMIC_IP_RANGE_END=${DYNAMIC_IP_RANGE_END:-10.8.0.49}
VPN_NETWORK=${VPN_NETWORK:-10.8.0.0}
ENABLE_STATIC_IPS=${ENABLE_STATIC_IPS:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLIENT=$1
ACTION=${2:-add} # add, revoke, list, show

show_usage() {
    echo -e "${BLUE}OpenVPN Client Management Script${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 <client-name> [add|revoke|show]"
    echo -e "  $0 <client-name> set-static-ip <ip-address>"
    echo -e "  $0 <client-name> remove-static-ip"
    echo -e "  $0 <client-name> show-static"
    echo -e "  $0 list"
    echo -e "  $0 list-static"
    echo ""
    echo -e "${YELLOW}Actions:${NC}"
    echo -e "  add              - Add a new client certificate (default)"
    echo -e "  revoke           - Revoke an existing client certificate"
    echo -e "  show             - Show existing client certificate"
    echo -e "  set-static-ip    - Assign static IP to existing client"
    echo -e "  remove-static-ip - Remove static IP from client (use dynamic)"
    echo -e "  show-static      - Show static IP configuration for client"
    echo -e "  list             - List all clients"
    echo -e "  list-static      - List all clients with static IPs"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 alice                        # Add client 'alice'"
    echo -e "  $0 alice add                    # Add client 'alice'"
    echo -e "  $0 alice revoke                 # Revoke client 'alice'"
    echo -e "  $0 alice show                   # Show client 'alice' config"
    echo -e "  $0 alice set-static-ip 10.8.0.100  # Assign static IP"
    echo -e "  $0 alice remove-static-ip       # Remove static IP"
    echo -e "  $0 alice show-static            # Show static IP info"
    echo -e "  $0 list                         # List all clients"
    echo -e "  $0 list-static                  # List clients with static IPs"
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

# Static IP utility functions
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

ip_to_int() {
    local ip=$1
    local IFS='.'
    local -a octets=($ip)
    echo $((${octets[0]} * 256**3 + ${octets[1]} * 256**2 + ${octets[2]} * 256 + ${octets[3]}))
}

validate_static_ip_range() {
    local ip=$1
    local start_int=$(ip_to_int "$STATIC_IP_RANGE_START")
    local end_int=$(ip_to_int "$STATIC_IP_RANGE_END")
    local ip_int=$(ip_to_int "$ip")
    
    if [[ $ip_int -ge $start_int && $ip_int -le $end_int ]]; then
        return 0
    else
        return 1
    fi
}

check_ip_conflict() {
    local ip=$1
    local client_to_exclude=$2
    
    # Check if IP is already assigned to another client
    local existing_client=$(docker run -v openvpn-data:/etc/openvpn --rm alpine sh -c "
        find /etc/openvpn/ccd -name '*' -type f -exec grep -l 'ifconfig-push $ip ' {} \; 2>/dev/null | head -1
    " | xargs basename 2>/dev/null || echo "")
    
    if [[ -n "$existing_client" && "$existing_client" != "$client_to_exclude" ]]; then
        echo "$existing_client"
        return 1
    fi
    return 0
}

get_client_static_ip() {
    local client_name=$1
    docker run -v openvpn-data:/etc/openvpn --rm alpine sh -c "
        if [ -f /etc/openvpn/ccd/$client_name ]; then
            grep '^ifconfig-push' /etc/openvpn/ccd/$client_name | awk '{print \$2}'
        fi
    " 2>/dev/null || echo ""
}

list_static_ips() {
    echo -e "${BLUE}📋 Listing clients with static IP assignments...${NC}"
    check_volume
    check_pki
    
    echo -e "${YELLOW}Static IP Assignments:${NC}"
    
    local has_static=false
    if docker run -v openvpn-data:/etc/openvpn --rm alpine test -d /etc/openvpn/ccd 2>/dev/null; then
        local static_clients=$(docker run -v openvpn-data:/etc/openvpn --rm alpine find /etc/openvpn/ccd -name '*' -type f 2>/dev/null | sort)
        
        if [[ -n "$static_clients" ]]; then
            while IFS= read -r ccd_file; do
                if [[ -n "$ccd_file" ]]; then
                    local client_name=$(basename "$ccd_file")
                    local static_ip=$(docker run -v openvpn-data:/etc/openvpn --rm alpine grep '^ifconfig-push' "$ccd_file" | awk '{print $2}' 2>/dev/null || echo "")
                    if [[ -n "$static_ip" ]]; then
                        echo -e "  ${GREEN}$client_name${NC} -> ${YELLOW}$static_ip${NC}"
                        has_static=true
                    fi
                fi
            done <<< "$static_clients"
        fi
    fi
    
    if [ "$has_static" = false ]; then
        echo -e "  ${YELLOW}No clients with static IP assignments${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Configuration Summary:${NC}"
    echo -e "  Static IP Range: $STATIC_IP_RANGE_START - $STATIC_IP_RANGE_END"
    echo -e "  Dynamic IP Range: $DYNAMIC_IP_RANGE_START - $DYNAMIC_IP_RANGE_END"
    echo -e "  VPN Network: $VPN_NETWORK/24"
}

show_static_ip() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}📊 Static IP information for client: $client_name${NC}"
    check_volume
    check_pki
    
    # Check if client exists
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${RED}❌ Client '$client_name' does not exist${NC}"
        exit 1
    fi
    
    local static_ip=$(get_client_static_ip "$client_name")
    if [[ -n "$static_ip" ]]; then
        echo -e "${GREEN}✅ Client has static IP assigned${NC}"
        echo -e "${YELLOW}📍 Static IP: $static_ip${NC}"
        echo ""
        echo -e "${BLUE}📄 Configuration details:${NC}"
        docker run -v openvpn-data:/etc/openvpn --rm alpine cat "/etc/openvpn/ccd/$client_name"
    else
        echo -e "${YELLOW}⚠️  No static IP assigned${NC}"
        echo -e "${BLUE}Client will receive dynamic IP from pool: $DYNAMIC_IP_RANGE_START - $DYNAMIC_IP_RANGE_END${NC}"
    fi
}

set_static_ip() {
    local client_name=$1
    local static_ip=$2
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    if [ -z "$static_ip" ]; then
        echo -e "${RED}❌ IP address is required${NC}"
        echo -e "${YELLOW}Usage: $0 $client_name set-static-ip <ip-address>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔧 Setting static IP for client: $client_name -> $static_ip${NC}"
    check_volume
    check_pki
    
    # Check if static IPs are enabled
    if [ "${ENABLE_STATIC_IPS,,}" != "true" ]; then
        echo -e "${RED}❌ Static IP support is disabled${NC}"
        echo -e "${YELLOW}Enable it by setting ENABLE_STATIC_IPS=true in .env and re-running ./init-openvpn.sh${NC}"
        exit 1
    fi
    
    # Check if client exists
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${RED}❌ Client '$client_name' does not exist${NC}"
        echo -e "${YELLOW}Create the client first with: $0 $client_name add${NC}"
        exit 1
    fi
    
    # Validate IP format
    if ! validate_ip "$static_ip"; then
        echo -e "${RED}❌ Invalid IP address format: $static_ip${NC}"
        exit 1
    fi
    
    # Validate IP is in static range
    if ! validate_static_ip_range "$static_ip"; then
        echo -e "${RED}❌ IP $static_ip is not in the static IP range${NC}"
        echo -e "${YELLOW}Valid range: $STATIC_IP_RANGE_START - $STATIC_IP_RANGE_END${NC}"
        exit 1
    fi
    
    # Check for IP conflicts
    local conflicting_client
    if conflicting_client=$(check_ip_conflict "$static_ip" "$client_name") && [[ -n "$conflicting_client" ]]; then
        echo -e "${RED}❌ IP $static_ip is already assigned to client: $conflicting_client${NC}"
        exit 1
    fi
    
    # Create CCD directory if it doesn't exist
    docker run -v openvpn-data:/etc/openvpn --rm alpine mkdir -p /etc/openvpn/ccd
    
    # Set static IP configuration
    echo -e "${BLUE}📝 Creating static IP configuration...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm alpine sh -c "
        echo 'ifconfig-push $static_ip 255.255.255.0' > /etc/openvpn/ccd/$client_name
        echo '# Static IP assigned: $static_ip' >> /etc/openvpn/ccd/$client_name
        echo '# Created: $(date)' >> /etc/openvpn/ccd/$client_name
    "
    
    # Restart server if running to apply changes
    if docker compose ps 2>/dev/null | grep -q "running"; then
        echo -e "${BLUE}🔄 Restarting OpenVPN server to apply changes...${NC}"
        docker compose restart
        sleep 2
    fi
    
    echo -e "${GREEN}✅ Static IP $static_ip assigned to client '$client_name'${NC}"
    echo -e "${YELLOW}📱 Client will receive this IP on next connection${NC}"
    echo -e "${YELLOW}📊 Current assignment: $client_name -> $static_ip${NC}"
}

remove_static_ip() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Client name is required${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}🗑️  Removing static IP for client: $client_name${NC}"
    check_volume
    check_pki
    
    # Check if client exists
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f "/etc/openvpn/pki/issued/${client_name}.crt" 2>/dev/null; then
        echo -e "${RED}❌ Client '$client_name' does not exist${NC}"
        exit 1
    fi
    
    # Check if client has static IP
    local current_ip=$(get_client_static_ip "$client_name")
    if [[ -z "$current_ip" ]]; then
        echo -e "${YELLOW}⚠️  Client '$client_name' doesn't have a static IP assigned${NC}"
        echo -e "${BLUE}Client will use dynamic IP from pool${NC}"
        exit 0
    fi
    
    # Remove static IP configuration
    echo -e "${BLUE}📝 Removing static IP configuration ($current_ip)...${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm alpine rm -f "/etc/openvpn/ccd/$client_name"
    
    # Restart server if running to apply changes
    if docker compose ps 2>/dev/null | grep -q "running"; then
        echo -e "${BLUE}🔄 Restarting OpenVPN server to apply changes...${NC}"
        docker compose restart
        sleep 2
    fi
    
    echo -e "${GREEN}✅ Static IP removed from client '$client_name'${NC}"
    echo -e "${YELLOW}📱 Client will now receive dynamic IP from pool${NC}"
}

# Main script logic
case "$1" in
    "list")
        list_clients
        ;;
    "list-static")
        list_static_ips
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
            "set-static-ip")
                shift 2
                set_static_ip $CLIENT "$@"
                ;;
            "remove-static-ip")
                remove_static_ip $CLIENT
                ;;
            "show-static")
                show_static_ip $CLIENT
                ;;
            "list-static")
                list_static_ips
                ;;
            *)
                echo -e "${RED}❌ Unknown action: $ACTION${NC}"
                show_usage
                exit 1
                ;;
        esac
        ;;
esac