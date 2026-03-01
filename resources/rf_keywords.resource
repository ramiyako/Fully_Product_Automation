*** Settings ***
Documentation     RF Equipment Control Keywords
...               Reusable Robot Framework keywords for controlling
...               RF test equipment (Spectrum Analyzers, Signal Generators, DUT)
...               Supports both real equipment (SCPI over TCP) and mock equipment

Library           SCPIEquipment.py
Library           RequestsLibrary
Library           Collections
Library           String
Library           OperatingSystem
Library           Process
Library           DateTime

Variables         network_vars.py

*** Variables ***
# Equipment Connection Status
${SA_CONNECTED}       ${False}
${SG_CONNECTED}       ${False}
${DUT_CONNECTED}      ${False}

# Equipment Communication Protocol
${SCPI_TIMEOUT}       30
${SCPI_TERMINATOR}    \n

# Default Settings
${DEFAULT_RBW}        1000000    # 1 MHz
${DEFAULT_VBW}        1000000    # 1 MHz
${DEFAULT_SPAN}       10000000   # 10 MHz

*** Keywords ***
#==============================================================================
# Network & Connectivity Keywords
#==============================================================================

Verify Lab Network
    [Documentation]    Verify connectivity to laboratory network
    [Arguments]    ${timeout}=10

    Log    Verifying laboratory network connectivity    level=INFO

    ${result}=    Run Process    ip    route    get    192.168.50.1
    Should Contain    ${result.stdout}    192.168.50
    ...    msg=Not connected to Lab VLAN

    Log    Lab network verified    level=INFO

Ping Equipment
    [Documentation]    Ping RF equipment to verify network connectivity
    [Arguments]    ${equipment_name}

    ${ip}=    Get Equipment IP    ${equipment_name}

    Log    Pinging ${equipment_name} at ${ip}    level=INFO

    ${result}=    Run Process    ping    -c    3    -W    2    ${ip}
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=${equipment_name} not reachable at ${ip}

    Log    ${equipment_name} is reachable    level=INFO

Get Equipment IP
    [Documentation]    Get IP address for specified equipment
    [Arguments]    ${equipment_name}

    ${ip}=    Evaluate    $EQUIPMENT_LIST.get("${equipment_name}")
    Should Not Be Equal    ${ip}    ${None}
    ...    msg=Equipment ${equipment_name} not found in configuration

    RETURN    ${ip}

Get Equipment Endpoint
    [Documentation]    Get IP address and port for specified equipment
    ...                Works with both real and mock equipment
    [Arguments]    ${equipment_name}

    ${ip}    ${port}=    Evaluate
    ...    sys.path.insert(0, '${CURDIR}') or __import__('network_vars').get_equipment_endpoint("${equipment_name}")
    ...    modules=sys

    RETURN    ${ip}    ${port}

#==============================================================================
# Equipment Connection Keywords
#==============================================================================

Connect To Spectrum Analyzer
    [Documentation]    Establish connection to Spectrum Analyzer
    ...                Works with both real and mock equipment

    Return From Keyword If    ${SA_CONNECTED}

    ${ip}    ${port}=    Get Equipment Endpoint    SpectrumAnalyzer

    Log    Connecting to Spectrum Analyzer at ${ip}:${port}    level=INFO

    # Connect via SCPI TCP
    Connect To Equipment    SpectrumAnalyzer    ${ip}    ${port}

    # Verify connection with ID query
    ${idn}=    Query SCPI    SpectrumAnalyzer    *IDN?
    Log    Spectrum Analyzer: ${idn}    level=INFO

    Set Suite Variable    ${SA_CONNECTED}    ${True}

Connect To Signal Generator
    [Documentation]    Establish connection to Signal Generator
    ...                Works with both real and mock equipment

    Return From Keyword If    ${SG_CONNECTED}

    ${ip}    ${port}=    Get Equipment Endpoint    SignalGenerator

    Log    Connecting to Signal Generator at ${ip}:${port}    level=INFO

    # Connect via SCPI TCP
    Connect To Equipment    SignalGenerator    ${ip}    ${port}

    ${idn}=    Query SCPI    SignalGenerator    *IDN?
    Log    Signal Generator: ${idn}    level=INFO

    Set Suite Variable    ${SG_CONNECTED}    ${True}

Connect To DUT
    [Documentation]    Establish connection to Device Under Test
    ...                Works with both real and mock equipment

    Return From Keyword If    ${DUT_CONNECTED}

    ${ip}    ${port}=    Get Equipment Endpoint    DUT

    Log    Connecting to DUT at ${ip}:${port}    level=INFO

    # Connect via SCPI TCP
    Connect To Equipment    DUT    ${ip}    ${port}

    # Verify connection
    ${idn}=    Query SCPI    DUT    *IDN?
    Log    DUT: ${idn}    level=INFO

    Set Suite Variable    ${DUT_CONNECTED}    ${True}

Initialize All Equipment
    [Documentation]    Connect to all RF equipment

    Log    Initializing all equipment connections    level=INFO

    Connect To Spectrum Analyzer
    Connect To Signal Generator
    Connect To DUT

    Log    All equipment initialized    level=INFO

Disconnect All Equipment
    [Documentation]    Disconnect from all equipment

    Log    Disconnecting from all equipment    level=INFO

    # Disconnect via SCPI library
    Disconnect All

    Set Suite Variable    ${SA_CONNECTED}    ${False}
    Set Suite Variable    ${SG_CONNECTED}    ${False}
    Set Suite Variable    ${DUT_CONNECTED}    ${False}

    Log    All equipment disconnected    level=INFO

#==============================================================================
# SCPI Communication Keywords
#==============================================================================

Send SCPI Command
    [Documentation]    Send SCPI command to equipment
    [Arguments]    ${equipment_name}    ${command}

    Log    Sending to ${equipment_name}: ${command}    level=DEBUG
    Send SCPI Command    ${equipment_name}    ${command}
    Log    Command sent: ${command}    level=DEBUG

Query Equipment
    [Documentation]    Query equipment and return response
    [Arguments]    ${equipment_name}    ${query}

    Log    Querying ${equipment_name}: ${query}    level=DEBUG
    ${result}=    Query SCPI    ${equipment_name}    ${query}
    Log    Response from ${equipment_name}: ${result}    level=DEBUG

    RETURN    ${result}

Reset Equipment
    [Documentation]    Send reset command to equipment
    [Arguments]    ${equipment_name}

    Log    Resetting ${equipment_name}    level=INFO

    Send SCPI Command    ${equipment_name}    *RST
    Sleep    5s    # Allow equipment to reset

    Log    ${equipment_name} reset complete    level=INFO

#==============================================================================
# Spectrum Analyzer Keywords
#==============================================================================

Configure Spectrum Analyzer
    [Documentation]    Configure spectrum analyzer sweep parameters
    [Arguments]    ${start_freq}    ${stop_freq}    ${points}=1001

    Log    Configuring Spectrum Analyzer    level=INFO
    Log    Frequency Range: ${start_freq} - ${stop_freq} Hz    level=INFO

    Send SCPI Command    SpectrumAnalyzer    FREQ:START ${start_freq}
    Send SCPI Command    SpectrumAnalyzer    FREQ:STOP ${stop_freq}
    Send SCPI Command    SpectrumAnalyzer    SWE:POIN ${points}

    # Set resolution and video bandwidth
    Send SCPI Command    SpectrumAnalyzer    BAND:RES ${DEFAULT_RBW}
    Send SCPI Command    SpectrumAnalyzer    BAND:VID ${DEFAULT_VBW}

    Log    Spectrum Analyzer configured    level=INFO

Set Spectrum Analyzer Center Frequency
    [Documentation]    Set center frequency for spectrum analyzer
    [Arguments]    ${frequency}

    Log    Setting SA center frequency: ${frequency} Hz    level=DEBUG

    Send SCPI Command    SpectrumAnalyzer    FREQ:CENT ${frequency}

Set Spectrum Analyzer Span
    [Documentation]    Set frequency span
    [Arguments]    ${span}

    Log    Setting SA span: ${span} Hz    level=DEBUG

    Send SCPI Command    SpectrumAnalyzer    FREQ:SPAN ${span}

Set Spectrum Analyzer Resolution Bandwidth
    [Documentation]    Set resolution bandwidth
    [Arguments]    ${rbw}

    Log    Setting SA RBW: ${rbw} Hz    level=DEBUG

    Send SCPI Command    SpectrumAnalyzer    BAND:RES ${rbw}

Measure Peak Power
    [Documentation]    Measure peak power using spectrum analyzer
    [Return Value]    Peak power in dBm

    Log    Measuring peak power    level=DEBUG

    Send SCPI Command    SpectrumAnalyzer    INIT:IMM
    Sleep    2s    # Wait for sweep

    ${power}=    Query Equipment    SpectrumAnalyzer    CALC:MARK:MAX
    ${power}=    Query Equipment    SpectrumAnalyzer    CALC:MARK:Y?

    # Parse numeric value (adjust parsing based on equipment response format)
    ${power}=    Convert To Number    ${power}

    Log    Measured Power: ${power} dBm    level=INFO

    RETURN    ${power}

Measure Peak Frequency
    [Documentation]    Measure frequency of peak signal
    [Return Value]    Frequency in Hz

    Log    Measuring peak frequency    level=DEBUG

    Send SCPI Command    SpectrumAnalyzer    INIT:IMM
    Sleep    2s

    ${freq}=    Query Equipment    SpectrumAnalyzer    CALC:MARK:MAX
    ${freq}=    Query Equipment    SpectrumAnalyzer    CALC:MARK:X?

    ${freq}=    Convert To Number    ${freq}

    Log    Measured Frequency: ${freq} Hz    level=INFO

    RETURN    ${freq}

#==============================================================================
# Signal Generator Keywords
#==============================================================================

Set Signal Generator Frequency
    [Documentation]    Set signal generator frequency
    [Arguments]    ${frequency}

    Log    Setting SG frequency: ${frequency} Hz    level=DEBUG

    Send SCPI Command    SignalGenerator    FREQ ${frequency}

Set Signal Generator Power
    [Documentation]    Set signal generator output power
    [Arguments]    ${power}

    Log    Setting SG power: ${power} dBm    level=DEBUG

    Send SCPI Command    SignalGenerator    POW ${power}

Enable Signal Generator Output
    [Documentation]    Enable RF output from signal generator

    Log    Enabling signal generator output    level=INFO

    Send SCPI Command    SignalGenerator    OUTP ON

Disable Signal Generator Output
    [Documentation]    Disable RF output from signal generator

    Log    Disabling signal generator output    level=INFO

    Send SCPI Command    SignalGenerator    OUTP OFF

#==============================================================================
# DUT Control Keywords
#==============================================================================

Send DUT Command
    [Documentation]    Send command to Device Under Test
    [Arguments]    ${equipment_name}    ${command}

    Log    Sending DUT command: ${command}    level=DEBUG

    Send SCPI Command    ${equipment_name}    ${command}

Configure DUT
    [Documentation]    Configure DUT for testing
    [Arguments]    ${config_mode}=DEFAULT

    Log    Configuring DUT: ${config_mode}    level=INFO

    # DUT-specific configuration commands
    Send DUT Command    DUT    CONFIG:MODE ${config_mode}

    Log    DUT configured    level=INFO

#==============================================================================
# Utility Keywords
#==============================================================================

Wait For Measurement
    [Documentation]    Wait for measurement to complete
    [Arguments]    ${timeout}=${SCPI_TIMEOUT}

    Log    Waiting for measurement to complete    level=DEBUG

    Sleep    ${timeout}s

Capture Screenshot
    [Documentation]    Capture screenshot from equipment (if supported)
    [Arguments]    ${filename}

    ${timestamp}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${screenshot_path}=    Set Variable    ${OUTPUT_DIR}/screenshots/${filename}_${timestamp}.png

    Log    Capturing screenshot: ${screenshot_path}    level=INFO

    # Equipment-specific screenshot command
    # Example: Send SCPI Command    SpectrumAnalyzer    HCOP:DEV:LANG PNG
    # Example: Send SCPI Command    SpectrumAnalyzer    HCOP:IMM

    # Download screenshot via HTTP/FTP
    # Example: Download File    http://${equipment_ip}/screenshot.png    ${screenshot_path}

    Log    Screenshot saved: ${screenshot_path}    level=INFO

Log Equipment Status
    [Documentation]    Log status of all equipment

    Log    ========================================    console=True
    Log    Equipment Connection Status               console=True
    Log    ========================================    console=True
    Log    Spectrum Analyzer: ${SA_CONNECTED}        console=True
    Log    Signal Generator:  ${SG_CONNECTED}        console=True
    Log    DUT:               ${DUT_CONNECTED}       console=True
    Log    ========================================    console=True
