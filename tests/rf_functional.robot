*** Settings ***
Documentation     RF Equipment Functional Test Suite
...               Comprehensive testing of RF equipment functionality
...               including signal generation, spectrum analysis, and DUT testing.

Library           RequestsLibrary
Library           Collections
Library           String
Library           OperatingSystem
Library           DateTime

Resource          ../resources/rf_keywords.resource

Suite Setup       Suite Initialization
Suite Teardown    Suite Cleanup
Test Timeout      5 minutes

*** Variables ***
# Test Configuration
${TEST_FREQUENCY}         1000000000    # 1 GHz in Hz
${TEST_POWER}            -10           # -10 dBm
${SWEEP_START}           100000000     # 100 MHz
${SWEEP_STOP}            6000000000    # 6 GHz
${SWEEP_POINTS}          1001
${MEASUREMENT_TIMEOUT}    30            # seconds

# Pass/Fail Criteria
${POWER_TOLERANCE}       0.5           # dB
${FREQUENCY_TOLERANCE}   1000000       # 1 MHz

*** Test Cases ***
TC001: Verify Equipment Connectivity
    [Documentation]    Verify all RF equipment is reachable on the network
    [Tags]    connectivity    smoke    critical

    Log    Testing connectivity to all RF equipment    console=True

    Ping Equipment    SpectrumAnalyzer
    Ping Equipment    SignalGenerator
    Ping Equipment    DUT

    Log    All equipment is reachable    level=INFO

TC002: Initialize Spectrum Analyzer
    [Documentation]    Initialize and configure spectrum analyzer for testing
    [Tags]    spectrum_analyzer    initialization

    Connect To Spectrum Analyzer

    ${idn}=    Query Equipment    SpectrumAnalyzer    *IDN?
    Log    Spectrum Analyzer ID: ${idn}    level=INFO

    Reset Equipment    SpectrumAnalyzer
    Configure Spectrum Analyzer    ${SWEEP_START}    ${SWEEP_STOP}    ${SWEEP_POINTS}

    ${freq_start}=    Query Equipment    SpectrumAnalyzer    FREQ:START?
    ${freq_stop}=     Query Equipment    SpectrumAnalyzer    FREQ:STOP?

    Should Be Equal As Numbers    ${freq_start}    ${SWEEP_START}
    Should Be Equal As Numbers    ${freq_stop}     ${SWEEP_STOP}

TC003: Initialize Signal Generator
    [Documentation]    Initialize and configure signal generator
    [Tags]    signal_generator    initialization

    Connect To Signal Generator

    ${idn}=    Query Equipment    SignalGenerator    *IDN?
    Log    Signal Generator ID: ${idn}    level=INFO

    Reset Equipment    SignalGenerator
    Set Signal Generator Frequency    ${TEST_FREQUENCY}
    Set Signal Generator Power    ${TEST_POWER}

    ${actual_freq}=    Query Equipment    SignalGenerator    FREQ?
    ${actual_power}=   Query Equipment    SignalGenerator    POW?

    Should Be Equal As Numbers    ${actual_freq}    ${TEST_FREQUENCY}
    Should Be Equal As Numbers    ${actual_power}   ${TEST_POWER}    precision=1

TC004: Enable Signal Generator Output
    [Documentation]    Enable RF output from signal generator
    [Tags]    signal_generator    output

    Enable Signal Generator Output

    ${output_state}=    Query Equipment    SignalGenerator    OUTP?
    Should Be Equal As Strings    ${output_state}    1

    Log    Signal generator output enabled    level=INFO

TC005: Measure Signal Power
    [Documentation]    Measure output power using spectrum analyzer
    [Tags]    measurement    power    critical

    Set Spectrum Analyzer Center Frequency    ${TEST_FREQUENCY}
    Set Spectrum Analyzer Span    10000000    # 10 MHz span

    ${measured_power}=    Measure Peak Power

    Log    Expected Power: ${TEST_POWER} dBm    level=INFO
    Log    Measured Power: ${measured_power} dBm    level=INFO

    ${power_diff}=    Evaluate    abs(${measured_power} - ${TEST_POWER})

    Should Be True    ${power_diff} <= ${POWER_TOLERANCE}
    ...    msg=Power measurement out of tolerance (${power_diff} dB)

TC006: Frequency Sweep Test
    [Documentation]    Perform frequency sweep and verify signal presence
    [Tags]    sweep    frequency    critical

    @{test_frequencies}=    Create List
    ...    500000000     # 500 MHz
    ...    1000000000    # 1 GHz
    ...    2000000000    # 2 GHz
    ...    3000000000    # 3 GHz

    FOR    ${freq}    IN    @{test_frequencies}
        Log    Testing frequency: ${freq} Hz    console=True

        Set Signal Generator Frequency    ${freq}
        Sleep    2s    # Allow signal to stabilize

        Set Spectrum Analyzer Center Frequency    ${freq}
        ${measured_freq}=    Measure Peak Frequency

        ${freq_error}=    Evaluate    abs(${measured_freq} - ${freq})

        Should Be True    ${freq_error} <= ${FREQUENCY_TOLERANCE}
        ...    msg=Frequency error: ${freq_error} Hz at ${freq} Hz

        Log    Frequency verified: ${measured_freq} Hz    level=INFO
    END

TC007: Power Sweep Test
    [Documentation]    Test signal generator power range
    [Tags]    sweep    power

    Set Signal Generator Frequency    ${TEST_FREQUENCY}
    Set Spectrum Analyzer Center Frequency    ${TEST_FREQUENCY}

    @{power_levels}=    Create List    -20    -10    0    5

    FOR    ${power}    IN    @{power_levels}
        Log    Testing power level: ${power} dBm    console=True

        Set Signal Generator Power    ${power}
        Sleep    2s

        ${measured_power}=    Measure Peak Power
        ${power_diff}=    Evaluate    abs(${measured_power} - ${power})

        Should Be True    ${power_diff} <= ${POWER_TOLERANCE}
        ...    msg=Power error: ${power_diff} dB at ${power} dBm

        Log    Power verified: ${measured_power} dBm    level=INFO
    END

TC008: DUT Signal Path Verification
    [Documentation]    Verify signal path through Device Under Test
    [Tags]    dut    signal_path    critical

    [Setup]    Configure DUT Test Setup

    # Configure signal generator
    Set Signal Generator Frequency    ${TEST_FREQUENCY}
    Set Signal Generator Power    ${TEST_POWER}
    Enable Signal Generator Output

    # Measure input to DUT
    ${input_power}=    Measure Peak Power
    Log    DUT Input Power: ${input_power} dBm    level=INFO

    # Configure DUT (example - adjust per your DUT)
    Send DUT Command    DUT    CONFIG:MODE PASSTHROUGH

    # Measure output from DUT
    ${output_power}=    Measure Peak Power
    Log    DUT Output Power: ${output_power} dBm    level=INFO

    # Calculate insertion loss
    ${insertion_loss}=    Evaluate    ${input_power} - ${output_power}
    Log    Insertion Loss: ${insertion_loss} dB    level=INFO

    # Verify reasonable insertion loss (adjust threshold as needed)
    Should Be True    ${insertion_loss} < 10
    ...    msg=Excessive insertion loss: ${insertion_loss} dB

TC009: Harmonic Distortion Test
    [Documentation]    Measure harmonic distortion of signal
    [Tags]    harmonic    distortion    advanced

    Set Signal Generator Frequency    ${TEST_FREQUENCY}
    Set Signal Generator Power    0    # 0 dBm for distortion testing

    # Measure fundamental
    Set Spectrum Analyzer Center Frequency    ${TEST_FREQUENCY}
    ${fundamental}=    Measure Peak Power

    # Measure 2nd harmonic
    ${harmonic2_freq}=    Evaluate    ${TEST_FREQUENCY} * 2
    Set Spectrum Analyzer Center Frequency    ${harmonic2_freq}
    ${harmonic2}=    Measure Peak Power

    # Measure 3rd harmonic
    ${harmonic3_freq}=    Evaluate    ${TEST_FREQUENCY} * 3
    Set Spectrum Analyzer Center Frequency    ${harmonic3_freq}
    ${harmonic3}=    Measure Peak Power

    # Calculate distortion
    ${h2_distortion}=    Evaluate    ${harmonic2} - ${fundamental}
    ${h3_distortion}=    Evaluate    ${harmonic3} - ${fundamental}

    Log    2nd Harmonic Distortion: ${h2_distortion} dBc    level=INFO
    Log    3rd Harmonic Distortion: ${h3_distortion} dBc    level=INFO

    # Verify distortion is below threshold (adjust as needed)
    Should Be True    ${h2_distortion} < -40
    Should Be True    ${h3_distortion} < -40

TC010: Equipment Self-Test
    [Documentation]    Run built-in self-test on all equipment
    [Tags]    self_test    diagnostic

    Log    Running equipment self-tests    console=True

    # Spectrum Analyzer self-test
    ${sa_selftest}=    Query Equipment    SpectrumAnalyzer    *TST?
    Should Be Equal As Strings    ${sa_selftest}    0    msg=Spectrum Analyzer self-test failed

    # Signal Generator self-test
    ${sg_selftest}=    Query Equipment    SignalGenerator    *TST?
    Should Be Equal As Strings    ${sg_selftest}    0    msg=Signal Generator self-test failed

    Log    All equipment passed self-test    level=INFO

*** Keywords ***
Suite Initialization
    [Documentation]    Initialize test suite

    Log    ========================================    console=True
    Log    RF Equipment Functional Test Suite        console=True
    Log    ========================================    console=True

    Create Directory    ${OUTPUT_DIR}/screenshots
    Set Screenshot Directory    ${OUTPUT_DIR}/screenshots

    # Verify network connectivity
    Verify Lab Network

    # Initialize equipment connections
    Initialize All Equipment

Suite Cleanup
    [Documentation]    Clean up after test suite

    Log    Cleaning up test suite    console=True

    # Disable outputs
    Run Keyword And Ignore Error    Disable Signal Generator Output

    # Disconnect from equipment
    Disconnect All Equipment

    Log    Test suite complete    console=True

Configure DUT Test Setup
    [Documentation]    Configure DUT for testing

    Connect To DUT
    Reset Equipment    DUT

    # Add DUT-specific configuration here
    Log    DUT configured for testing    level=INFO
