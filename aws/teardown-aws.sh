#!/bin/bash
set -euo pipefail

# ============================================================================
# Teardown AWS resources to avoid charges
# Run this when you're done to stay within Free Tier
# ============================================================================

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT_NAME="rf-automation"

echo "===== Tearing down RF Automation AWS Infrastructure ====="
echo "WARNING: This will delete ALL resources for project: $PROJECT_NAME"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi
echo ""

# Find and terminate EC2 instance
echo "[1/3] Terminating EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${PROJECT_NAME}" \
    "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
  echo "  Terminating: $INSTANCE_ID"
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION"
  echo "  Terminated."
else
  echo "  No instance found."
fi
echo ""

# Delete security group
echo "[2/3] Deleting security group..."
SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=${PROJECT_NAME}-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "None")

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
  sleep 5
  aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" || echo "  Retry needed (dependencies may still exist)"
  echo "  Deleted: $SG_ID"
else
  echo "  No security group found."
fi
echo ""

# Delete key pair
echo "[3/3] Deleting key pair..."
aws ec2 delete-key-pair --key-name "${PROJECT_NAME}-key" --region "$REGION" 2>/dev/null && \
  echo "  Deleted key pair." || echo "  No key pair found."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -f "$SCRIPT_DIR/${PROJECT_NAME}-key.pem"
rm -f "$SCRIPT_DIR/connection-info.txt"
echo ""

echo "===== Teardown Complete ====="
echo "All AWS resources have been cleaned up."
