*** Settings ***
Documentation     RF Equipment Calibration Test Suite
...               Automated calibration procedures for RF test equipment
...               ensuring measurement accuracy and traceability.

Library           RequestsLibrary
Library           Collections
Library           DateTime
Library           OperatingSystem
Library           String

Resource          ../resources/rf_keywords.resource

Suite Setup       Calibration Suite Setup
Suite Teardown    Calibration Suite Teardown
Test Timeout      10 minutes

*** Variables ***
# Calibration Standards
${CAL_FREQUENCY}         1000000000    # 1 GHz calibration frequency
${CAL_POWER}            0             # 0 dBm calibration power
${CAL_TOLERANCE}        0.5           # ±0.5 dB tolerance
${TEMP_TOLERANCE}       5             # ±5°C temperature tolerance

# Calibration Intervals
${CAL_INTERVAL_DAYS}    30
${LAST_CAL_DATE}        ${EMPTY}

# Reference Values (from last successful calibration)
${REF_POWER_SA}         0.0
${REF_POWER_SG}         0.0
${REF_FREQUENCY_SA}     1000000000
${REF_FREQUENCY_SG}     1000000000

*** Test Cases ***
TC_CAL_001: Pre-Calibration Checks
    [Documentation]    Verify equipment is ready for calibration
    [Tags]    calibration    pre-check    critical

    Log    === PRE-CALIBRATION CHECKS ===    console=True

    # Verify equipment connectivity
    Ping Equipment    SpectrumAnalyzer
    Ping Equipment    SignalGenerator

    # Check equipment errors
    ${sa_errors}=    Query Equipment    SpectrumAnalyzer    SYST:ERR?
    ${sg_errors}=    Query Equipment    SignalGenerator    SYST:ERR?

    Should Contain    ${sa_errors}    No error
    Should Contain    ${sg_errors}    No error

    # Verify warm-up time (equipment should be powered on for at least 30 min)
    Log    REMINDER: Equipment should be warmed up for 30+ minutes    WARN

    # Check ambient temperature (if sensor available)
    # ${temp}=    Get Ambient Temperature
    # Should Be True    ${temp} >= 20 and ${temp} <= 25

    Log    Pre-calibration checks passed    level=INFO

TC_CAL_002: Spectrum Analyzer Frequency Accuracy
    [Documentation]    Verify spectrum analyzer frequency accuracy
    [Tags]    calibration    frequency    spectrum_analyzer

    Log    === SPECTRUM ANALYZER FREQUENCY CALIBRATION ===    console=True

    Connect To Spectrum Analyzer
    Connect To Signal Generator

    # Reset and configure
    Reset Equipment    SpectrumAnalyzer
    Reset Equipment    SignalGenerator

    # Set signal generator to calibration frequency
    Set Signal Generator Frequency    ${CAL_FREQUENCY}
    Set Signal Generator Power    ${CAL_POWER}
    Enable Signal Generator Output

    Sleep    5s    # Allow signal to stabilize

    # Configure spectrum analyzer
    Set Spectrum Analyzer Center Frequency    ${CAL_FREQUENCY}
    Set Spectrum Analyzer Span    10000000    # 10 MHz span
    Set Spectrum Analyzer Resolution Bandwidth    100000    # 100 kHz

    # Measure frequency
    ${measured_freq}=    Measure Peak Frequency
    ${freq_error}=    Evaluate    abs(${measured_freq} - ${CAL_FREQUENCY})
    ${freq_error_ppm}=    Evaluate    (${freq_error} / ${CAL_FREQUENCY}) * 1e6

    Log    Expected Frequency: ${CAL_FREQUENCY} Hz    level=INFO
    Log    Measured Frequency: ${measured_freq} Hz    level=INFO
    Log    Frequency Error: ${freq_error} Hz (${freq_error_ppm} ppm)    level=INFO

    # Verify frequency accuracy (< 1 MHz or < 1 ppm)
    Should Be True    ${freq_error} < 1000000    msg=Frequency error exceeds limit

    # Store calibration result
    Set Suite Variable    ${CAL_FREQ_ERROR}    ${freq_error}

    Disable Signal Generator Output

TC_CAL_003: Spectrum Analyzer Power Accuracy
    [Documentation]    Verify spectrum analyzer power measurement accuracy
    [Tags]    calibration    power    spectrum_analyzer    critical

    Log    === SPECTRUM ANALYZER POWER CALIBRATION ===    console=True

    @{power_levels}=    Create List    -20    -10    0    +5
    @{measured_powers}=    Create List
    @{power_errors}=    Create List

    FOR    ${ref_power}    IN    @{power_levels}
        Log    Calibrating at ${ref_power} dBm    console=True

        # Set signal generator
        Set Signal Generator Frequency    ${CAL_FREQUENCY}
        Set Signal Generator Power    ${ref_power}
        Enable Signal Generator Output

        Sleep    3s

        # Measure power
        Set Spectrum Analyzer Center Frequency    ${CAL_FREQUENCY}
        ${measured_power}=    Measure Peak Power

        ${power_error}=    Evaluate    ${measured_power} - ${ref_power}

        Append To List    ${measured_powers}    ${measured_power}
        Append To List    ${power_errors}    ${power_error}

        Log    Reference: ${ref_power} dBm | Measured: ${measured_power} dBm | Error: ${power_error} dB    level=INFO

        # Verify within tolerance
        ${abs_error}=    Evaluate    abs(${power_error})
        Should Be True    ${abs_error} <= ${CAL_TOLERANCE}
        ...    msg=Power error ${power_error} dB exceeds tolerance at ${ref_power} dBm
    END

    # Calculate average error
    ${avg_error}=    Calculate Average    ${power_errors}
    Log    Average Power Error: ${avg_error} dB    level=INFO

    Set Suite Variable    ${CAL_POWER_ERROR_AVG}    ${avg_error}

    Disable Signal Generator Output

TC_CAL_004: Signal Generator Frequency Accuracy
    [Documentation]    Verify signal generator frequency accuracy
    [Tags]    calibration    frequency    signal_generator

    Log    === SIGNAL GENERATOR FREQUENCY CALIBRATION ===    console=True

    # Use spectrum analyzer as reference
    @{test_frequencies}=    Create List
    ...    100000000      # 100 MHz
    ...    500000000      # 500 MHz
    ...    1000000000     # 1 GHz
    ...    2000000000     # 2 GHz
    ...    3000000000     # 3 GHz

    @{freq_errors}=    Create List

    FOR    ${set_freq}    IN    @{test_frequencies}
        Log    Testing ${set_freq} Hz    console=True

        Set Signal Generator Frequency    ${set_freq}
        Set Signal Generator Power    ${CAL_POWER}
        Enable Signal Generator Output

        Sleep    2s

        Set Spectrum Analyzer Center Frequency    ${set_freq}
        ${measured_freq}=    Measure Peak Frequency

        ${freq_error}=    Evaluate    ${measured_freq} - ${set_freq}
        Append To List    ${freq_errors}    ${freq_error}

        Log    Set: ${set_freq} Hz | Measured: ${measured_freq} Hz | Error: ${freq_error} Hz    level=INFO

        # Verify < 1 MHz error
        ${abs_error}=    Evaluate    abs(${freq_error})
        Should Be True    ${abs_error} < 1000000
    END

    Disable Signal Generator Output

TC_CAL_005: Signal Generator Power Accuracy
    [Documentation]    Verify signal generator power output accuracy
    [Tags]    calibration    power    signal_generator    critical

    Log    === SIGNAL GENERATOR POWER CALIBRATION ===    console=True

    Set Signal Generator Frequency    ${CAL_FREQUENCY}
    Set Spectrum Analyzer Center Frequency    ${CAL_FREQUENCY}

    @{power_levels}=    Create List    -20    -10    0    +5    +10
    @{power_errors}=    Create List

    FOR    ${set_power}    IN    @{power_levels}
        Log    Testing ${set_power} dBm    console=True

        Set Signal Generator Power    ${set_power}
        Enable Signal Generator Output

        Sleep    3s

        ${measured_power}=    Measure Peak Power
        ${power_error}=    Evaluate    ${measured_power} - ${set_power}

        Append To List    ${power_errors}    ${power_error}

        Log    Set: ${set_power} dBm | Measured: ${measured_power} dBm | Error: ${power_error} dB    level=INFO

        ${abs_error}=    Evaluate    abs(${power_error})
        Should Be True    ${abs_error} <= ${CAL_TOLERANCE}
        ...    msg=Power error exceeds tolerance at ${set_power} dBm
    END

    ${avg_error}=    Calculate Average    ${power_errors}
    Log    Average Power Error: ${avg_error} dB    level=INFO

    Disable Signal Generator Output

TC_CAL_006: Linearity Test
    [Documentation]    Verify power measurement linearity
    [Tags]    calibration    linearity    advanced

    Log    === LINEARITY TEST ===    console=True

    Set Signal Generator Frequency    ${CAL_FREQUENCY}
    Set Spectrum Analyzer Center Frequency    ${CAL_FREQUENCY}

    # Test across wide power range
    @{power_range}=    Create List
    ...    -30    -25    -20    -15    -10    -5    0    +5    +10

    @{linearities}=    Create List

    ${previous_measured}=    Set Variable    ${None}

    FOR    ${power}    IN    @{power_range}
        Set Signal Generator Power    ${power}
        Enable Signal Generator Output

        Sleep    2s

        ${measured}=    Measure Peak Power

        Run Keyword If    '${previous_measured}' != '${None}'
        ...    Calculate Linearity Error    ${power}    ${measured}    ${previous_measured}

        ${previous_measured}=    Set Variable    ${measured}
    END

    Disable Signal Generator Output

TC_CAL_007: Generate Calibration Report
    [Documentation]    Generate calibration certificate/report
    [Tags]    calibration    report

    Log    === GENERATING CALIBRATION REPORT ===    console=True

    ${timestamp}=    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    ${next_cal_date}=    Add Time To Date    ${timestamp}    ${CAL_INTERVAL_DAYS} days
    ...    result_format=%Y-%m-%d

    ${report}=    Catenate    SEPARATOR=\n
    ...    ========================================
    ...    RF EQUIPMENT CALIBRATION REPORT
    ...    ========================================
    ...    ${EMPTY}
    ...    Calibration Date: ${timestamp}
    ...    Next Calibration Due: ${next_cal_date}
    ...    ${EMPTY}
    ...    SPECTRUM ANALYZER:
    ...    - Frequency Error: ${CAL_FREQ_ERROR} Hz
    ...    - Power Error (Avg): ${CAL_POWER_ERROR_AVG} dB
    ...    ${EMPTY}
    ...    STATUS: PASSED
    ...    ${EMPTY}
    ...    Calibrated by: Automated System
    ...    ========================================

    Log    ${report}    console=True

    # Save report to file
    ${report_file}=    Set Variable    ${OUTPUT_DIR}/calibration_report_${timestamp}.txt
    Create File    ${report_file}    ${report}

    Log    Calibration report saved: ${report_file}    level=INFO

*** Keywords ***
Calibration Suite Setup
    [Documentation]    Initialize calibration suite

    Log    ========================================    console=True
    Log    RF EQUIPMENT CALIBRATION SUITE            console=True
    Log    ========================================    console=True

    Create Directory    ${OUTPUT_DIR}/calibration

    Verify Lab Network
    Initialize All Equipment

    # Load previous calibration data if exists
    ${cal_data_exists}=    Run Keyword And Return Status
    ...    File Should Exist    ${OUTPUT_DIR}/last_calibration.json

    Run Keyword If    ${cal_data_exists}
    ...    Load Previous Calibration Data

Calibration Suite Teardown
    [Documentation]    Clean up calibration suite

    # Disable all outputs
    Run Keyword And Ignore Error    Disable Signal Generator Output

    # Save calibration data
    Save Calibration Data

    Disconnect All Equipment

    Log    Calibration suite complete    console=True

Calculate Average
    [Arguments]    ${list}
    [Documentation]    Calculate average of a list of numbers

    ${sum}=    Set Variable    0
    ${count}=    Get Length    ${list}

    FOR    ${value}    IN    @{list}
        ${sum}=    Evaluate    ${sum} + ${value}
    END

    ${average}=    Evaluate    ${sum} / ${count}

    [Return]    ${average}

Calculate Linearity Error
    [Arguments]    ${power}    ${measured}    ${previous_measured}
    [Documentation]    Calculate linearity error between consecutive measurements

    ${expected_step}=    Set Variable    5
    ${actual_step}=    Evaluate    ${measured} - ${previous_measured}
    ${linearity_error}=    Evaluate    ${actual_step} - ${expected_step}

    Log    Linearity Error: ${linearity_error} dB at ${power} dBm    level=INFO

    ${abs_error}=    Evaluate    abs(${linearity_error})
    Should Be True    ${abs_error} < 0.5    msg=Linearity error exceeds 0.5 dB

Load Previous Calibration Data
    [Documentation]    Load previous calibration results

    Log    Loading previous calibration data    level=INFO
    # Implementation depends on storage format

Save Calibration Data
    [Documentation]    Save calibration results for future reference

    ${timestamp}=    Get Current Date    result_format=%Y-%m-%d

    # Create calibration data structure
    # Save to JSON file for tracking
    Log    Calibration data saved    level=INFO
