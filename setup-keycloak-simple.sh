#!/bin/bash

# Simple Keycloak Setup using kcadm.sh

echo "Setting up Keycloak realm and client..."

# Login to Keycloak
echo "Logging in to Keycloak..."
docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080/keycloak \
  --realm master \
  --user admin \
  --password KeycloakAdmin123!

# Create realm
echo "Creating rocketchat-realm..."
docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh create realms \
  -s realm=rocketchat-realm \
  -s enabled=true \
  -s displayName="Rocket.Chat Realm" \
  -s sslRequired=none

# Create client
echo "Creating OAuth client..."
CLIENT_ID=$(docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh create clients \
  -r rocketchat-realm \
  -s clientId=rocketchat \
  -s enabled=true \
  -s publicClient=false \
  -s 'redirectUris=["http://109.237.71.25:3000/_oauth/keycloak"]' \
  -s 'webOrigins=["http://109.237.71.25:3000"]' \
  -s protocol=openid-connect \
  -s directAccessGrantsEnabled=false \
  -i)

echo "Client created with ID: $CLIENT_ID"

# Get client secret
echo "Getting client secret..."
SECRET=$(docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_ID/client-secret \
  -r rocketchat-realm \
  --fields value \
  --format csv \
  --noquotes)

# Create test user
echo "Creating test user..."
docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh create users \
  -r rocketchat-realm \
  -s username=testuser \
  -s email=testuser@example.com \
  -s firstName=Test \
  -s lastName=User \
  -s enabled=true \
  -s emailVerified=true

# Set user password
docker exec rocketchat-keycloak /opt/keycloak/bin/kcadm.sh set-password \
  -r rocketchat-realm \
  --username testuser \
  --new-password testpass123

echo ""
echo "=========================================="
echo "Keycloak OAuth Configuration"
echo "=========================================="
echo "Realm: rocketchat-realm"
echo "Client ID: rocketchat"
echo "Client Secret: $SECRET"
echo ""
echo "Use these values in Rocket.Chat OAuth configuration:"
echo "- URL: http://109.237.71.25:3000/keycloak"
echo "- Token Path: /realms/rocketchat-realm/protocol/openid-connect/token"
echo "- Identity Path: /realms/rocketchat-realm/protocol/openid-connect/userinfo"
echo "- Authorize Path: /realms/rocketchat-realm/protocol/openid-connect/auth"
echo "- Id: rocketchat"
echo "- Secret: $SECRET"
echo "=========================================="
echo ""
echo "Test user: testuser / testpass123"
echo ""
echo "You can now access the realm at: http://109.237.71.25:3000/keycloak/admin/rocketchat-realm/console/"