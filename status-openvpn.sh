#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 OpenVPN Server Status${NC}"
echo "================================"

# Check if docker compose is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠️  docker compose not found, checking docker-compose...${NC}"
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Neither 'docker compose' nor 'docker-compose' found${NC}"
        exit 1
    fi
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

# Volume Status
echo -e "${BLUE}💾 Volume Status:${NC}"
if docker volume inspect openvpn-data >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ OpenVPN volume exists${NC}"
    VOLUME_SIZE=$(docker run -v openvpn-data:/data --rm alpine du -sh /data 2>/dev/null | cut -f1 || echo "Unknown")
    echo -e "     Size: $VOLUME_SIZE"
else
    echo -e "  ${RED}❌ OpenVPN volume missing${NC}"
    echo -e "     ${YELLOW}Run ./init-openvpn.sh to initialize${NC}"
fi

echo ""

# PKI Status
echo -e "${BLUE}🔐 PKI Status:${NC}"
if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/pki/ca.crt 2>/dev/null; then
    echo -e "  ${GREEN}✅ Certificate Authority initialized${NC}"
    
    # Get CA expiry
    CA_EXPIRY=$(docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn openssl x509 -in /etc/openvpn/pki/ca.crt -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2 || echo "Unknown")
    echo -e "     CA expires: $CA_EXPIRY"
else
    echo -e "  ${RED}❌ PKI not initialized${NC}"
    echo -e "     ${YELLOW}Run ./init-openvpn.sh to initialize${NC}"
fi

echo ""

# Container Status
echo -e "${BLUE}🐳 Container Status:${NC}"
COMPOSE_OUTPUT=$($COMPOSE_CMD ps 2>/dev/null)
if echo "$COMPOSE_OUTPUT" | grep -q "openvpn"; then
    if echo "$COMPOSE_OUTPUT" | grep "openvpn" | grep -q "Up"; then
        echo -e "  ${GREEN}✅ OpenVPN container is running${NC}"
        
        # Get container details
        CONTAINER_ID=$($COMPOSE_CMD ps -q openvpn 2>/dev/null)
        if [ -n "$CONTAINER_ID" ]; then
            UPTIME=$(docker inspect $CONTAINER_ID --format='{{.State.StartedAt}}' 2>/dev/null | xargs -I {} date -d {} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
            echo -e "     Started: $UPTIME"
        fi
        
        # Resource usage
        echo -e "${BLUE}💾 Resource Usage:${NC}"
        docker exec openvpn-server sh -c "
            echo '  🖥️  CPU: '$(top -bn1 | grep '^CPU:' | awk '{print $2}' | sed 's/%us,//')' user'
            echo '  🧠 Memory: '$(free -h | awk '/^Mem:/ {print $3 \"/\" $2}')
            echo '  💽 Disk: '$(df -h /etc/openvpn | awk 'NR==2 {print $3 \"/\" $2 \" (\" $5 \" used)\"}')
        " 2>/dev/null || echo -e "  ${YELLOW}⚠️  Resource info unavailable${NC}"
    else
        echo -e "  ${YELLOW}⚠️  OpenVPN container exists but not running${NC}"
        echo -e "     ${YELLOW}Start with: $COMPOSE_CMD up -d${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  OpenVPN container not found${NC}"
    echo -e "     ${YELLOW}Start with: $COMPOSE_CMD up -d${NC}"
fi

echo ""

# Network Configuration
echo -e "${BLUE}🌐 Network Configuration:${NC}"
if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/openvpn.conf 2>/dev/null; then
    echo -e "  ${GREEN}✅ Server configuration exists${NC}"
    
    # Get network info from config
    SERVER_CONFIG=$(docker run -v openvpn-data:/etc/openvpn --rm alpine cat /etc/openvpn/openvpn.conf 2>/dev/null || echo "Config not accessible")
    
    echo -e "     Server Config:"
    echo "$SERVER_CONFIG" | grep -E "(port |proto |server )" | sed 's/^/       /' 2>/dev/null || echo "       Config details not accessible"
    
    # Check port accessibility
    PORT=$($COMPOSE_CMD ps 2>/dev/null | grep openvpn | grep -o '1194\|443\|[0-9]*194' | head -1 || echo "1194")
    echo -e "     Port Status:"
    if netstat -tuln 2>/dev/null | grep -q ":${PORT:-1194}"; then
        echo -e "       ${GREEN}✅ Port ${PORT:-1194}/UDP is listening${NC}"
    else
        echo -e "       ${YELLOW}⚠️  Port ${PORT:-1194}/UDP status unclear${NC}"
    fi
else
    echo -e "  ${RED}❌ Server configuration missing${NC}"
fi

echo ""

# Client Status
echo -e "${BLUE}👥 Client Information:${NC}"
if docker run -v openvpn-data:/etc/openvpn --rm alpine test -d /etc/openvpn/pki/issued 2>/dev/null; then
    # Count active certificates
    ACTIVE_CLIENTS=$(docker run -v openvpn-data:/etc/openvpn --rm alpine find /etc/openvpn/pki/issued -name "*.crt" -exec basename {} \; 2>/dev/null | sed 's/\.crt$//' | grep -v "^server$" | wc -l)
    echo -e "     Active Certificates: $ACTIVE_CLIENTS"
    
    # Show recent clients
    if [ "$ACTIVE_CLIENTS" -gt 0 ]; then
        echo -e "     Recent Clients:"
        docker run -v openvpn-data:/etc/openvpn --rm alpine find /etc/openvpn/pki/issued -name "*.crt" -not -name "server.crt" -exec basename {} .crt \; 2>/dev/null | head -5 | sed 's/^/       - /'
    fi
    
    # Connected clients (this requires OpenVPN management interface, which isn't enabled by default)
    echo -e "     Currently Connected: ${YELLOW}N/A (management interface not enabled)${NC}"
else
    echo -e "  ${RED}❌ Cannot check clients - PKI not initialized${NC}"
fi

echo ""

# Security Status
echo -e "${BLUE}🔒 Security Status:${NC}"
if docker run -v openvpn-data:/etc/openvpn --rm alpine test -f /etc/openvpn/openvpn.conf 2>/dev/null; then
    echo -e "     Security Features:"
    
    # Check for TLS auth
    if docker run -v openvpn-data:/etc/openvpn --rm alpine grep -q "tls-crypt\|tls-auth" /etc/openvpn/openvpn.conf 2>/dev/null; then
        echo -e "       ${GREEN}✅ TLS authentication enabled${NC}"
    else
        echo -e "       ${YELLOW}⚠️  TLS authentication status unknown${NC}"
    fi
    
    # Check for client-to-client
    if docker run -v openvpn-data:/etc/openvpn --rm alpine grep -q "client-to-client" /etc/openvpn/openvpn.conf 2>/dev/null; then
        echo -e "       ${GREEN}✅ Client-to-client communication enabled${NC}"
    else
        echo -e "       ${YELLOW}⚠️  Client-to-client status unknown${NC}"
    fi
    
    # Check for redirect-gateway (should NOT be present for P2P)
    if ! docker run -v openvpn-data:/etc/openvpn --rm alpine grep -q "redirect-gateway" /etc/openvpn/openvpn.conf 2>/dev/null; then
        echo -e "       ${GREEN}✅ No internet routing (P2P only)${NC}"
    else
        echo -e "       ${YELLOW}⚠️  Internet routing may be enabled${NC}"
    fi
else
    echo -e "  ${RED}❌ Cannot check security - configuration missing${NC}"
fi

echo ""

# Recent Logs (if container is running)
echo -e "${BLUE}📋 Recent Activity:${NC}"
if echo "$COMPOSE_OUTPUT" | grep "openvpn" | grep -q "Up"; then
    echo -e "     Last 5 log entries:"
    $COMPOSE_CMD logs --tail=5 openvpn 2>/dev/null | sed 's/^/       /' || echo "       No logs available"
else
    echo -e "  ${YELLOW}⚠️  No logs available - container not running${NC}"
fi

echo ""
echo "================================"
echo -e "${BLUE}💡 Quick Commands:${NC}"
echo -e "  Start server:   ${YELLOW}$COMPOSE_CMD up -d${NC}"
echo -e "  Stop server:    ${YELLOW}$COMPOSE_CMD down${NC}"
echo -e "  View logs:      ${YELLOW}$COMPOSE_CMD logs -f${NC}"
echo -e "  Add client:     ${YELLOW}./manage-client.sh <name>${NC}"
echo -e "  List clients:   ${YELLOW}./manage-client.sh list${NC}"
echo -e "  Create backup:  ${YELLOW}./backup-openvpn.sh${NC}"
echo -e "  Initialize:     ${YELLOW}./init-openvpn.sh <domain>${NC}"