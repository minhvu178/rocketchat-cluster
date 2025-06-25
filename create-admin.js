// MongoDB script to create admin user
// Usage: docker compose exec -T mongodb-primary mongosh rocketchat < create-admin.js

db.users.insertOne({
  "_id": "admin.rocketchat",
  "createdAt": new Date(),
  "services": {
    "password": {
      // Password: Admin123! (you should change this)
      "bcrypt": "$2b$10$jzSFyTc9MWiTcnmBVfviM.vjCdm8EMbmG7ECQslP2bcCrS.XenOsy"
    },
    "email": {
      "verificationTokens": []
    }
  },
  "username": "admin",
  "emails": [{
    "address": "admin@rocketchat.local",
    "verified": true
  }],
  "type": "user",
  "status": "offline",
  "active": true,
  "roles": ["admin"],
  "name": "Administrator",
  "requirePasswordChange": false,
  "_updatedAt": new Date()
});

print("Admin user created!");
print("Username: admin");
print("Password: Admin123!");
print("Please change the password after first login!");