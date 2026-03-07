#!/bin/bash
###############################################################################
# AWS Security Group Configuration Script
# Creates and configures security group for RF Automation Integration
#
# Usage:
#   bash scripts/configure_aws_security_group.sh [OPTIONS]
#
# Options:
#   --group-name=NAME       Security group name (default: rf-automation-sg)
#   --description=DESC      Security group description
#   --vpc-id=ID            VPC ID (default: default VPC)
#   --allowed-ip=IP        Restrict access to specific IP (default: 0.0.0.0/0)
#   --region=REGION        AWS region (default: from AWS config)
#   --profile=PROFILE      AWS CLI profile (default: default)
#   --dry-run              Show what would be done without executing
#   --help                 Show this help message
#
# Example:
#   bash scripts/configure_aws_security_group.sh --group-name=rf-automation-sg --allowed-ip=1.2.3.4/32
#
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
GROUP_NAME="rf-automation-sg"
DESCRIPTION="RF Automation Integration Environment Security Group"
VPC_ID=""
ALLOWED_IP="0.0.0.0/0"
REGION=""
PROFILE="default"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --group-name=*)
            GROUP_NAME="${1#*=}"
            shift
            ;;
        --description=*)
            DESCRIPTION="${1#*=}"
            shift
            ;;
        --vpc-id=*)
            VPC_ID="${1#*=}"
            shift
            ;;
        --allowed-ip=*)
            ALLOWED_IP="${1#*=}"
            shift
            ;;
        --region=*)
            REGION="${1#*=}"
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            grep "^#" "$0" | grep -v "#!/bin/bash" | sed 's/^# //'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    log_info "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Set AWS CLI options
AWS_OPTS="--profile $PROFILE"
if [ -n "$REGION" ]; then
    AWS_OPTS="$AWS_OPTS --region $REGION"
else
    # Get region from AWS config or EC2 metadata
    if [ -z "$REGION" ]; then
        REGION=$(aws configure get region --profile "$PROFILE" 2>/dev/null || echo "us-east-1")
        AWS_OPTS="$AWS_OPTS --region $REGION"
    fi
fi

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE - No changes will be made"
    AWS_OPTS="$AWS_OPTS --dry-run"
fi

log_step "AWS Security Group Configuration"
log_info "Group Name: $GROUP_NAME"
log_info "Description: $DESCRIPTION"
log_info "Allowed IP: $ALLOWED_IP"
log_info "Region: $REGION"
log_info "Profile: $PROFILE"

# Get default VPC if not specified
if [ -z "$VPC_ID" ]; then
    log_info "Getting default VPC..."
    VPC_ID=$(aws ec2 describe-vpcs \
        $AWS_OPTS \
        --filters "Name=isDefault,Values=true" \
        --query "Vpcs[0].VpcId" \
        --output text)

    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        log_error "No default VPC found. Please specify --vpc-id"
        exit 1
    fi
    log_info "Using default VPC: $VPC_ID"
else
    log_info "Using specified VPC: $VPC_ID"
fi

# Check if security group already exists
log_info "Checking if security group already exists..."
EXISTING_SG=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters "Name=group-name,Values=$GROUP_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_SG" != "None" ] && [ -n "$EXISTING_SG" ]; then
    log_warning "Security group '$GROUP_NAME' already exists with ID: $EXISTING_SG"
    log_info "Will update existing security group rules..."
    SG_ID="$EXISTING_SG"
else
    # Create security group
    log_step "Creating Security Group"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would create security group: $GROUP_NAME in VPC: $VPC_ID"
        SG_ID="sg-dry-run-id"
    else
        SG_ID=$(aws ec2 create-security-group \
            --profile "$PROFILE" \
            --region "$REGION" \
            --group-name "$GROUP_NAME" \
            --description "$DESCRIPTION" \
            --vpc-id "$VPC_ID" \
            --query "GroupId" \
            --output text)

        log_success "Security group created: $SG_ID"
    fi
fi

# Define security rules
log_step "Configuring Security Rules"

# Remove existing rules (if updating)
if [ "$EXISTING_SG" != "None" ] && [ "$DRY_RUN" = false ]; then
    log_info "Removing existing ingress rules..."
    aws ec2 describe-security-groups \
        --profile "$PROFILE" \
        --region "$REGION" \
        --group-ids "$SG_ID" \
        --query "SecurityGroups[0].IpPermissions" \
        --output json > /tmp/sg-rules.json

    if [ -s /tmp/sg-rules.json ] && [ "$(cat /tmp/sg-rules.json)" != "[]" ]; then
        aws ec2 revoke-security-group-ingress \
            --profile "$PROFILE" \
            --region "$REGION" \
            --group-id "$SG_ID" \
            --ip-permissions file:///tmp/sg-rules.json 2>/dev/null || true
    fi
    rm -f /tmp/sg-rules.json
fi

# Function to add rule
add_rule() {
    local PORT=$1
    local DESCRIPTION=$2

    log_info "Adding rule: Port $PORT ($DESCRIPTION) from $ALLOWED_IP"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would add rule for port $PORT"
        return
    fi

    aws ec2 authorize-security-group-ingress \
        --profile "$PROFILE" \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --ip-permissions \
            IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges="[{CidrIp=$ALLOWED_IP,Description='$DESCRIPTION'}]" \
        2>/dev/null || log_warning "Rule for port $PORT may already exist"
}

# Add SSH rule
add_rule 22 "SSH access"

# Add Jenkins rule
add_rule 8080 "Jenkins CI/CD server"

# Add Kibana rule
add_rule 5601 "Kibana data visualization"

# Add Elasticsearch rule
add_rule 9200 "Elasticsearch test results storage"

# Add Allure Reports rule
add_rule 9080 "Allure test reports (nginx)"

# Add Mock Equipment rules
add_rule 8001 "Mock Spectrum Analyzer admin interface"
add_rule 8002 "Mock Signal Generator admin interface"
add_rule 8003 "Mock DUT admin interface"

# Add SCPI ports (for direct equipment communication if needed)
log_info "Adding SCPI communication ports..."
for port in 5001 5002 5003; do
    add_rule $port "SCPI communication port $port"
done

# Tag security group
if [ "$DRY_RUN" = false ]; then
    log_step "Tagging Security Group"

    aws ec2 create-tags \
        --profile "$PROFILE" \
        --region "$REGION" \
        --resources "$SG_ID" \
        --tags \
            Key=Name,Value="$GROUP_NAME" \
            Key=Project,Value="RF-Automation" \
            Key=Environment,Value="Integration" \
            Key=ManagedBy,Value="automation-script" \
            Key=CreatedDate,Value="$(date +%Y-%m-%d)"

    log_success "Security group tagged"
fi

# Display final configuration
log_step "Security Group Configuration Complete"

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo -e "${GREEN}Security Group Details:${NC}"
    echo -e "  Group ID:    $SG_ID"
    echo -e "  Group Name:  $GROUP_NAME"
    echo -e "  VPC:         $VPC_ID"
    echo -e "  Region:      $REGION"
    echo ""

    echo -e "${GREEN}Configured Ports:${NC}"
    echo -e "  SSH:               22"
    echo -e "  Jenkins:           8080"
    echo -e "  Kibana:            5601"
    echo -e "  Elasticsearch:     9200"
    echo -e "  Allure Reports:    9080"
    echo -e "  Mock SA Admin:     8001"
    echo -e "  Mock SG Admin:     8002"
    echo -e "  Mock DUT Admin:    8003"
    echo -e "  SCPI Ports:        5001, 5002, 5003"
    echo ""

    echo -e "${GREEN}Access Configuration:${NC}"
    echo -e "  Allowed IP:        $ALLOWED_IP"
    if [ "$ALLOWED_IP" = "0.0.0.0/0" ]; then
        echo -e "  ${YELLOW}WARNING: Open to all IPs. Consider restricting for production!${NC}"
    fi
    echo ""

    echo -e "${GREEN}To view security group rules:${NC}"
    echo -e "  aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION"
    echo ""

    echo -e "${GREEN}To attach to an instance:${NC}"
    echo -e "  aws ec2 modify-instance-attribute \\"
    echo -e "    --instance-id i-xxxxx \\"
    echo -e "    --groups $SG_ID \\"
    echo -e "    --region $REGION"
    echo ""

    # Generate AWS Console URL
    CONSOLE_URL="https://console.aws.amazon.com/ec2/v2/home?region=${REGION}#SecurityGroups:group-id=${SG_ID}"
    echo -e "${GREEN}View in AWS Console:${NC}"
    echo -e "  $CONSOLE_URL"
    echo ""

    log_success "Security group configured successfully!"

    # Save configuration to file
    CONFIG_FILE="/tmp/rf-automation-sg-config.txt"
    cat > "$CONFIG_FILE" <<EOF
RF Automation Security Group Configuration
==========================================
Created: $(date)

Security Group ID: $SG_ID
Group Name:        $GROUP_NAME
VPC ID:            $VPC_ID
Region:            $REGION
Allowed IP:        $ALLOWED_IP

Configured Ports:
- SSH:             22
- Jenkins:         8080
- Kibana:          5601
- Elasticsearch:   9200
- Mock SA Admin:   8001
- Mock SG Admin:   8002
- Mock DUT Admin:  8003
- SCPI Ports:      5001, 5002, 5003

AWS Console URL:
$CONSOLE_URL

To attach to instance:
aws ec2 modify-instance-attribute \\
  --instance-id <INSTANCE_ID> \\
  --groups $SG_ID \\
  --region $REGION
EOF

    log_info "Configuration saved to: $CONFIG_FILE"
else
    log_warning "Dry run completed - no changes made"
fi

# Security recommendations
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Security Recommendations:${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "1. Restrict source IPs: Use your organization's CIDR instead of 0.0.0.0/0"
echo "   Example: --allowed-ip=YOUR_IP/32"
echo ""
echo "2. Use VPN or bastion host for production access"
echo ""
echo "3. Enable AWS CloudTrail for audit logging"
echo ""
echo "4. Use AWS Systems Manager Session Manager instead of SSH"
echo ""
echo "5. Consider using AWS WAF for web services (Jenkins, Kibana)"
echo ""
echo "6. Enable VPC Flow Logs for network traffic monitoring"
echo ""
echo "7. Regularly review and update security group rules"
echo ""
echo "8. Use AWS Security Hub for continuous compliance monitoring"
echo ""
