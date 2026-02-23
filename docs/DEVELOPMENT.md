# Development Guide - RF Automation Infrastructure

Guide for developers and test engineers working with the RF automation system.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Workflow](#development-workflow)
3. [Writing Robot Framework Tests](#writing-robot-framework-tests)
4. [Creating Custom Keywords](#creating-custom-keywords)
5. [Adding New Equipment](#adding-new-equipment)
6. [Testing Locally](#testing-locally)
7. [Debugging](#debugging)
8. [Best Practices](#best-practices)
9. [Code Review Guidelines](#code-review-guidelines)

---

## Getting Started

### Prerequisites

- Git installed and configured
- Python 3.11+
- Docker installed (for local testing)
- SSH access to NUC server
- Access to Git repository

### Development Environment Setup

```bash
# Clone repository
git clone <repository-url>
cd Fully_Product_Automation

# Create virtual environment
python3 -m venv venv
source venv/bin/activate    # Linux/Mac
# OR
venv\Scripts\activate       # Windows

# Install dependencies
pip install -r requirements.txt

# Install Robot Framework IDE support (optional)
pip install robotframework-lsp
pip install robotframework-tidy
```

### IDE Setup

**VS Code** (Recommended):

Install extensions:
- Robot Framework Language Server
- Python
- Docker
- GitLens

**PyCharm**:

Install plugins:
- Robot Framework Support
- Docker Integration

---

## Development Workflow

### Branching Strategy

```
main (production)
  │
  ├── develop (integration)
  │     │
  │     ├── feature/add-new-rf-test
  │     ├── feature/calibration-improvements
  │     └── feature/new-equipment-support
  │
  └── hotfix/critical-bug-fix
```

### Workflow Steps

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/my-new-feature
   ```

2. **Develop and Test Locally**
   ```bash
   # Make changes
   vim tests/my_new_test.robot

   # Test locally
   robot --outputdir results tests/my_new_test.robot

   # Verify Docker build
   docker build -t rf-test-runner .
   docker run --rm --network host \
       -v $(pwd)/results:/app/results \
       rf-test-runner --outputdir results tests/my_new_test.robot
   ```

3. **Commit Changes**
   ```bash
   git add tests/my_new_test.robot
   git commit -m "Add new RF power sweep test"
   ```

4. **Push and Create Pull Request**
   ```bash
   git push origin feature/my-new-feature
   # Create PR to develop branch via GitHub/GitLab
   ```

5. **Code Review**
   - Automated tests run via Jenkins
   - Manual code review by team member
   - Address feedback

6. **Merge to Develop**
   - Squash commits if needed
   - Merge PR

7. **Deploy to Main** (after testing in develop)
   ```bash
   git checkout main
   git merge develop
   git push origin main
   # Automatic deployment to production via Jenkins
   ```

---

## Writing Robot Framework Tests

### Test File Structure

```robot
*** Settings ***
Documentation     Brief description of test suite
...               Can span multiple lines
...               Explain the purpose and scope

Library           RequestsLibrary
Library           Collections
Resource          ../resources/rf_keywords.resource

Suite Setup       Initialize Test Suite
Suite Teardown    Cleanup Test Suite
Test Timeout      5 minutes

*** Variables ***
${TEST_FREQUENCY}    1000000000    # 1 GHz
${TEST_POWER}       -10           # -10 dBm

*** Test Cases ***
TC001: Descriptive Test Name
    [Documentation]    What this test verifies
    [Tags]    category    priority

    Log    Starting test    console=True

    # Test steps
    Connect To Equipment
    Configure Settings
    Verify Results

*** Keywords ***
Custom Keyword Name
    [Documentation]    What this keyword does
    [Arguments]    ${param1}    ${param2}

    # Keyword implementation
    Log    Executing custom keyword
```

### Test Case Best Practices

#### 1. Naming Convention

```robot
# Good: Clear, descriptive names
TC001: Verify Signal Generator Frequency Accuracy
TC002: Measure Harmonic Distortion at 1GHz
TC003: DUT Insertion Loss Measurement

# Bad: Vague names
Test1
TestFrequency
Check Equipment
```

#### 2. Documentation

```robot
TC001: Verify Signal Generator Frequency Accuracy
    [Documentation]    Verifies that the signal generator outputs
    ...                the correct frequency within ±1 MHz tolerance
    ...                across the frequency range 100 MHz - 6 GHz.
    ...
    ...                Test Steps:
    ...                1. Set signal generator to test frequency
    ...                2. Measure actual frequency with spectrum analyzer
    ...                3. Calculate error
    ...                4. Verify error < tolerance
    ...
    ...                Pass Criteria: Frequency error < 1 MHz
    [Tags]    signal_generator    frequency    critical
```

#### 3. Tags Usage

```robot
# Category tags
[Tags]    smoke                  # Quick verification tests
[Tags]    regression             # Full regression suite
[Tags]    calibration            # Calibration tests
[Tags]    functional             # Functional tests

# Priority tags
[Tags]    critical               # Must pass
[Tags]    high_priority          # Important
[Tags]    low_priority           # Nice to have

# Equipment tags
[Tags]    spectrum_analyzer
[Tags]    signal_generator
[Tags]    dut

# Feature tags
[Tags]    frequency    power    harmonic    sweep
```

Run tests by tags:
```bash
# Run only critical tests
robot --include critical tests/

# Run smoke tests
robot --include smoke tests/

# Run spectrum analyzer tests
robot --include spectrum_analyzer tests/

# Exclude low priority
robot --exclude low_priority tests/
```

#### 4. Variables and Configuration

```robot
*** Variables ***
# Use descriptive names with units in comments
${TEST_FREQUENCY}         1000000000    # 1 GHz in Hz
${TEST_POWER}            -10           # -10 dBm
${SWEEP_START}           100000000     # 100 MHz
${SWEEP_STOP}            6000000000    # 6 GHz

# Use lists for test data
@{POWER_LEVELS}          -20    -10    0    5    10
@{TEST_FREQUENCIES}      100e6  500e6  1e9  2e9  3e9

# Use dictionaries for complex config (via Python)
&{EQUIPMENT}             sa=SpectrumAnalyzer    sg=SignalGenerator
```

#### 5. Error Handling

```robot
*** Test Cases ***
TC001: Robust Test with Error Handling
    [Documentation]    Example of proper error handling

    # Use TRY-EXCEPT for expected failures
    TRY
        Connect To Equipment
    EXCEPT    Connection timeout
        Log    Equipment not responding, retrying...    WARN
        Sleep    5s
        Connect To Equipment
    END

    # Use Run Keyword And Return Status for optional steps
    ${screenshot_ok}=    Run Keyword And Return Status
    ...    Capture Equipment Screenshot

    Run Keyword If    not ${screenshot_ok}
    ...    Log    Screenshot not available    WARN

    [Teardown]    Run Keyword If Test Failed
    ...    Log Equipment Debug Info
```

#### 6. Data-Driven Testing

```robot
*** Test Cases ***
Frequency Sweep Test
    [Documentation]    Test multiple frequencies
    [Template]    Test Single Frequency

    # Test data
    100000000     # 100 MHz
    500000000     # 500 MHz
    1000000000    # 1 GHz
    2000000000    # 2 GHz

*** Keywords ***
Test Single Frequency
    [Arguments]    ${frequency}

    Set Signal Generator Frequency    ${frequency}
    ${measured}=    Measure Frequency
    Should Be Equal    ${frequency}    ${measured}
    ...    precision=1000000    msg=Frequency out of tolerance
```

### Example: Complete Test Case

```robot
*** Test Cases ***
TC_PWR_001: Signal Generator Power Sweep
    [Documentation]    Verify signal generator power accuracy across range
    ...
    ...                Test Configuration:
    ...                - Frequency: 1 GHz
    ...                - Power Range: -20 to +10 dBm (5 dB steps)
    ...                - Tolerance: ±0.5 dB
    ...
    ...                Pass Criteria:
    ...                All power measurements within tolerance
    [Tags]    signal_generator    power    sweep    critical

    [Setup]    Setup Power Sweep Test

    # Test configuration
    ${test_frequency}=    Set Variable    ${1e9}
    @{power_levels}=    Create List    -20    -15    -10    -5    0    5    10

    Log    Testing power accuracy at ${test_frequency} Hz    console=True

    # Configure equipment
    Set Signal Generator Frequency    ${test_frequency}
    Set Spectrum Analyzer Center Frequency    ${test_frequency}
    Set Spectrum Analyzer Span    ${10e6}

    # Perform sweep
    FOR    ${set_power}    IN    @{power_levels}
        Log    Testing ${set_power} dBm    console=True

        Set Signal Generator Power    ${set_power}
        Enable Signal Generator Output
        Sleep    2s    # Allow signal to stabilize

        ${measured_power}=    Measure Peak Power
        ${error}=    Evaluate    abs(${measured_power} - ${set_power})

        Log    Set: ${set_power} dBm, Measured: ${measured_power} dBm, Error: ${error} dB
        ...    level=INFO

        Should Be True    ${error} <= 0.5
        ...    msg=Power error ${error} dB exceeds tolerance at ${set_power} dBm
    END

    [Teardown]    Teardown Power Sweep Test

*** Keywords ***
Setup Power Sweep Test
    Connect To Signal Generator
    Connect To Spectrum Analyzer
    Reset Equipment    SignalGenerator
    Reset Equipment    SpectrumAnalyzer

Teardown Power Sweep Test
    Disable Signal Generator Output
    Capture Equipment Screenshot    power_sweep_final
    Log    Power sweep test complete    level=INFO
```

---

## Creating Custom Keywords

### Keyword Design Principles

1. **Single Responsibility**: One keyword, one purpose
2. **Descriptive Names**: Clear what the keyword does
3. **Proper Documentation**: Explain usage and parameters
4. **Return Values**: Document what is returned
5. **Error Handling**: Handle failures gracefully

### Example: Well-Designed Keyword

```robot
*** Keywords ***
Measure Peak Power With Retry
    [Documentation]    Measure peak power using spectrum analyzer with automatic retry
    ...
    ...                Performs measurement with configurable retry logic to handle
    ...                transient failures or signal instability.
    ...
    ...                Arguments:
    ...                - max_attempts: Maximum number of measurement attempts (default: 3)
    ...                - delay: Delay between attempts in seconds (default: 2)
    ...
    ...                Returns:
    ...                - Peak power in dBm
    ...
    ...                Raises:
    ...                - RuntimeError if all attempts fail
    ...
    ...                Example:
    ...                ${power}=    Measure Peak Power With Retry    max_attempts=5
    [Arguments]    ${max_attempts}=3    ${delay}=2

    FOR    ${attempt}    IN RANGE    1    ${max_attempts}+1
        Log    Measurement attempt ${attempt}/${max_attempts}    level=DEBUG

        TRY
            Send SCPI Command    SpectrumAnalyzer    INIT:IMM
            Sleep    ${delay}s

            ${power}=    Query Equipment    SpectrumAnalyzer    CALC:MARK:MAX;MARK:Y?
            ${power}=    Convert To Number    ${power}

            # Validate result is reasonable
            Should Be True    ${power} >= -150 and ${power} <= 50
            ...    msg=Power reading ${power} dBm out of valid range

            Log    Measured power: ${power} dBm    level=INFO
            [Return]    ${power}

        EXCEPT    AS    ${error}
            Log    Attempt ${attempt} failed: ${error}    level=WARN

            Run Keyword If    ${attempt} < ${max_attempts}
            ...    Sleep    ${delay}s
            ...    ELSE
            ...    Fail    All ${max_attempts} measurement attempts failed
        END
    END
```

### Organizing Keywords

**File**: `resources/rf_keywords.resource`

Structure keywords by category:

```robot
*** Keywords ***
#==============================================================================
# Connection Keywords
#==============================================================================

Connect To Spectrum Analyzer
    [Documentation]    ...

Connect To Signal Generator
    [Documentation]    ...

#==============================================================================
# Configuration Keywords
#==============================================================================

Configure Spectrum Analyzer
    [Documentation]    ...

Set Signal Generator Frequency
    [Documentation]    ...

#==============================================================================
# Measurement Keywords
#==============================================================================

Measure Peak Power
    [Documentation]    ...

Measure Peak Frequency
    [Documentation]    ...

#==============================================================================
# Utility Keywords
#==============================================================================

Wait For Signal Stabilization
    [Documentation]    ...

Validate Measurement Range
    [Documentation]    ...
```

---

## Adding New Equipment

### Step 1: Update Configuration

Edit `resources/network_vars.py`:

```python
EQUIPMENT_LIST = {
    # Existing equipment
    "SpectrumAnalyzer": "192.168.50.10",
    "SignalGenerator": "192.168.50.11",
    "DUT": "192.168.50.20",

    # New equipment
    "PowerMeter": "192.168.50.14",
    "Attenuator": "192.168.50.15",
}
```

### Step 2: Create Keywords

Add to `resources/rf_keywords.resource`:

```robot
*** Keywords ***
Connect To Power Meter
    [Documentation]    Establish connection to RF power meter

    ${ip}=    Get Equipment IP    PowerMeter

    Log    Connecting to Power Meter at ${ip}    level=INFO

    # Create session
    # ...

    # Verify connection
    ${idn}=    Query Equipment    PowerMeter    *IDN?
    Log    Power Meter: ${idn}    level=INFO

Set Power Meter Frequency
    [Documentation]    Configure power meter frequency for measurement
    [Arguments]    ${frequency}

    Log    Setting power meter frequency: ${frequency} Hz    level=DEBUG

    Send SCPI Command    PowerMeter    SENS:FREQ ${frequency}

Measure Power With Power Meter
    [Documentation]    Measure power using power meter
    [Return]    Power in dBm

    Send SCPI Command    PowerMeter    INIT:IMM
    Sleep    1s

    ${power}=    Query Equipment    PowerMeter    FETCH?
    ${power}=    Convert To Number    ${power}

    Log    Power Meter Reading: ${power} dBm    level=INFO

    [Return]    ${power}
```

### Step 3: Write Tests

Create `tests/power_meter.robot`:

```robot
*** Settings ***
Documentation     Power Meter Test Suite

Resource          ../resources/rf_keywords.resource

Suite Setup       Connect To Power Meter
Suite Teardown    Disconnect All Equipment

*** Test Cases ***
TC001: Power Meter Basic Operation
    [Documentation]    Verify power meter basic functionality
    [Tags]    power_meter    smoke

    ${idn}=    Query Equipment    PowerMeter    *IDN?
    Should Contain    ${idn}    Power Meter

    Set Power Meter Frequency    ${1e9}
    ${power}=    Measure Power With Power Meter

    Should Be True    ${power} >= -100 and ${power} <= 50
```

---

## Testing Locally

### Run Single Test

```bash
robot --outputdir results tests/my_test.robot
```

### Run Specific Test Case

```bash
robot --test "TC001: Verify Equipment Connectivity" tests/rf_functional.robot
```

### Run with Tags

```bash
# Run critical tests only
robot --include critical --outputdir results tests/

# Run smoke tests
robot --include smoke --outputdir results tests/

# Exclude slow tests
robot --exclude slow --outputdir results tests/
```

### Verbose Output

```bash
robot --loglevel DEBUG --outputdir results tests/
```

### Dry Run (Syntax Check)

```bash
robot --dryrun tests/
```

### Docker Testing

```bash
# Build image
docker build -t rf-test-runner .

# Run tests in container
docker run --rm --network host \
    -v $(pwd)/results:/app/results \
    rf-test-runner --outputdir results tests/my_test.robot
```

---

## Debugging

### Enable Debug Logging

```robot
*** Settings ***
Library    Collections
Library    RequestsLibrary    WITH NAME    Requests

# Set log level to DEBUG
Set Log Level    DEBUG
```

### Capture Screenshots

```robot
*** Keywords ***
Debug Equipment State
    [Documentation]    Capture equipment state for debugging

    Log    === Equipment Debug Info ===    console=True

    # Query equipment status
    ${sa_status}=    Query Equipment    SpectrumAnalyzer    SYST:ERR?
    ${sg_status}=    Query Equipment    SignalGenerator    SYST:ERR?

    Log    SA Status: ${sa_status}    level=INFO
    Log    SG Status: ${sg_status}    level=INFO

    # Capture screenshots (if supported)
    Run Keyword And Ignore Error    Capture Equipment Screenshot    debug

    Log    === End Debug Info ===    console=True
```

### Interactive Debugging

```bash
# Install ipdb
pip install ipdb

# Add breakpoint in Python code
import ipdb; ipdb.set_trace()
```

### Test Teardown with Debug

```robot
*** Test Cases ***
My Test
    [Documentation]    Test with debug on failure

    # Test steps
    ...

    [Teardown]    Run Keyword If Test Failed
    ...    Debug Equipment State
```

---

## Best Practices

### 1. Test Independence

Each test should be independent and not rely on previous tests:

```robot
# Good: Independent tests
*** Test Cases ***
TC001: Test A
    [Setup]    Initialize Equipment
    # Test logic
    [Teardown]    Reset Equipment

TC002: Test B
    [Setup]    Initialize Equipment
    # Test logic
    [Teardown]    Reset Equipment

# Bad: Dependent tests
TC001: Test A
    Initialize Equipment
    # Test logic
    # No teardown - state carries over

TC002: Test B
    # Assumes equipment still initialized from TC001
    # Will fail if TC001 skipped
```

### 2. Magic Numbers

Avoid magic numbers, use variables:

```robot
# Good: Named variables
*** Variables ***
${POWER_TOLERANCE}    0.5    # dB
${FREQ_TOLERANCE}     1e6    # Hz

*** Test Cases ***
Test Power
    ${error}=    Calculate Error
    Should Be True    ${error} <= ${POWER_TOLERANCE}

# Bad: Magic numbers
Test Power
    ${error}=    Calculate Error
    Should Be True    ${error} <= 0.5    # What is 0.5?
```

### 3. DRY (Don't Repeat Yourself)

```robot
# Good: Reusable keyword
*** Keywords ***
Verify Power At Frequency
    [Arguments]    ${frequency}    ${expected_power}

    Set Signal Generator Frequency    ${frequency}
    ${measured}=    Measure Power
    Should Be Equal    ${measured}    ${expected_power}    precision=0.5

*** Test Cases ***
Test Multiple Frequencies
    Verify Power At Frequency    1e9    -10
    Verify Power At Frequency    2e9    -10
    Verify Power At Frequency    3e9    -10

# Bad: Repeated code
Test Multiple Frequencies
    Set Signal Generator Frequency    1e9
    ${measured}=    Measure Power
    Should Be Equal    ${measured}    -10    precision=0.5

    Set Signal Generator Frequency    2e9
    ${measured}=    Measure Power
    Should Be Equal    ${measured}    -10    precision=0.5

    # ... repeated many times
```

### 4. Meaningful Assertions

```robot
# Good: Clear failure messages
Should Be True    ${error} <= ${TOLERANCE}
...    msg=Power error ${error} dB exceeds tolerance ${TOLERANCE} dB at ${frequency} Hz

# Bad: No context
Should Be True    ${error} <= ${TOLERANCE}
```

### 5. Timeouts

```robot
# Good: Appropriate timeouts
*** Settings ***
Test Timeout    5 minutes    # Default for all tests

*** Test Cases ***
Quick Test
    [Timeout]    30 seconds    # Override for quick test
    ...

Long Calibration Test
    [Timeout]    30 minutes    # Override for long test
    ...

# Bad: No timeouts (tests can hang indefinitely)
```

---

## Code Review Guidelines

### Checklist for Reviewers

- [ ] Test names are descriptive
- [ ] Documentation is clear and complete
- [ ] Tags are appropriate
- [ ] Variables are well-named with units
- [ ] No magic numbers
- [ ] Error handling is present
- [ ] Test setup/teardown are correct
- [ ] Tests are independent
- [ ] Code follows DRY principle
- [ ] Assertions have meaningful messages
- [ ] Timeouts are set appropriately
- [ ] No sensitive data (passwords, IPs) hardcoded
- [ ] Docker build succeeds
- [ ] Tests pass locally

### Review Process

1. **Automated Checks**: Jenkins runs tests automatically
2. **Manual Review**: Team member reviews code
3. **Feedback**: Reviewer provides constructive feedback
4. **Revision**: Author addresses feedback
5. **Approval**: Reviewer approves PR
6. **Merge**: Changes merged to target branch

---

**Happy Testing!**

For questions or suggestions, contact the automation team or create an issue in the repository.
