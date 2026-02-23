# RF Automation Infrastructure

Professional on-premise automation system for RF equipment testing using Robot Framework, Docker, Jenkins, and ELK Stack.

## System Overview

An enterprise-grade automation infrastructure running on Intel NUC hardware, designed for controlling and testing RF equipment within a dedicated VLAN environment.

### Core Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Hardware** | Intel NUC (i7, 32GB RAM, 1TB SSD) | Dedicated test orchestration server |
| **OS** | Ubuntu Server 24.04 LTS | Native host operating system |
| **Orchestration** | Jenkins | CI/CD pipeline management |
| **Containerization** | Docker Engine | Test environment isolation |
| **Database** | Elasticsearch 8.12.0 | Test results storage |
| **Visualization** | Kibana 8.12.0 | Dashboard and analytics |
| **Framework** | Robot Framework (Python 3.11) | Test automation |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Intel NUC Server                         │
│                  Ubuntu Server 24.04 LTS                     │
│                                                              │
│  ┌────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │  Jenkins   │  │  Docker Engine   │  │   ELK Stack    │  │
│  │            │  │                  │  │                │  │
│  │  Pipeline  │──│  RF Test Runner  │──│  Elasticsearch │  │
│  │  Executor  │  │   Container      │  │     Kibana     │  │
│  └────────────┘  └──────────────────┘  └────────────────┘  │
│                           │                                  │
└───────────────────────────┼──────────────────────────────────┘
                            │ Host Network Mode
                            │
                    ┌───────▼────────┐
                    │   Lab VLAN     │
                    │  192.168.50.x  │
                    └────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐        ┌─────▼─────┐      ┌─────▼─────┐
   │ Spectrum│        │  Signal   │      │    DUT    │
   │ Analyzer│        │ Generator │      │           │
   │  .50.10 │        │   .50.11  │      │  .50.20   │
   └─────────┘        └───────────┘      └───────────┘
```

## Network Architecture

- **Host Network Mode**: Docker containers use `--network host` for direct equipment access
- **Dual Network**: Server connects to both office network (Git/Updates) and Lab VLAN (Equipment)
- **VLAN Segmentation**: RF equipment isolated in dedicated VLAN (192.168.50.0/24)

## Project Structure

```
project-root/
│
├── tests/                      # Robot Framework test suites
│   ├── rf_functional.robot     # Functional RF tests
│   └── calibration.robot       # Equipment calibration tests
│
├── resources/                  # Shared test resources
│   ├── rf_keywords.resource    # Custom RF keywords
│   └── network_vars.py         # Equipment IP configuration
│
├── scripts/                    # Automation scripts
│   ├── upload_to_elastic.py    # Results upload to Elasticsearch
│   └── setup_helpers.sh        # Installation helpers
│
├── infra/                      # Infrastructure as Code
│   └── docker-compose.yml      # ELK Stack definition
│
├── docs/                       # Documentation
│   ├── SETUP.md               # Installation guide
│   ├── ARCHITECTURE.md        # System architecture
│   ├── DEVELOPMENT.md         # Development guide
│   └── OPERATIONS.md          # Operations manual
│
├── results/                    # Test execution results (gitignored)
├── logs/                       # Application logs (gitignored)
│
├── Dockerfile                  # Test runner container
├── Jenkinsfile                 # CI/CD pipeline definition
├── requirements.txt            # Python dependencies
├── .gitignore                 # Git ignore patterns
└── README.md                  # This file
```

## Quick Start

### Prerequisites

- Intel NUC with Ubuntu Server 24.04 LTS installed
- Network connectivity to both office and Lab VLAN
- Git installed and configured
- Sudo/root access

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Fully_Product_Automation

# Run the setup script
sudo bash scripts/setup_helpers.sh

# Start ELK Stack
cd infra && docker-compose up -d

# Verify installation
docker ps
curl http://localhost:9200
curl http://localhost:5601
```

Detailed instructions: [docs/SETUP.md](docs/SETUP.md)

## Usage

### Running Tests Manually

```bash
# Build the test runner image
docker build -t rf-test-runner .

# Run tests
docker run --rm --network host \
  -v $(pwd)/results:/app/results \
  rf-test-runner --outputdir results tests/
```

### Running Tests via Jenkins

1. Access Jenkins: `http://<nuc-ip>:8080`
2. Navigate to RF-Automation-Pipeline
3. Click "Build Now"
4. View results in Kibana: `http://<nuc-ip>:5601`

### Viewing Results

- **Jenkins**: HTML reports archived in build artifacts
- **Kibana**: Real-time dashboards at `http://<nuc-ip>:5601`
- **Local**: `results/` directory contains log.html, report.html, output.xml

## Development Workflow

### Branching Strategy

- `main`: Production-ready code running in lab
- `develop`: Integration branch for new features
- `feature/*`: New test development or infrastructure updates

### Contributing

1. Create feature branch: `git checkout -b feature/new-rf-test`
2. Develop and test locally
3. Commit changes: `git commit -m "Add new RF test for X"`
4. Push to remote: `git push origin feature/new-rf-test`
5. Create Pull Request to `develop`
6. After review, merge to `develop`
7. CI/CD automatically deploys to lab

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for detailed guidelines.

## Configuration

### Equipment IP Addresses

Edit `resources/network_vars.py`:

```python
EQUIPMENT_LIST = {
    "SpectrumAnalyzer": "192.168.50.10",
    "SignalGenerator": "192.168.50.11",
    "DUT": "192.168.50.20"
}
```

### Elasticsearch Endpoint

Default: `http://localhost:9200`

Modify in `resources/network_vars.py` if using different configuration.

## Monitoring & Maintenance

### Health Checks

```bash
# Check Docker containers
docker ps

# Check ELK Stack
curl http://localhost:9200/_cluster/health
curl http://localhost:5601/api/status

# Check Jenkins
systemctl status jenkins
```

### Logs

```bash
# ELK Stack logs
docker-compose -f infra/docker-compose.yml logs -f

# Jenkins logs
sudo journalctl -u jenkins -f

# Test execution logs
tail -f logs/test_execution.log
```

## Troubleshooting

### Common Issues

**Equipment Not Reachable**
- Verify VLAN connectivity: `ping 192.168.50.10`
- Check host network mode in Docker run command
- Verify IP addresses in `resources/network_vars.py`

**Elasticsearch Not Starting**
- Check available memory: `free -h`
- Verify Java heap settings in docker-compose.yml
- Check logs: `docker logs elasticsearch`

**Jenkins Build Fails**
- Verify Docker image builds: `docker build -t rf-test-runner .`
- Check workspace permissions
- Review Jenkins console output

See [docs/OPERATIONS.md](docs/OPERATIONS.md) for comprehensive troubleshooting.

## Technology Stack

- **Python**: 3.11
- **Robot Framework**: Latest stable
- **Docker**: 24.x
- **Jenkins**: LTS
- **Elasticsearch**: 8.12.0
- **Kibana**: 8.12.0
- **Ubuntu**: Server 24.04 LTS

## License

Internal project - All rights reserved

## Support

For issues or questions:
- Create an issue in the repository
- Contact the automation team
- See documentation in `docs/`

## Roadmap

- [ ] Phase 1: Infrastructure setup and basic tests
- [ ] Phase 2: Advanced RF test scenarios
- [ ] Phase 3: Automated calibration workflows
- [ ] Phase 4: ML-based anomaly detection
- [ ] Phase 5: Multi-site deployment

---

**Last Updated**: 2026-02-23
**Maintainer**: Automation Team
**Status**: Active Development
