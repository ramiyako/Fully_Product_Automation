#!/bin/bash
###############################################################################
# AWS Services Accessibility Test Report
# Generated: $(date)
# Instance: i-0e14d354d2194366a
# Public IP: 51.84.240.159
###############################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          AWS RF Automation - Accessibility Test Report            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Test Date: $(date)"
echo "Instance: i-0e14d354d2194366a"
echo "Public IP: 51.84.240.159"
echo "Region: il-central-1"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TOTAL_TESTS=8
PASSED_TESTS=0
FAILED_TESTS=0

echo "════════════════════════════════════════════════════════════════════"
echo "ACCESSIBILITY TEST RESULTS"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Function to test port
test_port() {
    local SERVICE=$1
    local PORT=$2
    local EXPECTED_STATUS=$3

    printf "%-25s %-10s " "$SERVICE" "(Port $PORT)"

    # Test with netcat
    if nc -zv -w 3 51.84.240.159 $PORT 2>&1 | grep -q "succeeded"; then
        echo -e "${GREEN}✓ ACCESSIBLE${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Test SSH (should work)
test_port "SSH" "22" "200"

# Test Jenkins
test_port "Jenkins" "8080" "403"

# Test Kibana
test_port "Kibana" "5601" "200"

# Test Elasticsearch
test_port "Elasticsearch" "9200" "200"

# Test Allure Reports
test_port "Allure Reports" "9080" "200"

# Test Mock SA
test_port "Mock SA Admin" "8001" "200"

# Test Mock SG
test_port "Mock SG Admin" "8002" "200"

# Test Mock DUT
test_port "Mock DUT Admin" "8003" "200"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Total Tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $PASSED_TESTS -eq 1 ] && [ $FAILED_TESTS -eq 7 ]; then
    echo "════════════════════════════════════════════════════════════════════"
    echo "STATUS: SERVICES NOT RUNNING OR BLOCKED"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}Only SSH is accessible. This indicates:${NC}"
    echo ""
    echo "1. ✗ Services have NOT been started on the AWS instance"
    echo "   OR"
    echo "2. ✗ AWS Security Group is blocking the required ports"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "REQUIRED ACTIONS"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo "OPTION A: Configure Security Group (if not done)"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo "1. Go to AWS EC2 Console:"
    echo "   https://console.aws.amazon.com/ec2/"
    echo ""
    echo "2. Navigate to: Security Groups"
    echo ""
    echo "3. Select the security group attached to instance: i-0e14d354d2194366a"
    echo ""
    echo "4. Edit Inbound Rules → Add the following:"
    echo ""
    echo "   Type          Protocol   Port    Source          Description"
    echo "   ─────────────────────────────────────────────────────────────"
    echo "   Custom TCP    TCP        8080    0.0.0.0/0      Jenkins"
    echo "   Custom TCP    TCP        5601    0.0.0.0/0      Kibana"
    echo "   Custom TCP    TCP        9200    0.0.0.0/0      Elasticsearch"
    echo "   Custom TCP    TCP        9080    0.0.0.0/0      Allure Reports"
    echo "   Custom TCP    TCP        8001    0.0.0.0/0      Mock SA"
    echo "   Custom TCP    TCP        8002    0.0.0.0/0      Mock SG"
    echo "   Custom TCP    TCP        8003    0.0.0.0/0      Mock DUT"
    echo ""
    echo "5. Save rules"
    echo ""
    echo "OR use the automated script:"
    echo ""
    echo "   bash scripts/configure_aws_security_group.sh \\"
    echo "     --group-name=<YOUR_SG_NAME> \\"
    echo "     --allowed-ip=0.0.0.0/0"
    echo ""
    echo ""
    echo "OPTION B: Start Services (if Security Group is configured)"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo "1. SSH into the AWS instance:"
    echo "   ssh -i your-key.pem ubuntu@51.84.240.159"
    echo ""
    echo "2. Check if services are running:"
    echo "   docker ps"
    echo "   sudo systemctl status jenkins"
    echo ""
    echo "3. If not running, start the services:"
    echo ""
    echo "   # If setup hasn't been run yet:"
    echo "   cd ~/Fully_Product_Automation"
    echo "   sudo bash scripts/aws_setup.sh --environment=integration --verbose"
    echo ""
    echo "   # If setup was run but services stopped:"
    echo "   cd ~/Fully_Product_Automation/infra"
    echo "   docker compose -f docker-compose.aws.yml up -d"
    echo "   sudo systemctl start jenkins"
    echo ""
    echo ""
    echo "OPTION C: Quick Diagnosis (SSH in and check)"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo "1. SSH into instance:"
    echo "   ssh -i your-key.pem ubuntu@51.84.240.159"
    echo ""
    echo "2. Run quick diagnostic:"
    echo ""
    echo "   # Check Docker containers"
    echo "   docker ps"
    echo ""
    echo "   # Check Jenkins"
    echo "   sudo systemctl status jenkins"
    echo ""
    echo "   # Check if ports are listening"
    echo "   sudo netstat -tlnp | grep -E '8080|5601|9200|8001|8002|8003'"
    echo ""
    echo "   # Check firewall"
    echo "   sudo ufw status"
    echo ""
    echo "   # Check security group (if aws-cli installed)"
    echo "   aws ec2 describe-security-groups \\"
    echo "     --filters Name=instance.id,Values=i-0e14d354d2194366a"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo ""

elif [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo "════════════════════════════════════════════════════════════════════"
    echo "STATUS: ALL SERVICES ACCESSIBLE ✓"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo "All services are accessible from the public internet!"
    echo ""
    echo "Access URLs:"
    echo "─────────────────────────────────────────────────────────────────"
    echo "Jenkins:           http://51.84.240.159:8080"
    echo "Kibana:            http://51.84.240.159:5601"
    echo "Elasticsearch:     http://51.84.240.159:9200"
    echo "Allure Reports:    http://51.84.240.159:9080"
    echo "Mock SA Admin:     http://51.84.240.159:8001"
    echo "Mock SG Admin:     http://51.84.240.159:8002"
    echo "Mock DUT Admin:    http://51.84.240.159:8003"
    echo ""
else
    echo "════════════════════════════════════════════════════════════════════"
    echo "STATUS: PARTIAL CONNECTIVITY"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Some services are accessible, but not all."
    echo "Please review the failed tests above and:"
    echo ""
    echo "1. Check security group rules for the failed ports"
    echo "2. SSH in and verify those services are running"
    echo "3. Check service logs: docker logs <container-name>"
    echo ""
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "NEXT STEPS"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "After fixing accessibility issues:"
echo ""
echo "1. Re-run this test:"
echo "   bash scripts/check_aws_accessibility.sh"
echo ""
echo "2. View full deployment guide:"
echo "   docs/AWS_DEPLOYMENT.md"
echo ""
echo "3. View quick reference:"
echo "   docs/AWS_QUICK_REFERENCE.md"
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
