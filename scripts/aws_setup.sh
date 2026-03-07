#!/bin/bash
###############################################################################
# AWS Server Setup Script for RF Automation Integration
# One-command deployment for AWS EC2 instances
#
# Usage:
#   sudo bash scripts/aws_setup.sh [OPTIONS]
#
# Options:
#   --environment=ENV   Environment: integration, staging, production (default: integration)
#   --verbose           Enable verbose output
#   --help              Show this help message
#
# Example:
#   sudo bash scripts/aws_setup.sh --environment=integration --verbose
#
# Prerequisites:
#   - AWS EC2 instance (m5.large or better recommended)
#   - Ubuntu Server 24.04 LTS
#   - Public IP address
#   - Security groups configured for required ports
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
ENVIRONMENT="${ENVIRONMENT:-integration}"
VERBOSE=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            grep "^#" "$0" | grep -v "#!/bin/bash" | sed 's/^# //'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

# Detect AWS environment
INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d ' ' -f 2 || echo "unknown")
PUBLIC_IP=$(ec2-metadata --public-ipv4 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unknown")
PRIVATE_IP=$(ec2-metadata --local-ipv4 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "unknown")
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone 2>/dev/null | cut -d ' ' -f 2 || curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "unknown")

log_step "RF Automation AWS Environment Setup"
log_info "Environment: $ENVIRONMENT"
log_info "User: $ACTUAL_USER"
log_info "Project Root: $PROJECT_ROOT"
log_info "AWS Instance ID: $INSTANCE_ID"
log_info "Public IP: $PUBLIC_IP"
log_info "Private IP: $PRIVATE_IP"
log_info "Availability Zone: $AVAILABILITY_ZONE"

###############################################################################
# Phase 1: System Preparation
###############################################################################
log_step "Phase 1: System Preparation"

# Install EC2 metadata tools
log_info "Installing EC2 metadata tools..."
apt-get update -qq
apt-get install -y ec2-instance-connect cloud-init

# Clean up any broken Jenkins repository FIRST
log_info "Cleaning up any old/broken repository configurations..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-keyring.asc
rm -f /usr/share/keyrings/jenkins-keyring.gpg

log_info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y

log_info "Installing base dependencies..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    htop \
    iotop \
    nload \
    iftop \
    unzip

log_success "Base dependencies installed"

# Configure system resources for AWS
log_info "Configuring system resources for AWS..."

# Increase file descriptors
if ! grep -q "fs.file-max" /etc/sysctl.conf; then
    echo "fs.file-max = 65535" >> /etc/sysctl.conf
fi

# Increase vm.max_map_count for Elasticsearch
if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
    echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
fi

# Network optimizations for AWS
if ! grep -q "net.core.somaxconn" /etc/sysctl.conf; then
    echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
fi

if ! grep -q "net.ipv4.tcp_max_syn_backlog" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_max_syn_backlog = 2048" >> /etc/sysctl.conf
fi

sysctl -p

log_success "System resources configured"

# Configure firewall (UFW)
log_info "Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp comment 'SSH'

# Allow Jenkins
ufw allow 8080/tcp comment 'Jenkins'

# Allow Kibana
ufw allow 5601/tcp comment 'Kibana'

# Allow Elasticsearch
ufw allow 9200/tcp comment 'Elasticsearch'

# Allow Mock Equipment Admin Interfaces
ufw allow 8001/tcp comment 'Mock SA Admin'
ufw allow 8002/tcp comment 'Mock SG Admin'
ufw allow 8003/tcp comment 'Mock DUT Admin'

ufw reload
log_success "Firewall configured"

###############################################################################
# Phase 2: Docker Installation
###############################################################################
log_step "Phase 2: Docker Installation"

if command -v docker &> /dev/null; then
    log_info "Docker already installed: $(docker --version)"
else
    log_info "Installing Docker..."

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log_success "Docker installed: $(docker --version)"
fi

# Add user to docker group
usermod -aG docker "$ACTUAL_USER"

# Configure Docker for AWS
log_info "Configuring Docker daemon for AWS..."
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Docker
systemctl enable docker
systemctl start docker
systemctl restart docker

log_success "Docker configured and running"

###############################################################################
# Phase 3: Jenkins Installation
###############################################################################
log_step "Phase 3: Jenkins Installation"

if command -v jenkins &> /dev/null || systemctl is-active --quiet jenkins; then
    log_info "Jenkins already installed"
else
    log_info "Installing Java 17 (required for Jenkins and Allure)..."
    apt-get install -y openjdk-17-jdk

    log_info "Installing Allure command-line tool..."
    ALLURE_VERSION="2.25.0"
    wget -q https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/allure-${ALLURE_VERSION}.tgz -O /tmp/allure.tgz
    tar -xzf /tmp/allure.tgz -C /opt/
    ln -sf /opt/allure-${ALLURE_VERSION}/bin/allure /usr/local/bin/allure
    rm /tmp/allure.tgz
    log_success "Allure ${ALLURE_VERSION} installed: $(allure --version)"

    log_info "Installing Jenkins..."

    # Clean up any old Jenkins repository configuration
    rm -f /etc/apt/sources.list.d/jenkins.list
    rm -f /usr/share/keyrings/jenkins-keyring.asc
    rm -f /usr/share/keyrings/jenkins-keyring.gpg

    # Clean apt cache
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    apt-get update -qq

    # Add Jenkins GPG key
    log_info "Downloading Jenkins GPG key..."
    wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
      https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

    # Verify the key was downloaded
    if [ ! -f /usr/share/keyrings/jenkins-keyring.asc ]; then
        log_error "Failed to download Jenkins GPG key"
        exit 1
    fi

    # Add Jenkins repository
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian-stable binary/" | \
      tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    log_info "Installing Jenkins package..."
    apt-get update -qq
    apt-get install -y jenkins

    log_success "Jenkins installed"
fi

# Add Jenkins user to docker group
usermod -aG docker jenkins || true

# Configure Jenkins for AWS
log_info "Configuring Jenkins..."
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
log_info "Waiting for Jenkins to start..."
for i in {1..60}; do
    if systemctl is-active --quiet jenkins; then
        log_success "Jenkins is running"
        break
    fi
    sleep 2
done

# Get initial admin password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    log_info "Jenkins Initial Admin Password: $JENKINS_PASSWORD"
    echo "$JENKINS_PASSWORD" > "$PROJECT_ROOT/jenkins_initial_password.txt"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$PROJECT_ROOT/jenkins_initial_password.txt"
fi

log_success "Jenkins configured"

###############################################################################
# Phase 4: Infrastructure Deployment
###############################################################################
log_step "Phase 4: Infrastructure Deployment"

log_info "Building mock equipment Docker image..."
cd "$PROJECT_ROOT/mock_equipment"
docker build -t rf-mock-equipment:latest .

log_success "Mock equipment image built"

log_info "Starting AWS integration infrastructure..."
cd "$PROJECT_ROOT/infra"

# Use AWS-specific docker-compose if it exists, otherwise use integration
if [ -f "docker-compose.aws.yml" ]; then
    COMPOSE_FILE="docker-compose.aws.yml"
else
    COMPOSE_FILE="docker-compose.integration.yml"
fi

docker compose -f "$COMPOSE_FILE" up -d

log_info "Waiting for services to be healthy..."
sleep 15

# Check service health
for service in elasticsearch kibana mock-spectrum-analyzer mock-signal-generator mock-dut; do
    log_info "Checking $service..."
    for i in {1..60}; do
        if docker ps | grep -q "$service.*healthy" || docker ps | grep -q "$service.*Up"; then
            log_success "$service is running"
            break
        fi
        if [ $i -eq 60 ]; then
            log_warning "$service may not be healthy (check docker logs)"
        fi
        sleep 2
    done
done

log_success "All infrastructure services deployed"

###############################################################################
# Phase 5: Python Environment
###############################################################################
log_step "Phase 5: Python Environment Setup"

log_info "Creating Python virtual environment..."
cd "$PROJECT_ROOT"

# Remove old venv if exists
rm -rf venv

# Create new venv
su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && python3 -m venv venv"

log_info "Installing Python dependencies..."
su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

# Install mock equipment as package
if [ -f "$PROJECT_ROOT/mock_equipment/requirements.txt" ]; then
    log_info "Installing mock equipment package..."
    su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && source venv/bin/activate && pip install -e mock_equipment/"
fi

log_success "Python environment configured"

###############################################################################
# Phase 6: Configuration
###############################################################################
log_step "Phase 6: Configuration"

log_info "Setting up configuration directory..."
mkdir -p /etc/rf-automation

# Create AWS-specific environment file
cat > /etc/rf-automation/aws.env <<EOF
# AWS RF Automation Environment Configuration
ENVIRONMENT=${ENVIRONMENT}
AWS_INSTANCE_ID=${INSTANCE_ID}
AWS_PUBLIC_IP=${PUBLIC_IP}
AWS_PRIVATE_IP=${PRIVATE_IP}
AWS_AVAILABILITY_ZONE=${AVAILABILITY_ZONE}

# Service URLs (accessible from public IP)
JENKINS_URL=http://${PUBLIC_IP}:8080
KIBANA_URL=http://${PUBLIC_IP}:5601
ELASTICSEARCH_URL=http://${PUBLIC_IP}:9200

# Mock Equipment
USE_MOCK_EQUIPMENT=true
MOCK_SA_URL=http://localhost:8001
MOCK_SG_URL=http://localhost:8002
MOCK_DUT_URL=http://localhost:8003

# Test Configuration
RF_PHYSICS_ENABLED=true
NOISE_FLOOR_DBM=-120
EOF

chmod 644 /etc/rf-automation/aws.env

log_info "Creating results directories..."
su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && mkdir -p results logs allure-results allure-report"

log_success "Configuration completed"

###############################################################################
# Phase 7: Validation
###############################################################################
log_step "Phase 7: Environment Validation"

log_info "Running health checks..."

# Check Docker
if docker --version &> /dev/null; then
    log_success "✓ Docker: $(docker --version | head -n1)"
else
    log_error "✗ Docker not found"
fi

# Check Elasticsearch
if curl -f -s http://localhost:9200/_cluster/health &> /dev/null; then
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    log_success "✓ Elasticsearch: $ES_STATUS"
else
    log_warning "✗ Elasticsearch not responding (may still be starting)"
fi

# Check Kibana
if curl -f -s http://localhost:5601/api/status &> /dev/null; then
    log_success "✓ Kibana: Healthy"
else
    log_warning "✗ Kibana not responding (may still be starting)"
fi

# Check Jenkins
if systemctl is-active --quiet jenkins; then
    log_success "✓ Jenkins: Running"
else
    log_warning "✗ Jenkins not running"
fi

# Check Mock Equipment
for port in 8001 8002 8003; do
    SERVICE_NAME="Mock equipment on port $port"
    if curl -f -s "http://localhost:$port/health" &> /dev/null; then
        log_success "✓ $SERVICE_NAME: Healthy"
    else
        log_warning "✗ $SERVICE_NAME not responding (check docker logs)"
    fi
done

# Run PoPo tests if they exist
if [ -f "$PROJECT_ROOT/tests/integration_popo.robot" ]; then
    log_info "Running Proof of Platform tests..."
    cd "$PROJECT_ROOT"
    su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && source venv/bin/activate && USE_MOCK_EQUIPMENT=true robot --outputdir results --listener allure_robotframework:allure-results tests/integration_popo.robot" || log_warning "PoPo tests had failures (check results)"

    # Generate Allure report
    if [ -d "allure-results" ] && [ "$(ls -A allure-results)" ]; then
        log_info "Generating Allure report..."
        su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && allure generate allure-results --clean -o allure-report" || log_warning "Failed to generate Allure report"
        if [ -d "allure-report" ]; then
            log_success "Allure report generated: $PROJECT_ROOT/allure-report/index.html"
        fi
    else
        log_warning "No Allure results found, skipping report generation"
    fi
fi

###############################################################################
# Phase 8: Jenkins Configuration
###############################################################################
log_step "Phase 8: Jenkins Configuration"

log_info "Waiting for Jenkins to be fully ready..."
sleep 30

if [ -f "$SCRIPT_DIR/configure_jenkins.sh" ]; then
    log_info "Configuring Jenkins pipeline job..."
    bash "$SCRIPT_DIR/configure_jenkins.sh" \
        --jenkins-url=http://localhost:8080 \
        --project-root="$PROJECT_ROOT" || log_warning "Jenkins configuration may need manual setup"
else
    log_warning "configure_jenkins.sh not found, Jenkins job needs manual configuration"
fi

log_success "Jenkins configuration completed"

###############################################################################
# Completion
###############################################################################
log_step "AWS RF Automation Environment Setup Complete!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Instance Details:${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Instance ID:   $INSTANCE_ID"
echo -e "Public IP:     $PUBLIC_IP"
echo -e "Private IP:    $PRIVATE_IP"
echo -e "AZ:            $AVAILABILITY_ZONE"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access URLs (from your browser):${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Jenkins:       http://$PUBLIC_IP:8080"
echo -e "Kibana:        http://$PUBLIC_IP:5601"
echo -e "Elasticsearch: http://$PUBLIC_IP:9200"
echo -e "Mock SA Admin: http://$PUBLIC_IP:8001"
echo -e "Mock SG Admin: http://$PUBLIC_IP:8002"
echo -e "Mock DUT Admin: http://$PUBLIC_IP:8003"
echo ""

echo -e "${YELLOW}IMPORTANT: Ensure your AWS Security Group allows inbound traffic on:${NC}"
echo -e "  - Port 22   (SSH)"
echo -e "  - Port 8080 (Jenkins)"
echo -e "  - Port 5601 (Kibana)"
echo -e "  - Port 9200 (Elasticsearch)"
echo -e "  - Port 8001 (Mock SA)"
echo -e "  - Port 8002 (Mock SG)"
echo -e "  - Port 8003 (Mock DUT)"
echo ""

if [ -f "$PROJECT_ROOT/jenkins_initial_password.txt" ]; then
    echo -e "${YELLOW}Jenkins Initial Admin Password:${NC}"
    cat "$PROJECT_ROOT/jenkins_initial_password.txt"
    echo ""
fi

echo -e "${GREEN}To SSH into this instance:${NC}"
echo -e "  ssh -i your-key.pem ubuntu@$PUBLIC_IP"
echo ""

echo -e "${GREEN}To activate the Python environment:${NC}"
echo -e "  cd $PROJECT_ROOT"
echo -e "  source venv/bin/activate"
echo ""

echo -e "${GREEN}To run tests:${NC}"
echo -e "  source venv/bin/activate"
echo -e "  robot --outputdir results --listener allure_robotframework:allure-results tests/integration_popo.robot"
echo ""

echo -e "${GREEN}To view infrastructure logs:${NC}"
echo -e "  cd $PROJECT_ROOT/infra"
echo -e "  docker compose -f docker-compose.integration.yml logs -f"
echo ""

echo -e "${GREEN}Configuration saved to:${NC}"
echo -e "  /etc/rf-automation/aws.env"
echo ""

log_success "AWS setup completed successfully! 🚀"
log_info "Please verify security group settings in AWS console"
