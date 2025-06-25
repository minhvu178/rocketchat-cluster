#!/bin/bash

# Rocket.Chat Cluster Setup Script
set -e

echo "🚀 Rocket.Chat Cluster Setup"
echo "==========================="

# Check if Docker and Docker Compose are installed
check_dependencies() {
    echo "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    echo "✅ All dependencies are installed"
}

# Create necessary directories
setup_directories() {
    echo "Setting up directories..."
    mkdir -p ssl
    echo "✅ Directories created"
}

# Initialize environment variables
setup_environment() {
    if [ ! -f .env ]; then
        echo "Creating .env file from template..."
        cp .env.example .env
        echo "✅ .env file created. Please edit it with your settings."
    else
        echo "ℹ️  .env file already exists"
    fi
}

# Initialize MongoDB replica set
init_mongodb() {
    echo "Initializing MongoDB replica set..."
    
    # Start only MongoDB services first
    docker compose up -d mongodb-primary mongodb-secondary1 mongodb-secondary2
    
    echo "Waiting for MongoDB to start (30 seconds)..."
    sleep 30
    
    # Initialize replica set
    docker compose exec -T mongodb-primary mongosh --eval "
    rs.initiate({
        _id: 'rs0',
        members: [
            { _id: 0, host: 'mongodb-primary:27017', priority: 2 },
            { _id: 1, host: 'mongodb-secondary1:27017', priority: 1 },
            { _id: 2, host: 'mongodb-secondary2:27017', priority: 1 }
        ]
    })
    "
    
    echo "✅ MongoDB replica set initialized"
}

# Start the cluster
start_cluster() {
    echo "Starting Rocket.Chat cluster..."
    docker compose up -d
    
    echo "✅ Cluster started successfully!"
    echo ""
    echo "Services:"
    docker compose ps
}

# Scale Rocket.Chat instances
scale_rocketchat() {
    local instances=${1:-3}
    echo "Scaling Rocket.Chat to $instances instances..."
    docker compose up -d --scale rocketchat=$instances
    echo "✅ Scaled to $instances instances"
}

# Show cluster status
show_status() {
    echo "Cluster Status:"
    echo "=============="
    docker compose ps
    echo ""
    echo "MongoDB Replica Set Status:"
    docker compose exec -T mongodb-primary mongosh --eval "rs.status()" | grep -E "name|stateStr" || true
}

# Main menu
main_menu() {
    echo ""
    echo "What would you like to do?"
    echo "1) Full setup (first time)"
    echo "2) Start cluster"
    echo "3) Stop cluster"
    echo "4) Scale Rocket.Chat instances"
    echo "5) Show cluster status"
    echo "6) View logs"
    echo "7) Exit"
    
    read -p "Select option (1-7): " choice
    
    case $choice in
        1)
            check_dependencies
            setup_directories
            setup_environment
            init_mongodb
            start_cluster
            echo ""
            echo "🎉 Setup complete! Access Rocket.Chat at http://localhost"
            ;;
        2)
            docker compose up -d
            echo "✅ Cluster started"
            ;;
        3)
            docker compose down
            echo "✅ Cluster stopped"
            ;;
        4)
            read -p "Number of Rocket.Chat instances: " num
            scale_rocketchat $num
            ;;
        5)
            show_status
            ;;
        6)
            echo "Select service to view logs:"
            echo "1) All services"
            echo "2) Rocket.Chat"
            echo "3) MongoDB"
            echo "4) Nginx"
            read -p "Select (1-4): " log_choice
            case $log_choice in
                1) docker compose logs -f ;;
                2) docker compose logs -f rocketchat ;;
                3) docker compose logs -f mongodb-primary mongodb-secondary1 mongodb-secondary2 ;;
                4) docker compose logs -f nginx ;;
            esac
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Run main menu in a loop
while true; do
    main_menu
done