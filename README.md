# OpenVPN P2P Server Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![Docker Image](https://img.shields.io/badge/Docker%20Image-kylemanna%2Fopenvpn-blue.svg)](https://hub.docker.com/r/kylemanna/openvpn/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.5+-green.svg)](https://openvpn.net/)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange.svg)](https://www.linux.org/)

🔐 **Secure peer-to-peer VPN for company internal communication**

This setup creates an OpenVPN server specifically configured for **peer-to-peer communication** between team members
without routing internet traffic through the VPN server. Based on the
reliable [kylemanna/openvpn](https://hub.docker.com/r/kylemanna/openvpn/) Docker image.

## ✨ Features

- **🔒 Client-to-Client P2P**: Team members can directly communicate with each other
- **🚫 No Internet Routing**: Web browsing stays on local connections (no exit node)
- **🔐 Strong Security**: AES-256-GCM encryption with certificate-based authentication
- **📦 Docker-Based**: Easy deployment and management with Docker Compose
- **🌐 Protocol Support**: Both UDP (fast) and TCP (reliable) protocols
- **🛠️ Full Management**: Scripts for client management, monitoring, and backups
- **⚡ Production Ready**: Automated setup with proper security practices

---

## 🚀 Quick Start

### 1. **Configure Environment**
```bash
# Copy and customize environment variables
cp .env.example .env
nano .env  # Set VPN_DOMAIN and optionally OPENVPN_PROTOCOL
```

### 2. **Initialize OpenVPN Server**
```bash
# Option 1: Use VPN_DOMAIN from .env file (recommended)
./init-openvpn.sh

# Option 2: Override with command line argument
./init-openvpn.sh your-server-ip-or-domain.com
```

### 3. **Start the Server**
```bash
# Start OpenVPN server
docker compose up -d
```

### 4. **Create Team Member Certificates**
```bash
# Add team members
./manage-client.sh alice
./manage-client.sh bob
./manage-client.sh charlie

# List all clients
./manage-client.sh list
```

### 5. **Distribute Client Configs**

- Share the generated `.ovpn` files securely with team members
- Team members import these files into their OpenVPN clients
- Once connected, they can communicate via their VPN IPs (10.8.0.x range)

---

## 📁 Project Structure

```
├── docker-compose.yml      # Docker container configuration
├── .env                    # Environment variables (your config)
├── .env.example           # Environment template
├── init-openvpn.sh        # Server initialization script
├── manage-client.sh       # Client certificate management
├── status-openvpn.sh      # Server status monitoring
├── backup-openvpn.sh      # Backup certificates and config
├── validate-setup.sh      # Pre-deployment validation
└── README.md              # This documentation
```

---

## 🌐 Protocol Selection: UDP vs TCP

### **UDP Protocol (Default)**

```bash
# In .env file:
OPENVPN_PROTOCOL=udp
OPENVPN_PORT=1194
```

**✅ Best for:**

- Gaming and real-time applications
- Streaming media
- General purpose VPN usage
- Low-latency requirements

**📊 Characteristics:**

- **Faster**: Lower overhead and latency
- **Efficient**: Better bandwidth utilization
- **Default**: Standard OpenVPN protocol
- **NAT-friendly**: Works with most routers

### **TCP Protocol**

```bash
# In .env file:
OPENVPN_PROTOCOL=tcp
OPENVPN_PORT=443
```

**✅ Best for:**

- Restrictive corporate networks
- Networks that block UDP
- Highly regulated environments
- Connections through HTTP proxies

**📊 Characteristics:**

- **Reliable**: Guaranteed packet delivery
- **Proxy-friendly**: Works through HTTP proxies
- **Firewall-friendly**: Uses common ports (443)
- **Slightly slower**: Higher overhead due to TCP

### **Quick Protocol Comparison**

| Feature                | UDP                  | TCP              |
|------------------------|----------------------|------------------|
| **Speed**              | ⚡ Faster             | 🐌 Slower        |
| **Reliability**        | 🔄 Good              | ✅ Excellent      |
| **Firewall Bypass**    | ⚠️ Sometimes blocked | ✅ Rarely blocked |
| **Gaming/Streaming**   | ✅ Excellent          | ⚠️ Good          |
| **Corporate Networks** | ⚠️ May be blocked    | ✅ Usually works  |
| **Latency**            | ✅ Lower              | ⚠️ Higher        |

---

## 🔧 Detailed Usage

### Server Management

#### **Initialize Server with Protocol Selection**

```bash
# Use configuration from .env file (recommended approach)
./init-openvpn.sh

# Override domain from command line
./init-openvpn.sh vpn.mycompany.com

# Override with environment variables (still uses .env for other settings)
OPENVPN_PROTOCOL=tcp OPENVPN_PORT=443 ./init-openvpn.sh

# Override all parameters via command line arguments
./init-openvpn.sh vpn.example.com 10.9.0.0 10.9.0.1 443 tcp
```

**Parameter precedence (highest to lowest):**

1. Command line arguments
2. Environment variables from .env file
3. Built-in defaults

#### **Start/Stop Server**

```bash
# Start server
docker compose up -d

# Stop server  
docker compose down

# View logs
docker compose logs -f
```

#### **Check Server Status**

```bash
./status-openvpn.sh
```

### Client Management

#### **Add New Client**
```bash
# Add a new team member
./manage-client.sh username

# The script will generate username.ovpn file
```

#### **List All Clients**

```bash
./manage-client.sh list
```

#### **Show Client Certificate**

```bash
./manage-client.sh username show
```

#### **Revoke Client Access**

```bash
./manage-client.sh username revoke
```

### Backup & Restore

#### **Create Backup**

```bash
# Create backup in ./backups/ directory
./backup-openvpn.sh

# Custom backup location
./backup-openvpn.sh /path/to/backup/directory
```

#### **Restore from Backup**

```bash
# Extract backup
tar xzf openvpn_backup_YYYYMMDD_HHMMSS.tar.gz

# Restore volume data
docker run --rm -v openvpn-data:/target -v $(pwd):/backup alpine \
  sh -c 'cd /target && tar xzf /backup/openvpn-data.tar.gz'

# Start server
docker compose up -d
```

---

## ⚙️ Configuration

### Environment Variables (.env)

```bash
# Protocol Selection
OPENVPN_PROTOCOL=udp               # udp (fast) or tcp (reliable)
OPENVPN_PORT=1194                  # 1194 for UDP, 443 for TCP recommended

# Server Configuration
VPN_DOMAIN=your-server.example.com # Your server's public IP or domain
VPN_NETWORK=10.8.0.0               # Internal VPN network range
VPN_SERVER_IP=10.8.0.1             # VPN server's internal IP

# Multiple device connections per certificate
ALLOW_DUPLICATE_CN=false           # false (secure) or true (convenient)
```

> **💡 VPN_DOMAIN Usage**: The `VPN_DOMAIN` variable is used as the default domain when running `./init-openvpn.sh`
> without arguments. You can override it by providing a domain as the first argument:
`./init-openvpn.sh my-custom-domain.com`

### Protocol-Specific Configurations

#### **For Gaming/Streaming (UDP)**

```bash
OPENVPN_PROTOCOL=udp
OPENVPN_PORT=1194
```

#### **For Corporate Networks (TCP)**

```bash
OPENVPN_PROTOCOL=tcp
OPENVPN_PORT=443
```

#### **Custom Port Configurations**

```bash
# Alternative UDP ports
OPENVPN_PROTOCOL=udp
OPENVPN_PORT=443      # UDP on 443

# Alternative TCP ports  
OPENVPN_PROTOCOL=tcp
OPENVPN_PORT=80       # TCP on 80 (HTTP port)
OPENVPN_PORT=22       # TCP on 22 (SSH port)
```

### Network Configuration

- **VPN Network**: `10.8.0.0/24` (configurable)
- **Server IP**: `10.8.0.1` (internal VPN IP)
- **Client IPs**: `10.8.0.2` - `10.8.0.254` (auto-assigned)
- **Protocols**: UDP (default) or TCP
- **Ports**: 1194/UDP (default) or 443/TCP (recommended)

---

## 🔐 Security Features

### Encryption & Authentication

- **Cipher**: AES-256-GCM
- **Authentication**: SHA256
- **TLS Authentication**: Enabled for additional security
- **Certificate-based**: Each client has unique certificates

### P2P Configuration

- ✅ **Client-to-client** communication enabled
- ❌ **No redirect-gateway** (internet traffic stays local)
- ❌ **No DNS pushing** (uses local DNS)
- ✅ **TLS encryption** for all communications

---

## 🌐 How It Works

### Connection Flow
1. **Server Setup**: OpenVPN server runs on your company server
2. **Client Connection**: Team members connect using their `.ovpn` files
3. **IP Assignment**: Each client gets a private IP (10.8.0.x)
4. **P2P Communication**: Clients can directly communicate with each other
5. **Internet Independence**: Web browsing continues through local connections

### Use Cases

- **Internal file sharing** between team members
- **Private development environments**
- **Secure inter-office communication**
- **Database access** from remote locations
- **Internal service access** (Git, CI/CD, etc.)

---

## 🛠️ Troubleshooting

### Common Issues

#### **Server won't start**
```bash
# Check logs
docker compose logs

# Verify configuration
./validate-setup.sh

# Check port availability (adjust for your protocol)
sudo netstat -tuln | grep 1194  # UDP
sudo netstat -tuln | grep 443   # TCP
```

#### **Client can't connect**
```bash
# Verify server is running
./status-openvpn.sh

# Check firewall (adjust for your protocol/port)
sudo ufw allow 1194/udp  # UDP
sudo ufw allow 443/tcp   # TCP

# Regenerate client config
./manage-client.sh username show
```

#### **Protocol-specific issues**

**UDP Issues:**
```bash
# UDP might be blocked in restrictive networks
# Try switching to TCP:
# Edit .env: OPENVPN_PROTOCOL=tcp, OPENVPN_PORT=443
# Reinitialize: ./init-openvpn.sh your-domain.com
```

**TCP Issues:**

```bash
# TCP might be slower for real-time applications
# Try switching to UDP:
# Edit .env: OPENVPN_PROTOCOL=udp, OPENVPN_PORT=1194
# Reinitialize: ./init-openvpn.sh your-domain.com
```

### Port Configuration
```bash
# Default OpenVPN ports
sudo ufw allow 1194/udp  # UDP
sudo ufw allow 443/tcp   # TCP

# Check which protocol is active
./status-openvpn.sh
```

---

## 📋 Requirements

### Server Requirements
- **OS**: Linux with Docker support
- **RAM**: 1GB minimum (2GB recommended)
- **Storage**: 10GB minimum
- **Network**: Public IP or domain name
- **Ports**: 1194/UDP or 443/TCP (configurable)

### Client Requirements

- **OpenVPN Client**: Any platform (Windows, macOS, Linux, iOS, Android)
- **Network**: Internet connection to reach server

### Software Dependencies

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **OpenVPN Client**: Latest version recommended
- **Docker Image**: [kylemanna/openvpn:latest](https://hub.docker.com/r/kylemanna/openvpn/)

---

## 🔧 Advanced Configuration

### Dual Protocol Setup

For maximum compatibility, you can run both UDP and TCP simultaneously:

```yaml
# docker-compose.override.yml
services:
  openvpn-tcp:
    image: kylemanna/openvpn:latest
    container_name: openvpn-server-tcp
    ports:
      - "443:1194/tcp"
    volumes:
      - openvpn-data-tcp:/etc/openvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    restart: unless-stopped

volumes:
  openvpn-data-tcp:
    name: openvpn-data-tcp
    driver: local
```

### Custom Network Range

```bash
# Edit .env file
VPN_NETWORK=172.16.0.0
VPN_SERVER_IP=172.16.0.1

# Reinitialize server
./init-openvpn.sh your-domain.com 172.16.0.0 172.16.0.1
```

### Custom Certificate Validity
```bash
# Edit certificate duration (default 3 years)
# Modify init-openvpn.sh EASYRSA_CERT_EXPIRE variable
```

---

## 🤝 Support & Maintenance

### Regular Maintenance

```bash
# Weekly status check
./status-openvpn.sh

# Monthly backup
./backup-openvpn.sh

# Certificate expiry monitoring (every 6 months)
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  openssl x509 -in /etc/openvpn/pki/ca.crt -noout -dates
```

### Monitoring

- **Server Status**: `./status-openvpn.sh`
- **Client Connections**: Check server logs
- **Resource Usage**: Monitor via Docker stats
- **Certificate Expiry**: Built-in 3-year validity

---

## 📜 License & Security

### Docker Image Information

This project uses the [kylemanna/openvpn](https://hub.docker.com/r/kylemanna/openvpn/) Docker image:

- **Image**: `kylemanna/openvpn:latest`
- **GitHub**: [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn)
- **Docker Hub**: [kylemanna/openvpn](https://hub.docker.com/r/kylemanna/openvpn/)
- **License**: MIT (same as this project)

### Security Notice

- This setup creates a **private VPN for internal communication**
- **No internet traffic** is routed through the VPN
- **Certificates** should be distributed securely
- **Regular backups** are essential for business continuity

### Compliance

- Uses **industry-standard encryption** (AES-256-GCM)
- **Certificate-based authentication**
- **No logging** of user activities (privacy-focused)
- **Docker isolation** for security

---

## 🎯 Next Steps

After setup completion:

1. **✅ Test connectivity** between team members
2. **✅ Configure firewall rules** on server (UDP/TCP specific)
3. **✅ Set up automated backups** (cron job)
4. **✅ Document internal IP assignments** for team
5. **✅ Train team members** on OpenVPN client usage
6. **✅ Monitor server health** regularly
7. **✅ Test both protocols** if network issues arise

---

## 👨‍💻 Author & Contributors

**Mohammad Reza Mokhtarabadi**  
📧 [mmokhtarabadi@gmail.com](mailto:mmokhtarabadi@gmail.com)  
🐙 [GitHub Profile](https://github.com/mokhtarabadi)

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to
discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Issues & Support

If you encounter any problems or have questions:

1. Check the [troubleshooting section](#-troubleshooting) first
2. Search [existing issues](https://github.com/mokhtarabadi/ovpn_setup/issues)
3. Create a [new issue](https://github.com/mokhtarabadi/ovpn_setup/issues/new) with detailed information

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🎉 Your OpenVPN P2P server is now ready for secure team communication!**

For support or questions, refer to the troubleshooting section or check the server logs using `./status-openvpn.sh`.