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

echo -e "${BLUE}🔄 OpenVPN Static IP Upgrade Script${NC}"
echo -e "${YELLOW}This script will enable static IP support for existing OpenVPN installations${NC}"
echo ""

# Check if OpenVPN data volume exists
if ! docker volume inspect openvpn-data >/dev/null 2>&1; then
    echo -e "${RED}❌ OpenVPN volume 'openvpn-data' not found${NC}"
    echo -e "${YELLOW}Please run ./init-openvpn.sh first to initialize the server${NC}"
    exit 1
fi

# Check if PKI exists
if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/pki/ca.crt; then
    echo -e "${RED}❌ OpenVPN PKI not initialized${NC}"
    echo -e "${YELLOW}Please run ./init-openvpn.sh first to initialize the server${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Checking current configuration...${NC}"

# Check if client-config-dir is already enabled
if docker run -v openvpn-data:/etc/openvpn --rm alpine grep -q "^client-config-dir" /etc/openvpn/openvpn.conf 2>/dev/null; then
    echo -e "${GREEN}✅ Static IP support already enabled${NC}"
    echo -e "${YELLOW}Current configuration:${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm alpine grep "^client-config-dir" /etc/openvpn/openvpn.conf
else
    echo -e "${YELLOW}⚠️  Static IP support not enabled${NC}"
    echo -e "${BLUE}📝 Enabling static IP support...${NC}"
    
    # Add client-config-dir to OpenVPN configuration
    docker run -v openvpn-data:/etc/openvpn --rm alpine sh -c '
        echo "" >> /etc/openvpn/openvpn.conf
        echo "# Static IP support enabled by upgrade script" >> /etc/openvpn/openvpn.conf
        echo "client-config-dir ccd" >> /etc/openvpn/openvpn.conf
    '
    
    echo -e "${GREEN}✅ Client-config-dir added to configuration${NC}"
fi

# Create CCD directory if it doesn't exist
echo -e "${BLUE}📁 Creating client configuration directory...${NC}"
docker run -v openvpn-data:/etc/openvpn --rm alpine mkdir -p /etc/openvpn/ccd

# Check if .env has static IP configuration
if ! grep -q "ENABLE_STATIC_IPS" .env 2>/dev/null; then
    echo -e "${BLUE}📝 Adding static IP configuration to .env...${NC}"
    cat >> .env << 'EOF'

# Static IP Configuration
ENABLE_STATIC_IPS=true             # Enable client-config-dir for static IPs
STATIC_IP_RANGE_START=10.8.0.50    # Start of static IP range
STATIC_IP_RANGE_END=10.8.0.200     # End of static IP range
DYNAMIC_IP_RANGE_START=10.8.0.10   # Start of dynamic IP range  
DYNAMIC_IP_RANGE_END=10.8.0.49     # End of dynamic IP range
EOF
    echo -e "${GREEN}✅ Static IP configuration added to .env${NC}"
else
    echo -e "${GREEN}✅ Static IP configuration already exists in .env${NC}"
fi

# Check if server is running and restart if needed
if docker compose ps 2>/dev/null | grep -q "running"; then
    echo -e "${BLUE}🔄 Restarting OpenVPN server to apply changes...${NC}"
    docker compose restart
    sleep 3
    
    # Verify server is running
    if docker compose ps 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✅ Server restarted successfully${NC}"
    else
        echo -e "${RED}❌ Server failed to restart${NC}"
        echo -e "${YELLOW}Please check the logs: docker compose logs${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Server not running, start it with: docker compose up -d${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Static IP support upgrade completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Configuration Summary:${NC}"
echo -e "  Static IP Range: ${STATIC_IP_RANGE_START:-10.8.0.50} - ${STATIC_IP_RANGE_END:-10.8.0.200}"
echo -e "  Dynamic IP Range: ${DYNAMIC_IP_RANGE_START:-10.8.0.10} - ${DYNAMIC_IP_RANGE_END:-10.8.0.49}"
echo -e "  VPN Network: ${VPN_NETWORK:-10.8.0.0}/24"
echo ""
echo -e "${YELLOW}📱 Next steps:${NC}"
echo -e "  1. Assign static IP to existing clients:"
echo -e "     ${YELLOW}./manage-client.sh <client-name> set-static-ip <ip-address>${NC}"
echo -e "  2. View static IP assignments:"
echo -e "     ${YELLOW}./manage-client.sh list-static${NC}"
echo -e "  3. Show client's static IP info:"
echo -e "     ${YELLOW}./manage-client.sh <client-name> show-static${NC}"
echo ""
echo -e "${BLUE}ℹ️  Existing clients will continue to work with dynamic IPs${NC}"
echo -e "${BLUE}   until you assign them static IPs${NC}"