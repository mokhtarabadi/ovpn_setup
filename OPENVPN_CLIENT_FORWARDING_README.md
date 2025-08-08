# OpenVPN Client with Automatic Port Forwarding

This systemd service brings up an OpenVPN client connection on a server and automatically configures port forwarding
using iptables. When the service starts, other clients connected to the main OpenVPN server can access services running
on localhost of this server through the OpenVPN client's IP address.

## 🎯 Use Case

You have an OpenVPN server running (like the one in this workspace), and you want to:

1. Connect a secondary server as an OpenVPN client
2. Automatically expose services from that server to other VPN clients
3. Enable/disable access on-demand by starting/stopping the service

## 📋 Components

- **`openvpn-client-forwarding.service`** - Main systemd service file
- **`setup-port-forwarding.sh`** - Script that manages iptables rules
- **`openvpn-client-forwarding.env`** - Configuration file for ports and settings
- **`install-openvpn-client-forwarding.sh`** - Installation script

## 🚀 Installation

### Prerequisites

1. **OpenVPN client package** installed on the target server:
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install openvpn
   
   # CentOS/RHEL
   sudo yum install openvpn
   
   # Fedora
   sudo dnf install openvpn
   ```

2. **Firewall Configuration** - OpenVPN server port must be accessible:
   ```bash
   # UFW (Ubuntu/Debian)
   sudo ufw allow 1194/udp
   
   # firewalld (CentOS/RHEL/Fedora)
   sudo firewall-cmd --permanent --add-port=1194/udp
   sudo firewall-cmd --reload
   
   # iptables (manual)
   sudo iptables -I INPUT -p udp --dport 1194 -j ACCEPT
   ```

3. **Generate a client certificate** from your OpenVPN server:
   ```bash
   # On your OpenVPN server (this workspace)
   ./manage-client.sh myclient-server add
   ```

4. **Transfer the .ovpn file** to your target server

### Install the Service

1. **Copy all files** to your target server:
   ```bash
   scp *.service *.sh *.env myclient-server.ovpn user@target-server:/tmp/
   ```

2. **Run the installation script** on the target server:
   ```bash
   cd /tmp
   sudo ./install-openvpn-client-forwarding.sh myclient-server.ovpn
   ```

## ⚙️ Configuration

Edit the configuration file to customize your setup:

```bash
sudo nano /etc/openvpn/client/openvpn-client-forwarding.env
```

### Configuration Options

```bash
# OpenVPN Client Configuration
OPENVPN_CONFIG_PATH="/etc/openvpn/client/client.ovpn"
OPENVPN_CLIENT_NAME="client"

# VPN Network Configuration
VPN_INTERFACE="tun0"                    # VPN interface name
VPN_SERVER_NETWORK="10.8.0.0/24"      # Your VPN network range

# Ports to forward from localhost to VPN clients
# Format: LOCAL_PORT:PROTOCOL (tcp/udp)
FORWARD_PORTS="22:tcp 80:tcp 443:tcp 3000:tcp 8080:tcp"
```

### Example Port Configurations

```bash
# Web services only
FORWARD_PORTS="80:tcp 443:tcp"

# Development environment
FORWARD_PORTS="22:tcp 3000:tcp 8080:tcp 9000:tcp"

# Database and web services
FORWARD_PORTS="80:tcp 443:tcp 3306:tcp 5432:tcp"

# Gaming servers
FORWARD_PORTS="25565:tcp 7777:udp"
```

## 🎮 Usage

### Start the Service

```bash
sudo systemctl start openvpn-client-forwarding
```

### Check Status

```bash
sudo systemctl status openvpn-client-forwarding
```

### View Logs

```bash
sudo journalctl -u openvpn-client-forwarding -f
```

### Stop the Service

```bash
sudo systemctl stop openvpn-client-forwarding
```

### Enable Auto-start (Optional)

```bash
sudo systemctl enable openvpn-client-forwarding
```

## 🌐 How It Works

### 1. Service Startup Sequence

1. **Pre-flight Checks**: Validates configuration and OpenVPN files
2. **OpenVPN Client Start**: Connects to your OpenVPN server
3. **Interface Detection**: Waits for VPN interface (`tun0`) to be ready
4. **Port Forwarding Setup**: Configures iptables rules for specified ports
5. **Ready**: Service is running and ports are forwarded

### 2. Network Flow

```
VPN Client (10.8.0.2) → OpenVPN Server → Target Server (10.8.0.10)
                                              ↓
                                          iptables DNAT
                                              ↓
                                        localhost:port
```

### 3. Service Binding Requirements

⚠️ **Important**: Services must be properly configured to accept DNAT'd traffic:

**❌ Won't work:**

```bash
# Bound to 127.0.0.1 only - rejects DNAT traffic
python3 -m http.server 3000 --bind 127.0.0.1
```

**✅ Will work:**

```bash
# Bound to all interfaces - accepts DNAT traffic
python3 -m http.server 3000 --bind 0.0.0.0

# Or bound to VPN IP specifically  
python3 -m http.server 3000 --bind 10.8.0.6
```

**Why?** When iptables performs DNAT, the packet source IP remains the original VPN client IP (e.g., 10.8.0.4), but the
destination becomes 127.0.0.1:port. Services bound only to 127.0.0.1 reject connections from non-loopback source IPs.

### 4. Service Shutdown Sequence

1. **Cleanup Signal**: Removes iptables rules
2. **OpenVPN Stop**: Terminates OpenVPN client connection
3. **Final Cleanup**: Ensures all iptables rules are removed

## 🔍 Troubleshooting

### Check Service Status

```bash
sudo systemctl status openvpn-client-forwarding
```

### View Detailed Logs

```bash
sudo journalctl -u openvpn-client-forwarding -f --no-pager
```

### Test VPN Connection

```bash
# Check if VPN interface is up
ip addr show tun0

# Check VPN client IP
ip addr show tun0 | grep 'inet '
```

### Test Port Forwarding

```bash
# From another VPN client, test connection
nc -zv 10.8.0.10 22  # Replace with your target server's VPN IP and port
```

### Manual iptables Check

```bash
# View current iptables rules
sudo iptables -t nat -L OPENVPN_CLIENT_FORWARD -v
sudo iptables -L OPENVPN_CLIENT_ACCEPT -v
```

### Common Issues

1. **"VPN interface did not come up"**
    - Check OpenVPN client configuration
    - Verify server connectivity
   - Check firewall rules on OpenVPN server
   - Ensure OpenVPN server port is open: `sudo ufw allow 1194/udp`

2. **"Port forwarding not working"**
    - ✅ Verify service is bound to `0.0.0.0:port` or VPN IP, NOT `127.0.0.1:port`
    - Check iptables rules are applied
    - Test from another VPN client
   - Verify service is actually running

3. **"Service fails to start"**
    - Check configuration file syntax
    - Verify OpenVPN client config exists
    - Check system logs
   - Ensure OpenVPN server is accessible

4. **"Can connect to VPN but can't access forwarded ports"**
    - Most common cause: Service bound to 127.0.0.1 instead of 0.0.0.0
    - Check service binding: `ss -tlnp | grep <port>`
    - Restart service with correct binding

## 🔒 Security Considerations

- Service runs as root (required for VPN and iptables operations)
- Only VPN network clients can access forwarded ports
- Ports are forwarded to localhost only (not external interfaces)
- iptables rules are automatically cleaned up on service stop

## 📚 Examples

### Example 1: Web Development Server

```bash
# ❌ Wrong way (won't work with DNAT)
python3 -m http.server 3000 --bind 127.0.0.1

# ✅ Correct way (works with DNAT)  
python3 -m http.server 3000 --bind 0.0.0.0

# Configuration
FORWARD_PORTS="22:tcp 3000:tcp 8080:tcp"

# Access from VPN client
ssh user@10.8.0.10                    # SSH to server
curl http://10.8.0.10:3000           # Access development server  
curl http://10.8.0.10:8080           # Access alternative port
```

### Example 2: Database Server

```bash
# ✅ Correct MySQL configuration
# Edit /etc/mysql/mysql.conf.d/mysqld.cnf
bind-address = 0.0.0.0  # Instead of 127.0.0.1

# ✅ Correct PostgreSQL configuration  
# Edit /etc/postgresql/*/main/postgresql.conf
listen_addresses = '*'  # Instead of 'localhost'

# Configuration  
FORWARD_PORTS="3306:tcp 5432:tcp"

# Access from VPN client
mysql -h 10.8.0.10 -u user -p        # MySQL connection
psql -h 10.8.0.10 -U user dbname     # PostgreSQL connection
```

### Example 3: Production Web Services

```bash
# ✅ Correct Nginx configuration
# Edit /etc/nginx/sites-available/default  
server {
    listen 0.0.0.0:80;  # Instead of 127.0.0.1:80
    listen 0.0.0.0:443 ssl;  # Instead of 127.0.0.1:443
    ...
}

# Configuration
FORWARD_PORTS="80:tcp 443:tcp"

# Access from VPN client
curl http://10.8.0.10                # HTTP access
curl https://10.8.0.10               # HTTPS access
```

## 🛠️ Advanced Configuration

### Custom iptables Rules

If you need custom iptables rules, modify the `setup-port-forwarding.sh` script:

```bash
sudo nano /etc/openvpn/client/setup-port-forwarding.sh
```

### Multiple Services

You can run multiple instances with different configurations by:

1. Creating separate configuration files
2. Creating additional service files with different names
3. Using different client certificates

### Monitoring and Alerts

Add monitoring by creating systemd overrides:

```bash
sudo systemctl edit openvpn-client-forwarding
```

Add notification commands in the `[Service]` section.

## 📄 License

This service configuration is provided under the same license as the main project.