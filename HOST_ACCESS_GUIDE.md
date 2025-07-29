# 🏠 Host Access Guide for OpenVPN P2P Setup

This guide explains how to access Docker host services through your OpenVPN P2P connection while maintaining the
existing peer-to-peer functionality.

## 🎯 Overview

After configuration, VPN clients can access:

- **P2P Communication**: `10.8.0.x` addresses (existing functionality)
- **Host Services**: `172.17.0.1:PORT` or custom host IP
- **Docker Bridge Network**: `172.17.0.0/16` range

## 🔧 Configuration

### Automatic Setup (Recommended)

The host access is automatically configured when you run:

```bash
./init-openvpn.sh
```

### Manual Configuration

If you need to configure host access separately:

```bash
./configure-host-access.sh
```

### Environment Variables

Add to your `.env` file:

```bash
# Host access configuration
HOST_IP=172.17.0.1                 # Docker host IP (auto-detected)
ENABLE_HOST_ACCESS=true             # Enable/disable host access
```

## 🌐 Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    VPN Client Network                       │
│                      10.8.0.0/24                          │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Client A  │    │   Client B  │    │   Client C  │     │
│  │  10.8.0.2   │◄──►│  10.8.0.3   │◄──►│  10.8.0.4   │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│          │                  │                  │           │
│          └──────────────────┼──────────────────┘           │
│                             │                              │
│                    ┌─────────────┐                         │
│                    │ VPN Server  │                         │
│                    │  10.8.0.1   │                         │
│                    └─────────────┘                         │
│                             │                              │
└─────────────────────────────┼──────────────────────────────┘
                              │
                    ┌─────────────┐
                    │ Docker Host │
                    │ 172.17.0.1  │
                    └─────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                    │                     │
   ┌─────────┐         ┌─────────┐         ┌─────────┐
   │Web App  │         │Database │         │API      │
   │Port 80  │         │Port 5432│         │Port 8080│
   └─────────┘         └─────────┘         └─────────┘
```

## 📱 Client Usage

### Accessing Host Services

From any VPN client, you can access host services using:

```bash
# Web application running on host port 80
curl http://172.17.0.1:80

# Database connection
psql -h 172.17.0.1 -p 5432 -U username

# API endpoint
curl http://172.17.0.1:8080/api/status

# HTTPS services on port 443
curl https://172.17.0.1:443
```

### Service Discovery

**Available endpoints for VPN clients:**

- `10.8.0.1` - OpenVPN server (management/status)
- `10.8.0.x` - Other VPN clients (P2P communication)
- `172.17.0.1` - Docker host (your services)

## 🛠️ Testing Connectivity

### From VPN Client

```bash
# Test P2P connectivity (existing functionality)
ping 10.8.0.1    # VPN server
ping 10.8.0.2    # Another client

# Test host connectivity (new functionality)
ping 172.17.0.1  # Docker host
telnet 172.17.0.1 80   # Test specific service
```

### From Server

```bash
# Check VPN server status
./status-openvpn.sh

# Check host routes are configured
docker exec openvpn-server cat /etc/openvpn/openvpn.conf | grep route

# Test from container to host
docker exec openvpn-server ping 172.17.0.1
```

## 🔍 Troubleshooting

### Common Issues

#### **Host services not accessible**

1. **Check host IP configuration:**
   ```bash
   # Find Docker host IP
   docker network inspect bridge | grep Gateway
   
   # Update .env file if needed
   HOST_IP=172.17.0.1
   ```

2. **Verify routing configuration:**
   ```bash
   # Check OpenVPN routes
   docker exec openvpn-server cat /etc/openvpn/openvpn.conf | grep route
   
   # Should show:
   # push "route 172.17.0.1 255.255.255.255"
   # push "route 172.17.0.0 255.255.0.0"
   ```

3. **Restart OpenVPN server:**
   ```bash
   docker compose restart openvpn
   ```

#### **Services running in other Docker containers**

If your services are in other Docker containers, ensure they're accessible from the host:

```bash
# For services in docker-compose
# Make sure they expose ports to host:
services:
  webapp:
    ports:
      - "80:80"    # Host port 80 -> Container port 80
      - "443:443"  # Host port 443 -> Container port 443
```

#### **Firewall issues**

Check host firewall settings:

```bash
# Allow VPN traffic to host services
sudo ufw allow in on docker0
sudo ufw allow from 10.8.0.0/24
```

## 🔒 Security Considerations

### Network Isolation

- **VPN clients can access host services** through `172.17.0.1`
- **Host services remain isolated** from internet (unless explicitly exposed)
- **P2P traffic stays within VPN** network (`10.8.0.0/24`)

### Service Exposure

Only expose necessary services:

```bash
# Good: Specific service binding
services:
  database:
    ports:
      - "127.0.0.1:5432:5432"  # Only localhost access

# Avoid: Binding to all interfaces
services:
  database:
    ports:
      - "0.0.0.0:5432:5432"    # Accessible from anywhere
```

## 📋 Examples

### Accessing Different Services

#### **Web Application (Nginx/Apache)**

```bash
# From VPN client
curl http://172.17.0.1:80
curl https://172.17.0.1:443
```

#### **Database (PostgreSQL/MySQL)**

```bash
# PostgreSQL connection
psql -h 172.17.0.1 -p 5432 -U dbuser -d mydb

# MySQL connection  
mysql -h 172.17.0.1 -P 3306 -u dbuser -p mydb
```

#### **API Services**

```bash
# REST API calls
curl http://172.17.0.1:8080/api/v1/users
curl -X POST http://172.17.0.1:3000/api/data
```

#### **Development Services**

```bash
# Webpack dev server
http://172.17.0.1:3000

# Next.js development
http://172.17.0.1:3000

# React development server
http://172.17.0.1:3000
```

## 🎯 Use Cases

### Development Environment

- Access local development servers
- Connect to development databases
- Test API endpoints
- Share development services with team

### Production Environment

- Access internal services
- Database administration
- Monitoring dashboards
- Internal APIs

### Hybrid Setup

- P2P file sharing between team members
- Centralized database access
- Shared development resources
- Internal service discovery

## ⚙️ Advanced Configuration

### Custom Host IP

If Docker uses a different bridge IP:

```bash
# Find your Docker bridge IP
ip route | grep docker0

# Update .env file
HOST_IP=172.18.0.1  # or whatever IP is shown
```

### Multiple Host IPs

To access multiple network ranges:

```bash
# Edit configure-host-access.sh and add:
echo 'push "route 192.168.1.0 255.255.255.0"' >> /etc/openvpn/openvpn.conf
```

### Disable Host Access

To disable host access functionality:

```bash
# In .env file
ENABLE_HOST_ACCESS=false
```

## 📊 Monitoring

### Check Connected Clients

```bash
./status-openvpn.sh
```

### Monitor Host Access

```bash
# View OpenVPN logs
docker compose logs -f openvpn

# Check routing table in container
docker exec openvpn-server ip route
```

---

**✅ Your OpenVPN P2P setup now supports both peer-to-peer communication AND host service access!**