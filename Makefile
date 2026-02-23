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
	@echo "Infrastructure:"
	@echo "  make elk-up           Start ELK Stack"
	@echo "  make elk-down         Stop ELK Stack"
	@echo "  make elk-restart      Restart ELK Stack"
	@echo "  make elk-logs         View ELK Stack logs"
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

# ELK Stack operations
elk-up:
	@echo "Starting ELK Stack..."
	cd infra && docker compose up -d
	@echo "Waiting for Elasticsearch..."
	@sleep 10
	@curl -s http://localhost:9200 > /dev/null && echo "Elasticsearch: OK" || echo "Elasticsearch: Starting..."
	@echo "Access Kibana at: http://localhost:5601"

elk-down:
	@echo "Stopping ELK Stack..."
	cd infra && docker compose down

elk-restart:
	@echo "Restarting ELK Stack..."
	cd infra && docker compose restart

elk-logs:
	@echo "Viewing ELK Stack logs..."
	cd infra && docker compose logs -f

# Monitoring
health-check:
	@echo "Running system health check..."
	@/usr/local/bin/rf_health_check.sh

logs:
	@echo "Recent logs:"
	@echo ""
	@echo "=== Jenkins Logs ==="
	@sudo journalctl -u jenkins --since "1 hour ago" | tail -20
	@echo ""
	@echo "=== Docker Logs ==="
	@docker ps --format "{{.Names}}" | xargs -I {} sh -c 'echo "=== {} ===" && docker logs --tail 10 {}'

status:
	@echo "System Status:"
	@echo ""
	@echo "Services:"
	@systemctl is-active jenkins && echo "  Jenkins: Running" || echo "  Jenkins: Stopped"
	@systemctl is-active docker && echo "  Docker: Running" || echo "  Docker: Stopped"
	@echo ""
	@echo "Docker Containers:"
	@docker ps --format "  {{.Names}}: {{.Status}}"
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
	@docker compose -f infra/docker-compose.yml pull
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
