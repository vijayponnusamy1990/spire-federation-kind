#!/bin/bash

# Build the Hub image
docker build -t spire-hub:latest hub/

# Ensure old container is removed
docker rm -f spire-hub || true

# Create a local data directory if it doesn't exist
mkdir -p hub/data

# Run the Hub container without a fixed IP
docker run -d \
    --name spire-hub \
    --network kind \
    -v $(pwd)/hub/server.conf:/run/spire/config/server.conf:ro \
    -v $(pwd)/hub/data:/run/spire/data:rw \
    spire-hub:latest

# Wait for it to start and get an IP
echo "Waiting for Hub to start..."
sleep 5

HUB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' spire-hub)
echo "Hub SPIRE Server started at $HUB_IP"

# Update server.conf with its own IP if needed? Actually server.conf uses 0.0.0.0 for binding.
# But we need to update lab_clusters.sh or similar to store this IP.
echo "export hub_ip=$HUB_IP" >> lab_clusters.sh
