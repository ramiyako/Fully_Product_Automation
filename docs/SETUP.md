# Setup Guide - RF Automation Infrastructure

Complete installation and configuration guide for deploying the RF automation infrastructure on Intel NUC hardware.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Hardware Setup](#hardware-setup)
3. [Ubuntu Server Installation](#ubuntu-server-installation)
4. [Docker Installation](#docker-installation)
5. [Jenkins Installation](#jenkins-installation)
6. [ELK Stack Deployment](#elk-stack-deployment)
7. [Project Deployment](#project-deployment)
8. [Verification](#verification)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

- **Intel NUC** (or equivalent)
  - CPU: Intel i7 or better
  - RAM: 32GB (minimum 16GB)
  - Storage: 1TB SSD
  - Network: Dual network interfaces (or VLAN capable)

### Network Requirements

- **Office Network**: Internet access for Git, Docker registry, updates
- **Lab VLAN**: Access to RF equipment (192.168.50.0/24)
- Static IP address configured for the NUC

### Software Requirements

- Ubuntu Server 24.04 LTS ISO
- USB drive (8GB+) for installation media

---

## Hardware Setup

### 1. Network Configuration

The NUC requires access to two networks:

```
┌──────────────────────────────────────┐
│          Intel NUC Server             │
│                                       │
│  ┌─────────────┐  ┌────────────────┐ │
│  │  eth0       │  │  eth1          │ │
│  │  (Office)   │  │  (Lab VLAN)    │ │
│  └──────┬──────┘  └──────┬─────────┘ │
└─────────┼─────────────────┼───────────┘
          │                 │
          │                 │
    ┌─────▼─────┐    ┌──────▼───────┐
    │  Office   │    │   Lab VLAN   │
    │  Network  │    │ 192.168.50.x │
    └───────────┘    └──────────────┘
```

**Option A: Two Physical Network Interfaces**
- eth0: Office network (DHCP or static)
- eth1: Lab VLAN (static: 192.168.50.5/24)

**Option B: Single Interface with VLAN Tagging**
- Configure VLAN tagging on the switch
- Create VLAN interface on NUC

### 2. Physical Connections

1. Connect NUC to both networks (or configure VLAN)
2. Connect power supply
3. Connect keyboard, mouse, monitor for initial setup
4. Ensure RF equipment is powered and connected to Lab VLAN

---

## Ubuntu Server Installation

### 1. Create Installation Media

```bash
# On your workstation (Linux)
sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

### 2. Install Ubuntu Server

1. Boot NUC from USB drive
2. Select "Install Ubuntu Server"
3. Choose language and keyboard layout
4. Configure network:
   - **Primary Interface (Office)**: DHCP or Static
   - **Secondary Interface (Lab)**: Configure manually
     - IP: 192.168.50.5
     - Netmask: 255.255.255.0
     - Gateway: 192.168.50.1
     - DNS: 8.8.8.8, 8.8.4.4
5. Configure storage: Use entire disk
6. Create user account:
   - Username: `automation`
   - Password: [Secure password]
7. Install OpenSSH server: **Yes**
8. Skip additional packages for now
9. Reboot after installation

### 3. Post-Installation Configuration

SSH into the server:

```bash
ssh automation@<nuc-ip-address>
```

Update system:

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

Install essential tools:

```bash
sudo apt install -y \
    vim \
    git \
    curl \
    wget \
    net-tools \
    htop \
    python3-pip \
    python3-venv
```

### 4. Configure Static Networking (Netplan)

Edit network configuration:

```bash
sudo vim /etc/netplan/00-installer-config.yaml
```

Example configuration:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    # Office network interface
    enp0s25:
      dhcp4: true
      dhcp6: false

    # Lab VLAN interface
    enp3s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.50.5/24
      routes:
        - to: 192.168.50.0/24
          via: 192.168.50.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply configuration:

```bash
sudo netplan apply
```

Verify connectivity:

```bash
# Test office network
ping -c 3 google.com

# Test lab VLAN
ping -c 3 192.168.50.1
ping -c 3 192.168.50.10    # Spectrum Analyzer
ping -c 3 192.168.50.11    # Signal Generator
```

---

## Docker Installation

### 1. Install Docker Engine

```bash
# Remove old versions (if any)
sudo apt remove docker docker-engine docker.io containerd runc

# Install prerequisites
sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
sudo docker --version
sudo docker compose version
```

### 2. Configure Docker

Add user to docker group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Verify Docker works without sudo:

```bash
docker run hello-world
```

Configure Docker daemon (optional optimizations):

```bash
sudo vim /etc/docker/daemon.json
```

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
```

Restart Docker:

```bash
sudo systemctl restart docker
sudo systemctl enable docker
```

---

## Jenkins Installation

### 1. Install Java (Jenkins Requirement)

```bash
sudo apt install -y openjdk-17-jdk

# Verify installation
java -version
```

### 2. Install Jenkins

```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check status
sudo systemctl status jenkins
```

### 3. Initial Jenkins Setup

Get initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Access Jenkins web interface:

```
http://<nuc-ip>:8080
```

1. Enter initial admin password
2. Install suggested plugins
3. Create admin user
4. Configure Jenkins URL

### 4. Install Required Jenkins Plugins

Navigate to: **Manage Jenkins** → **Manage Plugins** → **Available**

Install:
- **Git Plugin**
- **Pipeline Plugin**
- **Docker Pipeline Plugin**
- **Robot Framework Plugin**
- **Blue Ocean** (optional, for better UI)

### 5. Configure Jenkins for Docker

Add Jenkins user to docker group:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## ELK Stack Deployment

### 1. Clone Project Repository

```bash
cd ~
git clone <repository-url> Fully_Product_Automation
cd Fully_Product_Automation
```

### 2. Deploy Elasticsearch and Kibana

```bash
cd infra
docker compose up -d
```

### 3. Verify ELK Stack

Check container status:

```bash
docker ps
```

Expected output:
```
CONTAINER ID   IMAGE                                                  STATUS
xxx            docker.elastic.co/elasticsearch/elasticsearch:8.12.0   Up
xxx            docker.elastic.co/kibana/kibana:8.12.0                 Up
```

Check Elasticsearch:

```bash
curl http://localhost:9200

# Expected: JSON response with cluster info
```

Check Kibana:

```bash
curl http://localhost:5601/api/status

# Expected: JSON response with Kibana status
```

Access Kibana web interface:

```
http://<nuc-ip>:5601
```

### 4. Configure System Resources (if needed)

Increase virtual memory for Elasticsearch:

```bash
sudo sysctl -w vm.max_map_count=262144

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

---

## Project Deployment

### 1. Install Python Dependencies

```bash
cd ~/Fully_Product_Automation

# Create virtual environment (optional but recommended for testing)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Equipment IP Addresses

Edit configuration:

```bash
vim resources/network_vars.py
```

Update IP addresses to match your equipment:

```python
EQUIPMENT_LIST = {
    "SpectrumAnalyzer": "192.168.50.10",    # Your SA IP
    "SignalGenerator": "192.168.50.11",     # Your SG IP
    "DUT": "192.168.50.20",                 # Your DUT IP
}
```

Validate configuration:

```bash
python3 resources/network_vars.py
```

### 3. Build Docker Test Runner Image

```bash
docker build -t rf-test-runner .
```

Verify image:

```bash
docker images | grep rf-test-runner
```

### 4. Test Execution Locally

```bash
# Run tests locally
docker run --rm --network host \
    -v $(pwd)/results:/app/results \
    rf-test-runner --outputdir results tests/

# Check results
ls -lh results/
```

---

## Jenkins Pipeline Configuration

### 1. Create Jenkins Pipeline Job

1. In Jenkins, click **New Item**
2. Enter name: `RF-Automation-Pipeline`
3. Select: **Pipeline**
4. Click **OK**

### 2. Configure Pipeline

**General**:
- ✓ Discard old builds (keep last 30)

**Build Triggers**:
- ✓ Poll SCM: `H/15 * * * *` (every 15 minutes)
- Or configure webhook from Git

**Pipeline**:
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `<your-repo-url>`
- Branch: `*/main`
- Script Path: `Jenkinsfile`

### 3. Configure Git Credentials (if private repo)

**Manage Jenkins** → **Manage Credentials** → **Add Credentials**

- Kind: Username with password
- Username: <git-username>
- Password: <git-token>
- ID: git-credentials

### 4. Test Pipeline

Click **Build Now**

Monitor console output for any errors.

---

## Verification

### Complete System Test

```bash
# 1. Verify network connectivity
ping -c 3 192.168.50.10
ping -c 3 192.168.50.11

# 2. Verify Docker
docker ps

# 3. Verify ELK Stack
curl http://localhost:9200
curl http://localhost:5601/api/status

# 4. Verify Jenkins
curl http://localhost:8080

# 5. Run validation script
python3 resources/network_vars.py

# 6. Test local execution
docker run --rm --network host rf-test-runner --help
```

### Run Hello World Test

Create simple test:

```bash
cat > tests/hello_world.robot << 'EOF'
*** Test Cases ***
Hello World Test
    Log    Hello from RF Automation!    console=True
    Should Be True    ${True}
EOF
```

Run test:

```bash
docker run --rm --network host \
    -v $(pwd)/results:/app/results \
    rf-test-runner --outputdir results tests/hello_world.robot
```

Trigger via Jenkins and verify results appear in Kibana.

---

## Troubleshooting

### Docker Issues

**Problem**: Permission denied when running docker

**Solution**:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Problem**: Elasticsearch won't start

**Solution**:
```bash
sudo sysctl -w vm.max_map_count=262144
docker compose -f infra/docker-compose.yml restart elasticsearch
```

### Network Issues

**Problem**: Can't reach equipment

**Solution**:
```bash
# Check routes
ip route

# Check if lab interface is up
ip addr show

# Test VLAN connectivity
ping 192.168.50.1
```

### Jenkins Issues

**Problem**: Jenkins can't run Docker commands

**Solution**:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## Next Steps

1. Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design details
2. Read [DEVELOPMENT.md](DEVELOPMENT.md) for writing tests
3. Check [OPERATIONS.md](OPERATIONS.md) for daily operations

---

**Installation Complete!**

Your RF Automation Infrastructure is now ready for use.
