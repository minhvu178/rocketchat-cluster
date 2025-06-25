# Rocket.Chat Cluster Setup

This Docker Compose configuration sets up a scalable Rocket.Chat cluster with MongoDB replica set, Redis session sharing, and Nginx load balancing.

## Architecture

- **Rocket.Chat**: Scalable application instances (default: 3)
- **MongoDB**: 3-node replica set for high availability
- **Redis**: Session sharing between Rocket.Chat instances
- **Nginx**: Load balancer with WebSocket support

## Quick Start

1. **Clone and setup environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

2. **Run the setup script:**
   ```bash
   ./setup.sh
   # Select option 1 for full setup
   ```

3. **Access Rocket.Chat:**
   - URL: http://localhost
   - Complete the setup wizard

## Manual Setup

1. **Start MongoDB replica set:**
   ```bash
   docker compose up -d mongodb-primary mongodb-secondary1 mongodb-secondary2
   sleep 30
   ```

2. **Initialize replica set:**
   ```bash
   docker compose exec mongodb-primary mongosh --eval "
   rs.initiate({
       _id: 'rs0',
       members: [
           { _id: 0, host: 'mongodb-primary:27017', priority: 2 },
           { _id: 1, host: 'mongodb-secondary1:27017', priority: 1 },
           { _id: 2, host: 'mongodb-secondary2:27017', priority: 1 }
       ]
   })"
   ```

3. **Start all services:**
   ```bash
   docker compose up -d
   ```

## Scaling

Scale Rocket.Chat instances:
```bash
docker compose up -d --scale rocketchat=5
```

## Monitoring

View logs:
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f rocketchat
```

Check status:
```bash
docker compose ps
```

## Production Considerations

1. **SSL/TLS**: 
   - Place SSL certificates in `./ssl/`
   - Uncomment HTTPS configuration in `nginx.conf`
   - Update `ROOT_URL` in `.env`

2. **Backup MongoDB:**
   ```bash
   docker compose exec mongodb-primary mongodump --out /backup
   ```

3. **Performance Tuning:**
   - Adjust `ROCKETCHAT_REPLICAS` in `.env`
   - Configure MongoDB memory limits
   - Enable Redis persistence

4. **Security:**
   - Change default passwords in `.env`
   - Configure firewall rules
   - Enable 2FA for admin accounts

## Troubleshooting

**MongoDB replica set issues:**
```bash
docker compose exec mongodb-primary mongosh --eval "rs.status()"
```

**Rocket.Chat not starting:**
```bash
docker compose logs rocketchat | tail -50
```

**Reset everything:**
```bash
docker compose down -v
rm -rf mongo_*_data redis_data
```

## Environment Variables

Key variables in `.env`:
- `ROOT_URL`: Public URL of your Rocket.Chat
- `ROCKETCHAT_REPLICAS`: Number of app instances
- `MONGO_ROOT_PASSWORD`: MongoDB admin password
- `FILE_UPLOAD_MAX_FILE_SIZE`: Max upload size

## Ports

- 80: HTTP (Nginx)
- 443: HTTPS (Nginx) - when configured
- 27017: MongoDB (internal only)
- 6379: Redis (internal only)

## Support

- [Rocket.Chat Documentation](https://docs.rocket.chat)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [MongoDB Replica Sets](https://docs.mongodb.com/manual/replication/)