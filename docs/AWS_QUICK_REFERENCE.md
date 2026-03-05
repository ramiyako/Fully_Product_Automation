# AWS Quick Reference Card

Quick commands and procedures for managing the RF Automation environment on AWS.

## 🚀 Quick Setup

```bash
# 1. SSH into your AWS instance
ssh -i your-key.pem ubuntu@51.84.240.159

# 2. Clone repository
git clone <repo-url> Fully_Product_Automation
cd Fully_Product_Automation
git checkout integration

# 3. Run AWS setup script
sudo bash scripts/aws_setup.sh --environment=integration --verbose

# Duration: ~30-40 minutes
```

## 🌐 Access URLs

Replace `51.84.240.159` with your instance's public IP:

| Service | URL | Port |
|---------|-----|------|
| Jenkins | http://51.84.240.159:8080 | 8080 |
| Kibana | http://51.84.240.159:5601 | 5601 |
| Elasticsearch | http://51.84.240.159:9200 | 9200 |
| Mock SA Admin | http://51.84.240.159:8001 | 8001 |
| Mock SG Admin | http://51.84.240.159:8002 | 8002 |
| Mock DUT Admin | http://51.84.240.159:8003 | 8003 |

## 🔐 Security Group Rules

```bash
# Create security group
bash scripts/configure_aws_security_group.sh \
  --group-name=rf-automation-sg \
  --allowed-ip=YOUR_IP/32

# Required inbound ports:
# - 22    (SSH)
# - 8080  (Jenkins)
# - 5601  (Kibana)
# - 9200  (Elasticsearch)
# - 8001  (Mock SA)
# - 8002  (Mock SG)
# - 8003  (Mock DUT)
```

## 🔍 Service Health Checks

```bash
# Check all Docker containers
docker ps

# Check Elasticsearch
curl http://localhost:9200/_cluster/health

# Check Kibana
curl http://localhost:5601/api/status

# Check Jenkins
sudo systemctl status jenkins

# Check Mock Equipment
curl http://localhost:8001/health  # SA
curl http://localhost:8002/health  # SG
curl http://localhost:8003/health  # DUT
```

## 🎛️ Managing Services

### Start/Stop All Services

```bash
cd ~/Fully_Product_Automation/infra

# Start all services
docker compose -f docker-compose.aws.yml up -d

# Stop all services
docker compose -f docker-compose.aws.yml down

# Restart all services
docker compose -f docker-compose.aws.yml restart

# View logs
docker compose -f docker-compose.aws.yml logs -f
```

### Individual Services

```bash
# Restart Elasticsearch
docker restart rf-elasticsearch

# Restart Kibana
docker restart rf-kibana

# Restart Jenkins
sudo systemctl restart jenkins

# Restart Mock Equipment
docker restart mock-sa mock-sg mock-dut
```

## 🧪 Running Tests

### Via Jenkins UI

1. Open: http://YOUR_IP:8080
2. Job: "RF-Automation-Integration"
3. Click: "Build with Parameters"
4. Configure and click "Build"

### Via Command Line

```bash
# Activate environment
cd ~/Fully_Product_Automation
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
```

## 📊 Viewing Results

### Allure Reports

```bash
# Generate report
cd ~/Fully_Product_Automation
allure generate allure-results --clean -o allure-report

# Serve locally (access via SSH tunnel)
allure open allure-report
```

### Kibana Dashboards

1. Open: http://YOUR_IP:5601
2. Navigate to: Dashboards
3. Search: "RF Automation"

### Elasticsearch Queries

```bash
# Get all test results
curl -X GET "http://localhost:9200/rf-automation-*/_search?pretty"

# Count total tests
curl -X GET "http://localhost:9200/rf-automation-*/_count?pretty"

# Get failed tests only
curl -X GET "http://localhost:9200/rf-automation-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"term":{"status":"FAIL"}}}'
```

## 🐛 Troubleshooting

### Cannot Access Services

```bash
# 1. Check security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# 2. Check firewall
sudo ufw status

# 3. Check service is running
docker ps
sudo systemctl status jenkins
```

### Elasticsearch Won't Start

```bash
# Check vm.max_map_count
sysctl vm.max_map_count

# Set if needed (should be >= 262144)
sudo sysctl -w vm.max_map_count=262144

# Check logs
docker logs rf-elasticsearch
```

### Jenkins Build Fails

```bash
# Check Jenkins can access Docker
sudo -u jenkins docker ps

# Add jenkins to docker group if needed
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### High Memory Usage

```bash
# Check memory
free -h

# Check Docker stats
docker stats

# Restart services to free memory
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.aws.yml restart
```

## 💾 Backup & Restore

### Create Snapshot

```bash
# Via AWS CLI
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "RF Automation backup $(date +%Y-%m-%d)"

# Via AWS Console
# EC2 → Elastic Block Store → Volumes → Actions → Create Snapshot
```

### Backup Elasticsearch Data

```bash
# Create backup directory
sudo mkdir -p /backup/elasticsearch

# Create snapshot repository
curl -X PUT "http://localhost:9200/_snapshot/backup_repo" \
  -H 'Content-Type: application/json' \
  -d '{"type":"fs","settings":{"location":"/backup/elasticsearch"}}'

# Create snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)"
```

### Backup Jenkins Configuration

```bash
# Backup Jenkins home directory
sudo tar -czf ~/jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins/
```

## 📈 Monitoring

### System Resources

```bash
# CPU and memory
htop

# Disk usage
df -h
du -sh ~/Fully_Product_Automation/*

# Network
nload

# Disk I/O
iotop
```

### Service Logs

```bash
# Docker containers
docker compose -f ~/Fully_Product_Automation/infra/docker-compose.aws.yml logs -f

# Jenkins
sudo journalctl -u jenkins -f

# System logs
sudo journalctl -f
```

## 💰 Cost Management

### Stop Instance When Not Needed

```bash
# From local machine with AWS CLI
aws ec2 stop-instances --instance-ids i-xxxxx

# Start again when needed
aws ec2 start-instances --instance-ids i-xxxxx

# Check instance state
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].State.Name'
```

### Clean Up Resources

```bash
# Remove old Docker images
docker system prune -af

# Remove old test results
find ~/Fully_Product_Automation/results -type f -mtime +30 -delete

# Remove old Elasticsearch data
curl -X DELETE "http://localhost:9200/rf-automation-2026-01-*"
```

## 🔄 Updates

### Update System Packages

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Update Docker Images

```bash
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.aws.yml pull
docker compose -f docker-compose.aws.yml up -d
```

### Update Python Dependencies

```bash
cd ~/Fully_Product_Automation
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

### Update Repository

```bash
cd ~/Fully_Product_Automation
git pull origin integration
```

## 🔗 Useful AWS CLI Commands

### Instance Management

```bash
# Get instance details
aws ec2 describe-instances --instance-ids i-xxxxx

# Get public IP
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# Change instance type
aws ec2 stop-instances --instance-ids i-xxxxx
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxx \
  --instance-type t3.medium
aws ec2 start-instances --instance-ids i-xxxxx
```

### Security Group Management

```bash
# List security groups
aws ec2 describe-security-groups

# Add inbound rule
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 1.2.3.4/32

# Remove inbound rule
aws ec2 revoke-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 1.2.3.4/32
```

### Volume Management

```bash
# List volumes
aws ec2 describe-volumes

# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "Backup $(date +%Y-%m-%d)"

# List snapshots
aws ec2 describe-snapshots --owner-ids self
```

## 📚 Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| AWS Environment | `/etc/rf-automation/aws.env` | AWS-specific configuration |
| Docker Compose | `~/Fully_Product_Automation/infra/docker-compose.aws.yml` | AWS Docker services |
| Jenkins Config | `/var/lib/jenkins/config.xml` | Jenkins configuration |
| Python Venv | `~/Fully_Product_Automation/venv/` | Python virtual environment |

## 🆘 Emergency Procedures

### Service Not Responding

```bash
# 1. Check if running
docker ps -a
sudo systemctl status jenkins

# 2. Check logs
docker logs <container-name>
sudo journalctl -u jenkins -n 50

# 3. Restart
docker restart <container-name>
sudo systemctl restart jenkins

# 4. Nuclear option - restart all
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.aws.yml down
docker compose -f docker-compose.aws.yml up -d
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -af --volumes

# Clean logs
sudo journalctl --vacuum-time=7d

# Clean test results
find ~/Fully_Product_Automation/results -type f -mtime +7 -delete
```

### Out of Memory

```bash
# Check memory
free -h

# Check what's using memory
docker stats
ps aux --sort=-%mem | head

# Restart services
docker compose -f ~/Fully_Product_Automation/infra/docker-compose.aws.yml restart

# If persistent, increase instance size
# Stop instance → Change type to m5.xlarge → Start instance
```

## 📞 Support Resources

- Full Documentation: `~/Fully_Product_Automation/docs/AWS_DEPLOYMENT.md`
- Quick Reference: `~/Fully_Product_Automation/docs/QUICK_REFERENCE.txt`
- AWS Console: https://console.aws.amazon.com/ec2/
- AWS CLI Docs: https://docs.aws.amazon.com/cli/

---

**Version:** 1.0
**Updated:** 2026-03-05
**Instance:** i-0e14d354d2194366a (51.84.240.159)
