#!/bin/bash
################################################################################
# RF Automation Infrastructure - Setup Helper Script
# Automated installation and configuration for Ubuntu Server 24.04 LTS
#
# Usage: sudo bash scripts/setup_helpers.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Get the actual user (not root)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    ACTUAL_USER=$(whoami)
fi

log_info "Running as user: $ACTUAL_USER"

################################################################################
# Configuration
################################################################################

PROJECT_DIR="/home/$ACTUAL_USER/py_projects/Fully_Product_Automation"
BACKUP_DIR="/backup"

################################################################################
# System Update
################################################################################

install_system_updates() {
    log_info "Updating system packages..."

    apt update
    apt upgrade -y

    log_success "System updated"
}

################################################################################
# Install Essential Tools
################################################################################

install_essential_tools() {
    log_info "Installing essential tools..."

    apt install -y \
        vim \
        git \
        curl \
        wget \
        net-tools \
        htop \
        iotop \
        iftop \
        jq \
        python3-pip \
        python3-venv \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common

    log_success "Essential tools installed"
}

################################################################################
# Install Docker
################################################################################

install_docker() {
    log_info "Installing Docker..."

    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc || true

    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add user to docker group
    usermod -aG docker $ACTUAL_USER

    # Enable Docker service
    systemctl enable docker
    systemctl start docker

    # Configure Docker daemon
    cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

    systemctl restart docker

    log_success "Docker installed: $(docker --version)"
}

################################################################################
# Install Java (for Jenkins and Allure)
################################################################################

install_java() {
    log_info "Installing OpenJDK 17..."

    apt install -y openjdk-17-jdk

    log_success "Java installed: $(java -version 2>&1 | head -n 1)"
}

################################################################################
# Install Allure CLI
################################################################################

install_allure() {
    log_info "Installing Allure CLI..."

    ALLURE_VERSION="2.25.0"
    ALLURE_TGZ="allure-${ALLURE_VERSION}.tgz"
    ALLURE_URL="https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/${ALLURE_TGZ}"

    # Download Allure
    cd /tmp
    wget -q $ALLURE_URL

    # Extract to /opt
    tar -zxf $ALLURE_TGZ -C /opt/
    ln -sf /opt/allure-${ALLURE_VERSION}/bin/allure /usr/bin/allure

    # Cleanup
    rm -f $ALLURE_TGZ

    # Verify installation
    if command -v allure &> /dev/null; then
        log_success "Allure installed: $(allure --version)"
    else
        log_error "Allure installation failed"
        exit 1
    fi
}

################################################################################
# Install Jenkins
################################################################################

install_jenkins() {
    log_info "Installing Jenkins..."

    # Add Jenkins repository (updated GPG key method)
    wget -O /usr/share/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
        tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    # Install Jenkins
    apt update
    apt install -y jenkins

    # Add Jenkins to docker group
    usermod -aG docker jenkins

    # Enable and start Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Wait for Jenkins to start
    log_info "Waiting for Jenkins to start (this may take a minute)..."
    sleep 30

    if systemctl is-active --quiet jenkins; then
        log_success "Jenkins installed and running"

        # Display initial admin password
        if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
            log_info "Jenkins initial admin password:"
            echo "=========================================="
            cat /var/lib/jenkins/secrets/initialAdminPassword
            echo ""
            echo "=========================================="
            log_info "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
        fi
    else
        log_error "Jenkins failed to start"
        systemctl status jenkins
    fi
}

################################################################################
# Configure System Resources
################################################################################

configure_system_resources() {
    log_info "Configuring system resources for Elasticsearch..."

    # Increase vm.max_map_count for Elasticsearch
    sysctl -w vm.max_map_count=262144

    # Make it persistent
    if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
        echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    fi

    # Increase file descriptors
    if ! grep -q "* soft nofile 65536" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf <<EOF

# Elasticsearch file descriptor limits
* soft nofile 65536
* hard nofile 65536
EOF
    fi

    log_success "System resources configured"
}

################################################################################
# Create Backup Directory
################################################################################

setup_backup_directory() {
    log_info "Creating backup directory..."

    mkdir -p $BACKUP_DIR
    chown $ACTUAL_USER:$ACTUAL_USER $BACKUP_DIR

    log_success "Backup directory created: $BACKUP_DIR"
}

################################################################################
# Clone/Update Project Repository
################################################################################

setup_project() {
    log_info "Setting up project..."

    if [ ! -d "$PROJECT_DIR" ]; then
        log_warn "Project directory not found: $PROJECT_DIR"
        log_info "Please clone the repository manually:"
        echo "  git clone <repository-url> $PROJECT_DIR"
    else
        log_success "Project directory found: $PROJECT_DIR"

        # Install Python dependencies
        if [ -f "$PROJECT_DIR/requirements.txt" ]; then
            log_info "Installing Python dependencies..."

            # Create virtual environment
            sudo -u $ACTUAL_USER python3 -m venv $PROJECT_DIR/venv

            # Install dependencies
            sudo -u $ACTUAL_USER $PROJECT_DIR/venv/bin/pip install --upgrade pip
            sudo -u $ACTUAL_USER $PROJECT_DIR/venv/bin/pip install -r $PROJECT_DIR/requirements.txt

            log_success "Python dependencies installed"
        fi

        # Make scripts executable
        chmod +x $PROJECT_DIR/scripts/*.py || true
        chmod +x $PROJECT_DIR/scripts/*.sh || true
    fi
}

################################################################################
# Deploy ELK Stack
################################################################################

deploy_infrastructure() {
    log_info "Deploying infrastructure (ELK + Mock Equipment)..."

    if [ ! -f "$PROJECT_DIR/infra/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in $PROJECT_DIR/infra/"
        return 1
    fi

    cd $PROJECT_DIR/infra

    # Build and start all containers
    sudo -u $ACTUAL_USER docker compose up -d --build

    log_info "Waiting for services to start..."
    sleep 30

    # Check Elasticsearch
    if curl -s http://localhost:9200 > /dev/null; then
        log_success "Elasticsearch is running"
    else
        log_warn "Elasticsearch may not be fully started yet"
    fi

    # Check Kibana
    if curl -s http://localhost:5601/api/status > /dev/null; then
        log_success "Kibana is running"
    else
        log_warn "Kibana may not be fully started yet (this can take 1-2 minutes)"
    fi

    # Check Mock Equipment
    for port in 8001 8002 8003; do
        if curl -s http://localhost:$port/health > /dev/null; then
            log_success "Mock equipment on port $port is running"
        else
            log_warn "Mock equipment on port $port not ready yet"
        fi
    done

    log_info "Infrastructure deployed"
    log_info "Elasticsearch: http://$(hostname -I | awk '{print $1}'):9200"
    log_info "Kibana: http://$(hostname -I | awk '{print $1}'):5601"
}

################################################################################
# Build Docker Test Runner Image
################################################################################

build_test_runner() {
    log_info "Building Docker test runner image..."

    if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
        log_error "Dockerfile not found in $PROJECT_DIR"
        return 1
    fi

    cd $PROJECT_DIR

    sudo -u $ACTUAL_USER docker build -t rf-test-runner .

    log_success "Test runner image built"
}

################################################################################
# Configure Firewall (UFW)
################################################################################

configure_firewall() {
    log_info "Configuring firewall..."

    # Install UFW if not present
    apt install -y ufw

    # Allow SSH
    ufw allow 22/tcp

    # Allow Jenkins
    ufw allow 8080/tcp

    # Allow Kibana
    ufw allow 5601/tcp

    # Deny Elasticsearch (internal only)
    ufw deny 9200/tcp

    # Enable UFW (only if not already enabled)
    if ! ufw status | grep -q "Status: active"; then
        log_warn "Firewall not enabled. Enable manually with: sudo ufw enable"
    fi

    log_success "Firewall rules configured"
}

################################################################################
# Create Health Check Script
################################################################################

create_health_check_script() {
    log_info "Creating health check script..."

    cat > /usr/local/bin/rf_health_check.sh <<'EOF'
#!/bin/bash

echo "=== RF Automation System Health Check ==="
echo ""

# Check services
echo "--- Service Status ---"
systemctl is-active jenkins && echo "Jenkins: OK" || echo "Jenkins: FAILED"
systemctl is-active docker && echo "Docker: OK" || echo "Docker: FAILED"

# Check Docker containers
echo ""
echo "--- Docker Containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check ELK health
echo ""
echo "--- Elasticsearch ---"
curl -s http://localhost:9200/_cluster/health 2>/dev/null | jq -r '.status' || echo "NOT AVAILABLE"

echo ""
echo "--- Kibana ---"
curl -s http://localhost:5601/api/status 2>/dev/null | jq -r '.status.overall.state' || echo "NOT AVAILABLE"

# Check disk space
echo ""
echo "--- Disk Usage ---"
df -h / | tail -n 1

# Check memory
echo ""
echo "--- Memory Usage ---"
free -h | grep Mem

# Check equipment connectivity
echo ""
echo "--- Equipment Connectivity ---"
ping -c 1 -W 1 192.168.50.10 >/dev/null 2>&1 && echo "Spectrum Analyzer (.50.10): OK" || echo "Spectrum Analyzer: UNREACHABLE"
ping -c 1 -W 1 192.168.50.11 >/dev/null 2>&1 && echo "Signal Generator (.50.11): OK" || echo "Signal Generator: UNREACHABLE"
ping -c 1 -W 1 192.168.50.20 >/dev/null 2>&1 && echo "DUT (.50.20): OK" || echo "DUT: UNREACHABLE"

echo ""
echo "=== Health Check Complete ==="
EOF

    chmod +x /usr/local/bin/rf_health_check.sh

    log_success "Health check script created: /usr/local/bin/rf_health_check.sh"
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    echo ""
    echo "=========================================="
    log_success "Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Configure equipment IP addresses:"
    echo "   vim $PROJECT_DIR/resources/network_vars.py"
    echo ""
    echo "2. Access Jenkins:"
    echo "   http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "3. Access Kibana:"
    echo "   http://$(hostname -I | awk '{print $1}'):5601"
    echo ""
    echo "4. Run health check:"
    echo "   /usr/local/bin/rf_health_check.sh"
    echo ""
    echo "5. Test execution:"
    echo "   cd $PROJECT_DIR"
    echo "   docker run --rm --network host -v \$(pwd)/results:/app/results rf-test-runner --help"
    echo ""
    echo "Documentation:"
    echo "   - Setup Guide: $PROJECT_DIR/docs/SETUP.md"
    echo "   - Architecture: $PROJECT_DIR/docs/ARCHITECTURE.md"
    echo "   - Development: $PROJECT_DIR/docs/DEVELOPMENT.md"
    echo "   - Operations: $PROJECT_DIR/docs/OPERATIONS.md"
    echo ""
    echo "=========================================="
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    echo "=========================================="
    echo "RF Automation Infrastructure Setup"
    echo "=========================================="
    echo ""

    log_info "Starting installation..."
    echo ""

    # Execute installation steps
    install_system_updates
    install_essential_tools
    install_docker
    install_java
    install_allure
    install_jenkins
    configure_system_resources
    setup_backup_directory
    setup_project
    deploy_infrastructure
    build_test_runner
    configure_firewall
    create_health_check_script

    # Display summary
    display_summary

    log_info "Please log out and log back in for docker group changes to take effect"
    log_info "Or run: newgrp docker"
}

# Run main installation
main
