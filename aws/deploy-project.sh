#!/bin/bash
set -euo pipefail

# ============================================================================
# Deploy RF Automation project to the AWS EC2 instance
# Run this AFTER provision-aws.sh has completed
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONN_FILE="$SCRIPT_DIR/connection-info.txt"

if [ ! -f "$CONN_FILE" ]; then
  echo "ERROR: connection-info.txt not found. Run provision-aws.sh first."
  exit 1
fi

PUBLIC_IP=$(grep "Public IP" "$CONN_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
KEY_FILE=$(grep "Key File" "$CONN_FILE" | awk -F': ' '{print $2}' | tr -d ' ')

if [ -z "$PUBLIC_IP" ] || [ -z "$KEY_FILE" ]; then
  echo "ERROR: Could not parse connection-info.txt"
  exit 1
fi

SSH_CMD="ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP"
SCP_CMD="scp -i $KEY_FILE -o StrictHostKeyChecking=no"

echo "===== Deploying RF Automation to $PUBLIC_IP ====="
echo ""

# Wait for cloud-init to finish
echo "[1/5] Waiting for server setup to complete..."
for i in $(seq 1 30); do
  if $SSH_CMD "test -f /var/log/user-data-setup.log && grep -q 'Bootstrap Complete' /var/log/user-data-setup.log" 2>/dev/null; then
    echo "  Server setup complete!"
    break
  fi
  echo "  Still setting up... (attempt $i/30, waiting 30s)"
  sleep 30
done
echo ""

# Upload project files
echo "[2/5] Uploading project files..."
$SSH_CMD "sudo mkdir -p /opt/rf-automation && sudo chown ubuntu:ubuntu /opt/rf-automation"

rsync -avz --progress \
  -e "ssh -i $KEY_FILE -o StrictHostKeyChecking=no" \
  --exclude '.git' \
  --exclude 'allure-results' \
  --exclude 'allure-report' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'aws/*.pem' \
  --exclude 'connection-info.txt' \
  "$PROJECT_DIR/" "ubuntu@$PUBLIC_IP:/opt/rf-automation/"

echo ""

# Start infrastructure services
echo "[3/5] Starting ELK stack..."
$SSH_CMD "cd /opt/rf-automation && sudo docker compose -f aws/docker-compose.infra.yml up -d" 2>/dev/null || \
$SSH_CMD "cd /opt/rf-automation && sudo docker-compose -f aws/docker-compose.infra.yml up -d"
echo ""

# Build test runner image
echo "[4/5] Building test runner Docker image..."
$SSH_CMD "cd /opt/rf-automation && sudo docker build -t rf-test-runner:latest ."
echo ""

# Get Jenkins password and configure
echo "[5/5] Getting Jenkins info..."
JENKINS_PASS=$($SSH_CMD "sudo cat /var/lib/jenkins/secrets/initialAdminPassword" 2>/dev/null || echo "not-ready-yet")
echo ""

echo "=============================================="
echo "  DEPLOYMENT COMPLETE"
echo "=============================================="
echo ""
echo "  Jenkins:       http://$PUBLIC_IP:8080"
echo "  Jenkins Pass:  $JENKINS_PASS"
echo "  Kibana:        http://$PUBLIC_IP:5601"
echo "  Elasticsearch: http://$PUBLIC_IP:9200"
echo ""
echo "  SSH: $SSH_CMD"
echo ""
echo "  Next steps:"
echo "  1. Open Jenkins at http://$PUBLIC_IP:8080"
echo "  2. Enter the initial admin password above"
echo "  3. Install suggested plugins + Allure + Robot Framework plugins"
echo "  4. Create a Pipeline job pointing to /opt/rf-automation/Jenkinsfile"
echo ""
echo "=============================================="
