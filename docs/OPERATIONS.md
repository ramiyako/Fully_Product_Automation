# Operations Manual - RF Automation Infrastructure

Day-to-day operations, monitoring, maintenance, and troubleshooting guide.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Monitoring](#monitoring)
3. [Maintenance](#maintenance)
4. [Backup and Recovery](#backup-and-recovery)
5. [Troubleshooting](#troubleshooting)
6. [Emergency Procedures](#emergency-procedures)
7. [Performance Tuning](#performance-tuning)

---

## Daily Operations

### Running Tests

#### Via Jenkins (Recommended)

1. Open Jenkins: `http://<nuc-ip>:8080`
2. Navigate to `RF-Automation-Pipeline`
3. Click **"Build with Parameters"**
4. Select options:
   - Test Suite: `all`, `rf_functional`, or `calibration`
   - Log Level: `INFO`, `DEBUG`, or `TRACE`
   - Skip Docker Build: Check if using cached image
5. Click **"Build"**
6. Monitor progress in console output
7. View results in:
   - Jenkins artifacts (HTML reports)
   - Kibana dashboards

#### Via Command Line (Manual)

```bash
# SSH to NUC
ssh automation@<nuc-ip>

# Navigate to project
cd ~/Fully_Product_Automation

# Pull latest code
git pull origin main

# Build Docker image
docker build -t rf-test-runner .

# Run tests
docker run --rm --network host \
    -v $(pwd)/results:/app/results \
    rf-test-runner --outputdir results tests/

# View results
firefox results/report.html &
```

### Scheduled Execution

Tests can run on schedule via Jenkins:

**Configure Cron Trigger**:

1. Jenkins → RF-Automation-Pipeline → Configure
2. Build Triggers → Build periodically
3. Schedule (cron syntax):

```
# Every day at 3 AM
0 3 * * *

# Every weekday at 6 AM
0 6 * * 1-5

# Every 4 hours
0 */4 * * *
```

---

## Monitoring

### System Health Checks

#### Quick Health Check Script

```bash
#!/bin/bash
# health_check.sh

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
curl -s http://localhost:9200/_cluster/health | jq '.status'

echo ""
echo "--- Kibana ---"
curl -s http://localhost:5601/api/status | jq '.status.overall.state'

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
ping -c 1 -W 1 192.168.50.10 >/dev/null 2>&1 && echo "Spectrum Analyzer: OK" || echo "Spectrum Analyzer: UNREACHABLE"
ping -c 1 -W 1 192.168.50.11 >/dev/null 2>&1 && echo "Signal Generator: OK" || echo "Signal Generator: UNREACHABLE"
ping -c 1 -W 1 192.168.50.20 >/dev/null 2>&1 && echo "DUT: OK" || echo "DUT: UNREACHABLE"

echo ""
echo "=== Health Check Complete ==="
```

Save and run:

```bash
chmod +x health_check.sh
./health_check.sh
```

#### Automated Monitoring

**Add to crontab**:

```bash
# Run health check every hour and email if failures
0 * * * * /home/automation/health_check.sh | grep -i "FAILED\|UNREACHABLE" && \
    mail -s "RF Automation Health Check Alert" admin@company.com
```

### Monitoring Dashboards

#### Kibana Dashboards

Access: `http://<nuc-ip>:5601`

**Key Dashboards**:

1. **Test Execution Overview**
   - Total tests run (today/week/month)
   - Pass rate trend
   - Failed test summary

2. **Equipment Availability**
   - Equipment uptime percentage
   - Connection failures
   - Timeout incidents

3. **Performance Metrics**
   - Average test duration
   - Longest running tests
   - Test execution frequency

**Creating Dashboard**:

1. Kibana → Dashboard → Create new dashboard
2. Add visualizations:
   - Line chart: Test pass rate over time
   - Pie chart: Test status distribution
   - Data table: Recent failed tests
3. Save dashboard

#### System Metrics

**Monitor with htop**:

```bash
# Install htop if not present
sudo apt install htop

# Run
htop
```

Watch:
- CPU usage (should be <80% normally)
- Memory usage (Elasticsearch typically uses 4-6GB)
- Load average

**Monitor with Docker stats**:

```bash
docker stats
```

### Log Monitoring

#### Jenkins Logs

```bash
# Real-time Jenkins logs
sudo journalctl -u jenkins -f

# Recent errors
sudo journalctl -u jenkins --since "1 hour ago" | grep -i error
```

#### Docker Container Logs

```bash
# Elasticsearch logs
docker logs -f elasticsearch

# Kibana logs
docker logs -f kibana

# Follow last 100 lines
docker logs --tail 100 -f elasticsearch
```

#### Application Logs

```bash
# Test execution logs
tail -f logs/test_execution.log

# Upload script logs
tail -f logs/upload_to_elastic.log
```

---

## Maintenance

### Weekly Maintenance

**Every Monday Morning**:

```bash
#!/bin/bash
# weekly_maintenance.sh

echo "=== Weekly Maintenance - $(date) ==="

# Update system packages
sudo apt update
sudo apt upgrade -y

# Clean up old Docker images/containers
docker system prune -f --volumes

# Check Elasticsearch index size
curl -s http://localhost:9200/_cat/indices?v

# Backup configuration
tar -czf /backup/config_$(date +%Y%m%d).tar.gz \
    ~/Fully_Product_Automation/resources/network_vars.py \
    ~/Fully_Product_Automation/infra/docker-compose.yml

# Check disk usage
df -h

# Restart services (if needed)
# sudo systemctl restart jenkins
# docker compose -f ~/Fully_Product_Automation/infra/docker-compose.yml restart

echo "=== Maintenance Complete ==="
```

### Monthly Maintenance

**First Monday of Month**:

1. **Review Test Results**
   - Analyze failure trends
   - Identify flaky tests
   - Update test thresholds if needed

2. **Update Dependencies**
   ```bash
   cd ~/Fully_Product_Automation

   # Update Python packages
   pip install --upgrade -r requirements.txt

   # Rebuild Docker image
   docker build -t rf-test-runner .
   ```

3. **Review Elasticsearch Indices**
   ```bash
   # List indices
   curl http://localhost:9200/_cat/indices?v

   # Delete old indices (older than 6 months)
   # Example: Delete indices from 2025.08
   curl -X DELETE http://localhost:9200/rf-automation-*-2025.08
   ```

4. **Equipment Calibration**
   - Run calibration test suite
   - Compare with previous calibration
   - Update calibration certificates

### Quarterly Maintenance

**Every 3 Months**:

1. **Security Updates**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   sudo reboot
   ```

2. **Docker Image Updates**
   ```bash
   # Update base images
   docker pull python:3.11-slim
   docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0
   docker pull docker.elastic.co/kibana/kibana:8.12.0

   # Rebuild
   docker compose -f ~/Fully_Product_Automation/infra/docker-compose.yml pull
   docker compose -f ~/Fully_Product_Automation/infra/docker-compose.yml up -d
   ```

3. **Full System Backup** (see Backup section)

4. **Performance Review**
   - Analyze test execution times
   - Review resource utilization
   - Optimize if needed

---

## Backup and Recovery

### What to Backup

1. **Elasticsearch Data** (Test results)
2. **Jenkins Configuration** (Jobs, credentials)
3. **Project Repository** (Git - already backed up)
4. **Equipment Configuration** (IP addresses, settings)

### Elasticsearch Backup

**Manual Snapshot**:

```bash
# Create snapshot repository
curl -X PUT "localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backup"
  }
}'

# Create snapshot
curl -X PUT "localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)" -H 'Content-Type: application/json' -d'
{
  "indices": "rf-automation-*",
  "include_global_state": false
}'

# List snapshots
curl -X GET "localhost:9200/_snapshot/backup_repo/_all"
```

**Automated Daily Backup**:

```bash
# Add to crontab
0 2 * * * curl -X PUT "localhost:9200/_snapshot/backup_repo/snapshot_$(date +\%Y\%m\%d)"
```

**Restore from Snapshot**:

```bash
# Close indices
curl -X POST "localhost:9200/rf-automation-*/_close"

# Restore
curl -X POST "localhost:9200/_snapshot/backup_repo/snapshot_20260223/_restore"

# Reopen indices
curl -X POST "localhost:9200/rf-automation-*/_open"
```

### Jenkins Backup

```bash
# Backup Jenkins home
sudo tar -czf /backup/jenkins_$(date +%Y%m%d).tar.gz \
    /var/lib/jenkins/

# Restore
sudo systemctl stop jenkins
sudo tar -xzf /backup/jenkins_20260223.tar.gz -C /
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo systemctl start jenkins
```

### Configuration Backup

```bash
# Backup project configuration
cd ~/Fully_Product_Automation
git add -A
git commit -m "Backup configuration - $(date +%Y-%m-%d)"
git push origin main

# Additional backup to external location
tar -czf /backup/rf_automation_config_$(date +%Y%m%d).tar.gz \
    ~/Fully_Product_Automation/
```

---

## Troubleshooting

### Common Issues

#### Issue: Tests Failing to Connect to Equipment

**Symptoms**:
- Connection timeout errors
- "Equipment not reachable" messages

**Diagnosis**:
```bash
# Check network connectivity
ping 192.168.50.10
ping 192.168.50.11

# Check routing
ip route show

# Verify VLAN interface
ip addr show
```

**Solutions**:
1. Check equipment power
2. Verify network cables
3. Check VLAN configuration
4. Restart network interface:
   ```bash
   sudo ip link set eth1 down
   sudo ip link set eth1 up
   ```

#### Issue: Elasticsearch Not Starting

**Symptoms**:
- Container repeatedly restarting
- "Out of memory" errors

**Diagnosis**:
```bash
docker logs elasticsearch

# Check memory
free -h

# Check vm.max_map_count
sysctl vm.max_map_count
```

**Solutions**:
1. Increase vm.max_map_count:
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   ```

2. Reduce Elasticsearch heap size (if low memory):
   Edit `infra/docker-compose.yml`:
   ```yaml
   environment:
     - "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # Reduce from 2g
   ```

3. Restart:
   ```bash
   docker compose -f infra/docker-compose.yml restart elasticsearch
   ```

#### Issue: Jenkins Build Hangs

**Symptoms**:
- Build stuck in progress
- No console output

**Diagnosis**:
```bash
# Check Jenkins processes
ps aux | grep jenkins

# Check Docker processes
docker ps

# Check system load
uptime
```

**Solutions**:
1. Kill stuck build (Jenkins UI → Build → Stop)
2. Restart Jenkins:
   ```bash
   sudo systemctl restart jenkins
   ```
3. Clean Docker:
   ```bash
   docker system prune -f
   ```

#### Issue: High Disk Usage

**Diagnosis**:
```bash
# Check disk usage
df -h

# Find large directories
du -sh /* | sort -hr | head -10

# Check Docker disk usage
docker system df
```

**Solutions**:
1. Clean Docker:
   ```bash
   docker system prune -af --volumes
   ```

2. Delete old Elasticsearch indices:
   ```bash
   curl -X DELETE "localhost:9200/rf-automation-*-2025.*"
   ```

3. Clean Jenkins builds:
   - Jenkins → Manage Jenkins → Disk Usage
   - Reduce "Days to keep builds"

4. Rotate logs:
   ```bash
   sudo journalctl --vacuum-time=30d
   ```

---

## Emergency Procedures

### Complete System Failure

**Recovery Steps**:

1. **Assess Situation**
   ```bash
   # Check system is responsive
   ping <nuc-ip>

   # SSH access
   ssh automation@<nuc-ip>

   # Check system load
   uptime
   top
   ```

2. **Restart Services**
   ```bash
   # Restart Docker
   sudo systemctl restart docker

   # Restart ELK Stack
   cd ~/Fully_Product_Automation/infra
   docker compose down
   docker compose up -d

   # Restart Jenkins
   sudo systemctl restart jenkins
   ```

3. **Verify Restoration**
   - Access Jenkins: http://<nuc-ip>:8080
   - Access Kibana: http://<nuc-ip>:5601
   - Run health check script

4. **Full System Reboot** (if above fails)
   ```bash
   sudo reboot
   ```

### Data Loss Recovery

If Elasticsearch data is lost:

1. **Restore from Snapshot** (see Backup section)
2. **Re-run Recent Tests** to regenerate data
3. **Update Documentation** with what was lost

### Equipment Connectivity Loss

If equipment becomes unreachable:

1. **Physical Check**
   - Verify equipment power
   - Check network cables
   - Verify switch port status

2. **Network Troubleshooting**
   ```bash
   # Check interface status
   ip link show eth1

   # Restart interface
   sudo ip link set eth1 down
   sudo ip link set eth1 up

   # Verify VLAN
   ip addr show eth1
   ```

3. **Contact Equipment Support** if hardware issue suspected

---

## Performance Tuning

### Elasticsearch Optimization

**For Large Result Sets**:

Edit `infra/docker-compose.yml`:

```yaml
environment:
  - "ES_JAVA_OPTS=-Xms4g -Xmx4g"  # Increase heap
  - indices.memory.index_buffer_size=30%
```

### Jenkins Optimization

**Increase Memory**:

```bash
sudo vim /etc/default/jenkins
```

Add:
```bash
JAVA_ARGS="-Xms2g -Xmx4g"
```

Restart:
```bash
sudo systemctl restart jenkins
```

### Docker Optimization

**Enable Experimental Features**:

```bash
sudo vim /etc/docker/daemon.json
```

```json
{
  "experimental": true,
  "metrics-addr": "127.0.0.1:9323"
}
```

---

**Operations Guide Version**: 1.0
**Last Updated**: 2026-02-23
**Contact**: automation-team@company.com
