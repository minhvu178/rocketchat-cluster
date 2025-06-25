# Rocket.Chat High Availability Cluster with Keycloak SSO

A production-ready Rocket.Chat deployment with MongoDB replica set, Redis session management, Nginx load balancing, and Keycloak authentication. This setup is designed for high availability and scalability with enterprise-grade authentication.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [Keycloak Integration](#keycloak-integration)
- [Administration Guide](#administration-guide)
- [Troubleshooting](#troubleshooting)
- [Development Workflow](#development-workflow)

## Architecture Overview

```
Internet (109.237.71.25:3000)
    ↓
NAT Gateway (Port 3000 → 80)
    ↓
VM (172.10.0.248)
    ↓
Nginx Load Balancer (Port 80)
    ├── /keycloak/* → Keycloak (Port 8080)
    └── /* → Rocket.Chat Instances (Port 3000)
              ├── Instance 1
              ├── Instance 2
              └── Instance 3
                    ↓
         ┌─────────────────────┐
         │   MongoDB Replica   │
         │  ├── Primary        │
         │  ├── Secondary 1    │
         │  └── Secondary 2    │
         └─────────────────────┘
                    ↓
              Redis (Sessions)
```

### Components

- **3x Rocket.Chat Instances**: Horizontally scaled for high availability
- **MongoDB Replica Set**: 3-node cluster for data persistence
- **Redis**: Session sharing across Rocket.Chat instances
- **Nginx**: Load balancer and reverse proxy
- **Keycloak**: Identity provider for SSO/OAuth
- **PostgreSQL**: Database for Keycloak

## Prerequisites

- Docker and Docker Compose installed
- Ubuntu/Debian host (tested on Ubuntu 24.04)
- Minimum 4GB RAM, 20GB storage
- Port 3000 available (for NAT setup)
- Git for version control

## Quick Start

```bash
# Clone the repository
git clone https://github.com/minhvu178/rocketchat-cluster.git
cd rocketchat-cluster

# Run the automated setup
./setup.sh

# Choose option 1: Deploy complete cluster
# Wait for services to start (~2-3 minutes)

# Access Rocket.Chat
# URL: http://your-server-ip:3000
```

## Detailed Setup Guide

### 1. Initial Deployment

```bash
# Deploy core services (MongoDB, Redis, Rocket.Chat, Nginx)
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs -f
```

### 2. MongoDB Replica Set Configuration

The replica set is automatically initialized via `mongo-init.js`. To verify:

```bash
docker exec mongodb-primary mongosh --eval "rs.status()"
```

### 3. Nginx Configuration

Nginx is configured to:
- Load balance between Rocket.Chat instances using IP hash
- Proxy Keycloak on `/keycloak/*` path
- Handle WebSocket connections
- Preserve client IPs and ports

Key configuration (`nginx-keycloak.conf`):
```nginx
upstream rocketchat_backend {
    ip_hash;  # Sticky sessions
    server rocketchat:3000;
}

upstream keycloak_backend {
    server keycloak:8080;
}

# Keycloak proxy with path prefix
location /keycloak/ {
    proxy_pass http://keycloak_backend/keycloak/;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Host 109.237.71.25:3000;
    # ... additional headers
}
```

### 4. Scaling Rocket.Chat

```bash
# Scale to 5 instances
docker compose up -d --scale rocketchat=5

# Scale back to 3 instances
docker compose up -d --scale rocketchat=3
```

## Keycloak Integration

### 1. Deploy Keycloak

```bash
# Deploy Keycloak with PostgreSQL
docker compose -f docker-compose.yml -f docker-compose.keycloak.yml up -d

# Wait for Keycloak to start
docker compose logs -f keycloak
```

### 2. Initial Keycloak Setup

Run the automated setup script:

```bash
./setup-keycloak-simple.sh
```

This creates:
- `rocketchat-realm`: Dedicated realm for Rocket.Chat
- `rocketchat` OAuth client with proper redirect URIs
- Test user: `testuser` / `testpass123`

### 3. Configure Rocket.Chat OAuth

1. Access Rocket.Chat Admin: http://your-server:3000/admin/settings/OAuth
2. Add Custom OAuth provider with these settings:

```
Enable: True
URL: http://109.237.71.25:3000/keycloak
Token Path: /realms/rocketchat-realm/protocol/openid-connect/token
Token Sent Via: Header
Identity Token Sent Via: Same as Token Sent Via
Identity Path: /realms/rocketchat-realm/protocol/openid-connect/userinfo
Authorize Path: /realms/rocketchat-realm/protocol/openid-connect/auth?prompt=login
Scope: openid profile email
Id: rocketchat
Secret: [Client secret from Keycloak]
Button Text: Login with Keycloak
Key Field: preferred_username
Username Field: preferred_username
Email Field: email
Name Field: name
```

### 4. Keycloak Administration

Access Keycloak Admin Console:
- URL: http://your-server:3000/keycloak/
- Username: `admin`
- Password: `KeycloakAdmin123!`

To manage the rocketchat-realm:
1. Login as master admin
2. Switch to `rocketchat-realm` from the dropdown
3. Create users, configure client settings, etc.

## Administration Guide

### Managing Rocket.Chat

#### 1. First Admin Setup

After deployment:
1. Access http://your-server:3000
2. Complete the setup wizard
3. Create the first admin account

#### 2. Creating Teams (Workspace-like separation)

1. Click **Create New** → **Create Team**
2. Configure:
   - Team Name: e.g., "Engineering Team"
   - Privacy: Private (invite-only)
   - Description: Team purpose

#### 3. User Management

**Via Rocket.Chat:**
- Admin → Users → Add User
- Set roles: admin, moderator, user, etc.

**Via Keycloak (SSO users):**
1. Access Keycloak admin console
2. Switch to rocketchat-realm
3. Users → Add User
4. Set password in Credentials tab

#### 4. Backup and Restore

**Backup MongoDB:**
```bash
# Create backup
docker exec mongodb-primary mongodump --out /data/backup

# Copy to host
docker cp mongodb-primary:/data/backup ./mongodb-backup
```

**Restore MongoDB:**
```bash
# Copy backup to container
docker cp ./mongodb-backup mongodb-primary:/data/backup

# Restore
docker exec mongodb-primary mongorestore /data/backup
```

### Monitoring

#### Check Service Health
```bash
# All services status
docker compose ps

# Resource usage
docker stats

# Rocket.Chat logs
docker compose logs -f rocketchat

# MongoDB replica set status
docker exec mongodb-primary mongosh --eval "rs.status()"
```

#### Nginx Access Logs
```bash
docker logs -f rocketchat-nginx
```

## Troubleshooting

### Common Issues

#### 1. Keycloak "Something Went Wrong" Error

**Symptoms:** Admin console shows loading screen then error

**Solutions:**
- Verify service name in nginx matches Docker service
- Check if running in dev mode without HTTPS enforcement
- Ensure proper path configuration (`KC_HTTP_RELATIVE_PATH`)

#### 2. MongoDB Connection Issues

**Check replica set:**
```bash
docker exec mongodb-primary mongosh --eval "rs.status()"
```

**Reinitialize if needed:**
```bash
docker compose down -v
docker compose up -d
# Wait 30 seconds
docker exec mongodb-primary mongosh /docker-entrypoint-initdb.d/mongo-init.js
```

#### 3. OAuth Login Loops

**Verify:**
- Client ID matches between Keycloak and Rocket.Chat
- Redirect URI is exactly: `http://your-server:3000/_oauth/keycloak`
- Client secret is correct

#### 4. Session Issues

**Clear Redis:**
```bash
docker compose restart redis
```

### Debug Commands

```bash
# Test Keycloak connectivity
curl -s http://your-server:3000/keycloak/realms/rocketchat-realm/.well-known/openid-configuration

# Check Nginx routing
docker exec rocketchat-nginx curl http://keycloak:8080/keycloak/

# Verify DNS resolution
docker exec rocketchat-nginx nslookup rocketchat

# MongoDB connection string
docker exec rocketchat-cluster-rocketchat-1 printenv MONGO_URL
```

## Development Workflow

### IMPORTANT: Always Edit Locally → Push to GitHub → Pull on VM

**Never edit files directly on the production VM!**

#### 1. Local Development
```bash
# Make changes locally
git add .
git commit -m "Description of changes"
git push origin main
```

#### 2. Deploy to VM
```bash
# SSH to VM
ssh -p 2222 -i ~/.ssh/stg root@109.237.71.25

# Navigate to project
cd /root/rocketchat-cluster

# Pull latest changes
git pull origin main

# Apply changes
docker compose down
docker compose -f docker-compose.yml -f docker-compose.keycloak.yml up -d
```

### Configuration Files

- `docker-compose.yml`: Core services configuration
- `docker-compose.keycloak.yml`: Keycloak addon configuration  
- `nginx-keycloak.conf`: Nginx routing and load balancing
- `mongo-init.js`: MongoDB replica set initialization
- `.env`: Environment variables (create from `.env.example`)

### Environment Variables

Create `.env` file:
```env
# Rocket.Chat Configuration
ROOT_URL=http://109.237.71.25:3000
MONGO_URL=mongodb://mongodb-primary:27017,mongodb-secondary1:27017,mongodb-secondary2:27017/rocketchat?replicaSet=rs0
MONGO_OPLOG_URL=mongodb://mongodb-primary:27017,mongodb-secondary1:27017,mongodb-secondary2:27017/local?replicaSet=rs0

# Keycloak Configuration
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=KeycloakAdmin123!
KC_DB_PASSWORD=keycloak123
```

## Security Considerations

1. **Change Default Passwords:**
   - MongoDB root password
   - Keycloak admin password
   - PostgreSQL passwords

2. **Enable HTTPS:**
   - Add SSL certificates to Nginx
   - Update ROOT_URL to use https://
   - Configure Keycloak for production mode

3. **Firewall Rules:**
   - Only expose port 3000 (or 443 for HTTPS)
   - Block direct access to MongoDB, Redis, etc.

4. **Regular Updates:**
   ```bash
   # Update images
   docker compose pull
   docker compose up -d
   ```

## Performance Tuning

### MongoDB
```javascript
// Add indexes for better performance
db.rocketchat_message.createIndex({ "rid": 1, "ts": -1 })
db.rocketchat_message.createIndex({ "u._id": 1 })
```

### Nginx
- Adjust `worker_connections` based on load
- Enable caching for static assets
- Configure rate limiting

### Rocket.Chat
- Set `INSTANCE_IP` for each instance in production
- Configure file upload limits
- Adjust Node.js memory: `NODE_OPTIONS="--max-old-space-size=4096"`

## Additional Resources

- [Rocket.Chat Documentation](https://docs.rocket.chat/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [MongoDB Replica Set Guide](https://docs.mongodb.com/manual/replication/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs: `docker compose logs -f [service-name]`
3. Check service status: `docker compose ps`
4. Refer to CLAUDE.md for detailed debugging steps

## License

This configuration is provided as-is for educational and production use. Ensure you comply with all software licenses for the included components.