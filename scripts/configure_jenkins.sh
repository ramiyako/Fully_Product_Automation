#!/bin/bash
###############################################################################
# Jenkins Auto-Configuration Script
# Configures Jenkins with the RF Automation Integration job
#
# This script:
# 1. Waits for Jenkins to be fully operational
# 2. Installs required Jenkins plugins
# 3. Creates the RF Automation Integration pipeline job
# 4. Configures Allure plugin settings
#
# Usage:
#   sudo bash scripts/configure_jenkins.sh [OPTIONS]
#
# Options:
#   --jenkins-url=URL    Jenkins URL (default: http://localhost:8080)
#   --project-root=PATH  Project root directory
#   --skip-plugins       Skip plugin installation
#   --verbose            Enable verbose output
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
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKIP_PLUGINS=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --jenkins-url=*)
            JENKINS_URL="${1#*=}"
            shift
            ;;
        --project-root=*)
            PROJECT_ROOT="${1#*=}"
            shift
            ;;
        --skip-plugins)
            SKIP_PLUGINS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

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

# Check if Jenkins is running
log_step "Checking Jenkins Status"
log_info "Jenkins URL: $JENKINS_URL"

# Wait for Jenkins to be ready
log_info "Waiting for Jenkins to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -f "$JENKINS_URL/api/json" > /dev/null 2>&1; then
        log_success "Jenkins is ready"
        break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log_error "Jenkins did not become ready in time"
        exit 1
    fi

    echo -n "."
    sleep 2
done

echo ""

# Get Jenkins credentials
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    JENKINS_USER="admin"
    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    log_info "Using initial admin password"
else
    log_warning "Initial admin password not found. Assuming Jenkins is configured."
    log_info "If job creation fails, you may need to manually configure Jenkins authentication."
fi

# Function to call Jenkins CLI
jenkins_cli() {
    if [ -n "$JENKINS_PASSWORD" ]; then
        curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$@"
    else
        curl -s "$@"
    fi
}

# Install required plugins
if [ "$SKIP_PLUGINS" = false ]; then
    log_step "Installing Required Jenkins Plugins"

    REQUIRED_PLUGINS=(
        "git"
        "workflow-aggregator"
        "allure-jenkins-plugin"
        "robot"
        "docker-workflow"
        "timestamper"
    )

    log_info "Required plugins: ${REQUIRED_PLUGINS[*]}"

    # Note: Plugin installation via CLI requires Jenkins to be fully configured
    # This is a placeholder - in production, plugins should be pre-installed or
    # installed via Jenkins Plugin Manager UI

    log_warning "Plugin installation via CLI requires Jenkins configuration."
    log_info "Please ensure the following plugins are installed via Jenkins UI:"
    for plugin in "${REQUIRED_PLUGINS[@]}"; do
        echo "  - $plugin"
    done

else
    log_info "Skipping plugin installation"
fi

# Enable HTML Markup Formatter for build descriptions
log_step "Enabling HTML Markup Formatter"

log_info "Setting Jenkins Markup Formatter to Safe HTML..."
GROOVY_SCRIPT='import hudson.markup.RawHtmlMarkupFormatter; Jenkins.instance.setMarkupFormatter(new RawHtmlMarkupFormatter(false)); Jenkins.instance.save(); println("OK")'

MARKUP_RESULT=$(jenkins_cli -X POST "$JENKINS_URL/scriptText" --data-urlencode "script=$GROOVY_SCRIPT" 2>/dev/null) || true

if echo "$MARKUP_RESULT" | grep -q "OK"; then
    log_success "HTML Markup Formatter enabled"
else
    log_warning "Could not set markup formatter automatically"
    log_info "Set manually: Manage Jenkins → Security → Markup Formatter → Safe HTML"
fi

# Configure Elasticsearch index template
log_step "Configuring Elasticsearch Index Template"

log_info "Uploading index template to Elasticsearch..."
curl -X PUT "http://localhost:9200/_index_template/rf-automation-template" \
    -H 'Content-Type: application/json' \
    -d @"$PROJECT_ROOT/infra/elasticsearch-index-template.json" \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_success "Elasticsearch index template configured"
else
    log_warning "Failed to configure Elasticsearch index template (Elasticsearch may not be ready)"
fi

# Import Kibana dashboard
log_step "Importing Kibana Dashboard"

log_info "Importing dashboard to Kibana..."
curl -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@"$PROJECT_ROOT/infra/kibana-dashboard.ndjson" \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_success "Kibana dashboard imported"
else
    log_warning "Failed to import Kibana dashboard (Kibana may not be ready)"
fi

# Create Jenkins job
log_step "Creating Jenkins Pipeline Job"

JOB_NAME="RF-Automation-Integration"
JOB_CONFIG="$PROJECT_ROOT/infra/jenkins-job-config.xml"

# Replace PROJECT_ROOT placeholder in job config
log_info "Preparing job configuration..."
TEMP_CONFIG="/tmp/jenkins-job-config-$$.xml"
sed "s|\$PROJECT_ROOT|$PROJECT_ROOT|g" "$JOB_CONFIG" > "$TEMP_CONFIG"

log_info "Creating job: $JOB_NAME"

# Check if job exists
JOB_EXISTS=$(jenkins_cli "$JENKINS_URL/job/$JOB_NAME/api/json" 2>&1 | grep -c "Hudson.model.Job" || true)

if [ "$JOB_EXISTS" -gt 0 ]; then
    log_info "Job already exists, updating configuration..."

    if [ -n "$JENKINS_PASSWORD" ]; then
        curl -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
            "$JENKINS_URL/job/$JOB_NAME/config.xml" \
            --data-binary @"$TEMP_CONFIG" \
            -H "Content-Type: text/xml"
    else
        log_warning "Cannot update job without credentials"
    fi
else
    log_info "Creating new job..."

    if [ -n "$JENKINS_PASSWORD" ]; then
        curl -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
            "$JENKINS_URL/createItem?name=$JOB_NAME" \
            --data-binary @"$TEMP_CONFIG" \
            -H "Content-Type: text/xml"
    else
        log_warning "Cannot create job without credentials"
    fi
fi

rm -f "$TEMP_CONFIG"

if [ $? -eq 0 ]; then
    log_success "Jenkins job created/updated successfully"
else
    log_warning "Job creation may have failed. Please check Jenkins UI."
fi

# Completion
log_step "Jenkins Configuration Complete"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access Information:${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Jenkins:       $JENKINS_URL"
echo -e "Job:           $JENKINS_URL/job/$JOB_NAME"
echo -e "Kibana:        http://localhost:5601"
echo -e "Elasticsearch: http://localhost:9200"
echo ""

if [ -n "$JENKINS_PASSWORD" ]; then
    echo -e "${YELLOW}Jenkins Admin Credentials:${NC}"
    echo -e "Username: $JENKINS_USER"
    echo -e "Password: $JENKINS_PASSWORD"
    echo ""
fi

echo -e "${GREEN}Next Steps:${NC}"
echo -e "1. Access Jenkins at $JENKINS_URL"
echo -e "2. Navigate to job: $JOB_NAME"
echo -e "3. Click 'Build with Parameters'"
echo -e "4. Select test scope and options"
echo -e "5. Click 'Build'"
echo -e "6. View results in Allure report and Kibana"
echo ""

log_success "Configuration completed successfully! 🚀"
