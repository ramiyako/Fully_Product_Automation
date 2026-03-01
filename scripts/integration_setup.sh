#!/bin/bash
###############################################################################
# Integration Environment Setup Script
# One-command deployment for RF Automation Integration Environment
#
# Usage:
#   sudo bash scripts/integration_setup.sh [OPTIONS]
#
# Options:
#   --mode=MODE         Setup mode: nuc, dev, ci (default: dev)
#   --environment=ENV   Environment: integration, staging (default: integration)
#   --verbose           Enable verbose output
#   --skip-jenkins      Skip Jenkins installation
#   --skip-docker       Skip Docker installation (assumes already installed)
#   --help              Show this help message
#
# Example:
#   sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose
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
MODE="${MODE:-dev}"
ENVIRONMENT="${ENVIRONMENT:-integration}"
VERBOSE=false
SKIP_JENKINS=false
SKIP_DOCKER=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --skip-jenkins)
            SKIP_JENKINS=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
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

log_step "RF Automation Integration Environment Setup"
log_info "Mode: $MODE"
log_info "Environment: $ENVIRONMENT"
log_info "User: $ACTUAL_USER"
log_info "Project Root: $PROJECT_ROOT"

###############################################################################
# Phase 1: System Preparation
###############################################################################
log_step "Phase 1: System Preparation"

# Clean up any broken Jenkins repository FIRST (before apt-get update)
log_info "Cleaning up any old/broken repository configurations..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-keyring.asc
rm -f /usr/share/keyrings/jenkins-keyring.gpg

log_info "Updating system packages..."
apt-get update -qq

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
    python3-venv

log_success "Base dependencies installed"

# Configure system resources
log_info "Configuring system resources..."

# Increase file descriptors
if ! grep -q "fs.file-max" /etc/sysctl.conf; then
    echo "fs.file-max = 65535" >> /etc/sysctl.conf
fi

# Increase vm.max_map_count for Elasticsearch
if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
    echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
fi

sysctl -p

log_success "System resources configured"

###############################################################################
# Phase 2: Docker Installation
###############################################################################
if [ "$SKIP_DOCKER" = false ]; then
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

    # Start and enable Docker
    systemctl enable docker
    systemctl start docker

    log_success "Docker configured and running"
else
    log_info "Skipping Docker installation (--skip-docker specified)"
fi

###############################################################################
# Phase 3: Jenkins Installation
###############################################################################
if [ "$SKIP_JENKINS" = false ]; then
    log_step "Phase 3: Jenkins Installation"

    if command -v jenkins &> /dev/null || systemctl is-active --quiet jenkins; then
        log_info "Jenkins already installed"
    else
        log_info "Installing Java 17 (required for Jenkins and Allure)..."
        apt-get install -y openjdk-17-jdk

        log_info "Installing Allure command-line tool..."
        # Download and install Allure
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

        # Clean apt cache to remove old repository references
        apt-get clean
        rm -rf /var/lib/apt/lists/*

        log_info "Cleaned old Jenkins configuration, updating apt..."
        apt-get update -qq

        # Add Jenkins GPG key (official method - keep as .asc, don't dearmor)
        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
          tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

        # Add Jenkins repository with signed-by pointing to .asc file
        echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
          https://pkg.jenkins.io/debian-stable binary/" | \
          tee /etc/apt/sources.list.d/jenkins.list > /dev/null

        log_info "Added new Jenkins repository, updating apt..."
        apt-get update -qq

        log_info "Installing Jenkins package..."
        apt-get install -y jenkins

        log_success "Jenkins installed"
    fi

    # Add Jenkins user to docker group
    usermod -aG docker jenkins || true

    # Configure Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Wait for Jenkins to start
    log_info "Waiting for Jenkins to start..."
    for i in {1..30}; do
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
else
    log_info "Skipping Jenkins installation (--skip-jenkins specified)"
fi

###############################################################################
# Phase 4: Infrastructure Deployment
###############################################################################
log_step "Phase 4: Infrastructure Deployment"

log_info "Building mock equipment Docker image..."
cd "$PROJECT_ROOT/mock_equipment"
docker build -t rf-mock-equipment:latest .

log_success "Mock equipment image built"

log_info "Starting integration infrastructure..."
cd "$PROJECT_ROOT/infra"
docker compose -f docker-compose.integration.yml up -d

log_info "Waiting for services to be healthy..."
sleep 10

# Check service health
for service in elasticsearch kibana mock-spectrum-analyzer mock-signal-generator mock-dut; do
    log_info "Checking $service..."
    for i in {1..30}; do
        if docker ps | grep -q "$service.*healthy" || docker ps | grep -q "$service.*Up"; then
            log_success "$service is running"
            break
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
log_info "Installing mock equipment package..."
su - "$ACTUAL_USER" -c "cd '$PROJECT_ROOT' && source venv/bin/activate && pip install -e mock_equipment/"

log_success "Python environment configured"

###############################################################################
# Phase 6: Configuration
###############################################################################
log_step "Phase 6: Configuration"

log_info "Setting up configuration directory..."
mkdir -p /etc/rf-automation
cp "$PROJECT_ROOT/config/integration.env" /etc/rf-automation/
chmod 644 /etc/rf-automation/integration.env

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
if [ "$SKIP_JENKINS" = false ]; then
    if systemctl is-active --quiet jenkins; then
        log_success "✓ Jenkins: Running"
    else
        log_warning "✗ Jenkins not running"
    fi
fi

# Check Mock Equipment
for port in 5001 5002 5003; do
    SERVICE_NAME="Mock equipment on port $port"
    if curl -f -s "http://localhost:$((port + 3000))/health" &> /dev/null; then
        log_success "✓ $SERVICE_NAME: Healthy"
    else
        log_warning "✗ $SERVICE_NAME not responding"
    fi
done

# Run PoPo tests
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

###############################################################################
# Completion
###############################################################################
log_step "Integration Environment Setup Complete!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access URLs:${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Jenkins:       http://localhost:8080"
echo -e "Kibana:        http://localhost:5601"
echo -e "Elasticsearch: http://localhost:9200"
echo -e "Mock SA Admin: http://localhost:8001"
echo -e "Mock SG Admin: http://localhost:8002"
echo -e "Mock DUT Admin: http://localhost:8003"
echo ""

if [ "$SKIP_JENKINS" = false ] && [ -f "$PROJECT_ROOT/jenkins_initial_password.txt" ]; then
    echo -e "${YELLOW}Jenkins Initial Admin Password:${NC}"
    cat "$PROJECT_ROOT/jenkins_initial_password.txt"
    echo ""
fi

echo -e "${GREEN}To activate the Python environment:${NC}"
echo -e "  cd $PROJECT_ROOT"
echo -e "  source venv/bin/activate"
echo ""

echo -e "${GREEN}To run tests:${NC}"
echo -e "  source venv/bin/activate"
echo -e "  robot --outputdir results --listener allure_robotframework:allure-results tests/integration_popo.robot"
echo ""

echo -e "${GREEN}To generate Allure report:${NC}"
echo -e "  allure generate allure-results --clean -o allure-report"
echo -e "  allure open allure-report"
echo ""

echo -e "${GREEN}To view logs:${NC}"
echo -e "  docker compose -f infra/docker-compose.integration.yml logs -f"
echo ""

log_success "Setup completed successfully! 🚀"
