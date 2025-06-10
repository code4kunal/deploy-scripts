#!/bin/bash
# Stop running containers and remove volumes
echo "Stopping running containers..."
docker-compose down
# Pull latest images
echo "Pulling latest images..."
docker-compose pull
# Start services
echo "Starting services..."
docker-compose up -d

echo "Services started successfully!"