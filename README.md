# RF Automation Infrastructure

On-premise automation system for RF equipment testing using Robot Framework, Docker, Jenkins, and ELK Stack.
Supports both **real equipment** (Lab VLAN) and **mock equipment** (local Docker simulation).

## Prerequisites

- Ubuntu 22.04+ (tested on 22.04 and 24.04)
- Docker Engine with Compose plugin (`docker compose` v2)
- Python 3.11+
- Git
- sudo/root access

## Quick Start (Local with Mock Equipment)

```bash
# 1. Clone
git clone <repo-url>
cd Fully_Product_Automation

# 2. Set vm.max_map_count for Elasticsearch
sudo sysctl -w vm.max_map_count=262144

# 3. Start all services (ELK + Mock Equipment)
cd infra && docker compose up -d --build

# 4. Wait ~60s for Elasticsearch to become healthy, then verify
docker compose ps
curl http://localhost:9200/_cluster/health?pretty
curl http://localhost:8001/health   # Mock Spectrum Analyzer
curl http://localhost:8002/health   # Mock Signal Generator
curl http://localhost:8003/health   # Mock DUT

# 5. Create a Python virtual environment and install dependencies
cd ..
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 6. Run tests
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      tests/integration_popo.robot
```

### Service URLs (after `docker compose up`)

| Service              | URL                     | Credentials   |
|----------------------|-------------------------|---------------|
| Jenkins              | http://localhost:8080   | admin / admin |
| Kibana               | http://localhost:5601   |               |
| Elasticsearch        | http://localhost:9200   |               |
| Mock Spectrum Analyzer (HTTP) | http://localhost:8001 |       |
| Mock Signal Generator (HTTP)  | http://localhost:8002 |       |
| Mock DUT (HTTP)               | http://localhost:8003 |       |

Mock equipment SCPI TCP ports: **5001** (SA), **5002** (SG), **5003** (DUT).

## Full Setup

All services (Jenkins, ELK, Mock Equipment) are included in a single `docker compose`:

```bash
sudo sysctl -w vm.max_map_count=262144
cd infra && docker compose up -d --build
```

Jenkins takes ~2 minutes to start. After all services are healthy:
- Jenkins: http://localhost:8080 (admin / admin)
- Kibana: http://localhost:5601
- Elasticsearch: http://localhost:9200

## Project Structure

```
project-root/
├── tests/                      # Robot Framework test suites
│   ├── integration_popo.robot  # Proof-of-platform tests (mock)
│   ├── rf_functional.robot     # Functional RF tests
│   └── calibration.robot       # Equipment calibration tests
│
├── resources/                  # Shared test resources
│   ├── rf_keywords.resource    # RF control keywords
│   ├── SCPIEquipment.py        # SCPI TCP communication library
│   ├── ElasticsearchListener.py # Real-time ES upload listener
│   ├── environment_config.py   # Environment config loader
│   └── network_vars.py         # Equipment IP/port configuration
│
├── mock_equipment/             # Mock RF equipment (Docker)
│   ├── Dockerfile
│   ├── main.py                 # FastAPI + SCPI server
│   ├── equipment/              # Equipment simulators
│   └── rf_physics.py           # RF physics simulation engine
│
├── infra/                      # Infrastructure as Code
│   ├── docker-compose.yml      # Jenkins + ELK + Mock Equipment (local)
│   ├── docker-compose.aws.yml  # AWS deployment variant
│   ├── jenkins/                # Jenkins Docker build context
│   │   ├── Dockerfile          # Jenkins LTS + plugins + Docker CLI
│   │   └── casc.yaml           # Jenkins Configuration as Code
│   ├── elasticsearch-index-template.json
│   ├── kibana-dashboard.ndjson
│   └── jenkins-job-config.xml
│
├── config/
│   ├── integration.env         # Mock equipment config
│   └── aws.env                 # AWS deployment config
│
├── scripts/                    # Automation scripts
│   ├── setup_helpers.sh        # Full system setup
│   ├── upload_to_elastic.py    # Manual ES upload
│   └── ...                     # Jenkins & AWS scripts
│
├── aws/                        # AWS deployment files
├── docs/                       # Documentation
├── Dockerfile                  # Test runner container
├── Jenkinsfile                 # Production Jenkins pipeline
├── Jenkinsfile.integration     # Integration Jenkins pipeline
├── Makefile                    # Convenience commands
└── requirements.txt            # Python dependencies
```

## Running Tests

### Locally (with mock equipment running)

```bash
source venv/bin/activate

# All PoPo tests
robot --outputdir results tests/integration_popo.robot

# Functional tests
robot --outputdir results tests/rf_functional.robot

# All tests with Allure + Elasticsearch listeners
robot --outputdir results \
      --listener allure_robotframework:allure-results \
      --listener resources.ElasticsearchListener \
      tests/
```

### Via Jenkins

1. Open Jenkins at http://localhost:8080
2. Select **RF-Automation-Integration** job
3. Click **Build with Parameters**
4. Choose test suite, tags, and options
5. Click **Build**

Results are available via:
- **Allure Report** (linked from Jenkins build page)
- **Kibana** dashboards at http://localhost:5601
- **Elasticsearch** API at http://localhost:9200

## Infrastructure Management

```bash
# Start everything
cd infra && docker compose up -d --build

# Stop everything
cd infra && docker compose down

# View logs
cd infra && docker compose logs -f

# Restart
cd infra && docker compose restart

# Check status
docker compose ps
```

Or use the Makefile:

```bash
make infra-up       # Start
make infra-down     # Stop
make infra-logs     # Logs
make status         # System status
make health-check   # Full health check
```

## Configuration

### Equipment Endpoints

Controlled via `config/integration.env` and environment variables:

- **Mock mode** (`USE_MOCK_EQUIPMENT=true`): connects to localhost:5001-5003
- **Real equipment** (`USE_MOCK_EQUIPMENT=false`): connects to Lab VLAN IPs in `resources/network_vars.py`

### Elasticsearch

Default: `http://localhost:9200` (no authentication).
Configure in `config/integration.env` or via `ELASTICSEARCH_HOST` / `ELASTICSEARCH_PORT` env vars.

## AWS Deployment

AWS deployment files are in `aws/` and `config/aws.env`. See `docs/AWS_DEPLOYMENT.md` for details.

```bash
# AWS-specific compose
cd infra && docker compose -f docker-compose.aws.yml up -d
```

## Troubleshooting

**`docker-compose` not found**
Use `docker compose` (v2 plugin, no hyphen). Verify: `docker compose version`

**Elasticsearch won't start**
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**Jenkins GPG key error**
```bash
sudo bash scripts/fix_jenkins_gpg.sh
```

**Mock equipment not healthy**
```bash
cd infra && docker compose logs mock-sa mock-sg mock-dut
docker compose restart mock-spectrum-analyzer mock-signal-generator mock-dut
```

**Check all services**
```bash
cd infra && docker compose ps
```
