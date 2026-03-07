#!/bin/bash
set -euo pipefail

# ============================================================================
# AWS Provisioning Script for RF Automation Infrastructure
# Creates: VPC, Security Group, Key Pair, EC2 instance with Jenkins + ELK
# Designed for AWS Free Tier (t2.micro)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="rf-automation"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
INSTANCE_TYPE="t3.micro"
KEY_NAME="${PROJECT_NAME}-key"
KEY_FILE="$SCRIPT_DIR/${KEY_NAME}.pem"
AMI_ID=""

echo "===== RF Automation AWS Provisioning ====="
echo "Region: $REGION"
echo "Instance Type: $INSTANCE_TYPE (Free Tier)"
echo ""

# Verify AWS credentials
echo "[1/7] Verifying AWS credentials..."
aws sts get-caller-identity --region "$REGION" || {
  echo "ERROR: AWS credentials not configured. Run: aws configure"
  exit 1
}
echo ""

# Find latest Ubuntu 22.04 AMI
echo "[2/7] Finding latest Ubuntu 22.04 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
  echo "ERROR: Could not find Ubuntu 22.04 AMI"
  exit 1
fi
echo "  AMI: $AMI_ID"
echo ""

# Create Key Pair
echo "[3/7] Creating key pair: $KEY_NAME..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" 2>/dev/null; then
  echo "  Key pair already exists, skipping..."
else
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query 'KeyMaterial' \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  echo "  Saved to: $KEY_FILE"
fi
echo ""

# Get default VPC
echo "[4/7] Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "  No default VPC found, creating one..."
  VPC_ID=$(aws ec2 create-default-vpc --region "$REGION" --query 'Vpc.VpcId' --output text)
fi
echo "  VPC: $VPC_ID"

SUBNET_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' \
  --output text)
echo "  Subnet: $SUBNET_ID"
echo ""

# Create Security Group
echo "[5/7] Creating security group..."
SG_NAME="${PROJECT_NAME}-sg"

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "RF Automation - Jenkins, ELK, SSH" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query 'GroupId' \
    --output text)

  MY_IP=$(curl -s https://checkip.amazonaws.com)/32

  # SSH
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --region "$REGION" \
    --protocol tcp --port 22 --cidr "$MY_IP"

  # Jenkins
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --region "$REGION" \
    --protocol tcp --port 8080 --cidr "$MY_IP"

  # Kibana
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --region "$REGION" \
    --protocol tcp --port 5601 --cidr "$MY_IP"

  # Elasticsearch
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --region "$REGION" \
    --protocol tcp --port 9200 --cidr "$MY_IP"

  echo "  Created SG: $SG_ID (restricted to your IP: $MY_IP)"
else
  echo "  Security group already exists: $SG_ID"
fi
echo ""

# Launch EC2 Instance
echo "[6/7] Launching EC2 instance..."

EXISTING_INSTANCE=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${PROJECT_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "None")

if [ "$EXISTING_INSTANCE" != "None" ] && [ -n "$EXISTING_INSTANCE" ]; then
  echo "  Instance already exists: $EXISTING_INSTANCE"
  INSTANCE_ID="$EXISTING_INSTANCE"
else
  INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --user-data "file://${SCRIPT_DIR}/user-data.sh" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}},{Key=Project,Value=RF-Automation},{Key=Environment,Value=dev}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

  echo "  Instance launched: $INSTANCE_ID"
fi
echo ""

# Wait for instance and get public IP
echo "[7/7] Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo ""
echo "=============================================="
echo "  RF Automation Infrastructure - DEPLOYED"
echo "=============================================="
echo ""
echo "  Instance ID : $INSTANCE_ID"
echo "  Public IP   : $PUBLIC_IP"
echo "  Key File    : $KEY_FILE"
echo ""
echo "  SSH:"
echo "    ssh -i $KEY_FILE ubuntu@$PUBLIC_IP"
echo ""
echo "  Jenkins (wait ~5 min for setup):"
echo "    http://$PUBLIC_IP:8080"
echo ""
echo "  Kibana (start manually via docker compose):"
echo "    http://$PUBLIC_IP:5601"
echo ""
echo "  Get Jenkins initial password:"
echo "    ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
echo ""
echo "  Upload project to server:"
echo "    scp -i $KEY_FILE -r ${SCRIPT_DIR}/.. ubuntu@$PUBLIC_IP:/opt/rf-automation/"
echo ""
echo "=============================================="

# Save connection info
cat > "$SCRIPT_DIR/connection-info.txt" << EOF
Instance ID : $INSTANCE_ID
Public IP   : $PUBLIC_IP
Region      : $REGION
Key File    : $KEY_FILE

SSH: ssh -i $KEY_FILE ubuntu@$PUBLIC_IP
Jenkins: http://$PUBLIC_IP:8080
Kibana: http://$PUBLIC_IP:5601
Elasticsearch: http://$PUBLIC_IP:9200

Jenkins Password: ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
EOF

echo "Connection info saved to: $SCRIPT_DIR/connection-info.txt"
