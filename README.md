# 🔐 Secure OpenVPN P2P Server - Isolated Network Communication

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-EA7E20?style=for-the-badge&logo=openvpn&logoColor=white)](https://openvpn.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**🚀 Easy-to-deploy, secure peer-to-peer VPN solution with complete network isolation**

## 🆕 What's New - Static IP Assignment!

**🎯 NEW FEATURE:** Certificate-based static IP assignment is now available! Assign predictable IP addresses to specific
clients for monitoring, firewall rules, or service dependencies.

**Key Benefits:**

- 🔒 **Secure & Reliable** - Uses certificate Common Name (CN) as identifier
- 🔄 **Backward Compatible** - Existing clients continue working unchanged
- ⚡ **Easy Management** - Simple commands to assign and manage static IPs
- 📊 **Conflict Prevention** - Automatic validation and IP range management

**Quick Example:**

```bash
# Assign static IP to a client
./manage-client.sh alice set-static-ip 10.8.0.100

# For existing installations - upgrade first
./upgrade-static-ips.sh
```

**[📖 Complete Static IP Documentation](#-static-ip-assignment)**

Transform your network into a secure, isolated peer-to-peer communication hub. This Docker-based OpenVPN server provides
enterprise-grade security while maintaining simplicity and ease of use.

## ✨ Key Features

- 🔒 **Complete Network Isolation** - No host or external network access
- 🤝 **Pure P2P Communication** - Clients communicate directly with each other
- 🐳 **Docker-Native** - Secure, isolated container deployment
- 🔧 **Zero Configuration** - Works out of the box with sensible defaults
- 📱 **Multi-Protocol Support** - UDP (fast) or TCP (reliable) protocols
- 🛡️ **Enterprise Security** - TLS authentication and certificate-based access
- 🎯 **Resource Efficient** - Minimal system resource requirements
- 📊 **Comprehensive Monitoring** - Built-in status and management tools

## 🎯 Use Cases

Perfect for:

- **Private Team Communication** - Secure internal team networks
- **IoT Device Networks** - Isolated device-to-device communication
- **Development Environments** - Secure development team collaboration
- **Gaming Networks** - Low-latency peer-to-peer gaming
- **File Sharing Networks** - Secure peer-to-peer file distribution
- **Remote Work Teams** - Secure team collaboration without internet routing

## 🔧 Upgrade for Existing Users

If you're already using this OpenVPN setup, you can upgrade to the latest version with static IP assignment support by
running the following command:

```bash
# Upgrade existing installation to support static IPs
./upgrade-static-ips.sh
```

This upgrade process is safe and won't interrupt existing client connections. After upgrading, you can start assigning
static IPs to your clients.

## 🚀 Quick Start Guide

### 1. 📋 Prerequisites

- Docker & Docker Compose installed
- Public IP address or domain name
- Open firewall port (1194/UDP or 443/TCP)
- Linux host system (recommended)

**🔥 Firewall Configuration Required:**

```bash
# UFW (Ubuntu/Debian) - Open OpenVPN server port
sudo ufw allow 1194/udp

# firewalld (CentOS/RHEL/Fedora)
sudo firewall-cmd --permanent --add-port=1194/udp
sudo firewall-cmd --reload

# iptables (manual)
sudo iptables -I INPUT -p udp --dport 1194 -j ACCEPT
```

### 2. ⚙️ Configuration

```bash
# Clone and configure
git clone <repository-url>
cd ovpn_setup

# Configure environment
cp .env.example .env
nano .env  # Set VPN_DOMAIN to your server IP/domain
```

### 3. 🏗️ Initialize Server

```bash
# Initialize OpenVPN with P2P configuration
./init-openvpn.sh

# Start the secure VPN server
docker compose up -d
```

### 4. 👥 Create Clients

```bash
# Add clients for your team
./manage-client.sh alice
./manage-client.sh bob
./manage-client.sh charlie

# Securely distribute .ovpn files to users
```

### 5. 📊 Monitor & Manage

```bash
# Check server status
./status-openvpn.sh

# View active connections
docker compose logs -f

# Create backups
./backup-openvpn.sh
```

## 🔧 Advanced Configuration

### Environment Variables (.env)

```bash
# Protocol Configuration
OPENVPN_PROTOCOL=udp              # udp (fast) or tcp (reliable)
OPENVPN_PORT=1194                 # 1194 for UDP, 443 for TCP recommended

# Server Network Configuration  
VPN_DOMAIN=your-server.com        # Your server IP or domain
VPN_NETWORK=10.8.0.0              # Internal VPN network range
VPN_SERVER_IP=10.8.0.1            # VPN server internal IP

# Advanced Options
TUN_DEVICE_NAME=tun0              # TUN device name (tun0, tun1, etc.)
ENABLE_COMPRESSION=false          # Enable LZO compression (false recommended)
ALLOW_DUPLICATE_CN=false          # Multiple devices per certificate (false = secure)
```

### Protocol Selection Guide

| Protocol          | Best For                       | Advantages                                  | Considerations                             |
|-------------------|--------------------------------|---------------------------------------------|--------------------------------------------|
| **UDP** (Default) | Gaming, Streaming, General Use | ⚡ Faster, Lower latency, Better performance | May have issues with restrictive firewalls |
| **TCP**           | Restrictive Networks           | 🛡️ More reliable, Works through proxies    | Slightly higher latency                    |

### Custom Device Configuration

```bash
# Use custom TUN device
TUN_DEVICE_NAME=tun1 ./init-openvpn.sh

# Enable compression for slow connections
ENABLE_COMPRESSION=true ./init-openvpn.sh

# Combined configuration
TUN_DEVICE_NAME=tun2 ENABLE_COMPRESSION=true ./init-openvpn.sh
```

## 🌐 Network Architecture

### Isolated Network Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                    🔒 Isolated VPN Network                      │
│                         10.8.0.0/24                             │
│                                                                 │
│  Client A        Client B        Client C        VPN Server     │
│  10.8.0.4   ←→   10.8.0.5   ←→   10.8.0.6   ←→   10.8.0.1      │
│                                                                 │
│  ✅ P2P Communication      ❌ Host Access      ❌ Internet       │
└─────────────────────────────────────────────────────────────────┘
```

### Security Model

- **🔐 Certificate-Based Authentication** - Each client requires unique certificate
- **🛡️ TLS Encryption** - All traffic encrypted with industry-standard protocols
- **🚫 Network Isolation** - Complete isolation from host and external networks
- **⚡ Direct P2P** - Clients communicate directly without routing through external networks

## 📱 Client Management

### Adding Clients

```bash
# Add a new client
./manage-client.sh username

# List all clients
./manage-client.sh list

# Revoke client access
./manage-client.sh username revoke
```

### Client Connection Examples

From any connected VPN client:

```bash
# Communicate with other VPN clients
ping 10.8.0.4          # Ping another client
ssh user@10.8.0.5      # SSH to another client
nc 10.8.0.6 8080       # Connect to service on another client

# File sharing between clients
scp file.txt user@10.8.0.4:/path/   # Secure file transfer
rsync -av folder/ user@10.8.0.5:/dest/  # Sync directories
```

## 🔢 Static IP Assignment

### Overview

By default, OpenVPN clients receive dynamic IP addresses from the configured pool. For scenarios requiring predictable
client IPs (monitoring, firewall rules, service dependencies), you can assign static IP addresses to specific clients.

**Key Features:**

- 🎯 **Certificate-based assignment** - Uses client certificate Common Name (CN) as identifier
- 🔒 **Secure and reliable** - No dependency on MAC addresses or hardware
- 🔄 **Backward compatible** - Existing clients continue working with dynamic IPs
- ⚡ **Easy management** - Simple commands to assign, remove, and view static IPs
- 📊 **Conflict prevention** - Automatic validation and conflict detection

### Configuration

Static IP support is enabled by default in new installations. The IP ranges are configurable in `.env`:

```bash
# Static IP Configuration
ENABLE_STATIC_IPS=true             # Enable/disable static IP support
STATIC_IP_RANGE_START=10.8.0.50    # Start of static IP range
STATIC_IP_RANGE_END=10.8.0.200     # End of static IP range
DYNAMIC_IP_RANGE_START=10.8.0.10   # Start of dynamic IP range  
DYNAMIC_IP_RANGE_END=10.8.0.49     # End of dynamic IP range
```

### Usage Examples

```bash
# Assign static IP to existing client
./manage-client.sh alice set-static-ip 10.8.0.100

# View client's static IP assignment
./manage-client.sh alice show-static

# List all clients with static IPs
./manage-client.sh list-static

# Remove static IP (client will use dynamic IP)
./manage-client.sh alice remove-static-ip

# Regular client management still works
./manage-client.sh bob add           # Creates client with dynamic IP
./manage-client.sh list              # Lists all clients
```

### Network Layout with Static IPs

```
┌─────────────────────────────────────────────────────────────────┐
│                    🔒 VPN Network: 10.8.0.0/24                 │
│                                                                 │
│  Server: 10.8.0.1                                              │
│                                                                 │
│  📊 Dynamic Pool: 10.8.0.10 - 10.8.0.49 (40 addresses)        │
│  • New clients get IPs from this range automatically           │
│                                                                 │
│  🎯 Static Pool: 10.8.0.50 - 10.8.0.200 (151 addresses)       │
│  • alice     -> 10.8.0.100 (static)                            │
│  • bob       -> 10.8.0.101 (static)                            │
│  • server-1  -> 10.8.0.150 (static)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Upgrading Existing Installations

For existing OpenVPN installations, use the upgrade script:

```bash
# Enable static IP support on existing installation
./upgrade-static-ips.sh

# Then assign static IPs to existing clients
./manage-client.sh existing-client set-static-ip 10.8.0.75
```

**✅ Safe Upgrade Process:**

- Existing clients continue working without interruption
- No certificate regeneration required
- Server restart handled automatically
- Rollback friendly (simply don't assign static IPs)

### Best Practices

1. **📋 Plan IP Allocation**
    - Reserve ranges for different purposes (users, servers, devices)
    - Document IP assignments for team reference
    - Use meaningful IP patterns (e.g., 10.8.0.100-120 for users, 10.8.0.150-200 for servers)

2. **🔒 Security Considerations**
    - Static IPs are tied to client certificates (secure)
    - Revoked clients automatically lose their static IPs
    - One static IP per client certificate (prevents conflicts)

3. **🔧 Management Tips**
    - Use `list-static` regularly to audit assignments
    - Remove static IPs before revoking clients (cleaner)
    - Test static IP assignments with ping after assignment

### Troubleshooting

| Issue                             | Solution                                                      |
|-----------------------------------|---------------------------------------------------------------|
| 🚫 "Static IP support disabled"   | Run `./upgrade-static-ips.sh` or set `ENABLE_STATIC_IPS=true` |
| ❌ "IP already assigned"           | Use `./manage-client.sh list-static` to find conflicts        |
| 🌐 "IP outside static range"      | Check `.env` file for correct `STATIC_IP_RANGE_START/END`     |
| 🔄 "Client not getting static IP" | Server restart required: `docker compose restart`             |

### Technical Details

- **Method**: OpenVPN `client-config-dir` with `ifconfig-push`
- **Identifier**: Client certificate Common Name (CN)
- **Configuration**: Individual files in `/etc/openvpn/ccd/` directory
- **Persistence**: Stored in Docker volume, survives container restarts
- **Validation**: IP format, range, and conflict checking built-in

## 🔗 Localhost to VPN Bridge (Socat Relay System)

### Accessing Localhost Services via VPN

Transform your localhost-bound services into VPN-accessible applications with our automated socat relay system.

**🎯 Perfect for:**

- Development servers (React, Node.js, Python, etc.)
- Database access (PostgreSQL, MySQL, Redis)
- API services and monitoring tools
- Any localhost service you need to access via VPN

### Quick Localhost Bridge Setup

```bash
# Configure services to relay
nano .env.socat

# Example configuration:
SOCAT_VPN_IP=10.8.0.6                 # Your VPN IP (auto-detected)
SOCAT_PORTS=3000:HTTP Dev,8080:API,5432:PostgreSQL,9090:Monitoring

# Install and start relay service
./manage-socat-relays.sh install      # Install system-wide
./manage-socat-relays.sh ufw-rules     # Apply firewall rules  
./manage-socat-relays.sh start         # Start relay services
./manage-socat-relays.sh enable        # Enable auto-start
```

### Service Management

```bash
# Monitoring and control
./manage-socat-relays.sh status        # Check service status
./manage-socat-relays.sh logs          # View service logs
./manage-socat-relays.sh restart       # Restart all relays

# Configuration management
./manage-socat-relays.sh config        # Show current config
./manage-socat-relays.sh ufw-rules     # Show UFW rules needed
```

### Example Usage

```bash
# Start your localhost development server
npm start                              # React app on localhost:3000
python manage.py runserver             # Django on localhost:8000

# Configure relay for these ports
echo "SOCAT_PORTS=3000:React App,8000:Django API" > .env.socat

# Access from any VPN client
curl http://10.8.0.6:3000              # Access React app via VPN
curl http://10.8.0.6:8000/api/         # Access Django API via VPN
```

### 🛡️ Security Features

- **VPN-Only Access** - Services only accessible via VPN clients (10.8.0.0/24)
- **Firewall Protected** - Automatic UFW rule generation
- **Systemd Managed** - Reliable service management with auto-restart
- **Process Isolation** - Security hardened service configuration

📖 **[Complete Socat Relay Documentation](SOCAT-VPN-RELAY.md)** - Detailed setup, configuration, and troubleshooting
guide.

## 🛠️ Management Commands

### Server Operations

```bash
# Server lifecycle
docker compose up -d        # Start server
docker compose down         # Stop server
docker compose restart      # Restart server

# Monitoring
./status-openvpn.sh         # Comprehensive status
docker compose logs -f      # Real-time logs
docker compose ps           # Container status
```

### Maintenance Operations

```bash
# Backup management
./backup-openvpn.sh         # Create full backup
                            # Includes certificates, keys, and configuration

# Volume management
docker volume ls            # List volumes
docker volume inspect openvpn-data  # Inspect volume details
```

## 🔍 Troubleshooting

### Common Issues & Solutions

| Issue                    | Solution                                                     |
|--------------------------|--------------------------------------------------------------|
| 🔥 Port blocked          | **CRITICAL**: Open firewall port: `sudo ufw allow 1194/udp`  |
| 🐳 Container won't start | Check logs: `docker compose logs openvpn`                    |
| 📡 Client can't connect  | Verify domain/IP in .env matches server + firewall port open |
| 🔐 Certificate errors    | Regenerate: `./init-openvpn.sh` (removes old data)           |
| 🌐 Network conflicts     | Change VPN_NETWORK in .env to unused range                   |

### Diagnostic Commands

```bash
# Network diagnostics
docker network ls                    # List Docker networks
docker network inspect openvpn-network  # Inspect VPN network

# Container diagnostics  
docker exec openvpn-server ip addr  # Check container network
docker exec openvpn-server netstat -tulnp | grep 1194  # Verify port binding
```

## 📈 Performance Optimization

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM       | 128MB   | 256MB       |
| CPU       | 1 Core  | 2 Cores     |
| Storage   | 100MB   | 500MB       |
| Network   | 1Mbps   | 10Mbps      |

### Optimization Tips

- 🚀 **Use UDP protocol** for better performance in most scenarios
- 🗜️ **Disable compression** unless bandwidth is severely limited
- 📊 **Monitor resource usage** with `docker stats openvpn-server`
- 🔧 **Tune TUN device** for specific network requirements

## 🔐 Security Best Practices

### Certificate Management

```bash
# Regular certificate rotation (every 1-2 years)
./manage-client.sh old-client revoke
./manage-client.sh new-client

# Backup certificates securely
./backup-openvpn.sh
# Store backup in secure, encrypted location
```

### Network Security

- 🛡️ **Firewall Configuration** - Only allow necessary VPN ports
- 🔒 **Regular Updates** - Keep Docker images updated
- 📊 **Monitor Access** - Regular audit of client certificates
- 🚫 **Principle of Least Privilege** - Only create necessary client certificates

## 👨‍💻 Developer Information

**Project Maintainer:** Mohammad Reza Mokhtarabadi  
**Email:** mmokhtarabadi@gmail.com  
**License:** MIT License

### Development Specifications

- **Architecture:** Container-based OpenVPN deployment
- **Base Image:** `kylemanna/openvpn:latest`
- **Network Mode:** Isolated bridge network (no host access)
- **Security Model:** Certificate-based authentication with TLS
- **Supported Protocols:** UDP/TCP with configurable ports
- **Management:** Script-based automation for common operations

### Contributing Guidelines

1. 🍴 Fork the repository
2. 🌟 Create feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to branch (`git push origin feature/amazing-feature`)
5. 🔄 Create Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [kylemanna/openvpn](https://github.com/kylemanna/docker-openvpn) - Base Docker image
- [OpenVPN Community](https://openvpn.net/) - VPN software
- [Docker Community](https://www.docker.com/) - Containerization platform

## 📚 Additional Resources

- 📖 [OpenVPN Documentation](https://openvpn.net/community-resources/)
- 🐳 [Docker Compose Documentation](https://docs.docker.com/compose/)
- 🔐 [VPN Security Best Practices](https://www.nist.gov/publications)
- 🛡️ [Network Security Guidelines](https://csrc.nist.gov/)
- 🔗 **[Socat VPN Relay System](SOCAT-VPN-RELAY.md)** - Localhost to VPN bridge documentation

---
**⭐ Star this repository if it helped you create a secure P2P network!**

*Keywords: OpenVPN, Docker, P2P VPN, Secure Network, Container Networking, Private Network, Team Communication, Network
Isolation, Docker Compose, VPN Server, Certificate Authentication*