# Keycloak OAuth Integration Guide for Rocket.Chat

This guide will help you integrate Keycloak as an OAuth provider for your Rocket.Chat cluster.

## Prerequisites

- Rocket.Chat cluster running at http://109.237.71.25:3000
- Keycloak server installed and running
- Admin access to both Rocket.Chat and Keycloak
- A realm created in Keycloak (we'll use "rocketchat-realm" as example)

## Step 1: Create Keycloak Client

### 1.1 Login to Keycloak Admin Console
- Access your Keycloak admin console (usually http://your-keycloak:8080/auth/admin)
- Select your realm or create a new one named "rocketchat-realm"

### 1.2 Create New Client
1. Go to **Clients** → **Create**
2. Fill in:
   - **Client ID**: `rocketchat`
   - **Client Protocol**: `openid-connect`
   - **Root URL**: `http://109.237.71.25:3000`
3. Click **Save**

### 1.3 Configure Client Settings
1. In the client settings, configure:
   - **Access Type**: `confidential`
   - **Standard Flow Enabled**: `ON`
   - **Direct Access Grants Enabled**: `ON`
   - **Valid Redirect URIs**: 
     - `http://109.237.71.25:3000/_oauth/keycloak`
     - `http://109.237.71.25:3000/*`
   - **Web Origins**: `http://109.237.71.25:3000`
2. Click **Save**

### 1.4 Get Client Credentials
1. Go to the **Credentials** tab
2. Copy the **Secret** value - you'll need this for Rocket.Chat

## Step 2: Configure Rocket.Chat

### 2.1 Add Custom OAuth
1. Login to Rocket.Chat as admin
2. Go to **Administration → Workspace → Settings → OAuth**
3. Click **Add custom oauth**
4. Enter name: `keycloak`
5. Click **Add**

### 2.2 Configure OAuth Settings
After adding, refresh the page and configure these settings:

**Basic Settings:**
- **Enable**: `True`
- **URL**: `http://your-keycloak-server:8080/auth` (replace with your Keycloak URL)
- **Token Path**: `/realms/rocketchat-realm/protocol/openid-connect/token`
- **Token Sent Via**: `Header`
- **Identity Token Sent Via**: `Same as Token Sent Via`
- **Identity Path**: `/realms/rocketchat-realm/protocol/openid-connect/userinfo`
- **Authorize Path**: `/realms/rocketchat-realm/protocol/openid-connect/auth`
- **Scope**: `openid profile email`
- **Param Name for access token**: `access_token`
- **Id**: `keycloak`
- **Secret**: (paste the secret from Keycloak client credentials)

**Advanced Settings:**
- **Login Style**: `redirect`
- **Button Text**: `Login with Keycloak`
- **Button Label Text**: `Login with Keycloak`
- **Button Color**: `#0088CC`
- **Button Text Color**: `#FFFFFF`
- **Username field**: `preferred_username`
- **Email field**: `email`
- **Name field**: `name`
- **Roles/Groups field name**: `groups`
- **Roles/Groups Path for Callback**: `groups`
- **Merge Roles from SSO**: `True`
- **Show Button on Login Page**: `True`

### 2.3 Save and Refresh
1. Click **Save Changes**
2. Click **Refresh OAuth Services** at the top of the OAuth page

## Step 3: Test the Integration

1. Logout from Rocket.Chat
2. You should see a "Login with Keycloak" button on the login page
3. Click it - you'll be redirected to Keycloak
4. Login with your Keycloak credentials
5. You'll be redirected back to Rocket.Chat and logged in

## Step 4: (Optional) Configure Role Mapping

### 4.1 Create Mapper in Keycloak
1. In Keycloak, go to your client → **Mappers**
2. Click **Create**
3. Configure:
   - **Name**: `groups`
   - **Mapper Type**: `Group Membership`
   - **Token Claim Name**: `groups`
   - **Full group path**: `OFF`
   - **Add to ID token**: `ON`
   - **Add to access token**: `ON`
   - **Add to userinfo**: `ON`

### 4.2 Create Groups in Keycloak
1. Go to **Groups** → **New**
2. Create groups like:
   - `rocketchat-admin`
   - `rocketchat-user`
   - `rocketchat-moderator`

### 4.3 Assign Users to Groups
1. Go to **Users**
2. Select a user → **Groups** tab
3. Join the appropriate groups

### 4.4 Map Groups to Rocket.Chat Roles
In Rocket.Chat OAuth settings:
- **Roles/Groups field name**: `groups`
- **Roles/Groups Path for Callback**: `groups`
- **Merge Roles from SSO**: `True`

## Step 5: Docker Compose Example for Keycloak

If you need to deploy Keycloak alongside Rocket.Chat:

```yaml
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
      KC_PROXY: edge
      KC_HOSTNAME_STRICT: false
      KC_HOSTNAME_STRICT_HTTPS: false
      KC_HTTP_ENABLED: true
    command: start-dev
    ports:
      - "8080:8080"
    networks:
      - rocketchat-network
```

## Troubleshooting

### Issue: "Invalid redirect_uri"
- Ensure the redirect URI in Keycloak exactly matches: `http://109.237.71.25:3000/_oauth/keycloak`
- Check that you're using the correct realm name in all paths

### Issue: "Invalid client credentials"
- Verify the client secret is copied correctly
- Ensure the client access type is set to "confidential"

### Issue: Connection refused
- If using Docker, ensure Keycloak container is on the same network
- Use the container name instead of localhost
- Example: `http://keycloak:8080/auth` instead of `http://localhost:8080/auth`

### Issue: User authenticated but not logged into Rocket.Chat
- Check username field mapping (try `sub` if `preferred_username` doesn't work)
- Verify email is properly mapped
- Check Rocket.Chat logs: `docker compose logs rocketchat`

## Environment Variables Alternative

You can also configure Keycloak OAuth via environment variables in docker-compose.yml:

```yaml
environment:
  # Keycloak OAuth
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak: "true"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-url: "http://keycloak:8080/auth"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-token_path: "/realms/rocketchat-realm/protocol/openid-connect/token"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-identity_path: "/realms/rocketchat-realm/protocol/openid-connect/userinfo"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-authorize_path: "/realms/rocketchat-realm/protocol/openid-connect/auth"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-id: "rocketchat"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-secret: "your-client-secret"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-login_style: "redirect"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-username_field: "preferred_username"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-email_field: "email"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-name_field: "name"
  OVERWRITE_SETTING_Accounts_OAuth_Custom-Keycloak-scope: "openid profile email"
```

## Security Considerations

1. **Use HTTPS in Production**: Replace all HTTP URLs with HTTPS
2. **Secure Client Secret**: Store the client secret securely
3. **Restrict Valid Redirect URIs**: Only add necessary URIs
4. **Enable SSL/TLS**: Configure proper certificates for both Keycloak and Rocket.Chat

## Next Steps

1. Configure user attributes mapping
2. Set up automatic user provisioning
3. Implement Single Logout (SLO)
4. Configure refresh token handling
5. Set up multi-factor authentication in Keycloak