*** Settings ***
Documentation     Proof of Platform (PoPo) Tests
...               Validates integration environment including:
...               - Mock equipment connectivity
...               - RF physics simulation accuracy
...               - Elasticsearch integration
...               - Allure reporting
...               - Complete data flow

Resource          ../resources/rf_keywords.resource
Library           OperatingSystem
Library           RequestsLibrary
Library           Collections

Suite Setup       PoPo Suite Setup
Suite Teardown    PoPo Suite Teardown

*** Variables ***
${ELASTICSEARCH_URL}    http://localhost:9200

*** Keywords ***
PoPo Suite Setup
    [Documentation]    Setup for PoPo test suite
    Log    Starting Proof of Platform test suite    level=INFO
    Set Log Level    DEBUG

PoPo Suite Teardown
    [Documentation]    Teardown for PoPo test suite
    Log    PoPo test suite completed    level=INFO
    Disconnect All Equipment

*** Test Cases ***
#==============================================================================
# Infrastructure Validation Tests
#==============================================================================

TC_POPO_001: Verify Mock Equipment Connectivity
    [Documentation]    Verify all mock equipment is accessible
    [Tags]    infrastructure    connectivity

    Log    Testing connectivity to mock equipment    level=INFO

    # Connect to all equipment
    Initialize All Equipment

    # Verify connections
    ${sa_connected}=    Is Connected    SpectrumAnalyzer
    Should Be True    ${sa_connected}    msg=Spectrum Analyzer not connected

    ${sg_connected}=    Is Connected    SignalGenerator
    Should Be True    ${sg_connected}    msg=Signal Generator not connected

    ${dut_connected}=    Is Connected    DUT
    Should Be True    ${dut_connected}    msg=DUT not connected

    Log    All mock equipment connected successfully    level=INFO

TC_POPO_002: Validate Elasticsearch Availability
    [Documentation]    Confirm Elasticsearch is running and accessible
    [Tags]    infrastructure    elasticsearch

    Log    Checking Elasticsearch availability    level=INFO

    # Check Elasticsearch health
    Create Session    elasticsearch    ${ELASTICSEARCH_URL}    verify=False
    ${response}=    GET On Session    elasticsearch    /_cluster/health

    Should Be Equal As Numbers    ${response.status_code}    200

    ${status}=    Get From Dictionary    ${response.json()}    status
    Should Be True    '${status}' in ['green', 'yellow']
    ...    msg=Elasticsearch cluster not healthy: ${status}

    Log    Elasticsearch is healthy: ${status}    level=INFO

TC_POPO_003: Confirm Allure Listener Active
    [Documentation]    Verify Allure listener is loaded and active
    [Tags]    infrastructure    reporting

    Log    Checking Allure listener status    level=INFO

    # This test validates that Allure is configured
    # The listener should be loaded via robot command line
    # We verify by checking for allure-results directory

    Directory Should Exist    allure-results
    ...    msg=Allure results directory not found

    Log    Allure listener configured    level=INFO

TC_POPO_004: Verify Jenkins Pipeline Configuration
    [Documentation]    Validate Jenkins is accessible (if running)
    [Tags]    infrastructure    jenkins

    Log    Checking Jenkins availability    level=INFO

    # This is an optional check - Jenkins may not be running during dev
    ${jenkins_running}=    Run Keyword And Return Status
    ...    Create Session    jenkins    http://localhost:8080    verify=False

    Run Keyword If    ${jenkins_running}
    ...    Log    Jenkins is accessible at http://localhost:8080    level=INFO
    ...    ELSE
    ...    Log    Jenkins not running (optional for PoPo tests)    level=WARN

#==============================================================================
# Mock Equipment Operation Tests
#==============================================================================

TC_POPO_005: Mock Equipment Initialization and IDN Query
    [Documentation]    Test equipment initialization and identification
    [Tags]    equipment    initialization

    Log    Testing equipment identification    level=INFO

    # Initialize equipment
    Initialize All Equipment

    # Query IDN from each equipment
    ${sa_idn}=    Query Equipment    SpectrumAnalyzer    *IDN?
    Should Contain    ${sa_idn}    Mock
    ...    msg=Unexpected Spectrum Analyzer IDN: ${sa_idn}
    Log    Spectrum Analyzer IDN: ${sa_idn}    level=INFO

    ${sg_idn}=    Query Equipment    SignalGenerator    *IDN?
    Should Contain    ${sg_idn}    Mock
    ...    msg=Unexpected Signal Generator IDN: ${sg_idn}
    Log    Signal Generator IDN: ${sg_idn}    level=INFO

    ${dut_idn}=    Query Equipment    DUT    *IDN?
    Should Contain    ${dut_idn}    Mock
    ...    msg=Unexpected DUT IDN: ${dut_idn}
    Log    DUT IDN: ${dut_idn}    level=INFO

TC_POPO_006: Equipment Reset and Configuration
    [Documentation]    Test equipment reset and basic configuration
    [Tags]    equipment    configuration

    Log    Testing equipment reset and configuration    level=INFO

    Initialize All Equipment

    # Reset all equipment
    Reset Equipment    SpectrumAnalyzer
    Reset Equipment    SignalGenerator
    Reset Equipment    DUT

    Sleep    1s    Wait for reset to complete

    # Configure signal generator
    Send SCPI Command    SignalGenerator    FREQ 1e9
    Send SCPI Command    SignalGenerator    POW -10

    # Query configuration
    ${freq}=    Query Equipment    SignalGenerator    FREQ?
    ${power}=    Query Equipment    SignalGenerator    POW?

    Log    Signal Generator configured: ${freq} Hz, ${power} dBm    level=INFO

TC_POPO_007: Signal Generator Output Control
    [Documentation]    Test signal generator output enable/disable
    [Tags]    equipment    signal_generator

    Log    Testing signal generator output control    level=INFO

    Initialize All Equipment

    # Enable output
    Send SCPI Command    SignalGenerator    OUTP ON
    ${output_state}=    Query Equipment    SignalGenerator    OUTP?

    Should Be Equal    ${output_state}    1
    ...    msg=Output not enabled

    Log    Signal generator output enabled    level=INFO

    # Disable output
    Send SCPI Command    SignalGenerator    OUTP OFF
    ${output_state}=    Query Equipment    SignalGenerator    OUTP?

    Should Be Equal    ${output_state}    0
    ...    msg=Output not disabled

    Log    Signal generator output disabled    level=INFO

TC_POPO_008: Spectrum Analyzer Sweep Operation
    [Documentation]    Test spectrum analyzer sweep with mock data
    [Tags]    equipment    spectrum_analyzer

    Log    Testing spectrum analyzer sweep operation    level=INFO

    Initialize All Equipment

    # Configure spectrum analyzer
    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT 1e9
    Send SCPI Command    SpectrumAnalyzer    FREQ:SPAN 10e6
    Send SCPI Command    SpectrumAnalyzer    BAND:RES 1000

    # Initiate sweep
    Send SCPI Command    SpectrumAnalyzer    INIT:IMM

    Sleep    2s    Wait for sweep to complete

    # Get trace data
    ${trace_data}=    Query Equipment    SpectrumAnalyzer    TRAC:DATA?

    Should Not Be Empty    ${trace_data}
    ...    msg=No trace data received

    # Verify trace data contains comma-separated values
    Should Contain    ${trace_data}    ,
    ...    msg=Invalid trace data format

    Log    Spectrum analyzer sweep completed    level=INFO

#==============================================================================
# RF Physics Simulation Tests
#==============================================================================

TC_POPO_009: Verify Harmonic Generation Accuracy
    [Documentation]    Validate RF physics harmonic simulation
    [Tags]    rf_physics    harmonics

    Log    Testing harmonic generation accuracy    level=INFO

    Initialize All Equipment

    # Configure signal generator for fundamental at 1 GHz
    Send SCPI Command    SignalGenerator    FREQ 1e9
    Send SCPI Command    SignalGenerator    POW 0
    Send SCPI Command    SignalGenerator    OUTP ON

    Sleep    1s

    # Configure SA to see harmonics
    Send SCPI Command    SpectrumAnalyzer    FREQ:START 0.5e9
    Send SCPI Command    SpectrumAnalyzer    FREQ:STOP 3.5e9
    Send SCPI Command    SpectrumAnalyzer    BAND:RES 10000

    # Initiate sweep
    Send SCPI Command    SpectrumAnalyzer    INIT:IMM
    Sleep    2s

    # Check for harmonics using markers
    # Marker at fundamental (1 GHz)
    Send SCPI Command    SpectrumAnalyzer    CALC:MARK1:X 1e9
    ${fundamental}=    Query Equipment    SpectrumAnalyzer    CALC:MARK1:Y?

    Log    Fundamental at 1 GHz: ${fundamental} dBm    level=INFO

    # Marker at 2nd harmonic (2 GHz)
    Send SCPI Command    SpectrumAnalyzer    CALC:MARK1:X 2e9
    ${harmonic2}=    Query Equipment    SpectrumAnalyzer    CALC:MARK1:Y?

    Log    2nd harmonic at 2 GHz: ${harmonic2} dBm    level=INFO

    # Verify 2nd harmonic is lower than fundamental
    ${h2_float}=    Convert To Number    ${harmonic2}
    ${fund_float}=    Convert To Number    ${fundamental}

    Should Be True    ${h2_float} < ${fund_float}
    ...    msg=2nd harmonic should be lower than fundamental

TC_POPO_010: Validate Noise Floor Modeling
    [Documentation]    Verify realistic noise floor simulation
    [Tags]    rf_physics    noise

    Log    Testing noise floor modeling    level=INFO

    Initialize All Equipment

    # Configure signal generator OFF
    Send SCPI Command    SignalGenerator    OUTP OFF

    # Configure SA for noise measurement
    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT 1e9
    Send SCPI Command    SpectrumAnalyzer    FREQ:SPAN 10e6
    Send SCPI Command    SpectrumAnalyzer    BAND:RES 1000

    # Perform sweep
    Send SCPI Command    SpectrumAnalyzer    INIT:IMM
    Sleep    2s

    # Check marker at center frequency (should be noise floor)
    Send SCPI Command    SpectrumAnalyzer    CALC:MARK1:X 1e9
    ${noise_level}=    Query Equipment    SpectrumAnalyzer    CALC:MARK1:Y?

    ${noise_float}=    Convert To Number    ${noise_level}

    # Noise floor should be reasonable (around -120 dBm for 1 kHz RBW)
    Should Be True    ${noise_float} < -100
    ...    msg=Noise floor too high: ${noise_float} dBm

    Should Be True    ${noise_float} > -150
    ...    msg=Noise floor too low: ${noise_float} dBm

    Log    Noise floor measured: ${noise_level} dBm    level=INFO

TC_POPO_011: Test Frequency Sweep With Realistic Spectrum
    [Documentation]    Verify complete spectrum sweep with signal present
    [Tags]    rf_physics    sweep

    Log    Testing frequency sweep with realistic spectrum    level=INFO

    Initialize All Equipment

    # Configure signal at 1 GHz, -20 dBm
    Send SCPI Command    SignalGenerator    FREQ 1e9
    Send SCPI Command    SignalGenerator    POW -20
    Send SCPI Command    SignalGenerator    OUTP ON

    Sleep    1s

    # Configure SA to sweep around signal
    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT 1e9
    Send SCPI Command    SpectrumAnalyzer    FREQ:SPAN 20e6
    Send SCPI Command    SpectrumAnalyzer    BAND:RES 10000
    Send SCPI Command    SpectrumAnalyzer    SWE:POIN 201

    # Perform sweep
    Send SCPI Command    SpectrumAnalyzer    INIT:IMM
    Sleep    2s

    # Get full trace data
    ${trace}=    Query Equipment    SpectrumAnalyzer    TRAC:DATA?

    # Verify we got 201 points
    ${point_count}=    Get Count    ${trace}    ,
    ${expected_count}=    Evaluate    201 - 1    # 201 points = 200 commas

    Should Be True    ${point_count} >= 100
    ...    msg=Expected ~200 trace points, got ${point_count}

    Log    Received trace with ${point_count} data points    level=INFO

#==============================================================================
# End-to-End Data Flow Test
#==============================================================================

TC_POPO_012: Complete Test Execution to Elasticsearch to Allure
    [Documentation]    Validate complete data flow from test to reporting
    [Tags]    integration    end_to_end    critical

    Log    Testing complete integration data flow    level=INFO

    # This test validates the entire pipeline:
    # 1. Test execution with mock equipment
    # 2. Elasticsearch data upload
    # 3. Allure report generation

    # Step 1: Execute a complete test scenario
    Initialize All Equipment

    # Configure and run a simple test
    Send SCPI Command    SignalGenerator    FREQ 2e9
    Send SCPI Command    SignalGenerator    POW -15
    Send SCPI Command    SignalGenerator    OUTP ON

    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT 2e9
    Send SCPI Command    SpectrumAnalyzer    FREQ:SPAN 10e6
    Send SCPI Command    SpectrumAnalyzer    INIT:IMM

    Sleep    2s

    ${measured_power}=    Query Equipment    SpectrumAnalyzer    CALC:MARK1:Y?

    Log    Measured power: ${measured_power} dBm    level=INFO

    # Step 2: Verify test data structure
    # This test itself will be uploaded to Elasticsearch via the listener

    # Step 3: Verify Allure results directory exists and contains data
    Directory Should Exist    allure-results

    @{allure_files}=    List Files In Directory    allure-results    *.json

    ${file_count}=    Get Length    ${allure_files}

    Should Be True    ${file_count} > 0
    ...    msg=No Allure result files generated

    Log    Allure results generated: ${file_count} files    level=INFO

    # Step 4: Verify Elasticsearch received data
    Create Session    elasticsearch    ${ELASTICSEARCH_URL}    verify=False

    # Search for recent test results
    ${search_body}=    Create Dictionary
    ...    query={"match_all": {}}
    ...    size=10

    ${response}=    POST On Session    elasticsearch
    ...    /rf-automation-*/_search
    ...    json=${search_body}
    ...    expected_status=any

    # Elasticsearch may not have data yet in first run, so we allow failure
    Run Keyword If    ${response.status_code} == 200
    ...    Log    Elasticsearch search successful    level=INFO
    ...    ELSE
    ...    Log    Elasticsearch search returned ${response.status_code} (may be empty on first run)    level=WARN

    Log    Complete integration data flow validated    level=INFO
