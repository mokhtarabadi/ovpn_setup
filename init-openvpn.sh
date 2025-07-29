#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Store environment variables before sourcing .env
ENV_TUN_DEVICE_NAME=${TUN_DEVICE_NAME}
ENV_ENABLE_COMPRESSION=${ENABLE_COMPRESSION}

# Load configuration from .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Default values (can be overridden by command line arguments or environment variables)
DOMAIN=${1:-${VPN_DOMAIN:-vpn.example.com}}
NETWORK=${2:-${VPN_NETWORK:-10.8.0.0}}
SERVER_IP=${3:-${VPN_SERVER_IP:-10.8.0.1}}
PORT=${4:-${OPENVPN_PORT:-1194}}
PROTOCOL=${5:-${OPENVPN_PROTOCOL:-udp}}

# Restore environment variables with proper precedence (env vars > .env > defaults)
DEVICE_NAME=${ENV_TUN_DEVICE_NAME:-${TUN_DEVICE_NAME:-tun0}}
COMPRESSION=${ENV_ENABLE_COMPRESSION:-${ENABLE_COMPRESSION:-false}}

# Validate protocol
if [[ "$PROTOCOL" != "udp" && "$PROTOCOL" != "tcp" ]]; then
    echo -e "${RED}❌ Invalid protocol: $PROTOCOL${NC}"
    echo -e "${YELLOW}Valid protocols: udp, tcp${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Initializing OpenVPN P2P Server${NC}"
echo -e "${YELLOW}Domain: $DOMAIN${NC}"
echo -e "${YELLOW}Protocol: $PROTOCOL${NC}"
echo -e "${YELLOW}Port: $PORT${NC}"
echo -e "${YELLOW}Network: $NETWORK${NC}"
echo -e "${YELLOW}Server IP: $SERVER_IP${NC}"
echo -e "${YELLOW}Device Name: $DEVICE_NAME${NC}"
echo -e "${YELLOW}Compression: $COMPRESSION${NC}"
echo ""

# Protocol-specific information
if [ "$PROTOCOL" = "tcp" ]; then
    echo -e "${BLUE}ℹ️  TCP Mode: Better for restrictive networks/firewalls${NC}"
    echo -e "${YELLOW}   • More reliable connection${NC}"
    echo -e "${YELLOW}   • Works through HTTP proxies${NC}"
    echo -e "${YELLOW}   • Slightly higher latency${NC}"
else
    echo -e "${BLUE}ℹ️  UDP Mode: Default OpenVPN protocol${NC}"
    echo -e "${YELLOW}   • Faster performance${NC}"
    echo -e "${YELLOW}   • Better for gaming/streaming${NC}"
    echo -e "${YELLOW}   • Lower latency${NC}"
fi
echo ""

# Stop any running containers
echo -e "${BLUE}🛑 Stopping existing OpenVPN containers...${NC}"
docker compose down 2>/dev/null || true

# Generate OpenVPN configuration with the specified protocol
echo -e "${BLUE}⚙️  Generating OpenVPN configuration for P2P ($PROTOCOL)...${NC}"
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u $PROTOCOL://$DOMAIN:$PORT -s $NETWORK/24 -d

echo -e "${GREEN}✅ Configuration generated successfully${NC}"

# Customize device name and compression settings
echo -e "${BLUE}🔧 Customizing device and compression settings...${NC}"

# Set custom TUN device name
if [ "$DEVICE_NAME" != "tun0" ]; then
    echo -e "${YELLOW}   • Setting device name to: $DEVICE_NAME${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c "
        sed -i 's/^dev tun0$/dev $DEVICE_NAME/' /etc/openvpn/openvpn.conf
    "
fi

# Configure server port
if [ "$PORT" != "1194" ]; then
    echo -e "${YELLOW}   • Setting server port to: $PORT${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c "
        sed -i 's/^port 1194$/port $PORT/' /etc/openvpn/openvpn.conf
    "
fi

# Configure compression settings
if [ "${COMPRESSION,,}" = "true" ]; then
    echo -e "${YELLOW}   • Enabling compression${NC}"
    docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c '
        sed -i "/^comp-lzo no/d" /etc/openvpn/openvpn.conf
        echo "comp-lzo" >> /etc/openvpn/openvpn.conf
    '
else
    echo -e "${YELLOW}   • Compression disabled (default)${NC}"
fi

# Initialize PKI (Public Key Infrastructure) without password for automation
echo -e "${BLUE}🔐 Initializing PKI and creating server certificates...${NC}"
echo -e "${YELLOW}Setting up Certificate Authority without password for easier management${NC}"

docker run -v openvpn-data:/etc/openvpn --rm -e EASYRSA_BATCH=1 -e EASYRSA_REQ_CN="OpenVPN CA" \
    kylemanna/openvpn ovpn_initpki nopass

echo -e "${GREEN}✅ PKI initialized successfully${NC}"

# Configure for P2P communication (no internet routing)
echo -e "${BLUE}🔧 Configuring for P2P communication...${NC}"

# Check if duplicate-cn should be enabled
DUPLICATE_CN_CONFIG=""
if [ "${ALLOW_DUPLICATE_CN,,}" = "true" ]; then
    DUPLICATE_CN_CONFIG='echo "duplicate-cn" >> /etc/openvpn/openvpn.conf'
    echo -e "${YELLOW}   • Multiple connections per certificate: ENABLED${NC}"
    echo -e "${YELLOW}   • Users can connect from multiple devices with same certificate${NC}"
else
    echo -e "${YELLOW}   • Multiple connections per certificate: DISABLED${NC}"
    echo -e "${YELLOW}   • One connection per certificate (more secure)${NC}"
fi

# Simplify subnet mask calculation and use /24 subnet
VPN_NETADDR="$NETWORK"
VPN_NETMASK="255.255.255.0"

docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn sh -c '
    sed -i "/^push.*redirect-gateway/d" /etc/openvpn/openvpn.conf
    sed -i "/^push.*dhcp-option.*DOMAIN/d" /etc/openvpn/openvpn.conf
    echo "client-to-client" >> /etc/openvpn/openvpn.conf
    '"$DUPLICATE_CN_CONFIG"'
    echo "push \"route '"$VPN_NETADDR"' '"$VPN_NETMASK"'\"" >> /etc/openvpn/openvpn.conf
'

echo -e "${GREEN}✅ P2P configuration applied${NC}"

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

# Display protocol-specific configuration
echo -e "${BLUE}🔍 Configuration Details:${NC}"
PROTO_CHECK=$(docker run -v openvpn-data:/etc/openvpn --rm alpine grep "^proto " /etc/openvpn/openvpn.conf 2>/dev/null || echo "proto $PROTOCOL")
PORT_CHECK=$(docker run -v openvpn-data:/etc/openvpn --rm alpine grep "^port " /etc/openvpn/openvpn.conf 2>/dev/null || echo "port $PORT")
echo -e "${YELLOW}   • $PROTO_CHECK${NC}"
echo -e "${YELLOW}   • $PORT_CHECK${NC}"

echo ""
echo -e "${GREEN}🎉 OpenVPN P2P server initialization complete!${NC}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Start server: ${YELLOW}docker compose up -d${NC}"
echo -e "  2. Create client: ${YELLOW}./manage-client.sh <client-name>${NC}"
echo -e "  3. Check status: ${YELLOW}./status-openvpn.sh${NC}"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo -e "  • Protocol: $PROTOCOL on port $PORT"
echo -e "  • Clients will be able to communicate with each other"
echo -e "  • Internet traffic will NOT be routed through the VPN"
echo -e "  • Each client will get an IP in the $NETWORK/24 range"
echo -e "  • Host services accessible at 10.8.0.1 via host networking"