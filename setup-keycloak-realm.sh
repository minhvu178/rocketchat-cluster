#!/bin/bash

# Keycloak Realm Setup Script
# This script creates the rocketchat-realm and configures the OAuth client

KEYCLOAK_URL="http://localhost:8080/keycloak"
ADMIN_USER="admin"
ADMIN_PASSWORD="KeycloakAdmin123!"
REALM_NAME="rocketchat-realm"
CLIENT_ID="rocketchat"
REDIRECT_URI="http://109.237.71.25:3000/_oauth/keycloak"

echo "Setting up Keycloak realm and client..."

# Get admin token
echo "Getting admin token..."
TOKEN=$(docker exec rocketchat-keycloak curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Failed to get admin token. Make sure Keycloak is running and admin credentials are correct."
  exit 1
fi

echo "Admin token obtained successfully"

# Create realm
echo "Creating realm: ${REALM_NAME}"
docker exec rocketchat-keycloak curl -s -X POST \
  "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "'${REALM_NAME}'",
    "enabled": true,
    "displayName": "Rocket.Chat Realm",
    "sslRequired": "none"
  }'

# Check if realm was created
REALM_CHECK=$(docker exec rocketchat-keycloak curl -s \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer ${TOKEN}")

if echo "$REALM_CHECK" | grep -q "\"realm\":\"${REALM_NAME}\""; then
  echo "Realm created successfully"
else
  echo "Realm might already exist or creation failed"
fi

# Create client
echo "Creating OAuth client: ${CLIENT_ID}"
CLIENT_JSON='{
  "clientId": "'${CLIENT_ID}'",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "redirectUris": ["'${REDIRECT_URI}'"],
  "webOrigins": ["http://109.237.71.25:3000"],
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "authorizationServicesEnabled": false
}'

RESPONSE=$(docker exec rocketchat-keycloak curl -s -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CLIENT_JSON}")

# Get client ID (internal UUID)
CLIENT_UUID=$(docker exec rocketchat-keycloak curl -s \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
  echo "Failed to create client or client already exists"
else
  echo "Client created successfully"
  
  # Get client secret
  SECRET=$(docker exec rocketchat-keycloak curl -s \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
    -H "Authorization: Bearer ${TOKEN}" | jq -r '.value')
  
  echo ""
  echo "=========================================="
  echo "Keycloak OAuth Configuration"
  echo "=========================================="
  echo "Realm: ${REALM_NAME}"
  echo "Client ID: ${CLIENT_ID}"
  echo "Client Secret: ${SECRET}"
  echo ""
  echo "Use these values in Rocket.Chat OAuth configuration:"
  echo "- URL: http://109.237.71.25:3000/keycloak"
  echo "- Token Path: /realms/${REALM_NAME}/protocol/openid-connect/token"
  echo "- Identity Path: /realms/${REALM_NAME}/protocol/openid-connect/userinfo"
  echo "- Authorize Path: /realms/${REALM_NAME}/protocol/openid-connect/auth"
  echo "- Id: ${CLIENT_ID}"
  echo "- Secret: ${SECRET}"
  echo "=========================================="
fi

# Create a test user (optional)
echo ""
echo "Creating test user..."
USER_JSON='{
  "username": "testuser",
  "email": "testuser@example.com",
  "firstName": "Test",
  "lastName": "User",
  "enabled": true,
  "emailVerified": true,
  "credentials": [{
    "type": "password",
    "value": "testpass123",
    "temporary": false
  }]
}'

docker exec rocketchat-keycloak curl -s -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${USER_JSON}"

echo "Test user created: testuser / testpass123"
echo ""
echo "Setup complete! You can now configure Rocket.Chat OAuth with the values above."