# End-to-End Integration Pipeline User Guide

## 🎯 Overview

This guide walks you through using the complete RF Automation Integration Pipeline - from setup to viewing results in Allure and Kibana.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [One-Command Setup](#one-command-setup)
3. [Accessing Jenkins](#accessing-jenkins)
4. [Running Tests via Jenkins UI](#running-tests-via-jenkins-ui)
5. [Viewing Allure Reports](#viewing-allure-reports)
6. [Querying Results in Kibana](#querying-results-in-kibana)
7. [Querying Elasticsearch Directly](#querying-elasticsearch-directly)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Linux system (Ubuntu 22.04+ recommended)
- Minimum 8GB RAM (16GB recommended)
- 20GB free disk space
- Sudo/root access
- Internet connection

## One-Command Setup

Deploy the entire integration environment with a single command:

```bash
git clone <repository-url>
cd Fully_Product_Automation
git checkout integration
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose
```

**Setup Duration:** ~25 minutes

**What Gets Installed:**
- ✅ Docker and Docker Compose
- ✅ Jenkins with required plugins
- ✅ Elasticsearch and Kibana (ELK Stack)
- ✅ Mock RF Equipment (Spectrum Analyzer, Signal Generator, DUT)
- ✅ Python environment with Robot Framework
- ✅ Allure command-line tool
- ✅ Jenkins pipeline job pre-configured
- ✅ Kibana dashboards imported

**After Setup Completes:**

The script will display access information:

```
========================================
Access URLs:
========================================
Jenkins:       http://localhost:8080
Kibana:        http://localhost:5601
Elasticsearch: http://localhost:9200
Mock SA Admin: http://localhost:8001
Mock SG Admin: http://localhost:8002
Mock DUT Admin: http://localhost:8003

Jenkins Initial Admin Password:
<password will be displayed here>
```

**Save the Jenkins admin password** - you'll need it to log in!

---

## Accessing Jenkins

### First-Time Login

1. Open browser and navigate to `http://localhost:8080`

2. **Unlock Jenkins** (first time only):
   - Enter the initial admin password displayed after setup
   - OR retrieve it from: `cat jenkins_initial_password.txt`

3. **Install Suggested Plugins**:
   - Click "Install suggested plugins"
   - Wait for installation to complete (~5 minutes)

4. **Create Admin User**:
   - Fill in your details:
     - Username: `admin` (or your choice)
     - Password: Choose a secure password
     - Full Name: Your name
     - Email: Your email
   - Click "Save and Continue"

5. **Instance Configuration**:
   - Keep default Jenkins URL: `http://localhost:8080`
   - Click "Save and Finish"

6. **Start Using Jenkins**:
   - Click "Start using Jenkins"

### Locating Your Pipeline Job

After login, you should see the pre-configured job:

**Job Name:** `RF-Automation-Integration`

If you don't see it, navigate to:
- Dashboard → New Item → Enter "RF-Automation-Integration"
- Or manually create it using the instructions in the troubleshooting section

---

## Running Tests via Jenkins UI

### Step 1: Navigate to the Job

1. From Jenkins Dashboard, click **RF-Automation-Integration**
2. Click **Build with Parameters** (left sidebar)

### Step 2: Configure Test Parameters

You'll see a parameters form with the following options:

#### **TEST_SUITE** (dropdown)
Select which tests to run:
- **All Tests** - Runs both PoPo and Functional tests (recommended for first run)
- **PoPo Tests Only** - Platform validation tests only
- **Functional Tests Only** - RF functional tests only
- **Custom (use tags)** - Use tags to filter tests

#### **TEST_TAGS** (text field)
Enter Robot Framework tags (only used with "Custom" suite):
- Examples: `smoke`, `regression`, `sanity`
- Multiple tags: `smoke critical`

#### **TEST_INCLUDE** (text field)
Test case name patterns to include:
- Example: `*connection*` - runs all tests with "connection" in name
- Example: `*calibration*` - runs calibration tests

#### **TEST_EXCLUDE** (text field)
Test case name patterns to exclude:
- Example: `*slow*` - skips slow tests

#### **ENABLE_RF_PHYSICS** (checkbox, default: checked)
Enable realistic RF physics simulation:
- Harmonics generation
- Intermodulation products
- Phase noise
- Recommended: Keep enabled for realistic testing

#### **NOISE_FLOOR_DBM** (dropdown, default: -120)
Simulated noise floor level:
- `-120` - Very low noise (ideal conditions)
- `-110` - Low noise
- `-100` - Moderate noise
- `-90` - High noise (challenging conditions)

#### **UPLOAD_TO_ELASTICSEARCH** (checkbox, default: checked)
Upload test results to Elasticsearch for Kibana visualization.
- Keep checked to view results in Kibana

#### **GENERATE_ALLURE_REPORT** (checkbox, default: checked)
Generate interactive Allure test report.
- Keep checked to view detailed test reports

### Step 3: Start the Build

1. Review your parameters
2. Click **Build** button at the bottom
3. Watch the build execute in real-time

### Step 4: Monitor Progress

**Build Queue:**
- Your build appears in "Build Queue" (left sidebar)
- Once started, it moves to "Build Executor Status"

**Console Output:**
- Click the build number (e.g., #1)
- Click **Console Output** to see live logs
- Watch for:
  ```
  ========================================
  RF Automation - Integration Pipeline
  ========================================
  Build: 1
  Branch: integration
  Test Suite: All Tests
  Mock Equipment: true
  RF Physics: true
  Noise Floor: -120 dBm
  ========================================
  ```

**Build Stages:**
You'll see these stages execute:
1. Environment Setup
2. Python Environment
3. Infrastructure Check
4. PoPo Tests (if selected)
5. Functional Tests (if selected)
6. Generate Allure Report
7. Upload to Elasticsearch

**Expected Duration:**
- PoPo Tests Only: ~3-5 minutes
- Functional Tests Only: ~10-15 minutes
- All Tests: ~15-20 minutes

---

## Viewing Allure Reports

### Accessing the Report

**Option 1: Via Jenkins (Recommended)**

1. After build completes, return to the build page
2. Click **Allure Report** in the left sidebar
3. Interactive report opens in new tab

**Option 2: Standalone**

```bash
cd /path/to/Fully_Product_Automation
allure open allure-report
```

### Navigating the Allure Report

#### **Overview Tab**
- **Test Statistics:**
  - Total tests executed
  - Pass/Fail/Skip counts
  - Pass rate percentage
  - Total duration

- **Environment Info:**
  - Build number
  - Test environment
  - Mock equipment status

- **Trend Charts:**
  - Historical pass/fail trends
  - Duration trends over time

#### **Suites Tab**
- Hierarchical view of test suites
- Expand to see individual test cases
- Click test case for detailed view:
  - Test steps
  - Parameters
  - Timing information
  - Screenshots (if captured)
  - Logs and attachments

#### **Graphs Tab**
- **Status Chart:** Visual pass/fail distribution
- **Severity Chart:** Tests by severity level
- **Duration Chart:** Test execution time breakdown
- **Categories:** Failure categorization (network, SCPI, measurements)

#### **Timeline Tab**
- Gantt chart showing test execution timeline
- Visualize parallel execution
- Identify bottlenecks

#### **Behaviors Tab**
- BDD-style organization
- Tests grouped by feature/story

#### **Packages Tab**
- Tests organized by package structure

### Understanding Test Results

**Green (Passed):**
- Test executed successfully
- All assertions passed
- Expected behavior verified

**Red (Failed):**
- Test failed due to assertion error
- Equipment communication error
- Unexpected behavior
- Click test to see failure details and stack trace

**Yellow (Skipped):**
- Test was not executed
- Prerequisites not met
- Intentionally skipped

**Purple (Broken):**
- Test could not complete
- Infrastructure issue
- Configuration problem

---

## Querying Results in Kibana

### Accessing Kibana

1. Open browser: `http://localhost:5601`
2. Wait for Kibana to load (~30 seconds on first access)

### First-Time Setup

**Create Index Pattern:**

1. Click **☰ Menu** (top-left) → **Stack Management**
2. Under **Kibana**, click **Index Patterns**
3. Click **Create index pattern**
4. Index pattern name: `rf-automation-*`
5. Click **Next step**
6. Time field: `@timestamp`
7. Click **Create index pattern**

### Viewing the Pre-Configured Dashboard

1. Click **☰ Menu** → **Dashboard**
2. Click **RF Automation - Test Results Overview**

**Dashboard Components:**

1. **Test Status Distribution (Pie Chart)**
   - Visual breakdown of pass/fail/skip status
   - Hover for percentages

2. **Test Execution Timeline (Line Chart)**
   - Tests executed over time
   - Color-coded by status
   - Zoom in/out on time range

3. **Build Statistics (Metrics)**
   - Total test count
   - Average duration
   - Average pass rate

4. **Test Duration by Suite (Bar Chart)**
   - Average duration per test suite
   - Identify slow test suites

5. **Tests by Equipment Type (Pie Chart)**
   - Distribution across Spectrum Analyzer, Signal Generator, DUT

### Creating Custom Queries

**Discover Tab:**

1. Click **☰ Menu** → **Discover**
2. Select index pattern: `rf-automation-*`
3. Time range: Last 7 days (or custom)

**Example Queries:**

Find failed tests:
```
status: "FAIL"
```

Find tests from specific build:
```
build_number: "1"
```

Find spectrum analyzer tests:
```
equipment_type: "spectrum_analyzer"
```

Find tests with high duration:
```
duration_ms > 5000
```

Complex query - failed tests on spectrum analyzer:
```
status: "FAIL" AND equipment_type: "spectrum_analyzer"
```

### Creating Custom Visualizations

1. Click **☰ Menu** → **Visualize Library**
2. Click **Create visualization**
3. Select visualization type (bar, line, pie, etc.)
4. Choose index pattern: `rf-automation-*`
5. Configure metrics and buckets
6. Click **Save**

**Example: Pass Rate by Build**

1. Visualization type: **Line**
2. Metrics:
   - Y-axis: Average → `pass_rate`
3. Buckets:
   - X-axis: Terms → `build_number`
4. Save as "Pass Rate Trend"

---

## Querying Elasticsearch Directly

### Using curl

**Get cluster health:**
```bash
curl http://localhost:9200/_cluster/health?pretty
```

**List indices:**
```bash
curl http://localhost:9200/_cat/indices?v
```

**Search all test results:**
```bash
curl -X GET "http://localhost:9200/rf-automation-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '
{
  "query": {
    "match_all": {}
  },
  "size": 10
}
'
```

**Get results from specific build:**
```bash
curl -X GET "http://localhost:9200/rf-automation-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '
{
  "query": {
    "term": {
      "build_number": "1"
    }
  }
}
'
```

**Count failed tests:**
```bash
curl -X GET "http://localhost:9200/rf-automation-*/_count?pretty" \
  -H 'Content-Type: application/json' \
  -d '
{
  "query": {
    "term": {
      "status": "FAIL"
    }
  }
}
'
```

**Aggregate pass rate by test suite:**
```bash
curl -X GET "http://localhost:9200/rf-automation-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '
{
  "size": 0,
  "aggs": {
    "by_suite": {
      "terms": {
        "field": "test_suite"
      },
      "aggs": {
        "avg_pass_rate": {
          "avg": {
            "field": "pass_rate"
          }
        }
      }
    }
  }
}
'
```

---

## Troubleshooting

### Jenkins Issues

**Issue: Cannot access Jenkins at http://localhost:8080**

Check if Jenkins is running:
```bash
sudo systemctl status jenkins
```

If not running:
```bash
sudo systemctl start jenkins
```

View Jenkins logs:
```bash
sudo journalctl -u jenkins -f
```

**Issue: Job "RF-Automation-Integration" not found**

Manually create the job:

1. Jenkins Dashboard → **New Item**
2. Item name: `RF-Automation-Integration`
3. Type: **Pipeline**
4. Click **OK**
5. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `/path/to/Fully_Product_Automation` (full path)
   - Branch: `*/integration`
   - Script Path: `Jenkinsfile.integration`
6. Under **This project is parameterized**, add parameters (see Jenkinsfile.integration for parameter definitions)
7. Click **Save**

**Issue: Build fails with "Permission denied" on Docker**

Add Jenkins user to docker group:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Infrastructure Issues

**Issue: Mock equipment not responding**

Check containers:
```bash
docker ps -a | grep mock
```

Restart mock equipment:
```bash
cd infra
docker compose -f docker-compose.integration.yml restart mock-spectrum-analyzer mock-signal-generator mock-dut
```

**Issue: Elasticsearch not starting**

Check memory:
```bash
free -h
```

Increase vm.max_map_count:
```bash
sudo sysctl -w vm.max_map_count=262144
```

Make permanent:
```bash
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

Restart Elasticsearch:
```bash
cd infra
docker compose -f docker-compose.integration.yml restart elasticsearch
```

**Issue: Kibana not accessible**

Check Kibana logs:
```bash
docker logs rf-kibana
```

Wait for Kibana to finish initialization (can take 2-3 minutes)

### Test Execution Issues

**Issue: Tests fail with "Equipment not reachable"**

Verify mock equipment health:
```bash
curl http://localhost:8001/health  # Spectrum Analyzer
curl http://localhost:8002/health  # Signal Generator
curl http://localhost:8003/health  # DUT
```

All should return:
```json
{
  "status": "healthy",
  "equipment_type": "...",
  "scpi_port": ...
}
```

**Issue: No results in Elasticsearch**

1. Check if Elasticsearch is healthy:
   ```bash
   curl http://localhost:9200/_cluster/health
   ```

2. Verify listener was enabled:
   - Check build parameters: `UPLOAD_TO_ELASTICSEARCH` should be checked
   - Check console output for Elasticsearch upload messages

3. Manual upload (if needed):
   ```bash
   cd /path/to/Fully_Product_Automation
   source venv/bin/activate
   python scripts/upload_to_elastic.py results/output.xml
   ```

**Issue: Allure report not generated**

1. Check if allure-results directory has content:
   ```bash
   ls -la allure-results/
   ```

2. Generate manually:
   ```bash
   cd /path/to/Fully_Product_Automation
   allure generate allure-results --clean -o allure-report
   allure open allure-report
   ```

### Getting Help

**View all service statuses:**
```bash
# Jenkins
sudo systemctl status jenkins

# Docker containers
docker ps -a

# Mock equipment health
for port in 8001 8002 8003; do
  echo "Port $port:"
  curl -s http://localhost:$port/health | jq .
done

# Elasticsearch
curl http://localhost:9200/_cluster/health?pretty

# Kibana
curl http://localhost:5601/api/status
```

**Collect logs:**
```bash
# Create debug bundle
mkdir -p debug-logs
sudo journalctl -u jenkins --since "1 hour ago" > debug-logs/jenkins.log
docker compose -f infra/docker-compose.integration.yml logs > debug-logs/docker.log
cp -r allure-results debug-logs/
cp -r results debug-logs/
tar -czf debug-bundle.tar.gz debug-logs/
```

**Reset everything:**
```bash
# Stop all services
cd infra
docker compose -f docker-compose.integration.yml down -v
sudo systemctl stop jenkins

# Clean up
cd ..
rm -rf allure-results allure-report results logs venv

# Re-run setup
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose
```

---

## 🎉 Success Checklist

After completing this guide, you should be able to:

- ✅ Access Jenkins at http://localhost:8080
- ✅ See "RF-Automation-Integration" job in Jenkins
- ✅ Run tests by clicking "Build with Parameters"
- ✅ Select test scope and configure RF simulation parameters
- ✅ View detailed Allure reports with pass/fail statistics
- ✅ Access Kibana at http://localhost:5601
- ✅ View test results in pre-configured dashboard
- ✅ Query Elasticsearch for specific test results
- ✅ Monitor test trends over time

**Congratulations! Your end-to-end RF automation pipeline is fully operational! 🚀**

---

## Next Steps

- Explore test customization with tags and filters
- Create custom Kibana visualizations
- Set up email notifications for build results
- Schedule periodic test runs
- Integrate with version control webhooks
- Export results for external reporting

## Support

For issues or questions:
- Check the troubleshooting section above
- Review container logs
- Consult project documentation in `docs/`
- Contact the automation team

---

**Document Version:** 1.0
**Last Updated:** 2026-03-01
**Maintained By:** Automation Team
