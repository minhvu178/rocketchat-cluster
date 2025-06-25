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

## Keycloak Debugging Journey

### The Problem
When first deploying Keycloak, the admin console at http://109.237.71.25:3000/keycloak/admin would load indefinitely showing "Loading the Administration Console" and then display "somethingWentWrong" error.

### Root Causes Identified

1. **Service Name Mismatch**
   - nginx.conf referenced `rocketchat-keycloak:8080`
   - Docker container actually named service as `keycloak`
   - Fixed by updating nginx upstream to use `keycloak:8080`

2. **Missing Port in Keycloak URLs**
   - Keycloak's admin console JavaScript had `authServerUrl: "http://109.237.71.25/keycloak"` (missing :3000)
   - This prevented API calls from working correctly
   - Browser console showed resources loading but console not initializing

3. **HTTPS Requirement in Development**
   - Initial configuration used `KC_PROXY: edge` which enforces HTTPS
   - API calls to `/keycloak/realms/master/.well-known/openid-configuration` returned 403 "HTTPS required"
   - Changed to `KC_PROXY: passthrough` didn't help

4. **Nginx Path Handling**
   - Requests to `/keycloak` (without trailing slash) redirected incorrectly
   - Added explicit redirect: `location = /keycloak { return 301 http://109.237.71.25:3000/keycloak/; }`

### Debugging Steps

1. **Checked Service Connectivity**
   ```bash
   # From nginx container to Keycloak
   docker exec rocketchat-nginx curl http://keycloak:8080/keycloak/admin
   # Returned 302 redirect - service was running
   ```

2. **Analyzed Request Flow**
   ```
   Browser → NAT (109.237.71.25:3000) → Nginx (port 80) → Keycloak (port 8080)
   ```

3. **Examined Keycloak Environment Configuration**
   ```bash
   curl -s http://109.237.71.25:3000/keycloak/admin/master/console/ | grep authServerUrl
   # Showed URLs missing port 3000
   ```

4. **Tested OIDC Endpoints**
   ```bash
   curl http://109.237.71.25:3000/keycloak/realms/master/.well-known/openid-configuration
   # Initially returned "HTTPS required" error
   ```

### Final Solution

1. **Simplified Keycloak Configuration** (docker-compose.keycloak.yml):
   ```yaml
   environment:
     # Development mode settings
     KC_HTTP_ENABLED: true
     KC_HTTP_RELATIVE_PATH: /keycloak
     KC_HTTP_PORT: 8080
     KC_HOSTNAME_STRICT: false
     KC_HOSTNAME_STRICT_HTTPS: false
   command: start-dev --http-relative-path=/keycloak
   ```

2. **Fixed Nginx Configuration** (nginx-keycloak.conf):
   ```nginx
   # Correct service name
   upstream keycloak_backend {
       server keycloak:8080;
   }
   
   # Handle path without trailing slash
   location = /keycloak {
       return 301 http://109.237.71.25:3000/keycloak/;
   }
   
   # Main Keycloak proxy
   location /keycloak/ {
       proxy_pass http://keycloak_backend/keycloak/;
       proxy_set_header Host $http_host;
       proxy_set_header X-Forwarded-Host 109.237.71.25:3000;
       # ... other headers
   }
   ```

3. **Removed Complex Proxy Settings**
   - Eliminated `KC_PROXY`, `KC_PROXY_HEADERS` settings
   - Let Keycloak run in simple dev mode
   - Avoided HTTPS enforcement issues

### Key Learnings

1. **Always verify service names match between Docker and nginx**
2. **Check browser console for JavaScript errors - not just network tab**
3. **Test API endpoints directly to identify authentication/HTTPS issues**
4. **Simplify configuration for development - avoid production proxy settings**
5. **Use explicit path redirects in nginx for better control**
6. **The NAT setup requires careful attention to port preservation in URLs**

### Verification Commands

```bash
# Test OIDC discovery endpoint
curl -s http://109.237.71.25:3000/keycloak/realms/master/.well-known/openid-configuration | jq .

# Check Keycloak admin login from inside container
docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080/keycloak --realm master --user admin --password KeycloakAdmin123!

# Monitor nginx access logs
docker logs -f rocketchat-nginx

# Check Keycloak startup logs
docker compose -f docker-compose.yml -f docker-compose.keycloak.yml logs keycloak --tail 50
```

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