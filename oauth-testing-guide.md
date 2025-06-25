# OAuth Testing Guide for Rocket.Chat Cluster

This guide will help you test OAuth authentication with your Rocket.Chat cluster using GitHub, Google, or GitLab.

## Prerequisites

- Admin access to your Rocket.Chat instance (http://109.237.71.25)
- Developer account on the OAuth provider (GitHub, Google, or GitLab)
- Access to create OAuth applications

## 1. GitHub OAuth (Easiest to Test)

### Step 1: Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click "OAuth Apps" → "New OAuth App"
3. Fill in the details:
   - **Application name**: Rocket.Chat Test
   - **Homepage URL**: http://109.237.71.25
   - **Authorization callback URL**: http://109.237.71.25/_oauth/github
4. Click "Register application"
5. Copy the **Client ID** and generate a **Client Secret**

### Step 2: Configure in Rocket.Chat

1. Login to Rocket.Chat as admin
2. Go to **Administration → Workspace → Settings → OAuth**
3. Click on **GitHub** tab
4. Enable **GitHub Login**
5. Fill in:
   - **Id**: Your GitHub Client ID
   - **Secret**: Your GitHub Client Secret
6. Click **Save Changes**
7. Click **Refresh OAuth Services** at the top

### Step 3: Test Login

1. Logout from Rocket.Chat
2. You should see "Sign in with GitHub" button on login page
3. Click it and authorize the app

## 2. Google OAuth

### Step 1: Create Google OAuth Credentials

1. Go to https://console.cloud.google.com/
2. Create a new project or select existing one
3. Enable Google+ API:
   - Go to **APIs & Services → Library**
   - Search for "Google+ API" and enable it
4. Create credentials:
   - Go to **APIs & Services → Credentials**
   - Click **Create Credentials → OAuth client ID**
   - Configure consent screen first if needed
   - Application type: **Web application**
   - Name: Rocket.Chat Test
   - Authorized redirect URIs: 
     - http://109.237.71.25/_oauth/google
     - http://109.237.71.25/_oauth/google/callback
5. Copy **Client ID** and **Client Secret**

### Step 2: Configure in Rocket.Chat

1. Go to **Administration → Workspace → Settings → OAuth**
2. Click on **Google** tab
3. Enable **Google Login**
4. Fill in:
   - **Id**: Your Google Client ID
   - **Secret**: Your Google Client Secret
5. Click **Save Changes**
6. Click **Refresh OAuth Services**

## 3. GitLab OAuth

### Step 1: Create GitLab Application

1. Go to https://gitlab.com/-/profile/applications
2. Click "New Application"
3. Fill in:
   - **Name**: Rocket.Chat Test
   - **Redirect URI**: http://109.237.71.25/_oauth/gitlab
   - **Scopes**: Select `read_user`, `openid`, `profile`, `email`
4. Click "Save application"
5. Copy **Application ID** and **Secret**

### Step 2: Configure in Rocket.Chat

1. Go to **Administration → Workspace → Settings → OAuth**
2. Click on **GitLab** tab
3. Enable **GitLab Login**
4. Fill in:
   - **GitLab Id**: Your Application ID
   - **Client Secret**: Your Secret
   - **GitLab URL**: https://gitlab.com (or your self-hosted URL)
5. Click **Save Changes**
6. Click **Refresh OAuth Services**

## 4. Custom OAuth Provider

You can also create a custom OAuth provider for testing:

1. Go to **Administration → Workspace → Settings → OAuth**
2. Click **Add custom oauth**
3. Give it a name (e.g., "TestOAuth")
4. Configure the endpoints and settings

## Testing Multiple OAuth Providers

To test the cluster's OAuth handling:

1. Configure multiple providers (GitHub + Google)
2. Test login with different users on different providers
3. Verify session handling across cluster nodes
4. Test logout and re-login
5. Check if sessions persist when one node goes down

## Troubleshooting

### OAuth Button Not Appearing
- Make sure to click "Refresh OAuth Services"
- Clear browser cache
- Check if the service is enabled

### Callback URL Errors
- Ensure the callback URL matches exactly
- Use HTTP (not HTTPS) for your test server
- Check for trailing slashes

### Session Issues in Cluster
- Redis should handle session sharing
- Check Redis logs: `docker compose logs redis`
- Verify all Rocket.Chat instances can connect to Redis

## Security Notes

⚠️ **For Testing Only**: Using HTTP is not secure. In production:
- Use HTTPS with valid SSL certificates
- Update all OAuth callback URLs to HTTPS
- Enable secure cookies in Rocket.Chat settings

## Quick Test Script

```bash
# Check OAuth endpoints are accessible
curl -I http://109.237.71.25/_oauth/github
curl -I http://109.237.71.25/_oauth/google
curl -I http://109.237.71.25/_oauth/gitlab

# Check cluster health
ssh -p 2222 -i ~/.ssh/stg root@109.237.71.25 "cd /root/rocketchat-cluster && docker compose ps"
```

## Next Steps

1. Test OAuth with multiple users simultaneously
2. Verify load balancing works with OAuth sessions
3. Test OAuth token refresh mechanisms
4. Monitor Redis for session data
5. Test failover scenarios