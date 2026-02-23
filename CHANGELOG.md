# Changelog

All notable changes to the RF Automation Infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-23

### Added
- **Allure Framework 2.25.0** integration for enhanced test reporting
  - Interactive HTML reports with rich visualizations
  - Historical trend analysis across builds (20 runs retention)
  - Automatic failure categorization (8 categories)
  - Screenshots and log attachments
  - Timeline and behavior views
- Allure CLI installed in Docker container
- Allure Jenkins Plugin support for report publishing
- allure.properties configuration file
- categories.json for automatic test failure classification
- Comprehensive Allure documentation (docs/ALLURE.md)
- Allure installation steps in setup_helpers.sh

### Changed
- Updated Jenkinsfile to:
  - Generate Allure reports during pipeline execution
  - Archive Allure reports as build artifacts
  - Enable allure_robotframework listener for test runs
- Modified Dockerfile to install Allure CLI with Java runtime
- Updated requirements.txt with allure-robotframework dependencies
- Enhanced README.md with Allure features and access information
- Updated SETUP.md with Allure installation instructions
- Updated ARCHITECTURE.md to include Allure as reporting component

### Documentation
- Added comprehensive Allure integration guide (docs/ALLURE.md) with:
  - Architecture and data flow diagrams
  - Configuration and usage instructions
  - Jenkins integration guide
  - Report features overview
  - Customization options
  - Best practices and troubleshooting
  - Security considerations

## [1.0.0] - 2026-02-23

### Added
- Initial project structure and infrastructure
- Docker-based test execution environment
- Jenkins CI/CD pipeline integration
- ELK Stack (Elasticsearch + Kibana) for test results
- Robot Framework test suites:
  - RF functional tests
  - Equipment calibration tests
- Comprehensive documentation:
  - README.md with project overview
  - SETUP.md for installation guide
  - ARCHITECTURE.md for system design
  - DEVELOPMENT.md for developers
  - OPERATIONS.md for daily operations
  - BLOCK_DIAGRAM.md with detailed architecture diagrams
- Python scripts:
  - network_vars.py for equipment configuration
  - upload_to_elastic.py for results upload
- Infrastructure as Code:
  - Dockerfile for test runner
  - docker-compose.yml for ELK Stack
  - Jenkinsfile for pipeline
- Automated setup script (setup_helpers.sh)
- Health check script for system monitoring
- Git configuration (.gitignore, .editorconfig)

### Infrastructure
- Ubuntu Server 24.04 LTS support
- Docker Engine integration
- Host network mode for equipment access
- Dual network architecture (Office + Lab VLAN)

### Documentation
- Complete setup guide with step-by-step instructions
- Architecture documentation with diagrams
- Development guide with best practices
- Operations manual with troubleshooting
- Detailed block diagrams for all system components

### Equipment Support
- Spectrum Analyzer control keywords
- Signal Generator control keywords
- Device Under Test (DUT) integration
- SCPI communication layer

## [Unreleased]

### Planned
- Additional equipment support (Power Meters, VNAs)
- Advanced calibration algorithms
- Machine learning-based anomaly detection
- Multi-site deployment support
- Email notifications for failures
- Slack/Teams integration
- Performance optimization
- Enhanced security features
- Test result comparison across builds
- Custom Allure plugins for RF-specific metrics

---

**Legend**:
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` for vulnerability fixes
