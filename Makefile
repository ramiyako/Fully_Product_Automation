# Makefile for RF Automation Infrastructure
# Convenient commands for common operations

.PHONY: help install build test clean docker-build docker-run health-check logs

# Default target
help:
	@echo "RF Automation Infrastructure - Available Commands"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make install          Run automated installation (requires sudo)"
	@echo "  make build            Build Docker test runner image"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run all tests locally"
	@echo "  make test-functional  Run functional tests only"
	@echo "  make test-calibration Run calibration tests only"
	@echo "  make dryrun           Syntax check all tests"
	@echo ""
	@echo "Docker Operations:"
	@echo "  make docker-build     Build Docker image"
	@echo "  make docker-run       Run tests in Docker container"
	@echo "  make docker-clean     Clean Docker resources"
	@echo ""
	@echo "Infrastructure (ELK + Mock Equipment + Jenkins):"
	@echo "  make infra-up         Start all services"
	@echo "  make infra-down       Stop all services"
	@echo "  make infra-restart    Restart all services"
	@echo "  make infra-logs       View service logs"
	@echo "  make jenkins-logs     View Jenkins logs"
	@echo "  make jenkins-restart  Restart Jenkins only"
	@echo ""
	@echo "Monitoring:"
	@echo "  make health-check     Run system health check"
	@echo "  make logs             View all logs"
	@echo "  make status           Show service status"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            Clean results and logs"
	@echo "  make backup           Backup configuration"
	@echo "  make update           Update dependencies"
	@echo ""

# Installation
install:
	@echo "Running automated installation..."
	sudo bash scripts/setup_helpers.sh

# Build targets
build: docker-build

docker-build:
	@echo "Building Docker test runner image..."
	docker build -t rf-test-runner .

# Testing targets
test:
	@echo "Running all tests..."
	robot --outputdir results tests/

test-functional:
	@echo "Running functional tests..."
	robot --outputdir results tests/rf_functional.robot

test-calibration:
	@echo "Running calibration tests..."
	robot --outputdir results tests/calibration.robot

dryrun:
	@echo "Checking test syntax..."
	robot --dryrun tests/

# Docker operations
docker-run:
	@echo "Running tests in Docker container..."
	docker run --rm --network host \
		-v $(PWD)/results:/app/results \
		rf-test-runner --outputdir results tests/

docker-clean:
	@echo "Cleaning Docker resources..."
	docker system prune -f --volumes

# Infrastructure operations (ELK + Mock Equipment)
infra-up:
	@echo "Starting infrastructure (ELK + Mock Equipment + Jenkins)..."
	cd infra && docker compose up -d --build
	@echo "Waiting for services to start..."
	@sleep 15
	@curl -s http://localhost:9200 > /dev/null && echo "Elasticsearch: OK" || echo "Elasticsearch: Starting..."
	@curl -s http://localhost:8001/health > /dev/null && echo "Mock SA: OK" || echo "Mock SA: Starting..."
	@curl -s http://localhost:8002/health > /dev/null && echo "Mock SG: OK" || echo "Mock SG: Starting..."
	@curl -s http://localhost:8003/health > /dev/null && echo "Mock DUT: OK" || echo "Mock DUT: Starting..."
	@curl -s http://localhost:8080/login > /dev/null && echo "Jenkins: OK" || echo "Jenkins: Starting (~2 min)..."
	@echo ""
	@echo "Jenkins:        http://localhost:8080  (admin/admin)"
	@echo "Kibana:         http://localhost:5601"
	@echo "Elasticsearch:  http://localhost:9200"

infra-down:
	@echo "Stopping infrastructure..."
	cd infra && docker compose down

infra-restart:
	@echo "Restarting infrastructure..."
	cd infra && docker compose restart

infra-logs:
	@echo "Viewing infrastructure logs..."
	cd infra && docker compose logs -f

elk-up: infra-up
elk-down: infra-down
elk-restart: infra-restart
elk-logs: infra-logs

jenkins-logs:
	@echo "Jenkins logs:"
	@docker logs rf-jenkins --tail 50

jenkins-restart:
	@echo "Restarting Jenkins..."
	cd infra && docker compose restart jenkins

# Monitoring
health-check:
	@echo "Running system health check..."
	@/usr/local/bin/rf_health_check.sh

logs:
	@echo "Recent logs:"
	@echo ""
	@echo "=== Docker Container Logs ==="
	@docker ps --format "{{.Names}}" | xargs -I {} sh -c 'echo "--- {} ---" && docker logs --tail 10 {}'

status:
	@echo "System Status:"
	@echo ""
	@echo "Services:"
	@systemctl is-active docker && echo "  Docker: Running" || echo "  Docker: Stopped"
	@echo ""
	@echo "Docker Containers:"
	@docker ps --format "  {{.Names}}: {{.Status}}"
	@echo ""
	@echo "URLs:"
	@echo "  Jenkins:        http://localhost:8080"
	@echo "  Kibana:         http://localhost:5601"
	@echo "  Elasticsearch:  http://localhost:9200"
	@echo ""
	@echo "Disk Usage:"
	@df -h / | tail -1

# Maintenance
clean:
	@echo "Cleaning results and logs..."
	rm -rf results/*
	rm -rf logs/*
	mkdir -p results logs
	@echo "Clean complete"

backup:
	@echo "Backing up configuration..."
	@mkdir -p /backup
	tar -czf /backup/rf_automation_config_$(shell date +%Y%m%d_%H%M%S).tar.gz \
		resources/network_vars.py \
		infra/docker-compose.yml \
		Jenkinsfile
	@echo "Backup complete: /backup/"

update:
	@echo "Updating dependencies..."
	@git pull origin main
	@pip install --upgrade -r requirements.txt
	@cd infra && docker compose pull
	@docker build -t rf-test-runner .
	@echo "Update complete"

# Development helpers
lint:
	@echo "Linting Python code..."
	@pylint scripts/*.py resources/*.py

format:
	@echo "Formatting Python code..."
	@black scripts/ resources/
	@isort scripts/ resources/

# Quick test
quick-test:
	@echo "Running quick smoke test..."
	robot --include smoke --outputdir results tests/
