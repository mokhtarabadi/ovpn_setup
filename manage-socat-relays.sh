#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"
SCRIPT_NAME="OpenVPN Socat Relay Manager"

# Configuration paths
CONFIG_FILE=".env.socat"
INSTALL_CONFIG_FILE="/etc/socat-vpn-relay/config"
SYSTEMD_SERVICE_PATH="/etc/systemd/system"
SYSTEMD_TEMPLATE="socat-vpn-relay@.service"
MANAGER_SERVICE="socat-vpn-relay-manager.service"
INSTALL_PATH="/usr/local/bin"
SCRIPT_INSTALL_NAME="manage-socat-relays"

# Default configuration
DEFAULT_VPN_IP=""
DEFAULT_LOCALHOST_IP="127.0.0.1"
DEFAULT_PORTS="3000:HTTP_Development_Server"
DEFAULT_RESTART_POLICY="always"
DEFAULT_RESTART_DELAY="10"
DEFAULT_USER="nobody"

ACTION=${1:-help}

show_usage() {
    echo -e "${BLUE}$SCRIPT_NAME v$VERSION${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 <action> [options]"
    echo ""
    echo -e "${YELLOW}Actions:${NC}"
    echo -e "  install         - Install socat relay service system-wide"
    echo -e "  uninstall       - Remove socat relay service from system"
    echo -e "  start           - Start all socat relay services"
    echo -e "  stop            - Stop all socat relay services"
    echo -e "  restart         - Restart all socat relay services"
    echo -e "  status          - Show status of all socat relay services"
    echo -e "  enable          - Enable auto-start on boot"
    echo -e "  disable         - Disable auto-start on boot"
    echo -e "  config          - Show current configuration"
    echo -e "  ufw-rules       - Show UFW rules needed for configured ports"
    echo -e "  remove-ufw-rules - Remove UFW rules created for configured ports"
    echo -e "  logs            - Show service logs"
    echo -e "  help            - Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 install              # Install service system-wide"
    echo -e "  $0 start                # Start all relay services"
    echo -e "  $0 status               # Check status"
    echo -e "  $0 ufw-rules            # Show required firewall rules"
    echo -e "  $0 remove-ufw-rules     # Remove firewall rules"
    echo -e "  $0 logs                 # View service logs"
}

load_config() {
    local config_file="$1"
    
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo -e "${YELLOW}⚠️  Configuration file not found: $config_file${NC}"
        echo -e "${YELLOW}Using default configuration${NC}"
    fi
    
    # Set defaults if not defined
    SOCAT_VPN_IP=${SOCAT_VPN_IP:-$DEFAULT_VPN_IP}
    SOCAT_LOCALHOST_IP=${SOCAT_LOCALHOST_IP:-$DEFAULT_LOCALHOST_IP}
    SOCAT_PORTS=${SOCAT_PORTS:-$DEFAULT_PORTS}
    SOCAT_RESTART_POLICY=${SOCAT_RESTART_POLICY:-$DEFAULT_RESTART_POLICY}
    SOCAT_RESTART_DELAY=${SOCAT_RESTART_DELAY:-$DEFAULT_RESTART_DELAY}
    SOCAT_USER=${SOCAT_USER:-$DEFAULT_USER}
    SOCAT_LOG_LEVEL=${SOCAT_LOG_LEVEL:-notice}
    SOCAT_ENABLE_LOGGING=${SOCAT_ENABLE_LOGGING:-true}
    SOCAT_FORK=${SOCAT_FORK:-true}
    SOCAT_REUSEADDR=${SOCAT_REUSEADDR:-true}
    SOCAT_KEEPALIVE=${SOCAT_KEEPALIVE:-false}
    SOCAT_AUTO_UFW_RULES=${SOCAT_AUTO_UFW_RULES:-true}
    SOCAT_UFW_COMMENT_PREFIX=${SOCAT_UFW_COMMENT_PREFIX:-"VPN Relay"}
}

get_vpn_ip() {
    if [ -n "$SOCAT_VPN_IP" ]; then
        echo "$SOCAT_VPN_IP"
    else
        # Auto-detect VPN IP from tun interface
        local vpn_ip=$(ip addr show | grep -E "tun[0-9]" -A 2 | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
        if [ -n "$vpn_ip" ]; then
            echo "$vpn_ip"
        else
            echo -e "${RED}❌ Cannot detect VPN IP. Please set SOCAT_VPN_IP in $CONFIG_FILE${NC}"
            exit 1
        fi
    fi
}

parse_ports() {
    local ports_config="$1"
    echo "$ports_config" | tr ',' '\n' | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1 | xargs)
            local description=$(echo "$port_config" | cut -d':' -f2- | xargs)
            echo "$port:$description"
        fi
    done
}

check_dependencies() {
    if ! command -v socat &> /dev/null; then
        echo -e "${RED}❌ socat not found${NC}"
        echo -e "${YELLOW}Install with: sudo apt install socat   # or   sudo yum install socat${NC}"
        exit 1
    fi
    
    if ! command -v systemctl &> /dev/null; then
        echo -e "${RED}❌ systemd not found${NC}"
        echo -e "${YELLOW}This script requires systemd${NC}"
        exit 1
    fi
}

create_systemd_template() {
    local template_path="$SYSTEMD_SERVICE_PATH/$SYSTEMD_TEMPLATE"
    
    echo -e "${BLUE}📝 Creating systemd service template...${NC}"
    
    sudo tee "$template_path" > /dev/null << 'EOF'
[Unit]
Description=Socat VPN Relay for port %i
Documentation=man:socat(1)
After=network.target
Requires=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/socat-vpn-relay-runner %i
Restart=always
RestartSec=10
User=nobody
Group=nogroup
StandardOutput=journal
StandardError=journal
SyslogIdentifier=socat-vpn-relay-%i

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${GREEN}✅ Systemd template created: $template_path${NC}"
}

create_runner_script() {
    local runner_path="$INSTALL_PATH/socat-vpn-relay-runner"
    
    echo -e "${BLUE}📝 Creating socat runner script...${NC}"
    
    sudo tee "$runner_path" > /dev/null << 'EOF'
#!/bin/bash

# Socat VPN Relay Runner
# This script runs a single socat relay instance

set -e

PORT="$1"
CONFIG_FILE="/etc/socat-vpn-relay/config"

if [ -z "$PORT" ]; then
    echo "ERROR: Port not specified"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Get VPN IP
if [ -n "$SOCAT_VPN_IP" ]; then
    VPN_IP="$SOCAT_VPN_IP"
else
    VPN_IP=$(ip addr show | grep -E "tun[0-9]" -A 2 | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
    if [ -z "$VPN_IP" ]; then
        echo "ERROR: Cannot detect VPN IP"
        exit 1
    fi
fi

# Build socat options
SOCAT_OPTS=""
if [ "${SOCAT_FORK}" = "true" ]; then
    SOCAT_OPTS="${SOCAT_OPTS},fork"
fi
if [ "${SOCAT_REUSEADDR}" = "true" ]; then
    SOCAT_OPTS="${SOCAT_OPTS},reuseaddr"
fi
if [ "${SOCAT_KEEPALIVE}" = "true" ]; then
    SOCAT_OPTS="${SOCAT_OPTS},keepalive"
fi

# Remove leading comma
SOCAT_OPTS="${SOCAT_OPTS#,}"

# Log startup
echo "Starting socat relay: ${VPN_IP}:${PORT} -> ${SOCAT_LOCALHOST_IP}:${PORT}"

# Execute socat
exec socat "TCP4-LISTEN:${PORT},bind=${VPN_IP}${SOCAT_OPTS:+,${SOCAT_OPTS}}" "TCP4:${SOCAT_LOCALHOST_IP}:${PORT}"
EOF
    
    sudo chmod +x "$runner_path"
    echo -e "${GREEN}✅ Runner script created: $runner_path${NC}"
}

install_service() {
    echo -e "${BLUE}🚀 Installing socat VPN relay service...${NC}"
    
    # Check dependencies
    check_dependencies
    
    # Load configuration
    load_config "$CONFIG_FILE"
    
    # Verify VPN connectivity
    local vpn_ip=$(get_vpn_ip)
    echo -e "${YELLOW}VPN IP detected: $vpn_ip${NC}"
    
    # Create installation directory
    sudo mkdir -p /etc/socat-vpn-relay
    sudo mkdir -p "$INSTALL_PATH"
    
    # Copy configuration
    if [ -f "$CONFIG_FILE" ]; then
        sudo cp "$CONFIG_FILE" "$INSTALL_CONFIG_FILE"
        echo -e "${GREEN}✅ Configuration installed: $INSTALL_CONFIG_FILE${NC}"
    else
        echo -e "${YELLOW}⚠️  No local config found, creating default${NC}"
        echo "SOCAT_VPN_IP=$vpn_ip" | sudo tee "$INSTALL_CONFIG_FILE" > /dev/null
        echo "SOCAT_LOCALHOST_IP=$SOCAT_LOCALHOST_IP" | sudo tee -a "$INSTALL_CONFIG_FILE" > /dev/null
        echo "SOCAT_PORTS=$SOCAT_PORTS" | sudo tee -a "$INSTALL_CONFIG_FILE" > /dev/null
    fi
    
    # Install scripts
    sudo cp "$0" "$INSTALL_PATH/$SCRIPT_INSTALL_NAME"
    sudo chmod +x "$INSTALL_PATH/$SCRIPT_INSTALL_NAME"
    echo -e "${GREEN}✅ Management script installed: $INSTALL_PATH/$SCRIPT_INSTALL_NAME${NC}"
    
    # Create systemd service files
    create_systemd_template
    create_runner_script
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Show UFW rules
    show_ufw_rules
    
    echo -e "${GREEN}🎉 Installation complete!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Apply UFW rules (shown above)"
    echo -e "  2. Start services: ${YELLOW}$INSTALL_PATH/$SCRIPT_INSTALL_NAME start${NC}"
    echo -e "  3. Enable auto-start: ${YELLOW}$INSTALL_PATH/$SCRIPT_INSTALL_NAME enable${NC}"
    echo -e "  4. Check status: ${YELLOW}$INSTALL_PATH/$SCRIPT_INSTALL_NAME status${NC}"
}

uninstall_service() {
    echo -e "${BLUE}🗑️  Uninstalling socat VPN relay service...${NC}"
    
    # Stop all services
    stop_services
    
    # Disable services
    disable_services
    
    # Remove systemd files
    sudo rm -f "$SYSTEMD_SERVICE_PATH/$SYSTEMD_TEMPLATE"
    sudo rm -f "$SYSTEMD_SERVICE_PATH/$MANAGER_SERVICE"
    sudo rm -f "$INSTALL_PATH/socat-vpn-relay-runner"
    sudo rm -f "$INSTALL_PATH/$SCRIPT_INSTALL_NAME"
    
    # Remove configuration directory
    sudo rm -rf /etc/socat-vpn-relay
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✅ Uninstallation complete${NC}"
}

start_services() {
    echo -e "${BLUE}▶️  Starting socat VPN relay services...${NC}"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    load_config "$config_file"
    
    local started_count=0
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            echo -e "${YELLOW}Starting relay for port $port...${NC}"
            if sudo systemctl start "socat-vpn-relay@${port}.service"; then
                echo -e "${GREEN}✅ Started socat-vpn-relay@${port}.service${NC}"
                started_count=$((started_count + 1))
            else
                echo -e "${RED}❌ Failed to start socat-vpn-relay@${port}.service${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}🎉 Service startup complete${NC}"
}

stop_services() {
    echo -e "${BLUE}⏹️  Stopping socat VPN relay services...${NC}"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    load_config "$config_file"
    
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            echo -e "${YELLOW}Stopping relay for port $port...${NC}"
            if sudo systemctl stop "socat-vpn-relay@${port}.service" 2>/dev/null; then
                echo -e "${GREEN}✅ Stopped socat-vpn-relay@${port}.service${NC}"
            else
                echo -e "${YELLOW}⚠️  Service socat-vpn-relay@${port}.service not running${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}🎉 Service shutdown complete${NC}"
}

restart_services() {
    echo -e "${BLUE}🔄 Restarting socat VPN relay services...${NC}"
    stop_services
    sleep 2
    start_services
}

enable_services() {
    echo -e "${BLUE}⚡ Enabling auto-start for socat VPN relay services...${NC}"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    load_config "$config_file"
    
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            echo -e "${YELLOW}Enabling auto-start for port $port...${NC}"
            if sudo systemctl enable "socat-vpn-relay@${port}.service"; then
                echo -e "${GREEN}✅ Enabled socat-vpn-relay@${port}.service${NC}"
            else
                echo -e "${RED}❌ Failed to enable socat-vpn-relay@${port}.service${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}🎉 Auto-start enabled${NC}"
}

disable_services() {
    echo -e "${BLUE}⚡ Disabling auto-start for socat VPN relay services...${NC}"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    load_config "$config_file"
    
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            echo -e "${YELLOW}Disabling auto-start for port $port...${NC}"
            if sudo systemctl disable "socat-vpn-relay@${port}.service" 2>/dev/null; then
                echo -e "${GREEN}✅ Disabled socat-vpn-relay@${port}.service${NC}"
            else
                echo -e "${YELLOW}⚠️  Service socat-vpn-relay@${port}.service not enabled${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}🎉 Auto-start disabled${NC}"
}

show_status() {
    echo -e "${BLUE}📊 Socat VPN Relay Service Status${NC}"
    echo "================================"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ No configuration found${NC}"
        echo -e "${YELLOW}Run 'install' action first${NC}"
        return 1
    fi
    
    load_config "$config_file"
    
    # VPN Status
    echo -e "${BLUE}🌐 Network Status:${NC}"
    local vpn_ip=$(get_vpn_ip 2>/dev/null || echo "Not detected")
    echo -e "  VPN IP: $vpn_ip"
    echo -e "  Localhost IP: $SOCAT_LOCALHOST_IP"
    echo ""
    
    # Service Status
    echo -e "${BLUE}⚙️  Service Status:${NC}"
    local total_services=0
    local running_services=0
    local enabled_services=0
    
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            local description=$(echo "$port_config" | cut -d':' -f2-)
            local service_name="socat-vpn-relay@${port}.service"
            
            echo -e "${YELLOW}  Port $port ($description):${NC}"
            
            # Check if service is active
            if sudo systemctl is-active "$service_name" &>/dev/null; then
                echo -e "    Status: ${GREEN}✅ Running${NC}"
                running_services=$((running_services + 1))
            else
                echo -e "    Status: ${RED}❌ Stopped${NC}"
            fi
            
            # Check if service is enabled
            if sudo systemctl is-enabled "$service_name" &>/dev/null; then
                echo -e "    Auto-start: ${GREEN}✅ Enabled${NC}"
                enabled_services=$((enabled_services + 1))
            else
                echo -e "    Auto-start: ${YELLOW}⚠️  Disabled${NC}"
            fi
            
            # Show process info if running
            local pid=$(sudo systemctl show -p MainPID --value "$service_name" 2>/dev/null)
            if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                echo -e "    PID: $pid"
            fi
            
            echo ""
            total_services=$((total_services + 1))
        fi
    done
    
    # Summary
    echo "================================"
    echo -e "${BLUE}📈 Summary:${NC}"
    echo -e "  Total Services: $total_services"
    echo -e "  Running: ${GREEN}$running_services${NC}"
    echo -e "  Enabled: ${GREEN}$enabled_services${NC}"
    echo ""
    
    # Quick commands
    echo -e "${BLUE}💡 Quick Commands:${NC}"
    local script_path="$INSTALL_PATH/$SCRIPT_INSTALL_NAME"
    if [ ! -f "$script_path" ]; then
        script_path="$0"
    fi
    echo -e "  Start all:    ${YELLOW}$script_path start${NC}"
    echo -e "  Stop all:     ${YELLOW}$script_path stop${NC}"
    echo -e "  Enable all:   ${YELLOW}$script_path enable${NC}"
    echo -e "  View logs:    ${YELLOW}$script_path logs${NC}"
}

show_config() {
    echo -e "${BLUE}📋 Socat VPN Relay Configuration${NC}"
    echo "================================"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ No configuration found${NC}"
        echo -e "${YELLOW}Create $CONFIG_FILE or run 'install' action first${NC}"
        return 1
    fi
    
    load_config "$config_file"
    
    echo -e "${BLUE}Network Configuration:${NC}"
    echo -e "  VPN IP: ${SOCAT_VPN_IP:-Auto-detect}"
    echo -e "  Localhost IP: $SOCAT_LOCALHOST_IP"
    echo ""
    
    echo -e "${BLUE}Port Relays:${NC}"
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            local description=$(echo "$port_config" | cut -d':' -f2-)
            echo -e "  $port - $description"
        fi
    done
    echo ""
    
    echo -e "${BLUE}Service Options:${NC}"
    echo -e "  Restart Policy: $SOCAT_RESTART_POLICY"
    echo -e "  Restart Delay: ${SOCAT_RESTART_DELAY}s"
    echo -e "  User: $SOCAT_USER"
    echo -e "  Log Level: $SOCAT_LOG_LEVEL"
    echo ""
    
    echo -e "${BLUE}Advanced Options:${NC}"
    echo -e "  Fork: $SOCAT_FORK"
    echo -e "  Reuse Address: $SOCAT_REUSEADDR"
    echo -e "  Keep Alive: $SOCAT_KEEPALIVE"
    echo ""
    
    echo -e "${BLUE}Configuration File:${NC} $config_file"
}

show_ufw_rules() {
    echo -e "${BLUE}🔥 UFW Firewall Rules${NC}"
    echo "================================"
    
    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ No configuration found${NC}"
        return 1
    fi
    
    load_config "$config_file"
    
    echo -e "${YELLOW}Required UFW rules for VPN relay:${NC}"
    echo ""
    
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            local description=$(echo "$port_config" | cut -d':' -f2-)
            echo -e "  ${GREEN}sudo ufw allow from 10.8.0.0/24 to any port $port comment \"$SOCAT_UFW_COMMENT_PREFIX: $description\"${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}ℹ️  These rules allow access to the specified ports only from VPN clients (10.8.0.0/24)${NC}"
    echo -e "${BLUE}   Internet traffic to these ports will still be blocked${NC}"
    
    if [ "$SOCAT_AUTO_UFW_RULES" = "true" ]; then
        echo ""
        echo -e "${YELLOW}⚡ Auto-apply all rules?${NC} (y/N)"
        read -r confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            parse_ports "$SOCAT_PORTS" | while read -r port_config; do
                if [ -n "$port_config" ]; then
                    local port=$(echo "$port_config" | cut -d':' -f1)
                    local description=$(echo "$port_config" | cut -d':' -f2-)
                    echo -e "${BLUE}Adding UFW rule for port $port...${NC}"
                    sudo ufw allow from 10.8.0.0/24 to any port "$port" comment "$SOCAT_UFW_COMMENT_PREFIX: $description"
                fi
            done
            echo -e "${GREEN}✅ UFW rules applied${NC}"
        fi
    fi
}

show_logs() {
    echo -e "${BLUE}📜 Socat VPN Relay Service Logs${NC}"
    echo "================================"

    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ No configuration found${NC}"
        return 1
    fi

    load_config "$config_file"

    # Show logs for all configured services
    local services=()
    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            services+=("socat-vpn-relay@${port}.service")
        fi
    done

    if [ ${#services[@]} -eq 0 ]; then
        echo -e "${YELLOW}No services configured${NC}"
        return 1
    fi

    echo -e "${YELLOW}Following logs for: ${services[*]}${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""

    sudo journalctl -f -u "socat-vpn-relay@*.service"
}

remove_ufw_rules() {
    echo -e "${BLUE}🗑️  Remove UFW Firewall Rules${NC}"
    echo "================================"

    local config_file="$INSTALL_CONFIG_FILE"
    if [ ! -f "$config_file" ]; then
        config_file="$CONFIG_FILE"
    fi

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ No configuration found${NC}"
        return 1
    fi

    load_config "$config_file"

    echo -e "${YELLOW}UFW rules to remove for VPN relay:${NC}"
    echo ""

    parse_ports "$SOCAT_PORTS" | while read -r port_config; do
        if [ -n "$port_config" ]; then
            local port=$(echo "$port_config" | cut -d':' -f1)
            local description=$(echo "$port_config" | cut -d':' -f2-)
            echo -e "  ${RED}sudo ufw delete allow from 10.8.0.0/24 to any port $port${NC}"
        fi
    done

    echo ""
    echo -e "${BLUE}ℹ️  These commands will remove the VPN relay firewall rules${NC}"
    echo -e "${BLUE}   Ports will no longer be accessible from VPN clients${NC}"

    echo ""
    echo -e "${YELLOW}⚡ Remove all rules?${NC} (y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        parse_ports "$SOCAT_PORTS" | while read -r port_config; do
            if [ -n "$port_config" ]; then
                local port=$(echo "$port_config" | cut -d':' -f1)
                local description=$(echo "$port_config" | cut -d':' -f2-)
                echo -e "${BLUE}Removing UFW rule for port $port...${NC}"
                if sudo ufw delete allow from 10.8.0.0/24 to any port "$port" 2>/dev/null; then
                    echo -e "${GREEN}✅ Removed UFW rule for port $port${NC}"
                else
                    echo -e "${YELLOW}⚠️  UFW rule for port $port not found or already removed${NC}"
                fi
            fi
        done
        echo -e "${GREEN}✅ UFW rules removal complete${NC}"
    else
        echo -e "${BLUE}UFW rules removal cancelled${NC}"
    fi
}

# Main script logic
case "$ACTION" in
    "install")
        install_service
        ;;
    "uninstall")
        uninstall_service
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "enable")
        enable_services
        ;;
    "disable")
        disable_services
        ;;
    "status")
        show_status
        ;;
    "config")
        show_config
        ;;
    "ufw-rules")
        show_ufw_rules
        ;;
    "remove-ufw-rules")
        remove_ufw_rules
        ;;
    "logs")
        show_logs
        ;;
    "help"|"")
        show_usage
        ;;
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        show_usage
        exit 1
        ;;
esac