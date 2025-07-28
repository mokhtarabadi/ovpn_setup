#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 OpenVPN Setup Validation${NC}"
echo "=============================="

ERRORS=0
WARNINGS=0

check_requirement() {
    local name=$1
    local command=$2
    local error_msg=$3
    
    if eval "$command" &>/dev/null; then
        echo -e "  ${GREEN}✅ $name${NC}"
    else
        echo -e "  ${RED}❌ $name${NC}"
        echo -e "    ${RED}$error_msg${NC}"
        ((ERRORS++))
    fi
}

check_warning() {
    local name=$1
    local command=$2
    local warning_msg=$3
    
    if eval "$command" &>/dev/null; then
        echo -e "  ${GREEN}✅ $name${NC}"
    else
        echo -e "  ${YELLOW}⚠️  $name${NC}"
        echo -e "    ${YELLOW}$warning_msg${NC}"
        ((WARNINGS++))
    fi
}

# System Requirements
echo -e "${BLUE}🖥️  System Requirements:${NC}"
check_requirement "Docker installed" "command -v docker" "Install Docker: https://docs.docker.com/get-docker/"
check_requirement "Docker Compose installed" "[ -n \"\$(docker compose version 2>/dev/null)\" ] || [ -n \"\$(command -v docker-compose 2>/dev/null)\" ]" "Install Docker Compose: https://docs.docker.com/compose/install/"
check_requirement "Docker daemon running" "docker info" "Start Docker daemon: sudo systemctl start docker"
check_requirement "User can run Docker" "docker ps" "Add user to docker group: sudo usermod -aG docker \$USER"

echo ""

# File Structure
echo -e "${BLUE}📁 File Structure:${NC}"
check_requirement "docker-compose.yml exists" "test -f docker-compose.yml" "File is missing or corrupted"
check_requirement "init-openvpn.sh exists" "test -f init-openvpn.sh" "File is missing or corrupted"
check_requirement "manage-client.sh exists" "test -f manage-client.sh" "File is missing or corrupted"
check_requirement "backup-openvpn.sh exists" "test -f backup-openvpn.sh" "File is missing or corrupted"
check_requirement "status-openvpn.sh exists" "test -f status-openvpn.sh" "File is missing or corrupted"
check_requirement ".env.example exists" "test -f .env.example" "File is missing"

echo ""

# File Permissions
echo -e "${BLUE}🔐 File Permissions:${NC}"
check_requirement "init-openvpn.sh executable" "test -x init-openvpn.sh" "Run: chmod +x init-openvpn.sh"
check_requirement "manage-client.sh executable" "test -x manage-client.sh" "Run: chmod +x manage-client.sh"
check_requirement "backup-openvpn.sh executable" "test -x backup-openvpn.sh" "Run: chmod +x backup-openvpn.sh"
check_requirement "status-openvpn.sh executable" "test -x status-openvpn.sh" "Run: chmod +x status-openvpn.sh"

echo ""

# Network Configuration
echo -e "${BLUE}🌐 Network Configuration:${NC}"
check_warning "Port 1194/UDP available" "! netstat -tuln 2>/dev/null | grep -q ':1194 '" "Port 1194 may be in use. Consider using alternative port."
check_warning "IP forwarding enabled" "sysctl net.ipv4.ip_forward | grep -q '1'" "Enable with: sudo sysctl net.ipv4.ip_forward=1"
check_warning "TUN module available" "test -e /dev/net/tun || lsmod | grep -q tun" "Load TUN module: sudo modprobe tun"

echo ""

# Environment Configuration
echo -e "${BLUE}⚙️  Environment Configuration:${NC}"
if [ -f .env ]; then
    echo -e "  ${GREEN}✅ .env file exists${NC}"
    
    # Check required variables
    if grep -q "VPN_DOMAIN=" .env && ! grep -q "VPN_DOMAIN=your-server.example.com" .env; then
        echo -e "  ${GREEN}✅ VPN_DOMAIN configured${NC}"
    else
        echo -e "  ${YELLOW}⚠️  VPN_DOMAIN not configured${NC}"
        echo -e "    ${YELLOW}Edit .env and set your server domain or IP${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "  ${YELLOW}⚠️  .env file missing${NC}"
    echo -e "    ${YELLOW}Copy .env.example to .env and configure: cp .env.example .env${NC}"
    ((WARNINGS++))
fi

echo ""

# Docker Image Availability
echo -e "${BLUE}🐳 Docker Image:${NC}"
check_requirement "Can pull kylemanna/openvpn" "docker pull kylemanna/openvpn:latest" "Check internet connection and Docker registry access"

echo ""

# Configuration Validation
echo -e "${BLUE}📋 Configuration Validation:${NC}"
if [ -f docker-compose.yml ]; then
    if [ -n "$(docker compose version 2>/dev/null)" ]; then
        COMPOSE_CMD="docker compose"
    elif [ -n "$(command -v docker-compose 2>/dev/null)" ]; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "  ${RED}❌ Docker Compose not available${NC}"
        ((ERRORS++))
        COMPOSE_CMD=""
    fi

    if [ -n "$COMPOSE_CMD" ]; then
        if $COMPOSE_CMD config &>/dev/null; then
            echo -e "  ${GREEN}✅ docker-compose.yml syntax valid${NC}"
        else
            echo -e "  ${RED}❌ docker-compose.yml syntax invalid${NC}"
            echo -e "    ${RED}Run: $COMPOSE_CMD config${NC}"
            ((ERRORS++))
        fi
    fi
fi

echo ""

# Security Checks
echo -e "${BLUE}🔒 Security Considerations:${NC}"
if [ "$(id -u)" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  Running as root${NC}"
    echo -e "    ${YELLOW}Consider running as non-root user after setup${NC}"
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ Not running as root${NC}"
fi

# Check for existing certificates (shouldn't exist on fresh install)
if docker volume inspect openvpn-data &>/dev/null; then
    echo -e "  ${YELLOW}⚠️  OpenVPN volume already exists${NC}"
    echo -e "    ${YELLOW}This may be from a previous installation${NC}"
    ((WARNINGS++))
else
    echo -e "  ${GREEN}✅ Clean installation (no existing volume)${NC}"
fi

echo ""
echo "=============================="

# Summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 Setup validation passed! You're ready to initialize OpenVPN.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Configure .env file with your domain: ${YELLOW}cp .env.example .env && nano .env${NC}"
    echo -e "  2. Initialize OpenVPN server: ${YELLOW}./init-openvpn.sh your-domain.com${NC}"
    echo -e "  3. Create client certificates: ${YELLOW}./manage-client.sh username${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Setup validation completed with $WARNINGS warning(s).${NC}"
    echo -e "${YELLOW}You can proceed, but consider addressing the warnings above.${NC}"
    echo ""
    echo -e "${BLUE}To proceed anyway:${NC}"
    echo -e "  1. ./init-openvpn.sh your-domain.com"
    echo -e "  2. ./manage-client.sh username"
else
    echo -e "${RED}❌ Setup validation failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo -e "${RED}Please fix the errors above before proceeding.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📚 Documentation: see README.md for detailed instructions${NC}"