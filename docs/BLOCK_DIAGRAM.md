# RF Automation Infrastructure - Detailed Block Diagram

## Overview
This document provides detailed block diagrams showing the architecture, data flow, and component interactions of the RF equipment automation system.

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Intel NUC Server (Ubuntu 24.04)                     │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Jenkins CI/CD Server                         │   │
│  │                         (Port 8080, systemd)                         │   │
│  │                                                                       │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │                    Pipeline Execution                         │  │   │
│  │  │  1. Git Checkout                                              │  │   │
│  │  │  2. Docker Build                                              │  │   │
│  │  │  3. Infrastructure Verify                                     │  │   │
│  │  │  4. Execute Tests                                             │  │   │
│  │  │  5. Process Results                                           │  │   │
│  │  │  6. Upload to Elasticsearch                                   │  │   │
│  │  │  7. Archive Artifacts                                         │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Docker Engine (24.x)                            │   │
│  │                                                                       │   │
│  │  ┌────────────────────────┐    ┌───────────────────────────────┐   │   │
│  │  │  Test Runner Container │    │    ELK Stack Containers       │   │   │
│  │  │  (--network host)      │    │                               │   │   │
│  │  │                        │    │  ┌─────────────────────────┐ │   │   │
│  │  │  - Python 3.11         │    │  │  Elasticsearch:8.12.0   │ │   │   │
│  │  │  - Robot Framework 7.0 │    │  │  Port: 9200, 9300       │ │   │   │
│  │  │  - Test Files          │    │  │  Heap: 2GB              │ │   │   │
│  │  │  - Resources           │    │  │  Volume: es_data        │ │   │   │
│  │  │  - Scripts             │    │  └─────────────────────────┘ │   │   │
│  │  │                        │    │              │                 │   │   │
│  │  │  Volumes:              │    │              ▼                 │   │   │
│  │  │  - /results            │    │  ┌─────────────────────────┐ │   │   │
│  │  │  - /logs               │    │  │  Kibana:8.12.0          │ │   │   │
│  │  └────────────────────────┘    │  │  Port: 5601             │ │   │   │
│  │             │                   │  │  Volume: kibana_data    │ │   │   │
│  │             │ (host network)    │  └─────────────────────────┘ │   │   │
│  │             │                   └───────────────────────────────┘   │   │
│  └─────────────┼───────────────────────────────────────────────────────┘   │
│                │                                                             │
│  ┌─────────────┴───────────────────────────────────────────────────────┐   │
│  │                      Network Interfaces                              │   │
│  │                                                                       │   │
│  │  eth0 (Office Network)           eth1 (Lab VLAN)                    │   │
│  │  DHCP/Static IP                  192.168.50.5/24                    │   │
│  │  - Git Access                    - Equipment Access                  │   │
│  │  - Updates                       - Test Traffic                      │   │
│  │  - Web UI                        - SCPI Commands                     │   │
│  └───────┬───────────────────────────────────┬───────────────────────────┘ │
└──────────┼───────────────────────────────────┼─────────────────────────────┘
           │                                   │
           ▼                                   ▼
    ┌─────────────┐                  ┌────────────────────────┐
    │   Internet  │                  │   Lab VLAN Network     │
    │             │                  │   192.168.50.0/24      │
    │   - Git     │                  │                        │
    │   - Updates │                  │  ┌──────────────────┐ │
    │   - Web     │                  │  │ Spectrum Analyzer│ │
    └─────────────┘                  │  │ 192.168.50.10    │ │
                                     │  └──────────────────┘ │
                                     │  ┌──────────────────┐ │
                                     │  │ Signal Generator │ │
                                     │  │ 192.168.50.11    │ │
                                     │  └──────────────────┘ │
                                     │  ┌──────────────────┐ │
                                     │  │ DUT (Device)     │ │
                                     │  │ 192.168.50.20    │ │
                                     │  └──────────────────┘ │
                                     └────────────────────────┘
```

---

## 2. CI/CD Pipeline Flow (Jenkinsfile)

```
┌────────────────────────────────────────────────────────────────────────┐
│                            PIPELINE STAGES                              │
└────────────────────────────────────────────────────────────────────────┘

START
  │
  ├─[1. Initialize]──────────────────────────────────────────────────────┐
  │   │                                                                    │
  │   ├─► Checkout Git Repository (main/develop/feature branch)          │
  │   ├─► Create result directories (results/, logs/)                     │
  │   ├─► Verify prerequisites (Docker, Python, curl)                     │
  │   └─► Display environment info                                        │
  │                                                                        │
  ├─[2. Build Docker Image]─────────────────────────────────(conditional)─┤
  │   │                                                                    │
  │   ├─► IF SKIP_DOCKER_BUILD == false:                                 │
  │   │    ├─► docker build -t rf-test-runner:${BUILD_NUMBER}            │
  │   │    ├─► Tag as rf-test-runner:latest                              │
  │   │    ├─► Add build metadata (date, number)                         │
  │   │    └─► Cache layers for faster rebuilds                          │
  │   │                                                                    │
  │   └─► ELSE: Use existing image                                       │
  │                                                                        │
  ├─[3. Verify Infrastructure]──────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Check Elasticsearch health (curl localhost:9200)               │
  │   │    ├─► SUCCESS: Log ready                                        │
  │   │    └─► FAILURE: Warn but continue                                │
  │   │                                                                    │
  │   ├─► Check Kibana availability (curl localhost:5601)                │
  │   │    ├─► SUCCESS: Log ready                                        │
  │   │    └─► FAILURE: Warn but continue                                │
  │   │                                                                    │
  │   └─► Infrastructure warnings don't block tests                       │
  │                                                                        │
  ├─[4. Execute Tests]──────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► docker run --rm --network host                                 │
  │   │    -v ${WORKSPACE}/results:/app/results                          │
  │   │    -v ${WORKSPACE}/logs:/app/logs                                │
  │   │    -e LOG_LEVEL=${LOG_LEVEL}                                     │
  │   │    rf-test-runner:${BUILD_NUMBER}                                │
  │   │    --outputdir results                                           │
  │   │    --loglevel ${LOG_LEVEL}                                       │
  │   │    --timestampoutputs                                            │
  │   │    --name "RF-Automation_Build_${BUILD_NUMBER}"                  │
  │   │    tests/${TEST_SUITE}                                           │
  │   │                                                                    │
  │   └─► Container Execution Flow: (see detailed diagram below)         │
  │                                                                        │
  ├─[5. Process Results]────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Verify output.xml exists                                       │
  │   │    ├─► SUCCESS: Continue                                         │
  │   │    └─► FAILURE: Mark build as failed                             │
  │   │                                                                    │
  │   ├─► List generated files with sizes:                               │
  │   │    ├─► output.xml (test results XML)                             │
  │   │    ├─► log.html (detailed execution log)                         │
  │   │    ├─► report.html (summary report)                              │
  │   │    └─► screenshots/*.png (test evidence)                         │
  │   │                                                                    │
  │   └─► Display summary statistics                                     │
  │                                                                        │
  ├─[6. Upload to Elasticsearch]────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► python3 scripts/upload_to_elastic.py                           │
  │   │    --results-file results/output.xml                             │
  │   │    --elastic-url http://localhost:9200                           │
  │   │    --build-number ${BUILD_NUMBER}                                │
  │   │    --branch ${GIT_BRANCH}                                        │
  │   │    --verbose                                                      │
  │   │                                                                    │
  │   ├─► Parse XML → Transform to JSON → Bulk upload                    │
  │   │                                                                    │
  │   └─► Non-blocking (failures logged but don't fail build)            │
  │                                                                        │
  ├─[7. Archive Artifacts]──────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Archive results/*.{html,xml,png}                               │
  │   ├─► Archive logs/*.log                                             │
  │   ├─► Robot Framework plugin integration (if installed)              │
  │   └─► Make available for download in Jenkins UI                      │
  │                                                                        │
  ├─[8. Cleanup]────────────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► docker system prune -f --volumes                               │
  │   ├─► Remove dangling images                                         │
  │   └─► Free disk space                                                │
  │                                                                        │
  ├─[Post-Build Actions]────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► IF SUCCESS:                                                    │
  │   │    ├─► Log success message                                       │
  │   │    ├─► Send success email (optional)                             │
  │   │    └─► Update build badge                                        │
  │   │                                                                    │
  │   └─► IF FAILURE:                                                    │
  │        ├─► Log failure details                                       │
  │        ├─► Send failure email/Slack notification                     │
  │        └─► Mark build as failed                                      │
  │                                                                        │
  END
  │
  └─► Build artifacts available for 30 builds / 60 days
```

### Pipeline Parameters

```
┌──────────────────────────────────────────────────────────────┐
│                  BUILD PARAMETERS                             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  TEST_SUITE (choice)                                         │
│  ├─ all (default) → tests/                                   │
│  ├─ rf_functional → tests/rf_functional.robot                │
│  └─ calibration → tests/calibration.robot                    │
│                                                               │
│  LOG_LEVEL (choice)                                          │
│  ├─ INFO (default)                                           │
│  ├─ DEBUG                                                    │
│  └─ TRACE (very detailed)                                    │
│                                                               │
│  SKIP_DOCKER_BUILD (boolean)                                 │
│  ├─ false (default) → Build new image                        │
│  └─ true → Use existing rf-test-runner:latest                │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Docker Container Execution Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                    DOCKER CONTAINER LIFECYCLE                           │
└────────────────────────────────────────────────────────────────────────┘

JENKINS EXECUTES: docker run --rm --network host ...
  │
  ├─► Docker pulls/uses image: rf-test-runner:${BUILD_NUMBER}
  │
  ├─► Container starts with:
  │    ├─ Base: python:3.11-slim
  │    ├─ Working dir: /app
  │    ├─ User: root (for network access)
  │    ├─ Network: host (shared with NUC server)
  │    └─ Volumes:
  │         ├─ ${WORKSPACE}/results → /app/results (rw)
  │         └─ ${WORKSPACE}/logs → /app/logs (rw)
  │
  ├─► Entrypoint: robot [args]
  │
  ├─[CONTAINER RUNTIME]──────────────────────────────────────────────────┐
  │   │                                                                    │
  │   ├─[A. Initialize Robot Framework]────────────────────────────────┐ │
  │   │   │                                                              │ │
  │   │   ├─► Parse command-line arguments                              │ │
  │   │   ├─► Set output directory: /app/results                        │ │
  │   │   ├─► Set log level: ${LOG_LEVEL}                               │ │
  │   │   ├─► Enable timestamp outputs                                  │ │
  │   │   └─► Set suite name                                            │ │
  │   │                                                                  │ │
  │   ├─[B. Load Test Files]───────────────────────────────────────────┤ │
  │   │   │                                                              │ │
  │   │   ├─► Scan tests/ directory                                     │ │
  │   │   ├─► Parse .robot files                                        │ │
  │   │   ├─► Build test suite structure                                │ │
  │   │   └─► Register test cases                                       │ │
  │   │                                                                  │ │
  │   ├─[C. Load Resources]────────────────────────────────────────────┤ │
  │   │   │                                                              │ │
  │   │   ├─► Load resources/rf_keywords.resource                       │ │
  │   │   │    ├─ Network & Connectivity keywords                       │ │
  │   │   │    ├─ Equipment Connection keywords                         │ │
  │   │   │    ├─ Equipment Control keywords (SCPI)                     │ │
  │   │   │    └─ Measurement keywords                                  │ │
  │   │   │                                                              │ │
  │   │   └─► Import resources/network_vars.py                          │ │
  │   │        ├─ EQUIPMENT_LIST dictionary                             │ │
  │   │        ├─ ELASTIC_ENDPOINT config                               │ │
  │   │        ├─ RF_TEST_PARAMS settings                               │ │
  │   │        └─ Helper functions                                      │ │
  │   │                                                                  │ │
  │   ├─[D. Execute Test Suite]────────────────────────────────────────┤ │
  │   │   │                                                              │ │
  │   │   ├─► Suite Setup (if defined)                                  │ │
  │   │   │    ├─ Initialize test environment                           │ │
  │   │   │    ├─ Verify Lab VLAN connectivity                          │ │
  │   │   │    └─ Ping all equipment                                    │ │
  │   │   │                                                              │ │
  │   │   ├─► FOR EACH TEST CASE:                                       │ │
  │   │   │   │                                                          │ │
  │   │   │   ├─[Test Setup]────────────────────────────────────────┐  │ │
  │   │   │   │   ├─► Initialize variables                           │  │ │
  │   │   │   │   ├─► Connect to equipment                           │  │ │
  │   │   │   │   └─► Reset equipment to known state                 │  │ │
  │   │   │   │                                                       │  │ │
  │   │   │   ├─[Test Execution]─────────────────────────────────────┤  │ │
  │   │   │   │   │                                                   │  │ │
  │   │   │   │   ├─► Execute test keywords sequentially            │  │ │
  │   │   │   │   │                                                   │  │ │
  │   │   │   │   ├─► Example: TC001 - Equipment Connectivity       │  │ │
  │   │   │   │   │    ├─ Verify Lab Network (ping 192.168.50.1)    │  │ │
  │   │   │   │   │    ├─ Get Equipment IP (SA)                      │  │ │
  │   │   │   │   │    ├─ Ping Equipment (192.168.50.10)            │  │ │
  │   │   │   │   │    ├─ Connect To Spectrum Analyzer              │  │ │
  │   │   │   │   │    │   └─► SCPI: socket.connect(IP, 5025)       │  │ │
  │   │   │   │   │    ├─ Query Equipment (*IDN?)                    │  │ │
  │   │   │   │   │    │   └─► SCPI: send("*IDN?\n")                │  │ │
  │   │   │   │   │    │   └─► Receive response                      │  │ │
  │   │   │   │   │    ├─ Verify response contains expected ID       │  │ │
  │   │   │   │   │    └─ Log success                                │  │ │
  │   │   │   │   │                                                   │  │ │
  │   │   │   │   ├─► IF KEYWORD FAILS:                              │  │ │
  │   │   │   │   │    ├─ Capture screenshot                         │  │ │
  │   │   │   │   │    ├─ Log error details                          │  │ │
  │   │   │   │   │    ├─ Mark test as FAILED                        │  │ │
  │   │   │   │   │    └─ Continue to teardown                       │  │ │
  │   │   │   │   │                                                   │  │ │
  │   │   │   │   └─► IF ALL KEYWORDS PASS:                          │  │ │
  │   │   │   │        └─ Mark test as PASSED                        │  │ │
  │   │   │   │                                                       │  │ │
  │   │   │   └─[Test Teardown]───────────────────────────────────────┤  │ │
  │   │   │       ├─► Disconnect from equipment                      │  │ │
  │   │   │       ├─► Reset equipment if needed                      │  │ │
  │   │   │       └─► Clean up resources                             │  │ │
  │   │   │                                                              │ │
  │   │   └─► Suite Teardown (if defined)                               │ │
  │   │        ├─ Disconnect all equipment                               │ │
  │   │        ├─ Log final statistics                                   │ │
  │   │        └─ Clean up test environment                              │ │
  │   │                                                                  │ │
  │   ├─[E. Generate Outputs]──────────────────────────────────────────┤ │
  │   │   │                                                              │ │
  │   │   ├─► output.xml (Robot Framework XML results)                  │ │
  │   │   │    ├─ Test metadata                                         │ │
  │   │   │    ├─ Test statistics                                       │ │
  │   │   │    ├─ Individual test results (PASS/FAIL)                   │ │
  │   │   │    ├─ Keyword execution details                             │ │
  │   │   │    ├─ Timing information                                    │ │
  │   │   │    └─ Error messages                                        │ │
  │   │   │                                                              │ │
  │   │   ├─► log.html (Detailed execution log)                         │ │
  │   │   │    ├─ Expandable tree view                                  │ │
  │   │   │    ├─ Keyword arguments and return values                   │ │
  │   │   │    ├─ SCPI commands sent/received                           │ │
  │   │   │    ├─ Timestamps for each operation                         │ │
  │   │   │    └─ Embedded screenshots                                  │ │
  │   │   │                                                              │ │
  │   │   ├─► report.html (Summary report)                              │ │
  │   │   │    ├─ Pass/fail statistics                                  │ │
  │   │   │    ├─ Test case summaries                                   │ │
  │   │   │    ├─ Execution time breakdown                              │ │
  │   │   │    └─ Top failures                                          │ │
  │   │   │                                                              │ │
  │   │   └─► screenshots/*.png (Test evidence)                         │ │
  │   │        └─ Captured on failures or explicit commands             │ │
  │   │                                                                  │ │
  │   └─► Files written to /app/results (volume mounted to host)        │ │
  │                                                                      │ │
  └──────────────────────────────────────────────────────────────────────┘ │
    │                                                                      │
    ├─► Container exits with code:                                        │
    │    ├─ 0 = All tests passed                                          │
    │    ├─ 1 = Some tests failed                                         │
    │    └─ >1 = Execution error                                          │
    │                                                                      │
    └─► Docker removes container (--rm flag)                              │
         ├─ Results persist on host in ${WORKSPACE}/results               │
         └─ Logs persist on host in ${WORKSPACE}/logs                     │
```

---

## 4. SCPI Communication Flow (Test Execution Detail)

```
┌────────────────────────────────────────────────────────────────────────┐
│              EQUIPMENT COMMUNICATION (SCPI OVER TCP/IP)                 │
└────────────────────────────────────────────────────────────────────────┘

Container (Host Network Mode: 192.168.50.5)
  │
  ├─► Test Keyword: "Connect To Spectrum Analyzer"
  │
  ├─[1. Establish Connection]────────────────────────────────────────────┐
  │   │                                                                    │
  │   ├─► Get IP from network_vars.py                                    │
  │   │    └─► EQUIPMENT_LIST["SpectrumAnalyzer"] = "192.168.50.10"      │
  │   │                                                                    │
  │   ├─► Create TCP socket                                              │
  │   │    └─► socket.socket(socket.AF_INET, socket.SOCK_STREAM)         │
  │   │                                                                    │
  │   ├─► Connect to equipment                                           │
  │   │    └─► socket.connect(("192.168.50.10", 5025))                   │
  │   │         ├─ Port 5025 (standard SCPI-over-LAN port)               │
  │   │         └─ Timeout: 10 seconds                                   │
  │   │                                                                    │
  │   └─► IF CONNECTION FAILS:                                           │
  │        ├─ Retry up to 3 times                                        │
  │        ├─ Log error with details                                     │
  │        └─ Mark test as FAILED                                        │
  │                                                                        │
  ├─[2. Send SCPI Commands]──────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Example: Query Identity                                        │
  │   │    │                                                              │
  │   │    ├─► Format command: "*IDN?\n"                                 │
  │   │    ├─► Send via socket.send()                                    │
  │   │    ├─► Log: "Sent to SA: *IDN?"                                  │
  │   │    │                                                              │
  │   │    └─► Wait for response (timeout: 5s)                           │
  │   │         ├─► socket.recv(1024)                                    │
  │   │         ├─► Response: "Keysight,N9000A,MY12345678,A.01.23"       │
  │   │         └─► Log: "Received from SA: ..."                         │
  │   │                                                                    │
  │   ├─► Example: Configure Spectrum Analyzer                           │
  │   │    │                                                              │
  │   │    ├─► Commands:                                                 │
  │   │    │    ├─ ":SENS:FREQ:CENT 2.4GHz" (set center frequency)      │
  │   │    │    ├─ ":SENS:FREQ:SPAN 100MHz" (set span)                  │
  │   │    │    ├─ ":SENS:BAND:RES 1MHz" (resolution bandwidth)         │
  │   │    │    ├─ ":SENS:BAND:VID 3MHz" (video bandwidth)              │
  │   │    │    └─ ":INIT:CONT ON" (continuous sweep)                   │
  │   │    │                                                              │
  │   │    └─► Each command:                                             │
  │   │         ├─ Send command + "\n"                                   │
  │   │         ├─ Check for errors: ":SYST:ERR?"                        │
  │   │         └─ Log command and response                              │
  │   │                                                                    │
  │   ├─► Example: Measure Peak Power                                    │
  │   │    │                                                              │
  │   │    ├─► ":CALC:MARK:MAX" (marker to peak)                        │
  │   │    ├─► ":CALC:MARK:Y?" (query marker Y value)                   │
  │   │    ├─► Response: "-15.3" (dBm)                                   │
  │   │    └─► Store result for validation                               │
  │   │                                                                    │
  │   └─► Example: Configure Signal Generator                            │
  │        │                                                              │
  │        ├─► ":FREQ 2.4GHz" (set frequency)                            │
  │        ├─► ":POW -10dBm" (set power)                                 │
  │        ├─► ":OUTP ON" (enable RF output)                             │
  │        └─► Verify: ":OUTP?"                                          │
  │             └─► Response: "1" (ON)                                   │
  │                                                                        │
  ├─[3. Error Handling]──────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► After each command set, query errors:                          │
  │   │    ├─► ":SYST:ERR?"                                              │
  │   │    ├─► Response: "0,No error" (success)                          │
  │   │    └─► OR: "-113,Undefined header" (error)                       │
  │   │                                                                    │
  │   ├─► IF ERROR DETECTED:                                             │
  │   │    ├─ Log full error details                                     │
  │   │    ├─ Capture screenshot (if applicable)                         │
  │   │    ├─ Mark test step as FAILED                                   │
  │   │    └─ Continue to teardown                                       │
  │   │                                                                    │
  │   └─► Handle timeouts and connection drops:                          │
  │        ├─ socket.timeout exception                                   │
  │        ├─ ConnectionResetError                                       │
  │        └─ Log and fail gracefully                                    │
  │                                                                        │
  └─[4. Disconnect]──────────────────────────────────────────────────────┤
      │                                                                    │
      ├─► In test teardown:                                              │
      │    ├─► Turn off outputs (if applicable)                          │
      │    │    └─► ":OUTP OFF"                                          │
      │    │                                                              │
      │    ├─► Close socket connection                                   │
      │    │    └─► socket.close()                                       │
      │    │                                                              │
      │    └─► Log disconnection                                         │
      │                                                                    │
      └─► Equipment returns to idle state                                │


Network Path:
┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────┐
│  Container           │      │  Host Network        │      │  Lab VLAN    │
│  (via host network)  │ ───► │  eth1: 192.168.50.5  │ ───► │  Switch      │
│                      │      │                      │      │              │
└──────────────────────┘      └──────────────────────┘      └──────┬───────┘
                                                                    │
                                        ┌───────────────────────────┼────────┐
                                        │                           │        │
                                   192.168.50.10             192.168.50.11  ...
                                 Spectrum Analyzer          Signal Generator
                                 (Port 5025)                (Port 5025)
```

---

## 5. Results Processing Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                     RESULTS UPLOAD TO ELASTICSEARCH                     │
└────────────────────────────────────────────────────────────────────────┘

Test Execution Complete → output.xml generated
  │
  ├─► Jenkins Stage: "Upload to Elasticsearch"
  │
  ├─► Execute: python3 scripts/upload_to_elastic.py
  │              --results-file results/output.xml
  │              --elastic-url http://localhost:9200
  │              --build-number ${BUILD_NUMBER}
  │              --branch ${GIT_BRANCH}
  │              --verbose
  │
  ├─[1. Parse XML Results]───────────────────────────────────────────────┐
  │   │                                                                    │
  │   ├─► RobotResultsParser class initialized                           │
  │   │                                                                    │
  │   ├─► Parse output.xml with lxml                                     │
  │   │    ├─ Read file: results/output.xml                              │
  │   │    ├─ Parse XML structure                                        │
  │   │    └─ Validate schema                                            │
  │   │                                                                    │
  │   ├─► Extract metadata:                                              │
  │   │    ├─ <robot generator="Robot 7.0">                              │
  │   │    ├─ <suite name="RF Functional Tests">                         │
  │   │    ├─ <statistics>                                               │
  │   │    │   ├─ Total tests: 10                                        │
  │   │    │   ├─ Passed: 8                                              │
  │   │    │   ├─ Failed: 2                                              │
  │   │    │   └─ Skipped: 0                                             │
  │   │    └─ Timestamps (start, end, elapsed)                           │
  │   │                                                                    │
  │   └─► Extract individual test results:                               │
  │        │                                                              │
  │        ├─► FOR EACH <test> element:                                  │
  │        │    ├─ Test name                                             │
  │        │    ├─ Status (PASS/FAIL)                                    │
  │        │    ├─ Start time                                            │
  │        │    ├─ End time                                              │
  │        │    ├─ Elapsed time                                          │
  │        │    ├─ Error message (if failed)                             │
  │        │    ├─ Tags                                                  │
  │        │    └─ Documentation                                         │
  │        │                                                              │
  │        └─► Store in list: test_results[]                             │
  │                                                                        │
  ├─[2. Transform to JSON]───────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► FOR EACH test result:                                          │
  │   │    │                                                              │
  │   │    ├─► Create document:                                          │
  │   │    │    {                                                         │
  │   │    │      "@timestamp": "2026-02-23T10:35:42Z",                  │
  │   │    │      "test_suite": "rf_functional",                         │
  │   │    │      "test_name": "TC001 Equipment Connectivity",           │
  │   │    │      "status": "PASS",                                      │
  │   │    │      "duration_ms": 2345,                                   │
  │   │    │      "build_number": 42,                                    │
  │   │    │      "branch": "main",                                      │
  │   │    │      "equipment": ["SpectrumAnalyzer", "SignalGenerator"],  │
  │   │    │      "tags": ["smoke", "connectivity"],                     │
  │   │    │      "error_message": null,                                 │
  │   │    │      "jenkins_url": "http://...:8080/job/.../42/"           │
  │   │    │    }                                                         │
  │   │    │                                                              │
  │   │    └─► Add to documents list                                     │
  │   │                                                                    │
  │   └─► Result: List of JSON documents ready for upload                │
  │                                                                        │
  ├─[3. Connect to Elasticsearch]────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► ElasticsearchUploader class initialized                        │
  │   │                                                                    │
  │   ├─► Connect to http://localhost:9200                               │
  │   │    ├─ Verify ES is reachable                                     │
  │   │    ├─ Check ES version (8.12.0)                                  │
  │   │    └─ Verify authentication (if enabled)                         │
  │   │                                                                    │
  │   ├─► IF CONNECTION FAILS:                                           │
  │   │    ├─ Log warning                                                │
  │   │    ├─ Save results to local file                                 │
  │   │    │   └─► results/failed_upload_${BUILD_NUMBER}.json            │
  │   │    └─ Continue (non-blocking)                                    │
  │   │                                                                    │
  │   └─► Calculate index name:                                          │
  │        └─► "rf-automation-rf_functional-2026.02"                     │
  │             ├─ Prefix: rf-automation                                 │
  │             ├─ Suite: rf_functional                                  │
  │             └─ Date suffix: YYYY.MM                                  │
  │                                                                        │
  ├─[4. Create Index (if needed)]────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Check if index exists                                          │
  │   │    └─► HEAD /rf-automation-rf_functional-2026.02                 │
  │   │                                                                    │
  │   ├─► IF NOT EXISTS:                                                 │
  │   │    ├─► Create index with mapping:                                │
  │   │    │    {                                                         │
  │   │    │      "mappings": {                                          │
  │   │    │        "properties": {                                      │
  │   │    │          "@timestamp": {"type": "date"},                    │
  │   │    │          "test_suite": {"type": "keyword"},                 │
  │   │    │          "test_name": {"type": "text"},                     │
  │   │    │          "status": {"type": "keyword"},                     │
  │   │    │          "duration_ms": {"type": "integer"},                │
  │   │    │          "build_number": {"type": "integer"},               │
  │   │    │          "branch": {"type": "keyword"},                     │
  │   │    │          "equipment": {"type": "keyword"},                  │
  │   │    │          "tags": {"type": "keyword"},                       │
  │   │    │          "error_message": {"type": "text"}                  │
  │   │    │        }                                                     │
  │   │    │      }                                                       │
  │   │    │    }                                                         │
  │   │    │                                                              │
  │   │    └─► Index lifecycle policy (ILM):                             │
  │   │         ├─ Hot phase: 30 days                                    │
  │   │         ├─ Warm phase: 90 days                                   │
  │   │         └─ Delete phase: 730 days (2 years)                      │
  │   │                                                                    │
  │   └─► ELSE: Use existing index                                       │
  │                                                                        │
  ├─[5. Bulk Upload]─────────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Prepare bulk request:                                          │
  │   │    │                                                              │
  │   │    ├─► FOR EACH document:                                        │
  │   │    │    ├─ Action line: {"index": {}}                            │
  │   │    │    └─ Document line: {JSON document}                        │
  │   │    │                                                              │
  │   │    └─► Format: NDJSON (newline-delimited JSON)                   │
  │   │                                                                    │
  │   ├─► Send bulk request:                                             │
  │   │    └─► POST /rf-automation-rf_functional-2026.02/_bulk           │
  │   │         ├─ Content-Type: application/x-ndjson                    │
  │   │         ├─ Body: bulk NDJSON payload                             │
  │   │         └─ Timeout: 30 seconds                                   │
  │   │                                                                    │
  │   ├─► Process response:                                              │
  │   │    ├─ Extract: items[]                                           │
  │   │    ├─ Count successful: 10                                       │
  │   │    ├─ Count failed: 0                                            │
  │   │    └─ Log results                                                │
  │   │                                                                    │
  │   └─► IF PARTIAL FAILURE:                                            │
  │        ├─ Log failed documents                                       │
  │        ├─ Save failed documents to file                              │
  │        └─ Continue (non-blocking)                                    │
  │                                                                        │
  ├─[6. Verify Upload]───────────────────────────────────────────────────┤
  │   │                                                                    │
  │   ├─► Query recent documents:                                        │
  │   │    └─► GET /rf-automation-*/_search                              │
  │   │         {                                                         │
  │   │           "query": {                                             │
  │   │             "bool": {                                            │
  │   │               "must": [                                          │
  │   │                 {"term": {"build_number": 42}},                  │
  │   │                 {"range": {"@timestamp": {"gte": "now-5m"}}}     │
  │   │               ]                                                   │
  │   │             }                                                     │
  │   │           },                                                      │
  │   │           "size": 100                                            │
  │   │         }                                                         │
  │   │                                                                    │
  │   ├─► Verify count matches expected                                  │
  │   │    ├─ Expected: 10 documents                                     │
  │   │    ├─ Actual: 10 documents                                       │
  │   │    └─ Status: SUCCESS                                            │
  │   │                                                                    │
  │   └─► Log summary:                                                   │
  │        └─► "Successfully uploaded 10/10 test results to              │
  │             rf-automation-rf_functional-2026.02"                     │
  │                                                                        │
  └─[7. Cleanup]─────────────────────────────────────────────────────────┤
      │                                                                    │
      ├─► Close Elasticsearch connection                                 │
      ├─► Remove temporary files                                         │
      └─► Exit with status code 0                                        │


VISUALIZATION (Kibana)
  │
  ├─► User accesses http://<nuc-ip>:5601
  │
  ├─► Kibana queries Elasticsearch:
  │    └─► GET /rf-automation-*/_search (all indices)
  │
  ├─► Dashboards display:
  │    ├─ Test pass rate over time (line chart)
  │    ├─ Build success/failure (bar chart)
  │    ├─ Test duration trends (area chart)
  │    ├─ Failed tests breakdown (pie chart)
  │    ├─ Equipment health status (metric)
  │    └─ Recent test executions (data table)
  │
  └─► Data updated in real-time (15s refresh)
```

---

## 6. Component Interaction Matrix

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     WHO DOES WHAT, WHEN, AND USING WHAT                   │
└──────────────────────────────────────────────────────────────────────────┘

╔════════════════╦═══════════════════════╦══════════════╦═════════════════╗
║   COMPONENT    ║      WHAT IT DOES     ║     WHEN     ║   USING WHAT    ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Git Repository ║ Store source code,    ║ Continuously ║ - Git           ║
║                ║ trigger builds via    ║              ║ - Webhooks      ║
║                ║ webhooks              ║              ║ - SCM polling   ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Jenkins        ║ Orchestrate CI/CD     ║ On trigger:  ║ - Jenkinsfile   ║
║                ║ pipeline:             ║ - Git push   ║ - Pipeline DSL  ║
║                ║ - Checkout code       ║ - Scheduled  ║ - Docker CLI    ║
║                ║ - Build Docker image  ║ - Manual     ║ - Python        ║
║                ║ - Execute tests       ║              ║ - Bash          ║
║                ║ - Process results     ║              ║ - Plugins       ║
║                ║ - Upload to ES        ║              ║                 ║
║                ║ - Archive artifacts   ║              ║                 ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Docker Engine  ║ Build and run test    ║ During build ║ - Dockerfile    ║
║                ║ containers in         ║ stage and    ║ - Host network  ║
║                ║ isolated environment  ║ test stage   ║ - Volumes       ║
║                ║                       ║              ║ - Python base   ║
║                ║                       ║              ║   image         ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Test Runner    ║ Execute Robot         ║ During test  ║ - Robot         ║
║ Container      ║ Framework tests,      ║ execution    ║   Framework 7.0 ║
║                ║ communicate with      ║ stage (2-60  ║ - SCPI over TCP ║
║                ║ equipment via SCPI,   ║ min typical) ║ - Python libs   ║
║                ║ generate results      ║              ║ - Network vars  ║
║                ║                       ║              ║ - RF keywords   ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ RF Equipment   ║ Respond to SCPI       ║ During test  ║ - SCPI protocol ║
║ (SA, SG, DUT)  ║ commands:             ║ execution    ║ - TCP/IP        ║
║                ║ - Generate signals    ║              ║ - Port 5025     ║
║                ║ - Measure signals     ║              ║ - Lab VLAN      ║
║                ║ - Return measurements ║              ║   network       ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ upload_to_     ║ Parse output.xml,     ║ After test   ║ - lxml (XML)    ║
║ elastic.py     ║ transform to JSON,    ║ execution    ║ - Elasticsearch ║
║                ║ bulk upload to ES,    ║ completes    ║   Python client ║
║                ║ handle failures       ║              ║ - Bulk API      ║
║                ║ gracefully            ║              ║ - NDJSON format ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Elasticsearch  ║ Store test results,   ║ Continuously ║ - Lucene index  ║
║                ║ index documents,      ║ (receives    ║ - REST API      ║
║                ║ provide search API,   ║ data after   ║ - ILM policies  ║
║                ║ manage data lifecycle ║ each build)  ║ - Mappings      ║
║                ║                       ║              ║ - Queries (DSL) ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Kibana         ║ Visualize test data,  ║ On-demand    ║ - Elasticsearch ║
║                ║ create dashboards,    ║ (user        ║   Query DSL     ║
║                ║ analyze trends,       ║ accesses     ║ - Visualizations║
║                ║ generate reports      ║ web UI)      ║ - Dashboards    ║
║                ║                       ║              ║ - Canvas        ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ network_vars.py║ Provide configuration ║ Test startup ║ - Python dict   ║
║                ║ data (equipment IPs,  ║ (imported by ║ - Helper funcs  ║
║                ║ ES endpoint, RF       ║ tests)       ║ - Constants     ║
║                ║ parameters), validate ║              ║                 ║
║                ║ connectivity          ║              ║                 ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ rf_keywords.   ║ Provide reusable      ║ Test runtime ║ - Robot         ║
║ resource       ║ keywords for:         ║ (referenced  ║   Framework     ║
║                ║ - Network checks      ║ in test      ║   keywords      ║
║                ║ - Equipment connect   ║ files)       ║ - Python libs   ║
║                ║ - SCPI commands       ║              ║ - network_vars  ║
║                ║ - Measurements        ║              ║                 ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ Test Files     ║ Define test cases,    ║ Test         ║ - Robot syntax  ║
║ (.robot)       ║ test logic, expected  ║ execution    ║ - rf_keywords   ║
║                ║ results, and          ║              ║ - network_vars  ║
║                ║ validations           ║              ║ - Built-in libs ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ setup_helpers. ║ Automate full         ║ One-time     ║ - apt-get       ║
║ sh             ║ infrastructure setup: ║ (initial     ║ - Docker        ║
║                ║ - Install Docker      ║ server       ║ - Jenkins       ║
║                ║ - Install Jenkins     ║ setup)       ║ - docker-compose║
║                ║ - Deploy ELK Stack    ║              ║ - systemctl     ║
║                ║ - Configure services  ║              ║ - pip           ║
║                ║                       ║              ║                 ║
╠════════════════╬═══════════════════════╬══════════════╬═════════════════╣
║                ║                       ║              ║                 ║
║ docker-compose.║ Define ELK Stack      ║ At service   ║ - Docker        ║
║ yml            ║ services, networks,   ║ startup      ║   Compose v2    ║
║                ║ volumes, and health   ║ (docker      ║ - YAML config   ║
║                ║ checks                ║ compose up)  ║ - Volumes       ║
║                ║                       ║              ║ - Networks      ║
║                ║                       ║              ║                 ║
╚════════════════╩═══════════════════════╩══════════════╩═════════════════╝
```

---

## 7. Timing Diagram (Typical Build Execution)

```
TIME →  0s     30s     60s     90s    120s    150s    180s    210s    240s
        │      │       │       │       │       │       │       │       │
Jenkins ├──────┤                                               ├───────┤
        │ Init │                                               │Archive│
        │      │                                               │       │
Docker  │      ├───────┤                                       │       │
Build   │      │ Build │                                       │       │
        │      │ Image │                                       │       │
        │      │       │                                       │       │
Infra   │      │       ├───┤                                   │       │
Verify  │      │       │CHK│                                   │       │
        │      │       │   │                                   │       │
Test    │      │       │   ├───────────────────────────────────┤       │
Exec    │      │       │   │  Robot Framework Execution        │       │
        │      │       │   │  - Setup: 5s                      │       │
        │      │       │   │  - TC001-TC010: 100s              │       │
        │      │       │   │  - Teardown: 5s                   │       │
        │      │       │   │  - Report gen: 10s                │       │
        │      │       │   │                                   │       │
Results │      │       │   │                                   ├───┤   │
Upload  │      │       │   │                                   │ES │   │
        │      │       │   │                                   │   │   │
        │      │       │   │                                   │   │   │
Clean   │      │       │   │                                   │   │   ├──┤
        │      │       │   │                                   │   │   │  │
        └──────┴───────┴───┴───────────────────────────────────┴───┴───┴──┘

Total Typical Build Time: 240 seconds (4 minutes)

Breakdown:
- Initialize: 10s (checkout, setup)
- Docker Build: 20s (with cache) or 90s (without cache)
- Infrastructure Verify: 5s (health checks)
- Test Execution: 120s (varies by test suite)
- Results Upload: 10s (parse + upload)
- Archive Artifacts: 5s
- Cleanup: 10s

Note: Times are approximate and vary based on:
- Number of tests in suite
- Equipment response times
- Network latency
- Server load
- Docker cache availability
```

---

## 8. Failure Scenarios and Handling

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FAILURE HANDLING FLOWS                           │
└────────────────────────────────────────────────────────────────────────┘

SCENARIO 1: Equipment Not Reachable
────────────────────────────────────
Test: "Connect To Spectrum Analyzer"
  │
  ├─► Ping 192.168.50.10
  │    └─► TIMEOUT
  │
  ├─► Retry ping (up to 3 times)
  │    └─► TIMEOUT
  │
  ├─► Mark test as FAILED
  ├─► Log: "Equipment unreachable: 192.168.50.10"
  ├─► Capture screenshot (if applicable)
  ├─► Continue to test teardown
  └─► Subsequent tests using SA are skipped


SCENARIO 2: SCPI Command Error
───────────────────────────────
Test: "Configure Spectrum Analyzer"
  │
  ├─► Send: ":SENS:FREQ:CENT 2.4GHz"
  │    └─► OK
  │
  ├─► Send: ":SENS:INVALID:COMMAND"
  │    └─► No response
  │
  ├─► Query errors: ":SYST:ERR?"
  │    └─► Response: "-113,Undefined header"
  │
  ├─► Mark test step as FAILED
  ├─► Log full error details
  ├─► Continue to next test step or teardown
  └─► Test marked as FAILED


SCENARIO 3: Elasticsearch Unavailable
──────────────────────────────────────
Upload Stage:
  │
  ├─► Attempt connection to localhost:9200
  │    └─► CONNECTION REFUSED
  │
  ├─► Retry connection (up to 3 times)
  │    └─► FAILED
  │
  ├─► Log warning: "Elasticsearch unavailable"
  ├─► Save results locally:
  │    └─► results/failed_upload_42.json
  │
  ├─► Continue pipeline (non-blocking)
  └─► Build status: SUCCESS (tests passed)
      Note: Results not in ES, but available in Jenkins


SCENARIO 4: Docker Build Failure
─────────────────────────────────
Build Stage:
  │
  ├─► docker build -t rf-test-runner:42
  │    │
  │    ├─► Copy requirements.txt
  │    │    └─► OK
  │    │
  │    ├─► pip install -r requirements.txt
  │    │    └─► ERROR: Package not found
  │    │
  │    └─► Build FAILED
  │
  ├─► Jenkins marks build as FAILED
  ├─► Log error details
  ├─► Send failure notification
  └─► STOP pipeline (do not execute tests)


SCENARIO 5: Test Timeout
─────────────────────────
Test: "Measure Signal Power"
  │
  ├─► Send SCPI command
  ├─► Wait for measurement (timeout: 5s)
  │    └─► NO RESPONSE (5s elapsed)
  │
  ├─► Robot Framework timeout triggered
  ├─► Mark keyword as FAILED
  ├─► Log: "Timeout waiting for measurement"
  ├─► Continue to test teardown
  └─► Test marked as FAILED


SCENARIO 6: Infrastructure Verify Warning
──────────────────────────────────────────
Verify Stage:
  │
  ├─► Check Elasticsearch
  │    └─► curl: Connection refused
  │
  ├─► Log warning: "ES not available"
  ├─► Check Kibana
  │    └─► curl: Connection refused
  │
  ├─► Log warning: "Kibana not available"
  ├─► Set flag: ELASTIC_UNAVAILABLE=true
  └─► Continue to test execution (non-blocking)
      Note: Tests run, but results won't upload


GRACEFUL DEGRADATION PRINCIPLES:
─────────────────────────────────
1. Test execution is CRITICAL → Failure stops pipeline
2. Results upload is BEST-EFFORT → Failure logged but doesn't fail build
3. Infrastructure checks are WARNINGS → Failures don't block tests
4. Equipment connectivity is CRITICAL → Failures fail individual tests
5. Individual test failures → Build continues, marked as UNSTABLE
```

---

## 9. Data Flow Summary

```
┌────────────────────────────────────────────────────────────────────────┐
│                          END-TO-END DATA FLOW                           │
└────────────────────────────────────────────────────────────────────────┘

[Git Repository]
      │
      │ (1) git clone / git pull
      ▼
[Jenkins Workspace]
      │
      │ (2) docker build
      ▼
[Docker Image: rf-test-runner:42]
      │
      │ (3) docker run --network host
      ▼
[Running Container]
      │
      ├─► (4) Import: resources/network_vars.py
      │         └─► EQUIPMENT_LIST → Equipment IPs
      │
      ├─► (5) Import: resources/rf_keywords.resource
      │         └─► Keywords → Test logic
      │
      └─► (6) Load: tests/*.robot
                └─► Test cases → Execution plan

[Running Container] ←─────────────────────────┐
      │                                        │
      │ (7) SCPI commands over TCP/IP          │
      ▼                                        │
[RF Equipment: 192.168.50.10, .11, .20]       │
      │                                        │
      │ (8) Measurements & responses           │
      └────────────────────────────────────────┘

[Running Container]
      │
      │ (9) Generate outputs
      ▼
[Mounted Volume: results/]
      ├─ output.xml (RF results)
      ├─ log.html (detailed log)
      ├─ report.html (summary)
      └─ screenshots/*.png

[Jenkins Workspace]
      │
      │ (10) python3 scripts/upload_to_elastic.py
      ▼
[Elasticsearch: localhost:9200]
      │
      │ (11) Index: rf-automation-rf_functional-2026.02
      │      └─► Documents: Test results as JSON
      │
      ▼
[Kibana: localhost:5601]
      │
      │ (12) Query Elasticsearch
      ▼
[User Browser: Dashboards & Visualizations]


DATA FORMATS AT EACH STAGE:
────────────────────────────
(1) Git       → Files (.robot, .py, .resource, .yml)
(2) Docker    → Image layers (filesystem snapshots)
(3) Container → Running processes (Python, Robot)
(4-6) Runtime → Python objects (dicts, lists, classes)
(7) SCPI      → ASCII text commands over TCP
(8) SCPI      → ASCII text responses
(9) Output    → XML (output.xml), HTML (reports), PNG (screenshots)
(10) Upload   → JSON documents (NDJSON bulk format)
(11) ES       → Indexed documents (Lucene format)
(12) Kibana   → Visualizations (charts, tables, metrics)
```

---

## 10. Deployment Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                    PHYSICAL DEPLOYMENT ARCHITECTURE                     │
└────────────────────────────────────────────────────────────────────────┘

LOCATION: On-Premise Lab

┌─────────────────────────────────────────────────────────────────────────┐
│                          Intel NUC Server                                │
│  Model: Intel NUC 11 Pro (or similar)                                   │
│  OS: Ubuntu Server 24.04 LTS                                            │
│  CPU: Intel Core i5/i7 (quad-core+)                                     │
│  RAM: 32GB DDR4                                                          │
│  Storage: 1TB NVMe SSD                                                   │
│  Network: 2x Gigabit Ethernet                                            │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                        SERVICES RUNNING                             │ │
│  ├────────────────────────────────────────────────────────────────────┤ │
│  │                                                                      │ │
│  │  Jenkins (systemd service)                                          │ │
│  │  ├─ Port: 8080                                                      │ │
│  │  ├─ User: jenkins                                                   │ │
│  │  ├─ Home: /var/lib/jenkins                                          │ │
│  │  └─ Java: OpenJDK 17                                                │ │
│  │                                                                      │ │
│  │  Docker Engine (systemd service)                                    │ │
│  │  ├─ Version: 24.x                                                   │ │
│  │  ├─ Socket: /var/run/docker.sock                                    │ │
│  │  ├─ Data root: /var/lib/docker                                      │ │
│  │  └─ Driver: overlay2                                                │ │
│  │                                                                      │ │
│  │  Elasticsearch (Docker container)                                   │ │
│  │  ├─ Image: elasticsearch:8.12.0                                     │ │
│  │  ├─ Ports: 9200 (HTTP), 9300 (Transport)                            │ │
│  │  ├─ Volume: elasticsearch_data (persistent)                         │ │
│  │  ├─ Heap: 2GB                                                       │ │
│  │  └─ Restart: always                                                 │ │
│  │                                                                      │ │
│  │  Kibana (Docker container)                                          │ │
│  │  ├─ Image: kibana:8.12.0                                            │ │
│  │  ├─ Port: 5601                                                      │ │
│  │  ├─ Volume: kibana_data (persistent)                                │ │
│  │  └─ Restart: always                                                 │ │
│  │                                                                      │ │
│  │  Test Runner (Docker container, ephemeral)                          │ │
│  │  ├─ Image: rf-test-runner:${BUILD_NUMBER}                           │ │
│  │  ├─ Lifecycle: Created per build, removed after                     │ │
│  │  ├─ Network: host (shares NUC's network stack)                      │ │
│  │  └─ Volumes: results/, logs/ (from Jenkins workspace)               │ │
│  │                                                                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      NETWORK CONFIGURATION                          │ │
│  ├────────────────────────────────────────────────────────────────────┤ │
│  │                                                                      │ │
│  │  eth0: Office Network                                               │ │
│  │  ├─ IP: DHCP or Static (e.g., 10.0.1.50)                            │ │
│  │  ├─ Gateway: Office router                                          │ │
│  │  ├─ DNS: Office DNS servers                                         │ │
│  │  └─ Purpose: Internet, Git, Jenkins UI, Kibana UI                   │ │
│  │                                                                      │ │
│  │  eth1: Lab VLAN                                                     │ │
│  │  ├─ IP: 192.168.50.5/24 (Static)                                    │ │
│  │  ├─ Gateway: None (isolated)                                        │ │
│  │  ├─ DNS: None                                                       │ │
│  │  └─ Purpose: RF equipment communication only                        │ │
│  │                                                                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      STORAGE LAYOUT                                 │ │
│  ├────────────────────────────────────────────────────────────────────┤ │
│  │                                                                      │ │
│  │  /                 (50GB, OS and system files)                      │ │
│  │  /var/lib/docker   (300GB, Docker images & containers)              │ │
│  │  /var/lib/jenkins  (100GB, Jenkins workspaces & artifacts)          │ │
│  │  /var/backups      (50GB, Configuration backups)                    │ │
│  │  elasticsearch_data (400GB, ES indices & data)                      │ │
│  │  kibana_data       (10GB, Kibana dashboards & config)               │ │
│  │  /home             (90GB, User files and scripts)                   │ │
│  │                                                                      │ │
│  │  Total: ~1TB NVMe SSD                                               │ │
│  │                                                                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
         │                                           │
         │ eth0 (Office Network)                     │ eth1 (Lab VLAN)
         ▼                                           ▼
┌──────────────────────┐                  ┌────────────────────────────┐
│  Office Network      │                  │  Lab VLAN Switch           │
│  10.0.1.0/24         │                  │  192.168.50.0/24           │
│                      │                  │  (Isolated, no internet)   │
│  - Internet Gateway  │                  │                            │
│  - Git Server        │                  │  ┌──────────────────────┐ │
│  - Developer PCs     │                  │  │ Spectrum Analyzer    │ │
│  - WiFi Access       │                  │  │ IP: 192.168.50.10    │ │
└──────────────────────┘                  │  │ Port: 5025 (SCPI)    │ │
                                          │  └──────────────────────┘ │
                                          │  ┌──────────────────────┐ │
                                          │  │ Signal Generator     │ │
                                          │  │ IP: 192.168.50.11    │ │
                                          │  │ Port: 5025 (SCPI)    │ │
                                          │  └──────────────────────┘ │
                                          │  ┌──────────────────────┐ │
                                          │  │ DUT (Device)         │ │
                                          │  │ IP: 192.168.50.20    │ │
                                          │  │ Port: Various        │ │
                                          │  └──────────────────────┘ │
                                          └────────────────────────────┘

SECURITY ZONES:
───────────────
Zone 1: Office Network (Trusted)
  - Internet access
  - User access to Jenkins/Kibana UI
  - Firewall: Ports 8080, 5601 only

Zone 2: Lab VLAN (Isolated)
  - NO internet access
  - RF equipment only
  - NO inbound from office network
  - Container access via host network mode

ACCESS CONTROLS:
────────────────
- Jenkins: User authentication required (local DB or LDAP)
- Kibana: Authentication via Elasticsearch (if enabled)
- SSH: Key-based authentication only
- Firewall (ufw):
    - 22/tcp (SSH, restricted IPs)
    - 8080/tcp (Jenkins UI)
    - 5601/tcp (Kibana UI)
    - All other ports blocked
```

---

## Summary

This detailed block diagram documentation covers:

1. **High-Level Architecture**: Complete system overview showing all components
2. **CI/CD Pipeline Flow**: Detailed Jenkinsfile execution stages
3. **Docker Container Execution**: Test runner lifecycle and test execution
4. **SCPI Communication**: Equipment communication protocol details
5. **Results Processing**: XML parsing and Elasticsearch upload flow
6. **Component Interaction Matrix**: Who does what, when, and using what
7. **Timing Diagram**: Typical build execution timeline
8. **Failure Scenarios**: How the system handles various failures
9. **Data Flow**: End-to-end data transformation and movement
10. **Deployment Architecture**: Physical deployment and network topology

These diagrams provide a complete technical reference for understanding, maintaining, and extending the RF automation infrastructure.
