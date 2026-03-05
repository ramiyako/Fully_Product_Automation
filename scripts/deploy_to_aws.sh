#!/bin/bash
###############################################################################
# Complete AWS Deployment Script with Allure Support
# One-command deployment for RF Automation on AWS
#
# This script will:
# 1. Verify AWS instance details
# 2. Clone repository
# 3. Run AWS setup script
# 4. Configure Allure with public access
# 5. Verify all services are running
# 6. Test accessibility
#
# Usage:
#   Run this ON THE AWS INSTANCE after SSH'ing in
#   bash deploy_to_aws.sh
#
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓ SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠ WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗ ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Check if running on AWS
log_step "Step 1: Verifying AWS Environment"

INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
PUBLIC_IP=$(ec2-metadata --public-ipv4 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unknown")
PRIVATE_IP=$(ec2-metadata --local-ipv4 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "unknown")
REGION=$(ec2-metadata --availability-zone 2>/dev/null | cut -d ' ' -f 2 | sed 's/[a-z]$//' || curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//' || echo "unknown")

if [ "$INSTANCE_ID" = "unknown" ]; then
    log_error "This doesn't appear to be an AWS EC2 instance!"
    log_warning "Running anyway, but some features may not work correctly."
else
    log_success "AWS Instance detected"
    echo "  Instance ID:  $INSTANCE_ID"
    echo "  Public IP:    $PUBLIC_IP"
    echo "  Private IP:   $PRIVATE_IP"
    echo "  Region:       $REGION"
fi

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo"
   exit 1
fi

# Get actual user
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

log_step "Step 2: Checking Repository"

PROJECT_DIR="$ACTUAL_HOME/Fully_Product_Automation"

if [ -d "$PROJECT_DIR" ]; then
    log_warning "Project directory already exists at: $PROJECT_DIR"
    read -p "Do you want to remove it and re-clone? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing directory..."
        rm -rf "$PROJECT_DIR"
    else
        log_info "Using existing directory"
        cd "$PROJECT_DIR"
        log_info "Pulling latest changes..."
        su - "$ACTUAL_USER" -c "cd '$PROJECT_DIR' && git pull origin integration"
    fi
fi

if [ ! -d "$PROJECT_DIR" ]; then
    log_info "Repository not found. Please provide the git repository URL:"
    read -p "Git URL: " GIT_URL

    if [ -z "$GIT_URL" ]; then
        log_error "No git URL provided. Exiting."
        exit 1
    fi

    log_info "Cloning repository..."
    su - "$ACTUAL_USER" -c "cd '$ACTUAL_HOME' && git clone '$GIT_URL' Fully_Product_Automation"

    log_info "Checking out integration branch..."
    su - "$ACTUAL_USER" -c "cd '$PROJECT_DIR' && git checkout integration"

    log_success "Repository cloned successfully"
fi

cd "$PROJECT_DIR"

log_step "Step 3: Running AWS Setup Script"

if [ -f "scripts/aws_setup.sh" ]; then
    log_info "Starting AWS setup (this will take 30-40 minutes)..."
    log_warning "You can monitor progress in real-time below..."
    echo ""

    bash scripts/aws_setup.sh --environment=integration --verbose

    log_success "AWS setup completed"
else
    log_error "scripts/aws_setup.sh not found!"
    exit 1
fi

log_step "Step 4: Configuring Allure Public Access"

# Install nginx for serving Allure reports
log_info "Installing nginx for Allure report hosting..."
apt-get update -qq
apt-get install -y nginx

# Create nginx configuration for Allure
log_info "Configuring nginx for Allure reports..."

cat > /etc/nginx/sites-available/allure <<EOF
server {
    listen 9080;
    server_name _;

    root $PROJECT_DIR/allure-report;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|json)$ {
        expires 1h;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/allure-access.log;
    error_log /var/log/nginx/allure-error.log;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/allure /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Restart nginx
systemctl restart nginx
systemctl enable nginx

# Add UFW rule for Allure
log_info "Opening firewall port 9080 for Allure..."
ufw allow 9080/tcp comment 'Allure Reports'
ufw reload

log_success "Nginx configured for Allure on port 9080"

log_step "Step 5: Verifying All Services"

log_info "Checking service status..."

# Check Docker containers
DOCKER_RUNNING=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "elasticsearch|kibana|mock" | wc -l)
log_info "Docker containers running: $DOCKER_RUNNING/5"

if [ "$DOCKER_RUNNING" -eq 5 ]; then
    log_success "All Docker containers are running"
else
    log_warning "Some Docker containers may not be running"
    docker ps --format "table {{.Names}}\t{{.Status}}"
fi

# Check Jenkins
if systemctl is-active --quiet jenkins; then
    log_success "Jenkins is running"
else
    log_warning "Jenkins is not running"
fi

# Check Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx is running (for Allure reports)"
else
    log_warning "Nginx is not running"
fi

log_step "Step 6: Testing Local Accessibility"

log_info "Testing services on localhost..."

test_service() {
    local SERVICE=$1
    local PORT=$2

    if curl -f -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" > /dev/null 2>&1; then
        log_success "$SERVICE (port $PORT) is accessible"
        return 0
    else
        log_warning "$SERVICE (port $PORT) is not accessible yet"
        return 1
    fi
}

sleep 5

test_service "Elasticsearch" "9200"
test_service "Kibana" "5601"
test_service "Jenkins" "8080"
test_service "Mock SA" "8001"
test_service "Mock SG" "8002"
test_service "Mock DUT" "8003"
test_service "Allure Reports" "9080"

log_step "Step 7: Generating Initial Allure Report"

if [ -d "$PROJECT_DIR/allure-results" ] && [ "$(ls -A $PROJECT_DIR/allure-results 2>/dev/null)" ]; then
    log_info "Generating Allure report from existing results..."
    su - "$ACTUAL_USER" -c "cd '$PROJECT_DIR' && allure generate allure-results --clean -o allure-report"
    log_success "Allure report generated"
else
    log_info "Creating placeholder Allure report..."
    mkdir -p "$PROJECT_DIR/allure-report"
    cat > "$PROJECT_DIR/allure-report/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>RF Automation - Allure Reports</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        .info {
            background: #e3f2fd;
            padding: 15px;
            border-left: 4px solid #2196F3;
            margin: 20px 0;
        }
        .command {
            background: #f5f5f5;
            padding: 10px;
            font-family: monospace;
            border-radius: 5px;
            margin: 10px 0;
        }
        a {
            color: #2196F3;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 RF Automation - Allure Reports</h1>

        <div class="info">
            <strong>No test results yet!</strong>
            <p>Run tests from Jenkins to generate Allure reports.</p>
        </div>

        <h2>How to Generate Reports:</h2>

        <h3>Option 1: Via Jenkins</h3>
        <ol>
            <li>Open Jenkins: <a href="http://INSTANCE_IP:8080">http://INSTANCE_IP:8080</a></li>
            <li>Run the "RF-Automation-Integration" job</li>
            <li>Reports will be automatically generated</li>
            <li>Refresh this page to view them</li>
        </ol>

        <h3>Option 2: Via Command Line</h3>
        <div class="command">
cd ~/Fully_Product_Automation<br>
source venv/bin/activate<br>
robot --outputdir results --listener allure_robotframework:allure-results tests/integration_popo.robot<br>
allure generate allure-results --clean -o allure-report
        </div>

        <h2>Service Links:</h2>
        <ul>
            <li><a href="http://INSTANCE_IP:8080">Jenkins (CI/CD)</a></li>
            <li><a href="http://INSTANCE_IP:5601">Kibana (Dashboards)</a></li>
            <li><a href="http://INSTANCE_IP:9200">Elasticsearch (API)</a></li>
            <li><a href="http://INSTANCE_IP:8001">Mock SA Admin</a></li>
            <li><a href="http://INSTANCE_IP:8002">Mock SG Admin</a></li>
            <li><a href="http://INSTANCE_IP:8003">Mock DUT Admin</a></li>
        </ul>
    </div>
</body>
</html>
HTMLEOF

    # Replace INSTANCE_IP with actual IP
    if [ "$PUBLIC_IP" != "unknown" ]; then
        sed -i "s/INSTANCE_IP/$PUBLIC_IP/g" "$PROJECT_DIR/allure-report/index.html"
    fi

    log_success "Placeholder Allure report created"
fi

# Set proper permissions
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$PROJECT_DIR/allure-report"
chmod -R 755 "$PROJECT_DIR/allure-report"

log_step "✅ DEPLOYMENT COMPLETE!"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 AWS Deployment Successful! 🎉                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$PUBLIC_IP" != "unknown" ]; then
    echo -e "${CYAN}📍 Access Your Services:${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Jenkins:${NC}           http://$PUBLIC_IP:8080"
    echo -e "  ${GREEN}Kibana:${NC}            http://$PUBLIC_IP:5601"
    echo -e "  ${GREEN}Elasticsearch:${NC}     http://$PUBLIC_IP:9200"
    echo -e "  ${GREEN}Allure Reports:${NC}    http://$PUBLIC_IP:9080"
    echo -e "  ${GREEN}Mock SA Admin:${NC}     http://$PUBLIC_IP:8001"
    echo -e "  ${GREEN}Mock SG Admin:${NC}     http://$PUBLIC_IP:8002"
    echo -e "  ${GREEN}Mock DUT Admin:${NC}    http://$PUBLIC_IP:8003"
    echo ""
fi

echo -e "${YELLOW}⚠️  IMPORTANT - Security Group Configuration Required:${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "You MUST configure your AWS Security Group to allow these ports:"
echo ""
echo "  Port 22   - SSH"
echo "  Port 8080 - Jenkins"
echo "  Port 5601 - Kibana"
echo "  Port 9200 - Elasticsearch"
echo "  Port 9080 - Allure Reports"
echo "  Port 8001 - Mock SA Admin"
echo "  Port 8002 - Mock SG Admin"
echo "  Port 8003 - Mock DUT Admin"
echo ""
echo "To configure security group:"
echo "1. Go to: https://console.aws.amazon.com/ec2/"
echo "2. Navigate to: Security Groups"
echo "3. Select your instance's security group"
echo "4. Edit Inbound Rules → Add the ports above"
echo ""
echo "OR run the automated script from your local machine:"
echo "  bash scripts/configure_aws_security_group.sh \\"
echo "    --group-name=<YOUR_SG_NAME> \\"
echo "    --allowed-ip=0.0.0.0/0"
echo ""

if [ -f "$PROJECT_DIR/jenkins_initial_password.txt" ]; then
    echo -e "${CYAN}🔐 Jenkins Initial Password:${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    cat "$PROJECT_DIR/jenkins_initial_password.txt"
    echo ""
fi

echo -e "${CYAN}📚 Next Steps:${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Configure AWS Security Group (instructions above)"
echo ""
echo "2. Test accessibility from your local machine:"
echo "   bash scripts/check_aws_accessibility.sh"
echo ""
echo "3. Open Jenkins and run your first test:"
echo "   http://$PUBLIC_IP:8080"
echo ""
echo "4. View Allure reports:"
echo "   http://$PUBLIC_IP:9080"
echo ""
echo "5. View documentation:"
echo "   - Full guide: docs/AWS_DEPLOYMENT.md"
echo "   - Quick ref:  docs/AWS_QUICK_REFERENCE.md"
echo ""

log_success "All services are configured and ready to use!"
echo ""
