# Rocket.Chat Cluster Development Workflow

## CRITICAL WORKFLOW - ALWAYS FOLLOW THIS PROCESS

### 🚨 IMPORTANT: Edit Locally → Push to GitHub → Pull on VM

**NEVER edit files directly on the VM.** Always follow this workflow:

1. **Edit on Local Machine** (your development environment)
2. **Push to GitHub** (version control)
3. **Pull on VM** (deployment)

This ensures:
- Version control tracks all changes
- Easy rollback if issues occur
- Consistent deployment process
- No accidental production changes

## Deployment Commands

### On Local Machine:
```bash
# After making changes
git add .
git commit -m "Description of changes"
git push origin main
```

### On VM (172.10.0.248):
```bash
# SSH to VM
ssh -p 2222 -i ~/.ssh/stg root@109.237.71.25

# Navigate to project directory
cd /root/rocketchat-cluster

# Pull latest changes from GitHub
git pull origin main

# Apply changes
docker compose down
docker compose up -d

# Or for Keycloak deployment
docker compose -f docker-compose.yml -f docker-compose.keycloak.yml up -d
```

## Network Architecture

### NAT Configuration
- **External Access**: 109.237.71.25:3000
- **Internal VM**: 172.10.0.248:80
- **NAT Rule**: Port 3000 → Port 80

### Service Access URLs
- **Rocket.Chat**: http://109.237.71.25:3000
- **Keycloak Admin**: http://109.237.71.25:3000/keycloak/admin
- **All services** must be accessed through port 3000

## Key Configuration Files

### docker-compose.yml
- Main orchestration file
- MongoDB replica set (3 nodes)
- Rocket.Chat instances (scalable)
- Redis for session sharing
- Nginx load balancer

### nginx-keycloak.conf
- Proxies both Rocket.Chat and Keycloak
- Path-based routing (/keycloak/* for Keycloak)
- Preserves port information in headers

### docker-compose.keycloak.yml
- Keycloak identity provider
- PostgreSQL database
- Configured for proxy deployment

## Common Tasks

### Check Service Status
```bash
docker compose ps
docker compose logs -f [service-name]
```

### Scale Rocket.Chat Instances
```bash
docker compose up -d --scale rocketchat=5
```

### Restart Services After Config Changes
```bash
docker compose restart nginx
docker compose restart rocketchat
```

### MongoDB Replica Set Status
```bash
docker compose exec mongodb-primary mongosh --eval "rs.status()"
```

## Troubleshooting

### Always Check Logs First
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f keycloak
docker compose logs -f rocketchat
docker compose logs -f nginx
```

### Common Issues

1. **Port Access Issues**
   - Remember: Only port 3000 is exposed via NAT
   - All services must be proxied through Nginx

2. **Configuration Changes Not Applied**
   - Did you pull from GitHub on the VM?
   - Did you restart the affected services?

3. **MongoDB Connection Issues**
   - Check replica set status
   - Ensure all MongoDB nodes are running

## Project Details

### VM Access
- **SSH Command**: `ssh -p 2222 -i ~/.ssh/stg root@109.237.71.25`
- **Project Location**: `/root/rocketchat-cluster`
- **GitHub Repository**: https://github.com/minhvu178/rocketchat-cluster.git

### Docker Network
- **Network Name**: rocketchat-cluster_rocketchat-network
- **All services** communicate through this network

### Current Services (Container Names)
- **mongodb-primary**: Primary MongoDB node
- **mongodb-secondary1**: Secondary MongoDB node 1
- **mongodb-secondary2**: Secondary MongoDB node 2
- **rocketchat-cluster-rocketchat-1**: Rocket.Chat instance 1
- **rocketchat-cluster-rocketchat-2**: Rocket.Chat instance 2
- **rocketchat-cluster-rocketchat-3**: Rocket.Chat instance 3
- **rocketchat-keycloak**: Keycloak identity provider (service name: keycloak)
- **rocketchat-keycloak-db**: PostgreSQL for Keycloak
- **rocketchat-nginx**: Nginx load balancer/proxy
- **rocketchat-redis**: Redis for session sharing

## Development Best Practices

1. **Test Locally First**
   - Use docker compose locally to test changes
   - Verify services start without errors

2. **Commit Meaningful Messages**
   - Describe what changed and why
   - Reference any issues or tickets

3. **Monitor After Deployment**
   - Watch logs after pulling changes
   - Verify all services are healthy
   - Test functionality through browser

## OAuth Integration Notes

### Keycloak Configuration
- URL: http://109.237.71.25:3000/keycloak
- Realm: rocketchat-realm
- Client ID: rocketchat
- Redirect URI: http://109.237.71.25:3000/_oauth/keycloak

### Testing OAuth
1. Always test login flow after changes
2. Check both Keycloak and Rocket.Chat logs
3. Verify redirect URLs match exactly

## Emergency Procedures

### Full Reset
```bash
# On VM - BE CAREFUL!
docker compose down -v
docker volume prune -f
git pull origin main
./setup.sh  # Choose option 1
```

### Rollback Changes
```bash
# On local machine
git log --oneline
git revert [commit-hash]
git push origin main

# On VM
git pull origin main
docker compose up -d
```

## Remember

**The golden rule: NEVER edit on the VM directly!**

Local → GitHub → VM

This workflow ensures reliable, traceable deployments.