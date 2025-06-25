# Keycloak Routing Analysis

## Current Path Flow

```
Browser Request                     → NAT       → Nginx              → Keycloak Container
================================================================================
http://109.237.71.25:3000/keycloak/ → :3000→:80 → /keycloak/         → http://keycloak:8080/keycloak/
                                                  ↓                      ↓
                                                  proxy_pass           KC_HTTP_RELATIVE_PATH=/keycloak
                                                  
Response Flow:
Keycloak (302) → Nginx → NAT → Browser
/keycloak/admin/master/console/
```

## Nginx Configuration
```nginx
location /keycloak/ {
    proxy_pass http://keycloak_backend/keycloak/;
    proxy_set_header Host $http_host;
    # ... other headers
}

upstream keycloak_backend {
    server keycloak:8080;
}
```

## Keycloak Configuration
- `KC_HTTP_RELATIVE_PATH: /keycloak` - All paths prefixed with /keycloak
- `KC_PROXY: edge` - Expects to be behind a proxy
- `KC_HOSTNAME_STRICT: false` - Accepts any hostname

## Request Examples

### 1. Initial Request
```
GET http://109.237.71.25:3000/keycloak/admin
→ Nginx receives: /keycloak/admin
→ Proxies to: http://keycloak:8080/keycloak/admin
→ Keycloak responds: 302 Location: /keycloak/admin/master/console/
```

### 2. Console Request
```
GET http://109.237.71.25:3000/keycloak/admin/master/console/
→ Nginx receives: /keycloak/admin/master/console/
→ Proxies to: http://keycloak:8080/keycloak/admin/master/console/
→ Keycloak responds: 200 OK + HTML
```

### 3. Static Resources
```
GET http://109.237.71.25:3000/keycloak/resources/ruz3p/admin/keycloak.v2/assets/main-BFMiUjhv.js
→ Nginx receives: /keycloak/resources/...
→ Proxies to: http://keycloak:8080/keycloak/resources/...
→ Keycloak responds: 200 OK + JavaScript
```

## Potential Issues

1. **JavaScript Base URL**: The admin console JavaScript might be configured with wrong base URLs
2. **API Calls**: The console makes API calls that might fail due to path issues
3. **WebSocket**: Admin console might use WebSocket connections that aren't properly proxied