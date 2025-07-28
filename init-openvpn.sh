#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOMAIN=${1:-vpn.example.com}
NETWORK=${2:-10.8.0.0}
SERVER_IP=${3:-10.8.0.1}
PORT=${4:-1194}

echo -e "${BLUE}🚀 Initializing OpenVPN P2P Server${NC}"
echo -e "${YELLOW}Domain: $DOMAIN${NC}"
echo -e "${YELLOW}Network: $NETWORK${NC}"
echo -e "${YELLOW}Server IP: $SERVER_IP${NC}"
echo -e "${YELLOW}Port: $PORT${NC}"
echo ""

# Stop any running containers
echo -e "${BLUE}🛑 Stopping existing OpenVPN containers...${NC}"
docker compose down 2>/dev/null || true

# Create volume if it doesn't exist
echo -e "${BLUE}📦 Creating OpenVPN data volume...${NC}"
docker volume create openvpn-data 2>/dev/null || echo "Volume already exists"

# Generate OpenVPN configuration with P2P settings (no internet routing)
echo -e "${BLUE}⚙️  Generating OpenVPN configuration for P2P...${NC}"
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig \
    -u udp://$DOMAIN:$PORT \
    -C AES-256-GCM \
    -a SHA256 \
    -t \
    -z \
    -p "route $NETWORK 255.255.255.0" \
    -p "client-to-client"

echo -e "${GREEN}✅ Configuration generated successfully${NC}"

# Initialize PKI (Public Key Infrastructure) without password for automation
echo -e "${BLUE}🔐 Initializing PKI and creating server certificates...${NC}"
echo -e "${YELLOW}Setting up Certificate Authority without password for easier management${NC}"

docker run -v openvpn-data:/etc/openvpn --rm -e EASYRSA_BATCH=1 -e EASYRSA_REQ_CN="OpenVPN CA" \
    kylemanna/openvpn ovpn_initpki nopass

echo -e "${GREEN}✅ PKI initialized successfully${NC}"

# Verify the setup
echo -e "${BLUE}🔍 Verifying configuration...${NC}"
if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/ovpn_env.sh; then
    echo -e "${GREEN}✅ Environment file created${NC}"
else
    echo -e "${RED}❌ Environment file missing${NC}"
fi

if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/pki/ca.crt; then
    echo -e "${GREEN}✅ Certificate Authority created${NC}"
else
    echo -e "${RED}❌ Certificate Authority missing${NC}"
fi

echo ""
echo -e "${GREEN}🎉 OpenVPN P2P server initialization complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Start server: ${YELLOW}docker compose up -d${NC}"
echo -e "  2. Create client: ${YELLOW}./manage-client.sh <client-name>${NC}"
echo -e "  3. Check status: ${YELLOW}./status-openvpn.sh${NC}"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo -e "  • Clients will be able to communicate with each other"
echo -e "  • Internet traffic will NOT be routed through the VPN"
echo -e "  • Each client will get an IP in the $NETWORK/24 range"