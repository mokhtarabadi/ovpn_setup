#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLIENT_CONFIG_FILE="${1}"

show_usage() {
    echo -e "${BLUE}OpenVPN Client with Port Forwarding - Installation Script${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 <client-config.ovpn>"
    echo ""
    echo -e "${YELLOW}Description:${NC}"
    echo -e "  This script installs and configures the OpenVPN client with automatic"
    echo -e "  port forwarding service on the target server."
    echo ""
    echo -e "${YELLOW}Prerequisites:${NC}"
    echo -e "  - Run this script with root privileges (sudo)"
    echo -e "  - OpenVPN client package installed (openvpn)"
    echo -e "  - iptables installed and accessible"
    echo -e "  - The client .ovpn file generated from your OpenVPN server"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo -e "  sudo $0 myclient.ovpn"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
        exit 1
    fi
}

check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
    
    local missing_deps=()
    
    if ! command -v openvpn >/dev/null 2>&1; then
        missing_deps+=("openvpn")
    fi
    
    if ! command -v iptables >/dev/null 2>&1; then
        missing_deps+=("iptables")
    fi
    
    if ! command -v systemctl >/dev/null 2>&1; then
        missing_deps+=("systemd")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required dependencies:${NC}"
        printf "   - %s\n" "${missing_deps[@]}"
        echo ""
        echo -e "${YELLOW}Install them first:${NC}"
        echo -e "  Ubuntu/Debian: apt update && apt install openvpn iptables systemd"
        echo -e "  CentOS/RHEL:   yum install openvpn iptables systemd"
        echo -e "  Fedora:        dnf install openvpn iptables systemd"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies are available${NC}"
}

install_service_files() {
    echo -e "${BLUE}📁 Creating directory structure...${NC}"
    
    # Create directories
    mkdir -p /etc/openvpn/client
    mkdir -p /etc/systemd/system
    
    echo -e "${BLUE}📋 Installing service files...${NC}"
    
    # Copy service files
    cp "openvpn-client-forwarding.service" "/etc/systemd/system/"
    cp "setup-port-forwarding.sh" "/etc/openvpn/client/"
    cp "openvpn-client-forwarding.env" "/etc/openvpn/client/"
    
    # Copy OpenVPN client configuration
    if [[ -n "$CLIENT_CONFIG_FILE" && -f "$CLIENT_CONFIG_FILE" ]]; then
        cp "$CLIENT_CONFIG_FILE" "/etc/openvpn/client/client.ovpn"
        echo -e "${GREEN}✅ OpenVPN client config installed: /etc/openvpn/client/client.ovpn${NC}"
    else
        echo -e "${YELLOW}⚠️  No client config provided. You'll need to place your .ovpn file at /etc/openvpn/client/client.ovpn${NC}"
    fi
    
    # Set permissions
    chmod +x /etc/openvpn/client/setup-port-forwarding.sh
    chmod 600 /etc/openvpn/client/client.ovpn 2>/dev/null || true
    chmod 644 /etc/openvpn/client/openvpn-client-forwarding.env
    chmod 644 /etc/systemd/system/openvpn-client-forwarding.service
    
    echo -e "${GREEN}✅ Service files installed successfully${NC}"
}

configure_service() {
    echo -e "${BLUE}🔧 Configuring systemd service...${NC}"
    
    # Reload systemd to recognize the new service
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ Service configured${NC}"
    
    echo -e "${YELLOW}📝 Configuration file location: /etc/openvpn/client/openvpn-client-forwarding.env${NC}"
    echo -e "${YELLOW}📝 You can edit this file to customize ports and settings${NC}"
}

show_next_steps() {
    echo ""
    echo -e "${BLUE}🎉 Installation completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo ""
    echo -e "${BLUE}1. Edit the configuration file:${NC}"
    echo -e "   sudo nano /etc/openvpn/client/openvpn-client-forwarding.env"
    echo ""
    echo -e "${BLUE}2. Verify your OpenVPN client config is present:${NC}"
    echo -e "   sudo ls -la /etc/openvpn/client/client.ovpn"
    echo ""
    echo -e "${BLUE}3. Enable the service to start on boot (optional):${NC}"
    echo -e "   sudo systemctl enable openvpn-client-forwarding"
    echo ""
    echo -e "${BLUE}4. Start the service:${NC}"
    echo -e "   sudo systemctl start openvpn-client-forwarding"
    echo ""
    echo -e "${BLUE}5. Check service status:${NC}"
    echo -e "   sudo systemctl status openvpn-client-forwarding"
    echo ""
    echo -e "${BLUE}6. View service logs:${NC}"
    echo -e "   sudo journalctl -u openvpn-client-forwarding -f"
    echo ""
    echo -e "${BLUE}7. Stop the service when not needed:${NC}"
    echo -e "   sudo systemctl stop openvpn-client-forwarding"
    echo ""
    echo -e "${YELLOW}⚠️  Remember to configure your ports in the .env file before starting!${NC}"
}

# Main installation process
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    echo -e "${BLUE}🚀 OpenVPN Client with Port Forwarding - Installation${NC}"
    echo ""
    
    check_root
    check_dependencies
    install_service_files
    configure_service
    show_next_steps
    
    echo -e "${GREEN}✅ Installation completed successfully!${NC}"
}

main "$@"