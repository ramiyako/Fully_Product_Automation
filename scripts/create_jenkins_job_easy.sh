#!/bin/bash
# Quick Jenkins Job Creator
# This creates the job using the Jenkins CLI

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================="
echo "Jenkins Job Quick Creator"
echo "=========================================="
echo ""

# Check if Jenkins is accessible
if ! curl -s http://localhost:8080/login > /dev/null 2>&1; then
    echo "ERROR: Jenkins is not accessible at http://localhost:8080"
    exit 1
fi

echo "Jenkins is running!"
echo ""
echo "OPTION 1: Import Job via UI (EASIEST)"
echo "======================================="
echo ""
echo "1. Open Jenkins: http://localhost:8080"
echo "2. Click: New Item"
echo "3. Name: RF-Automation-Integration"
echo "4. Type: Pipeline"
echo "5. Click: OK"
echo ""
echo "Then in the configuration page, copy/paste this:"
echo ""
echo "--- START COPY HERE ---"
echo ""
cat << 'JOBCONFIG'
// RF Automation Integration Pipeline

properties([
    parameters([
        choice(
            name: 'TEST_SUITE',
            choices: ['All Tests', 'PoPo Tests Only', 'Functional Tests Only', 'Custom (use tags)'],
            description: 'Select which test suite to run'
        ),
        string(
            name: 'TEST_TAGS',
            defaultValue: '',
            description: 'Robot Framework tags (e.g., smoke, regression)'
        ),
        string(
            name: 'TEST_INCLUDE',
            defaultValue: '',
            description: 'Test patterns to include'
        ),
        string(
            name: 'TEST_EXCLUDE',
            defaultValue: '',
            description: 'Test patterns to exclude'
        ),
        booleanParam(
            name: 'ENABLE_RF_PHYSICS',
            defaultValue: true,
            description: 'Enable RF physics simulation'
        ),
        choice(
            name: 'NOISE_FLOOR_DBM',
            choices: ['-120', '-110', '-100', '-90'],
            description: 'Noise floor level'
        ),
        booleanParam(
            name: 'UPLOAD_TO_ELASTICSEARCH',
            defaultValue: true,
            description: 'Upload to Elasticsearch'
        ),
        booleanParam(
            name: 'GENERATE_ALLURE_REPORT',
            defaultValue: true,
            description: 'Generate Allure report'
        )
    ])
])

node {
    stage('Checkout') {
        checkout([
            $class: 'GitSCM',
            branches: [[name: '*/integration']],
            userRemoteConfigs: [[url: 'PROJECTROOT']]
        ])
    }

    stage('Load Pipeline') {
        load 'Jenkinsfile.integration'
    }
}
JOBCONFIG

sed "s|PROJECTROOT|$PROJECT_ROOT|g" << 'JOBCONFIG'
// RF Automation Integration Pipeline

properties([
    parameters([
        choice(
            name: 'TEST_SUITE',
            choices: ['All Tests', 'PoPo Tests Only', 'Functional Tests Only', 'Custom (use tags)'],
            description: 'Select which test suite to run'
        ),
        string(
            name: 'TEST_TAGS',
            defaultValue: '',
            description: 'Robot Framework tags (e.g., smoke, regression)'
        ),
        string(
            name: 'TEST_INCLUDE',
            defaultValue: '',
            description: 'Test patterns to include'
        ),
        string(
            name: 'TEST_EXCLUDE',
            defaultValue: '',
            description: 'Test patterns to exclude'
        ),
        booleanParam(
            name: 'ENABLE_RF_PHYSICS',
            defaultValue: true,
            description: 'Enable RF physics simulation'
        ),
        choice(
            name: 'NOISE_FLOOR_DBM',
            choices: ['-120', '-110', '-100', '-90'],
            description: 'Noise floor level'
        ),
        booleanParam(
            name: 'UPLOAD_TO_ELASTICSEARCH',
            defaultValue: true,
            description: 'Upload to Elasticsearch'
        ),
        booleanParam(
            name: 'GENERATE_ALLURE_REPORT',
            defaultValue: true,
            description: 'Generate Allure report'
        )
    ])
])

node {
    stage('Checkout') {
        checkout([
            $class: 'GitSCM',
            branches: [[name: '*/integration']],
            userRemoteConfigs: [[url: 'PROJECTROOT']]
        ])
    }

    stage('Load Pipeline') {
        // Load and execute the main Jenkinsfile
        def pipeline = load('Jenkinsfile.integration')
    }
}
JOBCONFIG

echo ""
echo "--- END COPY ---"
echo ""
echo "Wait, that's complex! Let me give you the SIMPLER way..."
echo ""

echo "OPTION 2: Use Pipeline from SCM (RECOMMENDED)"
echo "=============================================="
echo ""
echo "1. Open Jenkins: http://localhost:8080"
echo "2. Click: New Item"
echo "3. Name: RF-Automation-Integration"
echo "4. Type: Pipeline"
echo "5. Click: OK"
echo "6. Check: 'This project is parameterized'"
echo "7. Add 8 parameters as shown in the guide"
echo "8. Scroll to 'Pipeline' section:"
echo "   - Definition: Pipeline script from SCM"
echo "   - SCM: Git"
echo "   - Repository URL: $PROJECT_ROOT"
echo "   - Branch: */integration"
echo "   - Script Path: Jenkinsfile.integration"
echo "9. Click: Save"
echo ""

echo "Full guide: bash scripts/setup_jenkins_job_manual.sh"
echo ""
