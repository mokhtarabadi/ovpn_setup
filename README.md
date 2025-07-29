# Simple OpenVPN P2P Server

🔐 **Easy peer-to-peer VPN setup with host network access**

## Quick Start

1. **Configure server**:
   ```bash
   cp .env.example .env
   nano .env  # Set VPN_DOMAIN to your server IP/domain
   ```

2. **Initialize OpenVPN**:
   ```bash
   ./init-openvpn.sh
   ```

3. **Start server**:
   ```bash
   docker compose up -d
   ```

4. **Create clients**:
   ```bash
   ./manage-client.sh alice
   ./manage-client.sh bob
   ```

5. **Distribute `.ovpn` files** to users securely

## Features

- **P2P Communication**: Clients can communicate directly with each other
- **Host Access**: Access host services at `10.8.0.1` (VPN server IP)
- **No Internet Routing**: Web browsing stays on local connections
- **Host Networking**: Direct access to host network via OpenVPN container
- **Configurable Device**: Custom TUN device names (tun0, tun1, etc.)
- **Optional Compression**: Enable/disable LZO compression (disabled by default)
- **Simple Setup**: Minimal configuration, maximum functionality

## Network Layout

- **VPN Network**: `10.8.0.0/24`
- **Server IP**: `10.8.0.1` (also host gateway)
- **Client IPs**: `10.8.0.2`, `10.8.0.3`, etc. (auto-assigned)

## Usage Examples

From any VPN client:

```bash
# Access other VPN clients
ping 10.8.0.2

# Access host services
curl http://10.8.0.1:80
ssh user@10.8.0.1
psql -h 10.8.0.1 -p 5432
```

## Management

```bash
# Check server status
./status-openvpn.sh

# List all clients
./manage-client.sh list

# Revoke a client
./manage-client.sh alice revoke

# Create backup
./backup-openvpn.sh
```

## Configuration (.env)

```bash
OPENVPN_PROTOCOL=udp              # udp or tcp
OPENVPN_PORT=1194                 # 1194 for UDP, 443 for TCP
VPN_DOMAIN=your-server.com        # Your server IP or domain
VPN_NETWORK=10.8.0.0              # VPN network range
VPN_SERVER_IP=10.8.0.1            # VPN server IP
TUN_DEVICE_NAME=tun0              # TUN device name (tun0, tun1, etc.)
ENABLE_COMPRESSION=false          # Enable/disable compression (false by default)
ALLOW_DUPLICATE_CN=false          # Multiple devices per certificate
```

## Advanced Usage

### Custom Device Name

```bash
# Use tun1 instead of default tun0
TUN_DEVICE_NAME=tun1 ./init-openvpn.sh
```

### Enable Compression

```bash
# Enable LZO compression for better performance on slow connections
ENABLE_COMPRESSION=true ./init-openvpn.sh
```

### Combined Configuration

```bash
# Custom device name with compression enabled
TUN_DEVICE_NAME=tun2 ENABLE_COMPRESSION=true ./init-openvpn.sh
```

## Requirements

- Docker & Docker Compose
- Public IP or domain name
- Open firewall port (1194/UDP or 443/TCP)

## License

MIT License - see LICENSE file