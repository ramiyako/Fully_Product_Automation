#!/bin/bash
# Fix Docker permissions and start mock equipment

echo "=========================================="
echo "Fixing Docker Permissions"
echo "=========================================="
echo ""

# Add current user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

echo ""
echo "Docker group membership updated!"
echo ""
echo "You need to log out and log back in for this to take effect."
echo ""
echo "BUT... let's start the mock equipment NOW using sudo:"
echo ""

cd infra

echo "Starting mock equipment containers..."
sudo docker compose -f docker-compose.integration.yml up -d

echo ""
echo "Waiting 15 seconds for containers to start..."
sleep 15

echo ""
echo "Checking container status..."
sudo docker ps | grep -E "mock|CONTAINER"

echo ""
echo "Checking health endpoints..."
echo ""

for port in 8001 8002 8003; do
    if curl -f -s http://localhost:${port}/health > /dev/null 2>&1; then
        echo "✓ Mock equipment on port ${port} is healthy"
    else
        echo "✗ Mock equipment on port ${port} not responding"
        echo "  Checking logs..."
        case $port in
            8001) sudo docker logs mock-sa 2>&1 | tail -5 ;;
            8002) sudo docker logs mock-sg 2>&1 | tail -5 ;;
            8003) sudo docker logs mock-dut 2>&1 | tail -5 ;;
        esac
    fi
done

cd ..

echo ""
echo "=========================================="
echo "IMPORTANT: To use docker without sudo"
echo "=========================================="
echo "Run this command and then LOG OUT and LOG BACK IN:"
echo "  newgrp docker"
echo ""
echo "Or just log out and back in to your system."
echo ""
