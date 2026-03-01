# Allure Reporting Integration

Complete guide for using Allure reports in the RF Automation Integration environment.

## Overview

Allure Framework provides beautiful, interactive HTML test reports with:
- Test execution history
- Trends and statistics
- Test case details with steps
- Attachments (logs, screenshots)
- Categories and suites organization
- Retries tracking
- Environment information

## Installation

Allure is automatically installed by the integration setup script:

```bash
sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration
```

**What gets installed:**
- Allure command-line tool (v2.25.0)
- allure-robotframework Python library (v2.13.2)
- Java 17 (required for Allure)

**Manual installation (if needed):**
```bash
# Download Allure
wget https://github.com/allure-framework/allure2/releases/download/2.25.0/allure-2.25.0.tgz

# Extract
sudo tar -xzf allure-2.25.0.tgz -C /opt/

# Create symlink
sudo ln -s /opt/allure-2.25.0/bin/allure /usr/local/bin/allure

# Verify
allure --version
```

## Usage

### Running Tests with Allure

**Basic usage:**
```bash
source venv/bin/activate

# Run tests with Allure listener
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      tests/integration_popo.robot
```

**With additional options:**
```bash
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      --listener resources.ElasticsearchListener \
      --name "Integration PoPo Tests" \
      --variable ENVIRONMENT:integration \
      tests/integration_popo.robot
```

### Generating Allure Reports

**Generate report:**
```bash
allure generate allure-results --clean -o allure-report
```

**Options:**
- `--clean`: Remove existing report directory before generating
- `-o <dir>`: Output directory (default: allure-report)

**Open report in browser:**
```bash
allure open allure-report
```

This starts a local web server (typically on http://localhost:port) and opens the report.

**Serve report on specific port:**
```bash
allure open allure-report --port 8080
```

### Complete Workflow

```bash
#!/bin/bash
# Complete test execution with Allure reporting

cd ~/Fully_Product_Automation
source venv/bin/activate

# Clean old results
rm -rf allure-results allure-report results/*

# Run tests
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      tests/integration_popo.robot

# Generate report
allure generate allure-results --clean -o allure-report

# Open in browser
allure open allure-report
```

## Allure Report Features

### 1. Overview Dashboard

Shows at-a-glance:
- Total tests run
- Pass/fail rate
- Test duration
- Trends over time
- Environment info

### 2. Test Suites

Organized view of:
- Test suites hierarchy
- Individual test cases
- Test status (passed, failed, skipped)
- Execution time

### 3. Graphs

Visual representations:
- Status distribution (pie chart)
- Severity distribution
- Duration trend
- Retries trend
- Categories trend

### 4. Timeline

Shows test execution:
- Parallel vs sequential execution
- Test duration visualization
- Overlap detection

### 5. Behaviors

BDD-style organization:
- Features
- Stories
- Test scenarios

### 6. Test Case Details

Each test shows:
- Description and tags
- Execution steps
- Parameters
- Attachments (logs, screenshots)
- Error messages and stack traces
- Execution time

## Integration with Robot Framework

### Test Annotations

Add Allure-specific information to Robot Framework tests:

```robot
*** Test Cases ***
TC_001: Example Test with Allure Annotations
    [Documentation]    This test demonstrates Allure integration
    [Tags]    critical    integration    allure

    Log    Step 1: Initialize    level=INFO
    Connect To Equipment    SpectrumAnalyzer

    Log    Step 2: Configure    level=INFO
    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT 1e9

    Log    Step 3: Measure    level=INFO
    ${result}=    Query Equipment    SpectrumAnalyzer    TRAC:DATA?

    Log    Step 4: Validate    level=INFO
    Should Not Be Empty    ${result}
```

### Adding Attachments

**In Robot Framework:**
```robot
*** Test Cases ***
Test With Screenshot
    [Documentation]    Test that includes attachments

    # Take screenshot (if using Selenium)
    Capture Page Screenshot    screenshot.png

    # Log files are automatically attached
    Log    This will appear in Allure    level=INFO

    # Create custom attachment
    Create File    ${TEMPDIR}/data.json    {"result": "success"}
```

### Environment Information

Create `allure-results/environment.properties`:

```properties
Environment=Integration
Mock.Equipment=Enabled
RF.Version=7.0
Python.Version=3.11
OS=Ubuntu 24.04
Elasticsearch=8.12.0
```

**Automated in setup script:**
```bash
cat > allure-results/environment.properties <<EOF
Environment=${ENVIRONMENT}
Branch=${GIT_BRANCH}
Build=${BUILD_NUMBER}
Timestamp=$(date -Iseconds)
Host=$(hostname)
EOF
```

## Jenkins Integration

The integration pipeline automatically generates Allure reports.

**Jenkinsfile.integration includes:**
```groovy
stage('Generate Allure Report') {
    steps {
        script {
            allure([
                includeProperties: false,
                jdk: '',
                results: [[path: 'allure-results']],
                reportBuildPolicy: 'ALWAYS'
            ])
        }
    }
}
```

**Jenkins Allure Plugin:**
The setup script should install the Allure Jenkins plugin. View reports at:
`http://localhost:8080/job/rf-integration/allure/`

## Customization

### Categories

Create `allure-results/categories.json` to categorize failures:

```json
[
  {
    "name": "Equipment Connection Failures",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*not reachable.*"
  },
  {
    "name": "Elasticsearch Issues",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*Elasticsearch.*"
  },
  {
    "name": "RF Physics Validation",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*harmonic.*|.*noise.*"
  }
]
```

### Trend History

To maintain historical trends across test runs:

```bash
# Copy history from previous report
cp -r allure-report/history allure-results/history

# Generate new report (will include trends)
allure generate allure-results --clean -o allure-report
```

**Automated history preservation:**
```bash
#!/bin/bash
# Save history before generating new report

if [ -d "allure-report/history" ]; then
    cp -r allure-report/history allure-results/history
fi

allure generate allure-results --clean -o allure-report
```

## Troubleshooting

### Issue: Allure command not found

**Solution:**
```bash
# Check installation
which allure
ls -l /usr/local/bin/allure

# Reinstall if needed
sudo ln -sf /opt/allure-2.25.0/bin/allure /usr/local/bin/allure
```

### Issue: No test results in report

**Check:**
1. `allure-results` directory exists
2. Contains `.json` files
3. Listener was specified: `--listener allure_robotframework:allure-results`

```bash
ls -la allure-results/
# Should show *-result.json, *-container.json files
```

### Issue: Report doesn't open in browser

**Manual method:**
```bash
# Generate report
allure generate allure-results --clean -o allure-report

# Serve manually with Python
cd allure-report
python3 -m http.server 8080

# Open browser to http://localhost:8080
```

### Issue: Java not found

Allure requires Java 11+:

```bash
# Check Java version
java -version

# Install if needed
sudo apt install openjdk-17-jdk
```

## Best Practices

### 1. Clean Results Between Runs

```bash
rm -rf allure-results/*
robot --listener allure_robotframework:allure-results tests/
```

### 2. Preserve History

```bash
# Before new run
[ -d allure-report/history ] && cp -r allure-report/history allure-results/

# Run tests
robot --listener allure_robotframework:allure-results tests/

# Generate with history
allure generate allure-results --clean -o allure-report
```

### 3. Use Descriptive Test Names

```robot
TC_POPO_001: Verify Mock Equipment Connectivity
    [Documentation]    Validates that all three mock equipment instances
    ...                (SA, SG, DUT) are accessible and respond to IDN queries
    [Tags]    infrastructure    connectivity    critical
```

### 4. Add Context to Failures

```robot
*** Keywords ***
Verify Equipment Response
    [Arguments]    ${equipment}    ${expected}

    ${actual}=    Query Equipment    ${equipment}    *IDN?

    # Log context for debugging in Allure
    Log    Expected: ${expected}    level=INFO
    Log    Actual: ${actual}    level=INFO

    Should Contain    ${actual}    ${expected}
    ...    msg=Equipment ${equipment} returned unexpected IDN: ${actual}
```

### 5. Organize with Tags

Use tags for filtering and categorization:

```robot
[Tags]    critical    integration    smoke
[Tags]    rf_physics    harmonics
[Tags]    infrastructure    elasticsearch
```

## Advanced Features

### Parallel Execution

When running tests in parallel, use unique result directories:

```bash
# Terminal 1
robot --listener allure_robotframework:allure-results-1 tests/suite1.robot &

# Terminal 2
robot --listener allure_robotframework:allure-results-2 tests/suite2.robot &

# Wait for completion
wait

# Merge results
cp allure-results-2/* allure-results-1/

# Generate combined report
allure generate allure-results-1 --clean -o allure-report
```

### CI/CD Integration

**Export reports for external hosting:**
```bash
# Generate report
allure generate allure-results --clean -o allure-report

# Archive for CI
tar -czf allure-report.tar.gz allure-report/

# Or upload to S3, artifact repository, etc.
aws s3 cp allure-report.tar.gz s3://my-bucket/reports/
```

## Example: Complete Integration Test with Allure

```bash
#!/bin/bash
# complete_test_with_allure.sh

set -e

PROJECT_ROOT=~/Fully_Product_Automation
cd "$PROJECT_ROOT"

# Activate Python environment
source venv/bin/activate

# Clean previous results
echo "Cleaning previous results..."
rm -rf allure-results allure-report results

# Preserve history if exists
if [ -d "allure-report-previous/history" ]; then
    mkdir -p allure-results
    cp -r allure-report-previous/history allure-results/
fi

# Run PoPo tests
echo "Running PoPo tests..."
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      --listener resources.ElasticsearchListener \
      --name "Integration Environment Validation" \
      --variable ENVIRONMENT:integration \
      tests/integration_popo.robot

# Run functional tests
echo "Running functional tests..."
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      --listener resources.ElasticsearchListener \
      --name "RF Functional Tests" \
      --variable ENVIRONMENT:integration \
      tests/rf_functional.robot || true

# Create environment info
cat > allure-results/environment.properties <<EOF
Environment=Integration
Date=$(date -Iseconds)
Host=$(hostname)
Python.Version=$(python3 --version)
Robot.Version=$(robot --version)
Mock.Equipment=Enabled
Elasticsearch=http://localhost:9200
EOF

# Generate Allure report
echo "Generating Allure report..."
allure generate allure-results --clean -o allure-report

# Backup current report
mv allure-report allure-report-$(date +%Y%m%d-%H%M%S)
cp -r allure-report-$(date +%Y%m%d-%H%M%S) allure-report-previous

# Open report
echo "Opening Allure report..."
allure open allure-report-$(date +%Y%m%d-%H%M%S)

echo "Test execution complete!"
```

## References

- [Allure Framework Official Documentation](https://docs.qameta.io/allure/)
- [Allure Robot Framework Integration](https://github.com/allure-framework/allure-python)
- [Integration Setup Guide](INTEGRATION_SETUP.md)
- [PoPo Tests Documentation](POPO_TESTS.md)
