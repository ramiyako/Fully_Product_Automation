# AWS Deployment Checklist

Complete step-by-step checklist for deploying RF Automation on AWS with Allure reporting.

## 📋 Pre-Deployment Checklist

### AWS Prerequisites
- [ ] AWS account with EC2 access
- [ ] IAM permissions for EC2 instance management
- [ ] EC2 key pair created and downloaded (.pem file)
- [ ] Understanding of basic AWS console navigation

### Instance Information
- Instance ID: `i-0e14d354d2194366a`
- Public IP: `51.84.240.159`
- Region: `il-central-1`
- Availability Zone: `il-central-1a`

## 🚀 Deployment Steps

### Step 1: Launch EC2 Instance ✅ COMPLETED

Your instance is already running with the following specs:
- **Type:** m5.large (2 vCPU, 8 GB RAM)
- **OS:** Ubuntu Server 24.04 LTS
- **Storage:** 50 GB gp3 EBS volume
- **Status:** Running

### Step 2: Configure Security Group

#### Option A: Manual Configuration (via AWS Console)

1. **Open AWS EC2 Console**
   - Navigate to: https://console.aws.amazon.com/ec2/

2. **Go to Security Groups**
   - Left menu → Network & Security → Security Groups

3. **Find Your Security Group**
   - Search for the security group attached to instance: `i-0e14d354d2194366a`

4. **Edit Inbound Rules**
   - Click "Edit inbound rules"
   - Add the following rules:

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/0.0.0.0/0 | SSH access |
| Custom TCP | TCP | 8080 | 0.0.0.0/0 | Jenkins |
| Custom TCP | TCP | 5601 | 0.0.0.0/0 | Kibana |
| Custom TCP | TCP | 9200 | 0.0.0.0/0 | Elasticsearch |
| Custom TCP | TCP | 9080 | 0.0.0.0/0 | **Allure Reports** |
| Custom TCP | TCP | 8001 | 0.0.0.0/0 | Mock SA Admin |
| Custom TCP | TCP | 8002 | 0.0.0.0/0 | Mock SG Admin |
| Custom TCP | TCP | 8003 | 0.0.0.0/0 | Mock DUT Admin |

5. **Save Rules**

#### Option B: Automated Configuration (via Script)

From your **local machine**, run:

```bash
bash scripts/configure_aws_security_group.sh \
  --group-name=<YOUR_SG_NAME> \
  --allowed-ip=0.0.0.0/0
```

**Checklist:**
- [ ] Security group configured with all required ports
- [ ] Port 9080 added for Allure Reports
- [ ] Rules saved successfully

### Step 3: SSH into AWS Instance

```bash
ssh -i your-key.pem ubuntu@51.84.240.159
```

**Checklist:**
- [ ] Successfully connected to AWS instance
- [ ] Have sudo access

### Step 4: Run Complete Deployment Script

On the AWS instance, run:

```bash
# Download or clone your repository first
git clone <your-repo-url> Fully_Product_Automation
cd Fully_Product_Automation
git checkout integration

# Run the complete deployment script
sudo bash scripts/deploy_to_aws.sh
```

This script will:
1. ✅ Verify AWS environment
2. ✅ Run aws_setup.sh (installs Docker, Jenkins, etc.)
3. ✅ Install nginx for Allure report hosting
4. ✅ Configure Allure on port 9080
5. ✅ Start all services
6. ✅ Run health checks
7. ✅ Generate initial Allure report

**Duration:** 30-40 minutes

**Checklist:**
- [ ] Script completed without errors
- [ ] All services started successfully
- [ ] Allure nginx configured on port 9080
- [ ] Initial health checks passed

### Step 5: Verify Services Locally (on AWS instance)

While still SSH'd into the AWS instance:

```bash
# Check Docker containers
docker ps

# Check Jenkins
sudo systemctl status jenkins

# Check Nginx (for Allure)
sudo systemctl status nginx

# Test local accessibility
curl http://localhost:8080  # Jenkins
curl http://localhost:5601  # Kibana
curl http://localhost:9200  # Elasticsearch
curl http://localhost:9080  # Allure Reports
curl http://localhost:8001/health  # Mock SA
curl http://localhost:8002/health  # Mock SG
curl http://localhost:8003/health  # Mock DUT
```

**Checklist:**
- [ ] 5 Docker containers running (Elasticsearch, Kibana, 3x Mock Equipment)
- [ ] Jenkins service active
- [ ] Nginx service active
- [ ] All localhost URLs responding

### Step 6: Test Public Accessibility

From your **local machine**:

```bash
# Run accessibility test
bash scripts/check_aws_accessibility.sh
```

This should show all 8 services as accessible.

**Expected Results:**
- [x] SSH (Port 22) - ✓ ACCESSIBLE
- [x] Jenkins (Port 8080) - ✓ ACCESSIBLE
- [x] Kibana (Port 5601) - ✓ ACCESSIBLE
- [x] Elasticsearch (Port 9200) - ✓ ACCESSIBLE
- [x] **Allure Reports (Port 9080)** - ✓ ACCESSIBLE
- [x] Mock SA (Port 8001) - ✓ ACCESSIBLE
- [x] Mock SG (Port 8002) - ✓ ACCESSIBLE
- [x] Mock DUT (Port 8003) - ✓ ACCESSIBLE

**Checklist:**
- [ ] All 8 services accessible from public internet
- [ ] Can open Jenkins in browser
- [ ] Can open Kibana in browser
- [ ] Can open Allure Reports in browser

### Step 7: Configure Jenkins

1. **Open Jenkins:** http://51.84.240.159:8080

2. **Get Initial Password:**
   ```bash
   # On AWS instance
   cat ~/Fully_Product_Automation/jenkins_initial_password.txt
   ```

3. **Complete Setup Wizard:**
   - [ ] Enter admin password
   - [ ] Install suggested plugins
   - [ ] Create admin user
   - [ ] Configure instance URL: `http://51.84.240.159:8080`

4. **Verify RF-Automation-Integration Job:**
   - [ ] Job appears in Jenkins dashboard
   - [ ] Can click "Build with Parameters"

### Step 8: Run First Test

1. **In Jenkins:**
   - Navigate to "RF-Automation-Integration" job
   - Click "Build with Parameters"
   - Configure:
     - Test Suite: PoPo Only (quick test)
     - RF Physics: Enabled
     - Upload to Elasticsearch: Checked
     - Generate Allure Report: Checked
   - Click "Build"

2. **Monitor Execution:**
   - [ ] Build starts successfully
   - [ ] Console output shows test execution
   - [ ] Build completes (pass or fail is OK for first run)

3. **Verify Allure Report:**
   - [ ] "Allure Report" link appears in Jenkins build
   - [ ] Can click and view Allure report in Jenkins
   - [ ] Public Allure available at: http://51.84.240.159:9080

**Checklist:**
- [ ] First test completed
- [ ] Allure report generated
- [ ] Allure report accessible via Jenkins
- [ ] Allure report accessible via public URL (port 9080)

### Step 9: Verify Allure Report Accessibility

Test Allure Reports from multiple locations:

1. **Via Jenkins Plugin:**
   - Jenkins → Build → "Allure Report" link
   - [ ] Opens Allure report successfully

2. **Via Public URL:**
   - http://51.84.240.159:9080
   - [ ] Opens Allure report successfully
   - [ ] Can navigate through test results
   - [ ] Graphs and charts display correctly

3. **Via SSH Tunnel (optional, for secure access):**
   ```bash
   # From local machine
   ssh -i your-key.pem -L 9080:localhost:9080 ubuntu@51.84.240.159
   # Then access: http://localhost:9080
   ```
   - [ ] Accessible via SSH tunnel

### Step 10: Verify Elasticsearch & Kibana

1. **Elasticsearch:**
   - http://51.84.240.159:9200
   - [ ] Shows cluster information
   - [ ] Can query: `curl http://51.84.240.159:9200/rf-automation-*/_search?pretty`
   - [ ] Test results appear in index

2. **Kibana:**
   - http://51.84.240.159:5601
   - [ ] Dashboard loads
   - [ ] Can see rf-automation-* indices
   - [ ] Can visualize test data

### Step 11: Verify Mock Equipment

Test mock equipment admin interfaces:

- http://51.84.240.159:8001 - Mock Spectrum Analyzer
- http://51.84.240.159:8002 - Mock Signal Generator
- http://51.84.240.159:8003 - Mock DUT

**For each:**
- [ ] Admin interface loads
- [ ] Health check responds: `/health` endpoint
- [ ] Can view equipment status
- [ ] Can see simulation parameters

## ✅ Post-Deployment Verification

### Complete Service URLs

All services accessible at `http://51.84.240.159:<PORT>`:

| Service | Port | URL | Status |
|---------|------|-----|--------|
| Jenkins | 8080 | http://51.84.240.159:8080 | [ ] |
| Kibana | 5601 | http://51.84.240.159:5601 | [ ] |
| Elasticsearch | 9200 | http://51.84.240.159:9200 | [ ] |
| **Allure Reports** | **9080** | **http://51.84.240.159:9080** | [ ] |
| Mock SA Admin | 8001 | http://51.84.240.159:8001 | [ ] |
| Mock SG Admin | 8002 | http://51.84.240.159:8002 | [ ] |
| Mock DUT Admin | 8003 | http://51.84.240.159:8003 | [ ] |

### Configuration Files

Verify these files exist:

- [ ] `/etc/rf-automation/aws.env` - AWS environment configuration
- [ ] `/etc/nginx/sites-available/allure` - Allure nginx config
- [ ] `~/Fully_Product_Automation/allure-report/` - Allure report directory
- [ ] `~/Fully_Product_Automation/jenkins_initial_password.txt` - Jenkins password

### Service Health

- [ ] All Docker containers healthy
- [ ] Jenkins service active and enabled
- [ ] Nginx service active and enabled
- [ ] No errors in logs:
  ```bash
  docker compose -f ~/Fully_Product_Automation/infra/docker-compose.aws.yml logs
  sudo journalctl -u jenkins -n 50
  sudo journalctl -u nginx -n 50
  ```

## 📊 Allure Report Workflow

### Generating Reports

**Method 1: Via Jenkins (Automatic)**
1. Run any Jenkins build
2. Reports automatically generated
3. Available at both:
   - Jenkins UI: Build → Allure Report
   - Public URL: http://51.84.240.159:9080

**Method 2: Via Command Line**
```bash
# SSH into instance
ssh -i your-key.pem ubuntu@51.84.240.159

# Navigate to project
cd ~/Fully_Product_Automation
source venv/bin/activate

# Run tests
robot --outputdir results \
  --listener allure_robotframework:allure-results \
  tests/integration_popo.robot

# Generate report
allure generate allure-results --clean -o allure-report

# Report now available at: http://51.84.240.159:9080
```

**Checklist:**
- [ ] Understand both report generation methods
- [ ] Can generate reports via Jenkins
- [ ] Can generate reports via CLI
- [ ] Reports accessible via public URL

### Allure Report Features

Verify these features work:

- [ ] Overview page with statistics
- [ ] Suites view with all test cases
- [ ] Trend graphs and charts
- [ ] Timeline visualization
- [ ] Test case details with steps
- [ ] Attachments (logs, screenshots)
- [ ] Historical data across builds

## 🔒 Security Checklist

- [ ] SSH key secure and backed up
- [ ] Consider restricting security group to your IP instead of 0.0.0.0/0
- [ ] Jenkins admin password changed from initial
- [ ] Regular security updates scheduled
- [ ] CloudWatch logging enabled (optional)
- [ ] CloudTrail enabled for audit (optional)

## 💾 Backup Checklist

- [ ] EBS snapshot created for instance
- [ ] Jenkins configuration backed up
- [ ] Elasticsearch data backup strategy in place
- [ ] Allure reports archived (if needed)
- [ ] Configuration files backed up

## 📚 Documentation Access

- [ ] Full deployment guide: `docs/AWS_DEPLOYMENT.md`
- [ ] Quick reference: `docs/AWS_QUICK_REFERENCE.md`
- [ ] Project README: `README.md`
- [ ] Quick reference card: `docs/QUICK_REFERENCE.txt`

## 🎯 Success Criteria

Your deployment is successful when ALL of the following are true:

1. **Services Running:**
   - [ ] 5 Docker containers running
   - [ ] Jenkins active
   - [ ] Nginx active (for Allure)

2. **Public Accessibility:**
   - [ ] All 8 services accessible from internet
   - [ ] Security group properly configured
   - [ ] No connection timeouts

3. **Jenkins Functional:**
   - [ ] Can login to Jenkins
   - [ ] RF-Automation-Integration job exists
   - [ ] Can run builds with parameters

4. **Allure Reports Working:**
   - [ ] Reports generated after test runs
   - [ ] Accessible via Jenkins UI
   - [ ] **Accessible via public URL (http://51.84.240.159:9080)**
   - [ ] Nginx serving reports correctly

5. **Test Execution:**
   - [ ] Can run PoPo tests
   - [ ] Can run functional tests
   - [ ] Results uploaded to Elasticsearch
   - [ ] Results visible in Kibana
   - [ ] Allure reports generated automatically

6. **Mock Equipment:**
   - [ ] All 3 mock devices responding
   - [ ] Health checks pass
   - [ ] Admin interfaces accessible

## 🆘 Troubleshooting

If any step fails, refer to:

1. **Accessibility issues:**
   - Run: `bash scripts/check_aws_accessibility.sh`
   - Check: AWS Security Group configuration
   - Verify: Services running on instance

2. **Service failures:**
   - Check logs: `docker compose logs -f`
   - Restart services: `docker compose restart`
   - Check disk space: `df -h`
   - Check memory: `free -h`

3. **Allure not accessible:**
   - Check nginx: `sudo systemctl status nginx`
   - Check nginx config: `sudo nginx -t`
   - Check firewall: `sudo ufw status`
   - Verify port 9080 in security group

4. **Documentation:**
   - See: `docs/AWS_DEPLOYMENT.md` - Troubleshooting section
   - See: `docs/AWS_QUICK_REFERENCE.md` - Emergency procedures

## 📝 Notes

- **Expected Setup Time:** 30-40 minutes
- **Monthly Cost (m5.large, 24/7):** ~$70/month
- **Cost Savings:** Stop instance when not in use
- **Region:** il-central-1
- **Instance Type:** Can downsize to t3.large if needed

---

**Deployment Date:** ____________
**Completed By:** ____________
**Instance ID:** i-0e14d354d2194366a
**Public IP:** 51.84.240.159
**Allure URL:** http://51.84.240.159:9080

**Status:** [ ] Complete [ ] In Progress [ ] Issues
