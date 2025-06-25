// MongoDB replica set initialization script
print('Starting replica set initialization...');

// Wait for MongoDB to be ready
sleep(5000);

// Initialize replica set
try {
  rs.status();
  print('Replica set already initialized');
} catch (e) {
  print('Initializing replica set...');
  rs.initiate({
    _id: 'rs0',
    members: [
      { _id: 0, host: 'mongodb-primary:27017', priority: 2 },
      { _id: 1, host: 'mongodb-secondary1:27017', priority: 1 },
      { _id: 2, host: 'mongodb-secondary2:27017', priority: 1 }
    ]
  });
  
  // Wait for replica set to be ready
  sleep(10000);
  print('Replica set initialized successfully');
}

// Create rocketchat database and user
db = db.getSiblingDB('admin');
db.auth('root', 'rocketchat123');

// Check if database exists
if (!db.getMongo().getDBNames().includes('rocketchat')) {
  db = db.getSiblingDB('rocketchat');
  db.createUser({
    user: 'rocketchat',
    pwd: 'rocketchat123',
    roles: [
      { role: 'readWrite', db: 'rocketchat' },
      { role: 'read', db: 'local' }
    ]
  });
  print('Rocket.Chat database and user created');
}

print('MongoDB initialization complete');