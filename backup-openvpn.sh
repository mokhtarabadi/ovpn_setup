#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKUP_DIR=${1:-./backups}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="openvpn_backup_${TIMESTAMP}.tar.gz"

echo -e "${BLUE}💾 OpenVPN Backup Utility${NC}"
echo -e "${YELLOW}Backup directory: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Backup file: $BACKUP_FILE${NC}"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if volume exists
if ! docker volume inspect openvpn-data >/dev/null 2>&1; then
    echo -e "${RED}❌ OpenVPN volume 'openvpn-data' not found${NC}"
    echo -e "${YELLOW}Nothing to backup - run ./init-openvpn.sh first${NC}"
    exit 1
fi

# Check server status
if docker compose ps 2>/dev/null | grep -q "running"; then
    echo -e "${GREEN}✅ OpenVPN server is running - backup will include live data${NC}"
elif docker compose ps 2>/dev/null | grep -q "openvpn"; then
    echo -e "${YELLOW}⚠️  OpenVPN server exists but not running${NC}"
    echo -e "${YELLOW}Backup will include stored data only${NC}"
else
    echo -e "${YELLOW}⚠️  OpenVPN server container not found${NC}"
    echo -e "${YELLOW}Backup will include volume data only${NC}"
fi

echo -e "${BLUE}📦 Creating backup...${NC}"

# Create temporary directory for backup
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy volume data to temporary directory
echo -e "${BLUE}📋 Backing up OpenVPN volume data...${NC}"
docker run --rm -v openvpn-data:/source -v "$TEMP_DIR":/backup alpine sh -c "cd /source && tar czf /backup/openvpn-data.tar.gz ."

# Copy configuration files
echo -e "${BLUE}📄 Backing up configuration files...${NC}"
[ -f docker-compose.yml ] && cp docker-compose.yml "$TEMP_DIR/" || echo "  Warning: docker-compose.yml not found"
[ -f .env ] && cp .env "$TEMP_DIR/" || echo "  Warning: .env not found"
[ -f .env.example ] && cp .env.example "$TEMP_DIR/" || true

# Copy management scripts
echo -e "${BLUE}🔧 Backing up management scripts...${NC}"
for script in *.sh; do
    [ -f "$script" ] && cp "$script" "$TEMP_DIR/" || true
done

# Copy README if it exists
[ -f README.md ] && cp README.md "$TEMP_DIR/" || true

# Create backup info file
echo -e "${BLUE}📝 Creating backup manifest...${NC}"
cat > "$TEMP_DIR/backup_info.txt" << EOF
OpenVPN P2P Backup
==================
Backup Date: $(date)
Backup Type: Full system backup
Server IP: $(grep VPN_DOMAIN .env 2>/dev/null | cut -d= -f2 || echo "Unknown")
Network: $(docker run -v openvpn-data:/etc/openvpn --rm alpine grep "^server " /etc/openvpn/openvpn.conf 2>/dev/null || echo "Unknown")

Contents:
- OpenVPN volume data (certificates, keys, configuration)
- Docker Compose configuration
- Management scripts
- Environment configuration

Restoration Instructions:
1. Extract this backup: tar xzf $BACKUP_FILE
2. Restore volume: docker run --rm -v openvpn-data:/target -v \$(pwd):/backup alpine sh -c 'cd /target && tar xzf /backup/openvpn-data.tar.gz'
3. Start server: docker compose up -d
EOF

# Create final backup archive
echo -e "${BLUE}🗜️  Compressing backup...${NC}"
cd "$TEMP_DIR"
tar czf "$BACKUP_DIR/$BACKUP_FILE" .

echo -e "${GREEN}✅ Backup created successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Backup Information:${NC}"
echo -e "  Location: $BACKUP_DIR/$BACKUP_FILE"
echo -e "  Size: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
echo -e "  Timestamp: $TIMESTAMP"
echo ""
echo -e "${YELLOW}📦 Backup Contents:${NC}"
echo -e "  • OpenVPN certificates and keys"
echo -e "  • Server configuration"
echo -e "  • Docker Compose configuration"
echo -e "  • Environment variables"
echo -e "  • Management scripts"
echo -e "  • README documentation"
echo ""
echo -e "${BLUE}🔄 Restoration Commands:${NC}"
echo -e "  Extract: ${YELLOW}tar xzf $BACKUP_FILE${NC}"
echo -e "  Restore: ${YELLOW}docker run --rm -v openvpn-data:/target -v \$(pwd):/backup alpine sh -c 'cd /target && tar xzf /backup/openvpn-data.tar.gz'${NC}"
echo -e "  Start:   ${YELLOW}docker compose up -d${NC}"

# Clean up old backups (keep last 10)
echo ""
echo -e "${BLUE}🧹 Cleaning up old backups...${NC}"
OLD_BACKUPS=$(ls -t "$BACKUP_DIR"/openvpn_backup_*.tar.gz 2>/dev/null | tail -n +11)
if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | xargs rm -f
    CLEANED_COUNT=$(echo "$OLD_BACKUPS" | wc -l)
    echo -e "${GREEN}✅ Cleaned up $CLEANED_COUNT old backup(s)${NC}"
else
    echo -e "${GREEN}✅ No old backups to clean up${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Backup process completed successfully!${NC}"