#!/bin/bash
# View Allure Report and Fix Infrastructure

echo "=========================================="
echo "Step 1: Opening Allure Report"
echo "=========================================="

if [ -d "allure-report" ] && [ -f "allure-report/index.html" ]; then
    echo "✓ Allure report exists"
    echo ""
    echo "Opening Allure report in browser..."
    allure open allure-report &
    echo ""
    echo "Allure report opened at: http://localhost:port"
    echo "(Check the output above for the exact port)"
else
    echo "Generating Allure report..."
    allure generate allure-results --clean -o allure-report
    echo "✓ Report generated"
    echo ""
    echo "Opening Allure report..."
    allure open allure-report &
fi

echo ""
echo "=========================================="
echo "Step 2: Fixing Mock Equipment"
echo "=========================================="
echo ""
echo "The build failed because mock equipment wasn't running."
echo "Let's start the infrastructure..."
echo ""

cd infra

echo "Starting infrastructure with docker compose..."
docker compose -f docker-compose.integration.yml up -d

echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "Checking service health..."
echo ""

# Check Elasticsearch
if curl -f -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    echo "✓ Elasticsearch is running"
else
    echo "✗ Elasticsearch not responding"
fi

# Check Kibana
if curl -f -s http://localhost:5601/api/status > /dev/null 2>&1; then
    echo "✓ Kibana is running"
else
    echo "✗ Kibana not responding (may still be starting)"
fi

# Check Mock Equipment
for port in 8001 8002 8003; do
    if curl -f -s http://localhost:${port}/health > /dev/null 2>&1; then
        echo "✓ Mock equipment on port ${port} is healthy"
    else
        echo "✗ Mock equipment on port ${port} not responding"
    fi
done

cd ..

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. View your Allure report in the browser that just opened"
echo "2. Go back to Jenkins: http://localhost:8080"
echo "3. Click 'Build with Parameters' on your job"
echo "4. Run the build again - it should work now!"
echo ""
echo "Access URLs:"
echo "  Jenkins:       http://localhost:8080"
echo "  Kibana:        http://localhost:5601"
echo "  Elasticsearch: http://localhost:9200"
echo ""
