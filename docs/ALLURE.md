# Allure Integration Guide

## Overview

Allure Framework is integrated into the RF automation infrastructure to provide beautiful, interactive test reports with rich visualizations, historical trends, and detailed test execution data.

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                     Test Execution Flow                            │
└───────────────────────────────────────────────────────────────────┘

Robot Framework Test Execution
        │
        ├─► --listener allure_robotframework
        │   (Collects test data during execution)
        │
        ▼
   allure-results/
   (JSON files with test data)
        │
        ├─► result-*.json          (Test case results)
        ├─► *-container.json       (Test suite containers)
        ├─► *-attachment.*         (Screenshots, logs)
        └─► environment.properties (Environment info)
        │
        ▼
   allure generate
   (Processes results and generates HTML report)
        │
        ▼
   allure-report/
   (Static HTML report)
        │
        ├─► index.html             (Main entry point)
        ├─► data/                  (Test data JSON)
        ├─► plugins/               (Allure plugins)
        └─► history/               (Trend data)
        │
        ▼
   Jenkins Allure Plugin
   (Serves report with history)
```

## Components

### 1. Robot Framework Listener

**allure-robotframework** package provides a listener that hooks into Robot Framework execution:

- Captures test case information
- Records test steps and keywords
- Attaches screenshots and logs
- Categorizes failures
- Tracks timing information

### 2. Allure CLI

**Allure 2.25.0** commandline tool:

- Installed in Docker container at `/opt/allure-2.25.0/`
- Symlinked to `/usr/bin/allure`
- Requires Java 17 (included in container)

### 3. Jenkins Plugin

**Allure Jenkins Plugin** (optional but recommended):

- Serves Allure reports from Jenkins
- Maintains history across builds
- Provides trend analysis
- Accessible from build page

## Configuration Files

### allure.properties

Location: Project root

```properties
allure.report.title=RF Equipment Automation Test Report
allure.project.name=RF Equipment Test Automation
allure.environment.project=RF Automation Infrastructure
allure.environment.framework=Robot Framework 7.0
allure.environment.test.runner=Docker Container
allure.environment.platform=Ubuntu Server 24.04 LTS
allure.results.history.enabled=true
allure.results.history.max.runs=20
```

### categories.json

Location: Project root

Defines failure categories for automatic classification:

```json
[
  {
    "name": "Equipment Connection Failures",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*[Cc]onnection.*|.*[Tt]imeout.*"
  },
  {
    "name": "SCPI Command Errors",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*SCPI.*|.*[Cc]ommand.*error.*"
  }
]
```

Categories include:
- Equipment Connection Failures
- SCPI Command Errors
- Measurement Errors
- Network Issues
- Infrastructure Failures
- Test Setup/Teardown Failures
- Product Defects
- Intermittent Failures

## Usage

### Running Tests with Allure

Tests automatically generate Allure results when using the `--listener` flag:

```bash
robot --listener allure_robotframework tests/
```

This is configured in the Jenkinsfile automatically.

### Generating Reports Manually

```bash
# Generate report from results
allure generate allure-results -o allure-report --clean

# Open report in browser
allure open allure-report

# Serve report on specific port
allure open allure-report -p 8081
```

### Docker Container Usage

```bash
# Run tests with Allure listener
docker run --rm \
    -v $(pwd)/allure-results:/app/allure-results \
    rf-test-runner:latest \
    --listener allure_robotframework \
    tests/

# Generate report using container
docker run --rm \
    -v $(pwd)/allure-results:/app/allure-results \
    -v $(pwd)/allure-report:/app/allure-report \
    rf-test-runner:latest \
    bash -c "allure generate /app/allure-results -o /app/allure-report --clean"
```

## Jenkins Integration

### Pipeline Configuration

The Jenkinsfile includes an "Generate Allure Report" stage:

```groovy
stage('Generate Allure Report') {
    steps {
        sh '''
            # Generate Allure report using Docker container
            docker run --rm \
                -v ${ALLURE_RESULTS_DIR}:/app/allure-results \
                -v ${ALLURE_REPORT_DIR}:/app/allure-report \
                ${DOCKER_IMAGE}:${DOCKER_TAG} \
                bash -c "allure generate /app/allure-results -o /app/allure-report --clean"
        '''
    }
}
```

### Allure Plugin Setup

1. **Install Plugin**:
   - Navigate to Jenkins → Manage Jenkins → Plugins
   - Search for "Allure Jenkins Plugin"
   - Install and restart Jenkins

2. **Configure Allure Tool**:
   - Navigate to Jenkins → Manage Jenkins → Tools
   - Add Allure Commandline
   - Name: "Allure"
   - Install automatically from GitHub (2.25.0)

3. **View Reports**:
   - Reports appear on build page under "Allure Report" link
   - Historical trends maintained across builds

## Report Features

### Overview Tab

- **Pass/Fail Summary**: Total tests, pass rate, failure rate
- **Test Duration**: Total time, average time per test
- **Environment**: Platform, framework version, build info
- **Executor**: Jenkins build number, URL, branch

### Suites Tab

Hierarchical view of test suites and test cases:

```
RF Functional Tests
├─ TC001: Equipment Connectivity [PASSED]
├─ TC002: Spectrum Analyzer Initialization [PASSED]
├─ TC003: Signal Generator Initialization [FAILED]
│   ├─ Error: Connection timeout
│   ├─ Screenshot: failure-screenshot.png
│   └─ Log: test-execution.log
└─ TC004: Signal Generator Output [SKIPPED]
```

### Graphs Tab

- **Status Chart**: Pie chart of pass/fail/skip
- **Severity Chart**: Distribution by severity level
- **Duration Chart**: Test execution time distribution
- **Retry Trend**: Shows test retries

### Timeline Tab

Gantt chart showing:
- Test execution sequence
- Parallel execution (if any)
- Test duration visualization
- Overlap identification

### Behaviors Tab

BDD-style view (if using Behavior-driven keywords):
- Features
- Stories
- Scenarios

### Categories Tab

Automatic failure classification:
- Equipment Connection Failures (e.g., 3 tests)
- SCPI Command Errors (e.g., 2 tests)
- Measurement Errors (e.g., 1 test)

### Trends

Historical analysis across builds:
- Pass/fail trend line
- Duration trend
- Flaky test identification
- Success rate over time

## Customization

### Adding Severity to Tests

In Robot Framework tests, add tags:

```robot
*** Test Cases ***
TC001 Equipment Connectivity
    [Tags]    critical    smoke
    [Documentation]    Verify connection to all RF equipment
    # Severity derived from tags: critical = blocker
    ...
```

Severity mapping:
- `critical` tag → blocker severity
- `high` tag → critical severity
- `medium` tag → normal severity (default)
- `low` tag → minor severity
- `trivial` tag → trivial severity

### Adding Links to Tests

Link to issue tracker or test management:

```robot
*** Settings ***
Metadata    Issue    https://jira.company.com/browse/RF-123
Metadata    TMS      https://testmanagement.company.com/test/456
```

### Custom Attachments

Attach additional files to test results:

```robot
*** Keywords ***
Capture Equipment State
    ${state}=    Query Equipment    *IDN?
    Create File    ${OUTPUT_DIR}/equipment_state.txt    ${state}
    # File automatically attached to Allure report
```

### Environment Information

Add dynamic environment info:

```python
# In network_vars.py or test setup
import os
os.environ['ALLURE_ENV_EQUIPMENT_VERSION'] = get_equipment_version()
os.environ['ALLURE_ENV_LAB_LOCATION'] = 'Building A, Floor 2'
```

## Best Practices

### 1. Meaningful Test Names

```robot
# Good
TC001 Verify Spectrum Analyzer Connection And Identity Query

# Bad
TC001 Test1
```

### 2. Detailed Documentation

```robot
*** Test Cases ***
TC003 Measure Signal Power At 2.4 GHz
    [Documentation]    Configures signal generator to output -10dBm at 2.4GHz,
    ...                then measures power using spectrum analyzer.
    ...                Expected power: -10dBm ± 1dB
    [Tags]    measurement    critical
```

### 3. Capture Evidence on Failure

```robot
*** Keywords ***
Measure Signal Power
    [Arguments]    ${expected_power}
    ${actual_power}=    Query Equipment    :CALC:MARK:Y?
    Run Keyword If    '${TEST_STATUS}' == 'FAIL'
    ...    Capture Screenshot
    ...    AND    Save Spectrum Analyzer Trace
```

### 4. Use Categories Wisely

Ensure failure messages are descriptive:

```robot
# Good
Run Keyword And Expect Error    Connection timeout: Could not reach equipment at 192.168.50.10
...    Connect To Equipment    192.168.50.10

# Bad
Run Keyword And Expect Error    Error
...    Connect To Equipment
```

### 5. Clean Up Allure Results

Old results should be cleaned:

```bash
# In Jenkinsfile initialization
rm -rf ${ALLURE_RESULTS_DIR}/*
```

## Troubleshooting

### Issue: No Allure Results Generated

**Symptoms**: `allure-results/` directory is empty

**Solutions**:
1. Verify listener is enabled: `--listener allure_robotframework`
2. Check allure-robotframework is installed: `pip list | grep allure`
3. Ensure output directory is writable
4. Check Robot Framework logs for listener errors

### Issue: Report Generation Fails

**Symptoms**: `allure generate` command fails

**Solutions**:
1. Verify Java is installed: `java -version`
2. Check Allure CLI is installed: `allure --version`
3. Verify allure-results contains valid JSON files
4. Check disk space: `df -h`

### Issue: History Not Working

**Symptoms**: Trends tab shows no historical data

**Solutions**:
1. Copy `allure-report/history` to next run's `allure-results/history`:
   ```bash
   cp -r allure-report/history allure-results/history
   ```
2. Jenkins plugin maintains this automatically
3. Ensure `allure.results.history.enabled=true` in config

### Issue: Screenshots Not Attached

**Symptoms**: Failure shows no screenshot

**Solutions**:
1. Verify Robot Framework screenshot library is imported
2. Check screenshot is saved to correct directory
3. Ensure file extension is supported (.png, .jpg, .txt, .log)
4. Verify file size is reasonable (<10MB recommended)

### Issue: Jenkins Plugin Shows "No Results"

**Symptoms**: Allure report link shows empty page

**Solutions**:
1. Verify `allure` step in Jenkinsfile:
   ```groovy
   allure([
       includeProperties: false,
       results: [[path: 'allure-results']]
   ])
   ```
2. Check allure-results path is correct relative to workspace
3. Verify plugin is installed and configured
4. Check Jenkins logs: `Manage Jenkins → System Log`

## Performance Considerations

### Report Size

- Limit attachments to essential files
- Compress large logs before attaching
- Clean old screenshots after archival
- Use history retention limit (max 20 runs recommended)

### Generation Time

Typical generation times:
- 10 tests: ~5 seconds
- 100 tests: ~15 seconds
- 1000 tests: ~60 seconds

Factors affecting speed:
- Number of attachments
- Size of screenshots
- Historical data volume

## Integration with Other Tools

### Elasticsearch

Results uploaded to Elasticsearch provide:
- Time-series analysis
- Cross-project aggregation
- Custom dashboards in Kibana

Allure provides:
- Rich interactive reports
- Detailed test execution view
- Beautiful visualizations

Use both for comprehensive analysis.

### Robot Framework Reports

Robot Framework generates:
- `log.html`: Detailed execution log
- `report.html`: Summary report
- `output.xml`: Machine-readable results

Allure provides:
- Better visual design
- Historical trends
- Automatic categorization
- Interactive features

Archive both in Jenkins for complete visibility.

## Security Considerations

### Report Access

- Allure reports contain test execution details
- May include IP addresses, equipment info
- Restrict Jenkins access appropriately
- Consider redacting sensitive data

### Credentials

- Never log credentials in test output
- Use Robot Framework variable files for secrets
- Mask sensitive data in allure-results
- Review attachments before archival

## Advanced Features

### Custom Plugins

Allure supports custom plugins for extended functionality:
- Custom widgets
- Additional tabs
- Data aggregators

### Programmatic Report Generation

```python
from allure_robotframework import AllureListener

listener = AllureListener(output_dir='allure-results')
# Custom logic
```

### API Integration

Allure report data is accessible via JSON files in `data/` directory:
- `test-cases/*.json`: Individual test results
- `widgets.json`: Summary statistics
- `timeline.json`: Execution timeline

Parse these for custom integrations.

## Resources

- **Allure Documentation**: https://docs.qameta.io/allure/
- **Robot Framework Listener**: https://github.com/allure-framework/allure-python
- **Jenkins Plugin**: https://plugins.jenkins.io/allure-jenkins-plugin/
- **GitHub Releases**: https://github.com/allure-framework/allure2/releases

## Summary

Allure integration provides:

✅ Beautiful, interactive test reports
✅ Historical trend analysis
✅ Automatic failure categorization
✅ Rich visualizations and charts
✅ Screenshot and log attachments
✅ Jenkins integration for easy access
✅ Professional reporting for stakeholders

Combined with Elasticsearch/Kibana, this provides comprehensive test result analysis and reporting capabilities for the RF automation infrastructure.
