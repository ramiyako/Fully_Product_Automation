# AWS Deployment Guide

Complete guide for deploying the RF Automation Integration Environment on AWS EC2.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [AWS Instance Setup](#aws-instance-setup)
- [Security Group Configuration](#security-group-configuration)
- [Deployment Steps](#deployment-steps)
- [Verification](#verification)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Cost Optimization](#cost-optimization)

## Overview

This guide walks you through deploying the complete RF Automation pipeline on AWS, including:
- Jenkins CI/CD server
- Elasticsearch + Kibana (ELK Stack)
- Mock RF Equipment with physics simulation
- Allure test reporting
- Complete automation infrastructure

**Estimated Setup Time:** 30-40 minutes

## Prerequisites

### AWS Account Requirements
- Active AWS account with EC2 access
- IAM permissions to create and manage EC2 instances
- EC2 key pair for SSH access

### Local Machine Requirements
- SSH client installed
- AWS CLI (optional, for advanced management)
- Web browser for accessing services

### Recommended Instance Type
- **Minimum:** t3.large (2 vCPU, 8 GB RAM)
- **Recommended:** m5.large (2 vCPU, 8 GB RAM) - Better network performance
- **Optimal:** m5.xlarge (4 vCPU, 16 GB RAM) - Best performance for concurrent tests

### Storage Requirements
- **Minimum:** 30 GB gp3 EBS volume
- **Recommended:** 50 GB gp3 EBS volume

### Operating System
- Ubuntu Server 24.04 LTS (Canonical, ami-xxxxx)

## AWS Instance Setup

### Step 1: Launch EC2 Instance

1. Navigate to AWS EC2 Console
2. Click "Launch Instance"
3. Configure instance:

```yaml
Name: Automation-Server-IL (or your preferred name)
Application and OS Images: Ubuntu Server 24.04 LTS
Instance type: m5.large
Key pair: Select or create new key pair
Network settings:
  - VPC: Default or custom VPC
  - Auto-assign public IP: Enable
  - Security group: Create new (see below)
Storage:
  - Size: 50 GB
  - Volume type: gp3
  - IOPS: 3000
  - Throughput: 125 MB/s
Advanced details:
  - User data: (leave empty for manual setup)
```

4. Click "Launch Instance"

### Step 2: Note Instance Details

After launch, record the following:
- Instance ID: `i-0e14d354d2194366a`
- Public IPv4 address: `51.84.240.159`
- Private IPv4 address: `172.31.40.202`
- Public DNS: `ec2-51-84-240-159.il-central-1.compute.amazonaws.com`

## Security Group Configuration

### Required Inbound Rules

Create or configure security group with the following rules:

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | Your IP/0.0.0.0/0 | SSH access |
| Custom TCP | TCP | 8080 | Your IP/0.0.0.0/0 | Jenkins |
| Custom TCP | TCP | 5601 | Your IP/0.0.0.0/0 | Kibana |
| Custom TCP | TCP | 9200 | Your IP/0.0.0.0/0 | Elasticsearch |
| Custom TCP | TCP | 8001 | Your IP/0.0.0.0/0 | Mock SA Admin |
| Custom TCP | TCP | 8002 | Your IP/0.0.0.0/0 | Mock SG Admin |
| Custom TCP | TCP | 8003 | Your IP/0.0.0.0/0 | Mock DUT Admin |

**Security Recommendation:**
- For production: Restrict source to your IP address or VPN CIDR
- For development: Can use 0.0.0.0/0 but not recommended for production

### AWS CLI Commands (Alternative)

```bash
# Create security group
aws ec2 create-security-group \
  --group-name rf-automation-sg \
  --description "RF Automation Integration Environment"

# Add inbound rules
aws ec2 authorize-security-group-ingress \
  --group-name rf-automation-sg \
  --ip-permissions \
    IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="SSH"}]' \
    IpProtocol=tcp,FromPort=8080,ToPort=8080,IpRanges='[{CidrIp=0.0.0.0/0,Description="Jenkins"}]' \
    IpProtocol=tcp,FromPort=5601,ToPort=5601,IpRanges='[{CidrIp=0.0.0.0/0,Description="Kibana"}]' \
    IpProtocol=tcp,FromPort=9200,ToPort=9200,IpRanges='[{CidrIp=0.0.0.0/0,Description="Elasticsearch"}]' \
    IpProtocol=tcp,FromPort=8001,ToPort=8003,IpRanges='[{CidrIp=0.0.0.0/0,Description="Mock Equipment"}]'
```

## Deployment Steps

### Step 1: Connect to Instance

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@51.84.240.159

# Or use AWS Session Manager (no key required)
aws ssm start-session --target i-0e14d354d2194366a
```

### Step 2: Clone Repository

```bash
# Update system first
sudo apt-get update
sudo apt-get install -y git

# Clone the repository
cd ~
git clone <your-repository-url> Fully_Product_Automation
cd Fully_Product_Automation

# Checkout integration branch
git checkout integration
```

### Step 3: Run AWS Setup Script

```bash
# Run the AWS-specific setup script
sudo bash scripts/aws_setup.sh --environment=integration --verbose
```

The script will:
1. ✅ Install all system dependencies
2. ✅ Configure system resources (vm.max_map_count, file descriptors)
3. ✅ Install Docker and Docker Compose
4. ✅ Install Jenkins with Allure plugin
5. ✅ Build mock equipment containers
6. ✅ Start Elasticsearch and Kibana
7. ✅ Deploy mock RF equipment
8. ✅ Create Python virtual environment
9. ✅ Run initial validation tests
10. ✅ Configure Jenkins pipeline job

**Duration:** Approximately 30-40 minutes

### Step 4: Monitor Installation

The script provides real-time progress updates:
- Green: Success messages
- Blue: Information
- Yellow: Warnings (usually safe to ignore)
- Red: Errors (requires attention)

## Verification

### Automated Health Checks

The setup script automatically validates:
- ✓ Docker installation and running
- ✓ Elasticsearch cluster health
- ✓ Kibana status
- ✓ Jenkins service
- ✓ Mock equipment health endpoints
- ✓ PoPo (Proof of Platform) tests

### Manual Verification

After setup completes, verify services:

```bash
# Check all Docker containers
docker ps

# Expected output: 5 running containers
# - elasticsearch
# - kibana
# - mock-spectrum-analyzer
# - mock-signal-generator
# - mock-dut

# Check service health
curl http://localhost:9200/_cluster/health
curl http://localhost:5601/api/status
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health

# Check Jenkins
sudo systemctl status jenkins
```

## Accessing Services

### From Your Local Browser

Replace `51.84.240.159` with your instance's public IP:

| Service | URL | Purpose |
|---------|-----|---------|
| Jenkins | http://51.84.240.159:8080 | CI/CD pipeline and test execution |
| Kibana | http://51.84.240.159:5601 | Test results visualization |
| Elasticsearch | http://51.84.240.159:9200 | Test data storage and queries |
| Mock SA Admin | http://51.84.240.159:8001 | Spectrum Analyzer admin interface |
| Mock SG Admin | http://51.84.240.159:8002 | Signal Generator admin interface |
| Mock DUT Admin | http://51.84.240.159:8003 | DUT admin interface |

### Jenkins Initial Setup

1. Open Jenkins: `http://your-public-ip:8080`

2. Get initial admin password:
   ```bash
   # On AWS instance
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   # Or from the file created by setup script
   cat ~/Fully_Product_Automation/jenkins_initial_password.txt
   ```

3. Complete setup wizard:
   - Install suggested plugins
   - Create admin user
   - Configure instance URL (use public IP)

4. Navigate to "RF-Automation-Integration" job
   - If not created automatically, import from repository's Jenkinsfile

### Kibana Initial Setup

1. Open Kibana: `http://your-public-ip:5601`

2. First-time setup:
   - Wait for Kibana to initialize (2-3 minutes)
   - No login required for default configuration

3. Import dashboard:
   - Navigate to Stack Management → Saved Objects
   - Import dashboard from `config/kibana-dashboard.ndjson` (if available)
   - Or create custom visualizations for `rf-automation-*` indices

## Running Tests

### Via Jenkins UI

1. Open Jenkins: `http://your-public-ip:8080`
2. Select "RF-Automation-Integration" job
3. Click "Build with Parameters"
4. Configure test run:
   - **Test Suite:** All / PoPo Only / Functional Only
   - **Test Tags:** smoke, regression, sanity
   - **RF Physics:** Enable/Disable
   - **Noise Floor:** -120 to -90 dBm
   - **Upload to Elasticsearch:** Checked
   - **Generate Allure Report:** Checked
5. Click "Build"
6. Monitor execution in Console Output
7. View results:
   - Allure Report: Click "Allure Report" link
   - Kibana: Open Kibana dashboard
   - Elasticsearch: Query directly via API

### Via Command Line

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@51.84.240.159

# Navigate to project
cd ~/Fully_Product_Automation

# Activate virtual environment
source venv/bin/activate

# Run PoPo tests
robot --outputdir results \
  --listener allure_robotframework:allure-results \
  tests/integration_popo.robot

# Run functional tests
robot --outputdir results \
  --listener allure_robotframework:allure-results \
  tests/integration_functional.robot

# Generate Allure report
allure generate allure-results --clean -o allure-report

# Upload to Elasticsearch
python scripts/upload_to_elastic.py results/output.xml
```

## Troubleshooting

### Issue: Cannot Access Services from Browser

**Symptoms:** Timeout when accessing http://public-ip:8080

**Solutions:**
1. Verify security group rules allow inbound traffic
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

2. Check instance is running
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx
   ```

3. Verify service is running on instance
   ```bash
   ssh -i key.pem ubuntu@public-ip
   sudo systemctl status jenkins
   docker ps
   ```

4. Check UFW firewall status
   ```bash
   sudo ufw status
   ```

### Issue: Elasticsearch Won't Start

**Symptoms:** Container repeatedly restarting

**Solutions:**
1. Check vm.max_map_count setting
   ```bash
   sysctl vm.max_map_count
   # Should be >= 262144
   ```

2. Increase if needed
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   ```

3. Check logs
   ```bash
   docker logs elasticsearch
   ```

4. Verify memory available
   ```bash
   free -h
   # Should have at least 4GB available
   ```

### Issue: Jenkins Build Fails

**Symptoms:** Pipeline fails with Docker permissions error

**Solutions:**
1. Add jenkins user to docker group
   ```bash
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```

2. Verify Docker access
   ```bash
   sudo -u jenkins docker ps
   ```

### Issue: Mock Equipment Not Responding

**Symptoms:** Health check endpoints return 404 or timeout

**Solutions:**
1. Check containers are running
   ```bash
   docker ps | grep mock
   ```

2. Check container logs
   ```bash
   docker logs mock-spectrum-analyzer
   docker logs mock-signal-generator
   docker logs mock-dut
   ```

3. Restart containers
   ```bash
   cd ~/Fully_Product_Automation/infra
   docker compose -f docker-compose.integration.yml restart
   ```

### Issue: High Instance Costs

**Symptoms:** AWS bill higher than expected

**Solutions:**
1. Stop instance when not in use
   ```bash
   aws ec2 stop-instances --instance-ids i-xxxxx
   ```

2. Use scheduled start/stop (AWS Lambda + EventBridge)
3. Downgrade to smaller instance type (t3.medium)
4. Use spot instances (up to 90% savings)

## Maintenance

### Regular Updates

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Update Docker images
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.integration.yml pull
docker compose -f docker-compose.integration.yml up -d

# Update Python dependencies
cd ~/Fully_Product_Automation
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

### Backup Strategies

#### 1. EBS Snapshots

```bash
# Create snapshot via AWS CLI
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "RF Automation backup $(date +%Y-%m-%d)"
```

#### 2. Elasticsearch Backups

```bash
# Create snapshot repository
curl -X PUT "http://localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backup/elasticsearch"
  }
}'

# Create snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)"
```

#### 3. Jenkins Configuration

```bash
# Backup Jenkins home
sudo tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins/
```

### Log Management

```bash
# View Docker container logs
docker compose -f ~/Fully_Product_Automation/infra/docker-compose.integration.yml logs -f

# View Jenkins logs
sudo journalctl -u jenkins -f

# Clean up old logs
docker system prune -af --volumes
```

### Performance Monitoring

```bash
# Monitor system resources
htop

# Monitor network
nload

# Monitor disk I/O
iotop

# Check disk usage
df -h
du -sh ~/Fully_Product_Automation/*
```

## Cost Optimization

### Instance Scheduling

Stop instance during non-working hours:

```bash
# Manual stop
aws ec2 stop-instances --instance-ids i-xxxxx

# Manual start
aws ec2 start-instances --instance-ids i-xxxxx
```

### Use Spot Instances

For dev/test environments, consider spot instances:
- Up to 90% cost savings
- Risk of interruption (2-minute warning)
- Suitable for non-critical workloads

### Right-Sizing

Monitor instance utilization:
```bash
# Check CPU usage over time
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time 2026-03-01T00:00:00Z \
  --end-time 2026-03-05T00:00:00Z \
  --period 3600 \
  --statistics Average
```

If consistently under 40% CPU, consider downsizing to t3.medium.

### Storage Optimization

```bash
# Clean up old Docker images
docker system prune -af

# Clean up old test results
find ~/Fully_Product_Automation/results -type f -mtime +30 -delete

# Clean up old Elasticsearch indices
curl -X DELETE "http://localhost:9200/rf-automation-*" -d'
{
  "query": {
    "range": {
      "@timestamp": {
        "lt": "now-30d"
      }
    }
  }
}'
```

## Estimated Monthly Costs (us-east-1)

| Configuration | Instance Type | Monthly Cost (24/7) | Monthly Cost (8/5) |
|--------------|---------------|---------------------|---------------------|
| Minimal | t3.large | ~$60 | ~$17 |
| Recommended | m5.large | ~$70 | ~$20 |
| Optimal | m5.xlarge | ~$140 | ~$40 |

*Costs include instance + 50GB gp3 storage. Excludes data transfer.*

## Security Best Practices

1. **Restrict Security Group Rules**
   - Limit source IPs to your organization's CIDR
   - Use VPN for access

2. **Enable AWS CloudWatch Logs**
   ```bash
   aws logs create-log-group --log-group-name /aws/ec2/rf-automation
   ```

3. **Use IAM Instance Roles** (instead of access keys)

4. **Enable AWS Systems Manager Session Manager**
   - No need to expose SSH port
   - All sessions logged

5. **Regular Security Updates**
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

6. **Enable AWS CloudTrail** for audit logging

## Next Steps

After successful deployment:

1. ✅ Configure Jenkins job (if not auto-created)
2. ✅ Import Kibana dashboards
3. ✅ Run your first test suite
4. ✅ Set up automated backups
5. ✅ Configure CloudWatch monitoring
6. ✅ Set up instance scheduling
7. ✅ Document your customizations

## Support

For issues or questions:
- Check [Troubleshooting](#troubleshooting) section
- Review logs: `docker compose logs -f`
- Check AWS instance console for system logs
- Review [QUICK_REFERENCE.txt](QUICK_REFERENCE.txt) for common operations

---

**Document Version:** 1.0
**Last Updated:** 2026-03-05
**Maintained by:** Automation Team
