#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}⚠️  configure-host-access.sh is DEPRECATED${NC}"
echo ""
echo -e "${BLUE}📢 This script has been replaced with a new VPN port forwarding system${NC}"
echo ""
echo -e "${YELLOW}New approach:${NC}"
echo -e "  • Access host services directly via VPN server IP (e.g., http://10.8.0.1:80)"
echo -e "  • Configure ports in .env file: VPN_FORWARD_PORTS=80,443,8080,3000"
echo -e "  • Use: ${GREEN}./manage-vpn-forwarding.sh${NC} to manage port forwarding"
echo ""
echo -e "${YELLOW}Benefits:${NC}"
echo -e "  • No IP conflicts (no need to remember 172.17.0.1)"
echo -e "  • Dynamic port management"
echo -e "  • Simpler user experience"
echo ""
echo -e "${BLUE}Migration steps:${NC}"
echo -e "  1. Add to .env: ${YELLOW}VPN_FORWARD_PORTS=80,443,8080${NC}"
echo -e "  2. Run: ${YELLOW}sudo ./manage-vpn-forwarding.sh${NC}"
echo -e "  3. Access services at: ${YELLOW}http://10.8.0.1:PORT${NC}"
echo ""
echo -e "${RED}This old script will be removed in a future version.${NC}"