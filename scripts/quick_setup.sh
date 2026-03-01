#!/bin/bash
###############################################################################
# Quick Integration Setup - Minimal Version
###############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Quick Integration Setup${NC}"
echo "=================================="

# Ensure we're in the right directory
if [ ! -f "mock_equipment/Dockerfile" ]; then
    echo -e "${RED}Error: Run this from the project root directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Phase 1: Docker check and permission handling
echo -e "${BLUE}[1/5]${NC} Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not installed!${NC}"
    exit 1
fi

# Check if we need sudo for docker
DOCKER_CMD="docker"
if ! docker ps &>/dev/null; then
    echo -e "${YELLOW}Docker requires sudo - will use sudo for Docker commands${NC}"
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker compose"
else
    COMPOSE_CMD="docker compose"
fi

echo "✓ Docker: $($DOCKER_CMD --version)"

# Phase 2: Build mock equipment
echo -e "${BLUE}[2/5]${NC} Building mock equipment Docker image..."
cd mock_equipment
$DOCKER_CMD build -t rf-mock-equipment:latest .
cd ..

# Phase 3: Start infrastructure
echo -e "${BLUE}[3/5]${NC} Starting integration infrastructure..."
cd infra
$COMPOSE_CMD -f docker-compose.integration.yml down 2>/dev/null || true
$COMPOSE_CMD -f docker-compose.integration.yml up -d
cd ..

# Phase 4: Python environment
echo -e "${BLUE}[4/5]${NC} Setting up Python virtual environment..."
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

# Phase 5: Wait and verify
echo -e "${BLUE}[5/5]${NC} Waiting for services to start..."
sleep 10

echo ""
echo "Checking service health:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(NAMES|mock-|elasticsearch|kibana)"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete! 🚀${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Access URLs:"
echo "  Mock SA Admin:     http://localhost:8001"
echo "  Mock SG Admin:     http://localhost:8002"
echo "  Mock DUT Admin:    http://localhost:8003"
echo "  Elasticsearch:     http://localhost:9200"
echo "  Kibana:            http://localhost:5601"
echo ""
echo "To run tests:"
echo "  cd ~/py_projects/Fully_Product_Automation"
echo "  source venv/bin/activate"
echo "  robot --outputdir results --listener allure_robotframework:allure-results tests/integration_popo.robot"
echo ""
echo "To generate Allure report (optional - requires Allure CLI):"
echo "  allure generate allure-results --clean -o allure-report"
echo "  allure open allure-report"
echo ""
