# Integration Environment Setup Guide

Complete guide for setting up the RF Automation Integration Environment with mock equipment for testing without physical hardware.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Steps](#detailed-setup-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)

## Overview

The integration branch provides a complete turnkey solution for running RF automation tests without physical equipment. It includes:

- **Mock RF Equipment**: High-fidelity simulation of Spectrum Analyzer, Signal Generator, and DUT
- **RF Physics Engine**: Realistic simulation of harmonics, noise floor, and intermodulation
- **Complete Infrastructure**: Elasticsearch, Kibana, Jenkins (all automated)
- **PoPo Tests**: 12 Proof-of-Platform tests validating the entire stack
- **One-Command Deployment**: Fully automated setup script

## Prerequisites

### Hardware Requirements

**Minimum:**
- 4 CPU cores
- 16 GB RAM
- 50 GB free disk space
- Network connectivity

**Recommended (NUC deployment):**
- Intel NUC or equivalent
- 8 CPU cores (Intel i7)
- 32 GB RAM
- 256 GB SSD
- Gigabit Ethernet

### Software Requirements

**Operating System:**
- Ubuntu 22.04 LTS or 24.04 LTS (recommended)
- Debian 11 or 12
- Other Linux distributions (may require adaptation)

**Pre-installed:**
- Git
- Sudo privileges
- Internet connectivity (for initial setup)

**Automatically installed by setup script:**
- Docker & Docker Compose
- Python 3.11+
- Jenkins LTS
- Java 17 (for Jenkins)
- All Python dependencies

## Quick Start

### One-Command Setup

For a fresh Ubuntu system (NUC or VM), run:

```bash
# Clone the repository
git clone <your-repo-url> ~/Fully_Product_Automation
cd ~/Fully_Product_Automation

# Checkout integration branch
git checkout integration

# Run setup script with sudo
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose
```

**Setup time:** ~20-30 minutes (depending on internet speed)

**What it does:**
1. Updates system packages
2. Installs Docker and Docker Compose
3. Installs Jenkins with required plugins
4. Builds and starts mock equipment containers
5. Starts Elasticsearch and Kibana
6. Creates Python virtual environment
7. Installs all dependencies
8. Runs validation tests (PoPo suite)
9. Displays access URLs and credentials

### Access URLs

After successful setup:

| Service | URL | Purpose |
|---------|-----|---------|
| Jenkins | http://localhost:8080 | CI/CD Pipeline |
| Kibana | http://localhost:5601 | Test Results Visualization |
| Elasticsearch | http://localhost:9200 | Test Results Storage |
| Mock SA Admin | http://localhost:8001 | Spectrum Analyzer Admin UI |
| Mock SG Admin | http://localhost:8002 | Signal Generator Admin UI |
| Mock DUT Admin | http://localhost:8003 | DUT Admin UI |

## Detailed Setup Steps

### Step 1: System Preparation

Update your system and install Git:

```bash
sudo apt update
sudo apt install -y git curl wget
```

### Step 2: Clone Repository

```bash
git clone <your-repo-url> ~/Fully_Product_Automation
cd ~/Fully_Product_Automation
git checkout integration
```

### Step 3: Review Configuration

Check the integration environment configuration:

```bash
cat config/integration.env
```

Key settings:
- `USE_MOCK_EQUIPMENT=true` - Enables mock equipment
- `MOCK_ENABLE_HARMONICS=true` - Enables harmonic simulation
- `MOCK_HARMONIC_ORDER=3` - Simulates up to 3rd harmonic
- `MOCK_NOISE_FLOOR_DBM=-120` - Noise floor setting

You can customize these settings before running setup.

### Step 4: Run Setup Script

**Full setup (recommended for first-time):**
```bash
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--mode=MODE` | Setup mode: `nuc`, `dev`, `ci` | `dev` |
| `--environment=ENV` | Environment: `integration`, `staging` | `integration` |
| `--verbose` | Enable detailed output | disabled |
| `--skip-jenkins` | Skip Jenkins installation | disabled |
| `--skip-docker` | Skip Docker installation | disabled |
| `--help` | Show help message | - |

**Examples:**

```bash
# Development setup (skip Jenkins)
sudo bash scripts/integration_setup.sh --skip-jenkins

# CI environment setup
sudo bash scripts/integration_setup.sh --mode=ci

# Re-run without reinstalling Docker
sudo bash scripts/integration_setup.sh --skip-docker
```

### Step 5: Verify Installation

The setup script automatically runs verification. You can manually verify:

```bash
# Activate Python environment
cd ~/Fully_Product_Automation
source venv/bin/activate

# Check Docker containers
docker ps

# Expected output: 5 containers running
# - rf-elasticsearch
# - rf-kibana
# - mock-sa
# - mock-sg
# - mock-dut

# Check service health
curl http://localhost:9200/_cluster/health    # Elasticsearch
curl http://localhost:8001/health             # Mock SA
curl http://localhost:8002/health             # Mock SG
curl http://localhost:8003/health             # Mock DUT

# Run PoPo tests
robot --outputdir results tests/integration_popo.robot
```

## Verification

### Health Check Script

Create and run a quick health check:

```bash
#!/bin/bash
echo "===== RF Automation Health Check ====="

# Docker
echo -n "Docker: "
docker --version || echo "NOT INSTALLED"

# Containers
echo -n "Containers: "
docker ps --format "{{.Names}}" | wc -l

# Elasticsearch
echo -n "Elasticsearch: "
curl -sf http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' || echo "DOWN"

# Kibana
echo -n "Kibana: "
curl -sf http://localhost:5601/api/status > /dev/null && echo "UP" || echo "DOWN"

# Jenkins
echo -n "Jenkins: "
systemctl is-active jenkins || echo "NOT RUNNING"

# Mock Equipment
for port in 8001 8002 8003; do
    echo -n "Mock equipment (port $port): "
    curl -sf http://localhost:$port/health > /dev/null && echo "UP" || echo "DOWN"
done

echo "====================================="
```

### Running Tests

**PoPo Tests (Proof of Platform):**
```bash
source venv/bin/activate
robot --outputdir results tests/integration_popo.robot
```

**Functional Tests:**
```bash
source venv/bin/activate
robot --outputdir results tests/rf_functional.robot
```

**With Allure Report:**
```bash
source venv/bin/activate
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      tests/integration_popo.robot

# Generate Allure report
allure generate allure-results --clean -o allure-report
allure open allure-report
```

## Troubleshooting

### Common Issues

#### 1. Docker Permission Denied

**Error:** `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or run:
newgrp docker
```

#### 2. Port Already in Use

**Error:** `Bind for 0.0.0.0:9200 failed: port is already allocated`

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :9200

# Stop the conflicting service or change port in docker-compose.yml
sudo systemctl stop elasticsearch  # if system ES is running
```

#### 3. Elasticsearch Won't Start

**Error:** `max virtual memory areas vm.max_map_count [65530] is too low`

**Solution:**
```bash
# Increase vm.max_map_count
sudo sysctl -w vm.max_map_count=262144

# Make it permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

#### 4. Mock Equipment Not Responding

**Check logs:**
```bash
docker logs mock-sa
docker logs mock-sg
docker logs mock-dut
```

**Restart container:**
```bash
docker restart mock-sa
```

#### 5. Tests Failing with Connection Errors

**Check configuration:**
```bash
# Verify environment variables
cat config/integration.env

# Verify network_vars.py is using mock endpoints
python3 -c "from resources.environment_config import get_config; c = get_config(); print(f'SA: {c.spectrum_analyzer.address}')"
```

**Expected output:**
```
SA: 127.0.0.1:5001
```

### Logs Location

| Component | Log Location |
|-----------|--------------|
| Setup script | Terminal output (redirect to file if needed) |
| Docker containers | `docker logs <container-name>` |
| Robot Framework | `results/log.html` |
| Jenkins | `/var/log/jenkins/jenkins.log` |
| Elasticsearch | `docker logs rf-elasticsearch` |

### Reset Environment

If you need to start fresh:

```bash
# Stop and remove all containers
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.integration.yml down -v

# Remove volumes
docker volume rm rf-elasticsearch-data

# Re-run setup
cd ~/Fully_Product_Automation
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration
```

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Integration Environment                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐          ┌─────────────────────────┐      │
│  │   Jenkins    │          │   Docker Infrastructure │      │
│  │  (Host OS)   │────────> │                         │      │
│  │              │          │  ┌──────────────────┐   │      │
│  │  - Pipeline  │          │  │  Elasticsearch   │   │      │
│  │  - Allure    │          │  │     (Port 9200)  │   │      │
│  │  - Reports   │          │  └──────────────────┘   │      │
│  └──────────────┘          │  ┌──────────────────┐   │      │
│                            │  │     Kibana       │   │      │
│  ┌──────────────┐          │  │   (Port 5601)    │   │      │
│  │  Robot       │          │  └──────────────────┘   │      │
│  │  Framework   │───┐      │                         │      │
│  │   Tests      │   │      │  ┌──────────────────┐   │      │
│  └──────────────┘   │      │  │  Mock Equipment  │   │      │
│                     │      │  │                  │   │      │
│                     └─────>│  │  - SA (5001)     │   │      │
│                            │  │  - SG (5002)     │   │      │
│                            │  │  - DUT (5003)    │   │      │
│                            │  │                  │   │      │
│                            │  │  RF Physics      │   │      │
│                            │  │  Simulation      │   │      │
│                            │  └──────────────────┘   │      │
│                            └─────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction

1. **Robot Framework Tests** → Send SCPI commands via TCP to **Mock Equipment**
2. **Mock Equipment** → Simulate RF behavior using **RF Physics Engine**
3. **Tests** → Upload results to **Elasticsearch** via listener
4. **Kibana** → Visualize test results from **Elasticsearch**
5. **Jenkins** → Orchestrate test execution and generate **Allure reports**

### Network Ports

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 5001 | Mock SA SCPI | TCP | Spectrum Analyzer SCPI commands |
| 5002 | Mock SG SCPI | TCP | Signal Generator SCPI commands |
| 5003 | Mock DUT SCPI | TCP | DUT SCPI commands |
| 8001 | Mock SA HTTP | HTTP | Admin interface for SA |
| 8002 | Mock SG HTTP | HTTP | Admin interface for SG |
| 8003 | Mock DUT HTTP | HTTP | Admin interface for DUT |
| 9200 | Elasticsearch | HTTP | Test results storage API |
| 9300 | Elasticsearch | TCP | Elasticsearch cluster communication |
| 5601 | Kibana | HTTP | Visualization dashboard |
| 8080 | Jenkins | HTTP | CI/CD pipeline interface |

## Next Steps

- [Mock Equipment Documentation](MOCK_EQUIPMENT.md)
- [PoPo Tests Documentation](POPO_TESTS.md)
- [RF Physics Simulation Details](RF_PHYSICS_SIMULATION.md)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs for specific components
3. Open an issue in the project repository
