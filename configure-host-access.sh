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

# Default host IP (Docker bridge gateway)
HOST_IP=${HOST_IP:-172.17.0.1}

echo -e "${BLUE}🏠 Configuring OpenVPN host access...${NC}"
echo -e "${YELLOW}Host IP: $HOST_IP${NC}"

# Check if OpenVPN volume exists
if ! docker volume inspect openvpn-data >/dev/null 2>&1; then
    echo -e "${RED}❌ OpenVPN volume 'openvpn-data' not found${NC}"
    echo -e "${YELLOW}Run ./init-openvpn.sh first to initialize the server${NC}"
    exit 1
fi

# Check if OpenVPN configuration exists
if ! docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/openvpn.conf; then
    echo -e "${RED}❌ OpenVPN configuration not found${NC}"
    echo -e "${YELLOW}Run ./init-openvpn.sh first to initialize the server${NC}"
    exit 1
fi

# Auto-detect Docker bridge IP if HOST_IP is default
if [ "$HOST_IP" = "172.17.0.1" ]; then
    echo -e "${BLUE}🔍 Auto-detecting Docker bridge IP...${NC}"
    DETECTED_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "")
    if [ -n "$DETECTED_IP" ] && [ "$DETECTED_IP" != "$HOST_IP" ]; then
        echo -e "${YELLOW}⚠️  Detected Docker bridge IP: $DETECTED_IP (different from configured: $HOST_IP)${NC}"
        HOST_IP="$DETECTED_IP"
        echo -e "${BLUE}Using detected IP: $HOST_IP${NC}"
    else
        echo -e "${GREEN}✅ Using configured Docker bridge IP: $HOST_IP${NC}"
    fi
fi

# Remove existing host access routes to avoid duplicates
echo -e "${BLUE}🧹 Removing existing host access routes...${NC}"
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c '
    sed -i "/^push.*route.*172\.17\./d" /etc/openvpn/openvpn.conf
    sed -i "/# Host access routes/d" /etc/openvpn/openvpn.conf
'

# Add host access routes
echo -e "${BLUE}📝 Adding host access routes...${NC}"
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c '
    echo "" >> /etc/openvpn/openvpn.conf
    echo "# Host access routes" >> /etc/openvpn/openvpn.conf
    echo "push \"route '"$HOST_IP"' 255.255.255.255\"" >> /etc/openvpn/openvpn.conf
    echo "push \"route 172.17.0.0 255.255.0.0\"" >> /etc/openvpn/openvpn.conf
'

# Verify configuration
echo -e "${BLUE}🔍 Verifying host access configuration...${NC}"
ROUTE_COUNT=$(docker run -v openvpn-data:/etc/openvpn --rm alpine grep -c "push.*route.*172\.17\." /etc/openvpn/openvpn.conf 2>/dev/null || echo "0")

if [ "$ROUTE_COUNT" -eq "2" ]; then
    echo -e "${GREEN}✅ Host access routes configured successfully${NC}"
    echo -e "${YELLOW}   • Host IP route: $HOST_IP/32${NC}"
    echo -e "${YELLOW}   • Bridge network route: 172.17.0.0/16${NC}"
else
    echo -e "${RED}❌ Failed to configure host access routes${NC}"
    exit 1
fi

# Show current routes
echo -e "${BLUE}📋 Current push routes in OpenVPN configuration:${NC}"
docker run -v openvpn-data:/etc/openvpn --rm alpine grep "^push.*route" /etc/openvpn/openvpn.conf | sed 's/^/  /'

echo ""
echo -e "${GREEN}🎉 Host access configuration complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. ${YELLOW}Restart OpenVPN server:${NC} docker compose restart"
echo -e "  2. ${YELLOW}Reconnect VPN clients${NC} to receive new routes"
echo -e "  3. ${YELLOW}Test connectivity:${NC} ping $HOST_IP from VPN client"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo -e "  • VPN clients can now access host services at $HOST_IP"
echo -e "  • Docker bridge network (172.17.0.0/16) is accessible"
echo -e "  • Existing P2P functionality is preserved"