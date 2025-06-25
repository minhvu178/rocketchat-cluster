# Keycloak Path Configuration and Routing Map

## Investigation Date: June 25, 2025

## Environment Configuration
- **Keycloak Environment Variables:**
  - `KC_HTTP_RELATIVE_PATH=/keycloak` - This sets Keycloak to serve from /keycloak path
  - `KC_PROXY=edge` - Configured for reverse proxy
  - `KC_PROXY_HEADERS=xforwarded` - Uses X-Forwarded headers
  - `KC_HOSTNAME_STRICT=false` - Accepts any hostname
  - `KC_HTTP_PORT=8080` - Internal port

## Keycloak Internal Routing (from nginx container to keycloak:8080)

### Root Path Behavior
- **Request:** `http://keycloak:8080/`
- **Response:** `302 Found` → Redirects to `/keycloak`
- **Note:** Root path automatically redirects to the configured relative path

### Keycloak Base Path
- **Request:** `http://keycloak:8080/keycloak/`
- **Response:** `302 Found` → Redirects to `/keycloak/admin/`
- **Note:** Base Keycloak path redirects to admin console

### Admin Console Path
- **Request:** `http://keycloak:8080/keycloak/admin`
- **Response:** `302 Found` → Redirects to `/keycloak/admin/master/console/`
- **Note:** Admin path redirects to full console URL

### Admin Console (Final)
- **Request:** `http://keycloak:8080/keycloak/admin/master/console/`
- **Response:** `200 OK` - Returns HTML content
- **Note:** This is the actual admin console page

### API Endpoints
- **Request:** `http://keycloak:8080/keycloak/realms/master`
- **Response:** `200 OK` - Returns JSON
- **Note:** REST API endpoints work correctly

### OpenID Configuration
- **Request:** `http://keycloak:8080/keycloak/realms/master/.well-known/openid-configuration`
- **Response:** `200 OK` - Returns OIDC discovery document
- **Note:** All endpoints in the document use the `/keycloak` prefix

### Invalid Paths (404 Responses)
- `http://keycloak:8080/admin` - 404 (missing /keycloak prefix)
- `http://keycloak:8080/admin/master/console/` - 404 (missing /keycloak prefix)

## Nginx Proxy Configuration

### Current Configuration
```nginx
location /keycloak/ {
    proxy_pass http://keycloak_backend/keycloak/;
    proxy_set_header Host $http_host;
    # Preserves port in Host header (109.237.71.25:3000)
}
```

### Request Flow
1. **Browser:** `http://109.237.71.25:3000/keycloak/admin`
2. **NAT:** Port 3000 → Port 80 (on VM)
3. **Nginx:** Receives request on port 80
4. **Nginx → Keycloak:** Proxies to `http://keycloak:8080/keycloak/admin`
5. **Keycloak:** Returns 302 redirect to `/keycloak/admin/master/console/`
6. **Browser:** Follows redirect to `http://109.237.71.25:3000/keycloak/admin/master/console/`

## Key Findings

1. **Keycloak requires the `/keycloak` prefix** for all paths when `KC_HTTP_RELATIVE_PATH=/keycloak` is set
2. **Direct access to paths without the prefix returns 404**
3. **The nginx configuration correctly preserves the `/keycloak/` path** when proxying
4. **All redirects maintain the correct external URL** including port 3000
5. **Static resources load correctly** from `/keycloak/resources/...`

## Correct URLs for Access

### External Access (via NAT)
- **Admin Console:** `http://109.237.71.25:3000/keycloak/admin`
- **Realms API:** `http://109.237.71.25:3000/keycloak/realms/master`
- **OIDC Discovery:** `http://109.237.71.25:3000/keycloak/realms/master/.well-known/openid-configuration`

### OAuth/OIDC Configuration for Rocket.Chat
- **Authorization URL:** `http://109.237.71.25:3000/keycloak/realms/rocketchat-realm/protocol/openid-connect/auth`
- **Token URL:** `http://109.237.71.25:3000/keycloak/realms/rocketchat-realm/protocol/openid-connect/token`
- **User Info URL:** `http://109.237.71.25:3000/keycloak/realms/rocketchat-realm/protocol/openid-connect/userinfo`
- **Redirect URI:** `http://109.237.71.25:3000/_oauth/keycloak`

## Summary

The current configuration is working correctly. Keycloak is properly configured to serve from the `/keycloak` path, and nginx is correctly proxying requests while preserving the necessary headers and paths. The 302 redirects are normal Keycloak behavior for navigating to the admin console.