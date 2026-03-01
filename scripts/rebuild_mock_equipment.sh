#!/bin/bash
# Rebuild and restart mock equipment with proper module installation

echo "=========================================="
echo "Rebuilding Mock Equipment Containers"
echo "=========================================="
echo ""

cd "$(dirname "$0")/.."

echo "Step 1: Stopping existing containers..."
sudo docker compose -f infra/docker-compose.integration.yml down

echo ""
echo "Step 2: Rebuilding mock equipment images..."
echo "(This will take 1-2 minutes)"
sudo docker compose -f infra/docker-compose.integration.yml build --no-cache

echo ""
echo "Step 3: Starting all services..."
sudo docker compose -f infra/docker-compose.integration.yml up -d

echo ""
echo "Step 4: Waiting 25 seconds for initialization..."
sleep 25

echo ""
echo "Step 5: Checking service health..."
echo ""

# Elasticsearch
if curl -f -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    echo "✓ Elasticsearch: http://localhost:9200"
else
    echo "✗ Elasticsearch not responding"
fi

# Kibana
if curl -f -s http://localhost:5601/api/status > /dev/null 2>&1; then
    echo "✓ Kibana: http://localhost:5601"
else
    echo "✗ Kibana not ready (may need more time)"
fi

# Mock Equipment
echo ""
for port in 8001 8002 8003; do
    SERVICE_NAME=$(case $port in
        8001) echo "Mock Spectrum Analyzer" ;;
        8002) echo "Mock Signal Generator" ;;
        8003) echo "Mock DUT" ;;
    esac)

    RESPONSE=$(curl -f -s http://localhost:${port}/health 2>&1)
    if [ $? -eq 0 ]; then
        echo "✓ $SERVICE_NAME: http://localhost:$port"
    else
        echo "✗ $SERVICE_NAME not responding on port $port"
        echo "  Last 5 log lines:"
        case $port in
            8001) sudo docker logs mock-sa 2>&1 | tail -5 ;;
            8002) sudo docker logs mock-sg 2>&1 | tail -5 ;;
            8003) sudo docker logs mock-dut 2>&1 | tail -5 ;;
        esac
        echo ""
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If all show ✓, run Jenkins build:"
echo "  http://localhost:8080/job/RF-Automation-Integration/"
echo ""
echo "To view live logs:"
echo "  sudo docker compose -f infra/docker-compose.integration.yml logs -f"
echo ""
