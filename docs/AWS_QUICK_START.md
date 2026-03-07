# Complete AWS Deployment Guide - Quick Commands

**Instance:** i-0e14d354d2194366a
**Public IP:** 51.84.240.159
**Region:** il-central-1

## 🎯 Complete Deployment (One Script Does It All!)

### SSH into your AWS instance:
```bash
ssh -i your-key.pem ubuntu@51.84.240.159
```

### Run the complete deployment script:
```bash
# This single script does EVERYTHING including Allure setup
sudo bash scripts/deploy_to_aws.sh
```

**What this script does:**
✅ Clones repository
✅ Runs AWS setup (Docker, Jenkins, all services)
✅ **Installs nginx for Allure on port 9080**
✅ Configures all services
✅ Generates initial Allure report
✅ Runs health checks
✅ Opens firewall for Allure (port 9080)

**Duration:** 30-40 minutes

---

## 🔐 Configure AWS Security Group

### IMPORTANT: Add These Ports to Your Security Group

Go to AWS Console → EC2 → Security Groups → Edit Inbound Rules:

| Port | Service |
|------|---------|
| 22 | SSH |
| 8080 | Jenkins |
| 5601 | Kibana |
| 9200 | Elasticsearch |
| **9080** | **Allure Reports (nginx)** |
| 8001 | Mock SA Admin |
| 8002 | Mock SG Admin |
| 8003 | Mock DUT Admin |

### Or use automated script (from local machine):
```bash
bash scripts/configure_aws_security_group.sh \
  --group-name=<YOUR_SG_NAME> \
  --allowed-ip=0.0.0.0/0
```

---

## ✅ Verify Deployment

### From your local machine:
```bash
# Test all service accessibility
bash scripts/check_aws_accessibility.sh
```

**Expected result:** All 8 services accessible (including Allure on port 9080)

---

## 🌐 Access All Services

Once deployment is complete and security group is configured:

### Main Services:
- **Jenkins:** http://51.84.240.159:8080
- **Kibana:** http://51.84.240.159:5601
- **Elasticsearch:** http://51.84.240.159:9200
- **Allure Reports:** http://51.84.240.159:9080 ⭐ **NEW!**

### Mock Equipment Admin:
- **Mock SA:** http://51.84.240.159:8001
- **Mock SG:** http://51.84.240.159:8002
- **Mock DUT:** http://51.84.240.159:8003

---

## 📊 Allure Reports

### Access Allure Reports (3 Ways):

**1. Public URL (Fastest):**
```
http://51.84.240.159:9080
```

**2. Via Jenkins:**
- Run any build → Click "Allure Report" link

**3. Via SSH Tunnel (Secure):**
```bash
ssh -i your-key.pem -L 9080:localhost:9080 ubuntu@51.84.240.159
# Then open: http://localhost:9080
```

### Generate New Allure Reports:

**Automatic (via Jenkins):**
- Just run any Jenkins build
- Reports automatically generated and published

**Manual (via CLI):**
```bash
ssh -i your-key.pem ubuntu@51.84.240.159

cd ~/Fully_Product_Automation
source venv/bin/activate

# Run tests
robot --outputdir results \
  --listener allure_robotframework:allure-results \
  tests/integration_popo.robot

# Generate report
allure generate allure-results --clean -o allure-report

# Now accessible at http://51.84.240.159:9080
```

---

## 🔍 Health Checks

### SSH into instance and check:

```bash
# All Docker containers
docker ps

# Should see 5 containers:
# - rf-elasticsearch
# - rf-kibana
# - mock-sa
# - mock-sg
# - mock-dut

# Jenkins status
sudo systemctl status jenkins

# Nginx status (for Allure)
sudo systemctl status nginx

# Test localhost
curl http://localhost:8080  # Jenkins
curl http://localhost:5601  # Kibana
curl http://localhost:9200  # Elasticsearch
curl http://localhost:9080  # Allure Reports
curl http://localhost:8001/health  # Mock SA
curl http://localhost:8002/health  # Mock SG
curl http://localhost:8003/health  # Mock DUT
```

---

## 🎛️ Jenkins Setup

### First time login:

1. Open: http://51.84.240.159:8080

2. Get password:
```bash
ssh -i your-key.pem ubuntu@51.84.240.159
cat ~/Fully_Product_Automation/jenkins_initial_password.txt
```

3. Complete wizard:
   - Install suggested plugins
   - Create admin user
   - Save & continue

4. Run first test:
   - Job: "RF-Automation-Integration"
   - Click "Build with Parameters"
   - Select test suite and options
   - Build!

---

## 🚨 Troubleshooting

### Services not accessible?

```bash
# 1. Check security group in AWS Console
# Make sure ALL ports are open (especially 9080 for Allure)

# 2. SSH in and check services
ssh -i your-key.pem ubuntu@51.84.240.159

# 3. Check Docker
docker ps

# 4. Check nginx
sudo systemctl status nginx

# 5. Check firewall
sudo ufw status

# 6. Restart if needed
cd ~/Fully_Product_Automation/infra
docker compose -f docker-compose.aws.yml restart
sudo systemctl restart jenkins
sudo systemctl restart nginx
```

### Allure reports not showing?

```bash
# Check nginx configuration
sudo nginx -t

# Check nginx is running
sudo systemctl status nginx

# Check report directory exists
ls -la ~/Fully_Product_Automation/allure-report/

# Regenerate report
cd ~/Fully_Product_Automation
source venv/bin/activate
allure generate allure-results --clean -o allure-report

# Restart nginx
sudo systemctl restart nginx
```

---

## 📚 Documentation

- **Complete Guide:** docs/AWS_DEPLOYMENT.md
- **Checklist:** docs/AWS_DEPLOYMENT_CHECKLIST.md
- **Quick Reference:** docs/AWS_QUICK_REFERENCE.md
- **General Guide:** docs/QUICK_REFERENCE.txt

---

## ✅ Deployment Success Checklist

- [ ] SSH into AWS instance successful
- [ ] `deploy_to_aws.sh` completed without errors
- [ ] Security group configured with all 8 ports
- [ ] All services accessible from browser:
  - [ ] Jenkins (8080)
  - [ ] Kibana (5601)
  - [ ] Elasticsearch (9200)
  - [ ] **Allure Reports (9080)** ⭐
  - [ ] Mock SA (8001)
  - [ ] Mock SG (8002)
  - [ ] Mock DUT (8003)
- [ ] Jenkins setup completed
- [ ] First test run successful
- [ ] Allure report generated and accessible

---

## 💡 Key Points

1. **One Script Deployment:** `deploy_to_aws.sh` handles everything
2. **Allure on Port 9080:** Served via nginx, publicly accessible
3. **Security Group:** Must configure 8 ports in AWS console
4. **Verify Everything:** Use `check_aws_accessibility.sh`
5. **Allure Access:** Via Jenkins OR public URL (http://51.84.240.159:9080)

---

## 🎉 You're Ready!

Your AWS RF Automation environment includes:
- ✅ Jenkins CI/CD with Allure plugin
- ✅ Elasticsearch + Kibana for analytics
- ✅ **Allure Reports publicly accessible on port 9080**
- ✅ Mock RF equipment with physics simulation
- ✅ Complete test automation pipeline

**Start testing now:** http://51.84.240.159:8080

**View Allure reports:** http://51.84.240.159:9080

---

**Need Help?**
- Check `docs/AWS_DEPLOYMENT_CHECKLIST.md` for step-by-step guide
- Run `scripts/check_aws_accessibility.sh` to diagnose issues
- All services should be accessible after security group configuration
