#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_FILE="${1:-/etc/openvpn/client/openvpn-client-forwarding.env}"
ACTION="${2:-setup}"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | systemd-cat -t openvpn-client-forwarding
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | systemd-cat -t openvpn-client-forwarding -p err
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | systemd-cat -t openvpn-client-forwarding
}

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Wait for VPN interface to be ready
wait_for_interface() {
    local max_attempts=30
    local attempt=1
    
    log "Waiting for VPN interface $VPN_INTERFACE to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if ip addr show "$VPN_INTERFACE" >/dev/null 2>&1; then
            VPN_CLIENT_IP=$(ip addr show "$VPN_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
            if [[ -n "$VPN_CLIENT_IP" ]]; then
                success "VPN interface $VPN_INTERFACE is ready with IP: $VPN_CLIENT_IP"
                return 0
            fi
        fi
        
        log "Attempt $attempt/$max_attempts: Interface not ready, waiting..."
        sleep 2
        ((attempt++))
    done
    
    error "VPN interface $VPN_INTERFACE did not come up within expected time"
    return 1
}

# Get the VPN client IP
get_vpn_client_ip() {
    VPN_CLIENT_IP=$(ip addr show "$VPN_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 2>/dev/null || echo "")
    if [[ -z "$VPN_CLIENT_IP" ]]; then
        error "Could not determine VPN client IP address"
        return 1
    fi
    log "VPN client IP: $VPN_CLIENT_IP"
}

# Setup iptables rules for port forwarding
setup_forwarding() {
    log "Setting up port forwarding rules..."
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    log "IP forwarding enabled"
    
    # Add custom chain for our rules
    iptables -t nat -N OPENVPN_CLIENT_FORWARD 2>/dev/null || true
    iptables -t filter -N OPENVPN_CLIENT_ACCEPT 2>/dev/null || true
    
    # Clear existing rules in our chains
    iptables -t nat -F OPENVPN_CLIENT_FORWARD 2>/dev/null || true
    iptables -t filter -F OPENVPN_CLIENT_ACCEPT 2>/dev/null || true
    
    # Process each port
    for port_config in $FORWARD_PORTS; do
        port=$(echo "$port_config" | cut -d':' -f1)
        protocol=$(echo "$port_config" | cut -d':' -f2)
        
        log "Setting up forwarding for port $port/$protocol"
        
        # DNAT rule: Forward traffic from VPN clients to this port to localhost
        iptables -t nat -A OPENVPN_CLIENT_FORWARD -s "$VPN_SERVER_NETWORK" -d "$VPN_CLIENT_IP" -p "$protocol" --dport "$port" -j DNAT --to-destination "127.0.0.1:$port"
        
        # Accept the forwarded traffic
        iptables -t filter -A OPENVPN_CLIENT_ACCEPT -s "$VPN_SERVER_NETWORK" -d "127.0.0.1" -p "$protocol" --dport "$port" -j ACCEPT
        
        success "Port forwarding configured for $port/$protocol"
    done
    
    # Insert our chains into the main chains if not already there
    if ! iptables -t nat -C PREROUTING -j OPENVPN_CLIENT_FORWARD 2>/dev/null; then
        iptables -t nat -I PREROUTING -j OPENVPN_CLIENT_FORWARD
    fi
    
    if ! iptables -t filter -C FORWARD -j OPENVPN_CLIENT_ACCEPT 2>/dev/null; then
        iptables -t filter -I FORWARD -j OPENVPN_CLIENT_ACCEPT
    fi
    
    # Allow established and related connections
    iptables -t filter -I FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    
    success "All port forwarding rules configured successfully"
}

# Clean up iptables rules
cleanup_forwarding() {
    log "Cleaning up port forwarding rules..."
    
    # Remove our chains from main chains
    iptables -t nat -D PREROUTING -j OPENVPN_CLIENT_FORWARD 2>/dev/null || true
    iptables -t filter -D FORWARD -j OPENVPN_CLIENT_ACCEPT 2>/dev/null || true
    
    # Flush and delete our custom chains
    iptables -t nat -F OPENVPN_CLIENT_FORWARD 2>/dev/null || true
    iptables -t filter -F OPENVPN_CLIENT_ACCEPT 2>/dev/null || true
    iptables -t nat -X OPENVPN_CLIENT_FORWARD 2>/dev/null || true
    iptables -t filter -X OPENVPN_CLIENT_ACCEPT 2>/dev/null || true
    
    success "Port forwarding rules cleaned up successfully"
}

# Main logic
case "$ACTION" in
    "setup")
        if wait_for_interface && get_vpn_client_ip; then
            setup_forwarding
        else
            exit 1
        fi
        ;;
    "cleanup")
        cleanup_forwarding
        ;;
    *)
        error "Unknown action: $ACTION. Use 'setup' or 'cleanup'"
        exit 1
        ;;
esac