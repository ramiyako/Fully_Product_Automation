#!/bin/bash
# Start Mock Equipment Infrastructure

echo "=========================================="
echo "Starting Mock Equipment"
echo "=========================================="
echo ""

cd "$(dirname "$0")/../infra"

echo "Starting containers..."
docker compose -f docker-compose.integration.yml up -d

echo ""
echo "Waiting 20 seconds for containers to initialize..."
sleep 20

echo ""
echo "Checking container status..."
docker compose -f docker-compose.integration.yml ps

echo ""
echo "Checking service health..."
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
        echo "  Checking logs..."
        case $port in
            8001) docker logs mock-sa 2>&1 | tail -10 ;;
            8002) docker logs mock-sg 2>&1 | tail -10 ;;
            8003) docker logs mock-dut 2>&1 | tail -10 ;;
        esac
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If all services show ✓, go to Jenkins and run the build:"
echo "  http://localhost:8080/job/RF-Automation-Integration/"
echo ""
echo "To view logs:"
echo "  cd infra"
echo "  docker compose -f docker-compose.integration.yml logs -f"
echo ""
echo "To stop:"
echo "  cd infra"
echo "  docker compose -f docker-compose.integration.yml down"
echo ""
