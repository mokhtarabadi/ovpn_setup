# 🔗 Socat VPN Relay System - Automatic Localhost to VPN Bridge

[![Systemd](https://img.shields.io/badge/systemd-service-blue?style=for-the-badge)](https://systemd.io/)
[![Socat](https://img.shields.io/badge/socat-relay-green?style=for-the-badge)](http://www.dest-unreach.org/socat/)
[![UFW](https://img.shields.io/badge/UFW-firewall-orange?style=for-the-badge)](https://launchpad.net/ufw)

**🚀 Automated socat relay service for bridging localhost services to OpenVPN clients**

Transform your localhost-bound applications into secure VPN-accessible services. This systemd-managed socat relay
automatically bridges multiple ports from your VPN interface to localhost, enabling seamless P2P application access
through your OpenVPN network.

## ✨ Key Features

- 🔄 **Automatic Service Management** - Systemd-powered service with auto-restart
- 🔧 **Multi-Port Configuration** - Configure multiple ports via simple configuration file
- 🛡️ **VPN-Only Access** - Secure firewall integration restricts access to VPN clients only
- ⚡ **Auto-Start Support** - Boot-time service startup with dependency management
- 📊 **Comprehensive Monitoring** - Built-in status checking and logging system
- 🎯 **Zero Configuration** - Automatic VPN IP detection with sensible defaults
- 📱 **Template-Based Architecture** - Systemd service templates for scalable port management
- 🔒 **Security Hardened** - Restricted service permissions and process isolation

## 🎯 Use Cases

Perfect for:

- **Development Servers** - Access localhost development services via VPN
- **Database Access** - Secure database connections through VPN tunnel
- **API Services** - Expose localhost APIs to VPN clients only
- **Web Applications** - Access localhost web servers from remote VPN clients
- **Monitoring Tools** - VPN-only access to localhost monitoring interfaces
- **File Services** - Share localhost file servers with VPN team members

## 🚀 Quick Start Guide

### 1. 📋 Prerequisites

- OpenVPN P2P server running (see main README.md)
- Connected VPN client with assigned IP
- socat package installed
- systemd system (Ubuntu 16.04+, CentOS 7+, etc.)

**🔥 Install Dependencies:**

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install socat

# CentOS/RHEL/Fedora  
sudo dnf install socat   # or: sudo yum install socat
```

### 2. ⚙️ Configuration

```bash
# Configure ports to relay
nano .env.socat

# Example configuration:
SOCAT_VPN_IP=10.8.0.6                 # Your VPN client IP (auto-detected)
SOCAT_PORTS=3000:HTTP Dev Server,8080:API Service,5432:PostgreSQL
```

### 3. 🚀 Installation & Deployment

```bash
# Install service system-wide
./manage-socat-relays.sh install

# Apply suggested UFW firewall rules
./manage-socat-relays.sh ufw-rules

# Start relay services
./manage-socat-relays.sh start

# Enable auto-start on boot
./manage-socat-relays.sh enable
```

### 4. 📊 Management & Monitoring

```bash
# Check service status
./manage-socat-relays.sh status

# View real-time logs
./manage-socat-relays.sh logs

# Restart all services
./manage-socat-relays.sh restart
```

## 🔧 Configuration Reference

### Environment File (.env.socat)

```bash
# VPN Network Configuration
SOCAT_VPN_IP=10.8.0.6                 # Your VPN client IP (auto-detected if empty)
SOCAT_LOCALHOST_IP=127.0.0.1          # Localhost IP for relay destination

# Port Relay Configuration
# Format: PORT:DESCRIPTION (comma separated)
SOCAT_PORTS=3000:HTTP Dev Server,8080:Alt HTTP,9000:Backend API,5432:PostgreSQL

# Service Configuration  
SOCAT_RESTART_POLICY=always           # always, on-failure, on-abnormal, etc.
SOCAT_RESTART_DELAY=10                # Seconds to wait before restart
SOCAT_USER=nobody                     # User to run socat as (root for ports < 1024)

# Advanced Options
SOCAT_FORK=true                       # Enable multiple concurrent connections
SOCAT_REUSEADDR=true                  # Enable SO_REUSEADDR socket option
SOCAT_KEEPALIVE=false                 # Enable TCP keepalive (experimental)
```

## 🌐 Network Architecture

### Service Bridge Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                    🔗 Socat Relay Bridge                       │
│                                                                 │
│  VPN Client      Socat Relay      Localhost Service            │
│  10.8.0.10   ←→  10.8.0.6:3000 ←→ 127.0.0.1:3000              │
│                                                                 │
│  ✅ VPN Access        ✅ Bridge         ✅ Localhost Service    │
│  ❌ Internet          🛡️ UFW Rules      🔒 Secure              │
└─────────────────────────────────────────────────────────────────┘
```

### Security Model

- **🛡️ Firewall-Protected** - UFW rules restrict access to VPN clients only
- **🔒 Process Isolation** - Systemd security sandboxing enabled
- **⚡ Automatic Restart** - Service resilience with automatic failure recovery
- **📊 Audit Logging** - Complete service activity logging via systemd journal

## 📱 Service Management

### Installation Commands

```bash
# System-wide installation
./manage-socat-relays.sh install

# Configuration validation
./manage-socat-relays.sh config

# UFW firewall rule generation
./manage-socat-relays.sh ufw-rules
```

### Service Control

```bash
# Service lifecycle management
./manage-socat-relays.sh start       # Start all relay services
./manage-socat-relays.sh stop        # Stop all relay services  
./manage-socat-relays.sh restart     # Restart all relay services

# Auto-start configuration
./manage-socat-relays.sh enable      # Enable boot-time startup
./manage-socat-relays.sh disable     # Disable boot-time startup
```

### Monitoring & Diagnostics

```bash
# Status checking
./manage-socat-relays.sh status      # Comprehensive status display
./manage-socat-relays.sh logs        # Real-time log following

# Direct systemd commands
sudo systemctl status socat-vpn-relay@3000.service
sudo journalctl -u socat-vpn-relay@3000.service
```

## 🔥 UFW Firewall Integration

### Automatic Rule Generation

The system automatically generates UFW rules for configured ports:

```bash
# Show required UFW rules
./manage-socat-relays.sh ufw-rules

# Example output:
sudo ufw allow from 10.8.0.0/24 to any port 3000 comment "VPN Relay: HTTP Dev Server"
sudo ufw allow from 10.8.0.0/24 to any port 8080 comment "VPN Relay: API Service"
```

### Security Benefits

- **🛡️ VPN-Only Access** - Only VPN clients (10.8.0.0/24) can access services
- **❌ Internet Blocked** - Internet traffic to ports remains blocked
- **📝 Rule Comments** - Descriptive comments for easy firewall management
- **⚡ Auto-Apply Option** - Optional automatic rule application

## 🛠️ Advanced Configuration

### Custom Port Configurations

```bash
# Development stack
SOCAT_PORTS=3000:React Dev,3001:API Server,8080:Backend,9000:Webpack

# Database services
SOCAT_PORTS=5432:PostgreSQL,3306:MySQL,6379:Redis,27017:MongoDB

# Monitoring stack
SOCAT_PORTS=3000:Grafana,9090:Prometheus,5601:Kibana,8086:InfluxDB
```

### Service User Configuration

```bash
# For ports 1024+ (recommended)
SOCAT_USER=nobody

# For privileged ports < 1024 (requires root)
SOCAT_USER=root
```

### Performance Tuning

```bash
# High-concurrency settings
SOCAT_FORK=true                       # Multiple connections
SOCAT_REUSEADDR=true                  # Fast socket reuse
SOCAT_KEEPALIVE=true                  # Connection persistence

# Resource optimization
SOCAT_RESTART_POLICY=on-failure       # Restart only on failure
SOCAT_RESTART_DELAY=5                 # Faster restart
```

## 🔍 Troubleshooting

### Common Issues & Solutions

| Issue                          | Solution                                                       |
|--------------------------------|----------------------------------------------------------------|
| 🔥 VPN IP not detected        | Set `SOCAT_VPN_IP` manually in `.env.socat`                   |
| 🚫 Service won't start        | Check `./manage-socat-relays.sh status` for detailed errors   |
| 🌐 Can't access from VPN      | Verify UFW rules: `./manage-socat-relays.sh ufw-rules`        |
| 🔐 Permission denied          | Use `SOCAT_USER=root` for ports < 1024                        |
| 📊 Service keeps restarting   | Check logs: `./manage-socat-relays.sh logs`                   |

### Diagnostic Commands

```bash
# Service diagnostics
sudo systemctl list-units "socat-vpn-relay@*"        # List all relay services
sudo systemctl status socat-vpn-relay@3000.service   # Check specific port

# Network diagnostics
netstat -tlnp | grep :3000                           # Verify port binding
ss -tlnp | grep 10.8.0.6                            # Check VPN interface binding

# Process diagnostics
sudo systemctl show socat-vpn-relay@3000.service     # Show service properties
sudo journalctl -u socat-vpn-relay@3000.service -f   # Follow service logs
```

## 📈 Service Architecture

### Systemd Template Design

The service uses systemd template units for scalable port management:

```
socat-vpn-relay@.service          # Template service unit
socat-vpn-relay@3000.service      # Instance for port 3000  
socat-vpn-relay@8080.service      # Instance for port 8080
```

### Process Management

- **🔄 Template Instantiation** - Each port gets its own systemd service instance
- **⚡ Dependency Management** - Services depend on network availability
- **🛡️ Security Hardening** - Process sandboxing and privilege restriction
- **📊 Resource Limits** - Controlled resource usage per service

### File Structure

```
/etc/systemd/system/
├── socat-vpn-relay@.service                    # Service template
/usr/local/bin/
├── manage-socat-relays                         # Management script
├── socat-vpn-relay-runner                      # Individual instance runner
/etc/socat-vpn-relay/
└── config                                      # System configuration
```

## 💡 Integration Examples

### Development Workflow

```bash
# Start development environment
npm start &                                     # React on localhost:3000
node api-server.js &                           # API on localhost:8080

# Configure VPN relay
echo "SOCAT_PORTS=3000:React App,8080:API Server" > .env.socat

# Deploy relay
./manage-socat-relays.sh install
./manage-socat-relays.sh start

# Access from VPN client
curl http://10.8.0.6:3000                      # React app via VPN
curl http://10.8.0.6:8080/api                  # API server via VPN
```

### Database Access

```bash
# Start local PostgreSQL
sudo systemctl start postgresql

# Configure database relay
echo "SOCAT_PORTS=5432:PostgreSQL Database" > .env.socat
echo "SOCAT_USER=root" >> .env.socat            # Privileged port

# Deploy and start
./manage-socat-relays.sh install
./manage-socat-relays.sh start

# Connect from VPN client
psql -h 10.8.0.6 -p 5432 -U username dbname
```

## 🔐 Security Best Practices

### Service Security

```bash
# Use unprivileged user when possible
SOCAT_USER=nobody

# Restrict to necessary ports only
SOCAT_PORTS=3000:Required Service Only

# Enable all security features
SOCAT_FORK=true
SOCAT_REUSEADDR=true
```

### Network Security

- 🛡️ **UFW Integration** - Always apply generated firewall rules
- 📊 **Regular Monitoring** - Monitor service logs and status
- 🔄 **Service Updates** - Keep socat and systemd updated
- 🚫 **Minimal Exposure** - Only expose necessary services

## 👨‍💻 Management Commands Reference

### Full Command List

```bash
# Installation & Setup
./manage-socat-relays.sh install     # Install service system-wide
./manage-socat-relays.sh uninstall   # Remove service from system

# Service Control
./manage-socat-relays.sh start       # Start all relay services
./manage-socat-relays.sh stop        # Stop all relay services
./manage-socat-relays.sh restart     # Restart all relay services

# Configuration Management
./manage-socat-relays.sh enable      # Enable auto-start on boot
./manage-socat-relays.sh disable     # Disable auto-start on boot

# Monitoring & Diagnostics
./manage-socat-relays.sh status      # Show comprehensive status
./manage-socat-relays.sh config      # Display current configuration
./manage-socat-relays.sh logs        # Follow service logs
./manage-socat-relays.sh ufw-rules   # Show/apply UFW rules

# Help & Information
./manage-socat-relays.sh help        # Show usage information
```

## 📜 Service Logs

### Log Locations

```bash
# Systemd journal (recommended)
sudo journalctl -u socat-vpn-relay@3000.service

# All relay services
sudo journalctl -u "socat-vpn-relay@*.service"

# Real-time following
sudo journalctl -f -u "socat-vpn-relay@*.service"
```

### Log Analysis

```bash
# Service startup logs
sudo journalctl -u socat-vpn-relay@3000.service --since "1 hour ago"

# Error filtering
sudo journalctl -u "socat-vpn-relay@*.service" -p err

# Performance monitoring
sudo journalctl -u "socat-vpn-relay@*.service" --since today
```

## 🚀 Performance Optimization

### High-Performance Configuration

```bash
# Optimized settings for high-traffic scenarios
SOCAT_FORK=true                       # Enable concurrent connections
SOCAT_REUSEADDR=true                  # Fast socket reuse
SOCAT_RESTART_POLICY=on-failure       # Avoid unnecessary restarts
SOCAT_RESTART_DELAY=2                 # Quick failure recovery
```

### Resource Management

- **📊 Memory Usage** - Each service instance uses minimal memory (~1-5MB)
- **⚡ CPU Utilization** - Extremely low CPU usage for relay operations
- **🌐 Network Overhead** - Minimal network overhead for proxying
- **🔄 Connection Limits** - Fork mode supports multiple concurrent connections

## 📚 Additional Resources

- 📖 [Socat Documentation](http://www.dest-unreach.org/socat/doc/socat.html)
- 🔧 [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- 🛡️ [UFW Firewall Guide](https://help.ubuntu.com/community/UFW)
- 🌐 [OpenVPN P2P Setup](README.md) - Main OpenVPN configuration

---

**⭐ This socat relay system seamlessly bridges your localhost services to your secure P2P VPN network!**

*Keywords: socat, VPN relay, systemd service, localhost bridge, OpenVPN, P2P networking, secure access, port forwarding,
service management, firewall integration*