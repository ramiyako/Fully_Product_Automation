#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/user-data-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting EC2 Bootstrap - $(date) ====="

# System updates
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release unzip
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# Install Docker Compose standalone
DOCKER_COMPOSE_VERSION="v2.24.5"
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Java (required for Jenkins)
apt-get install -y fontconfig openjdk-17-jre-headless

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# Add jenkins user to docker group
usermod -aG docker jenkins

# Install Python 3 and pip
apt-get install -y python3 python3-pip python3-venv

# Install Allure CLI
ALLURE_VERSION="2.25.0"
curl -sL "https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/allure-${ALLURE_VERSION}.tgz" \
  -o /tmp/allure.tgz
tar -zxf /tmp/allure.tgz -C /opt/
ln -sf /opt/allure-${ALLURE_VERSION}/bin/allure /usr/local/bin/allure
rm /tmp/allure.tgz

# Install AWS CLI
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -qo /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Configure Jenkins
systemctl enable jenkins
systemctl start jenkins

# Increase vm.max_map_count for Elasticsearch
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144

# Create project directory
PROJECT_DIR="/opt/rf-automation"
mkdir -p "$PROJECT_DIR"
chown jenkins:jenkins "$PROJECT_DIR"

# Create swap file (needed for t2.micro with only 1GB RAM)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Create a lightweight docker-compose for the infra services (optimized for Free Tier)
cat > "$PROJECT_DIR/docker-compose.infra.yml" << 'COMPOSE_EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms256m -Xmx256m"
      - cluster.name=rf-automation-cluster
      - node.name=rf-automation-node-1
      - bootstrap.memory_lock=false
      - network.host=0.0.0.0
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 120s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M

  kibana:
    image: docker.elastic.co/kibana/kibana:8.12.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - SERVER_NAME=kibana
      - SERVER_HOST=0.0.0.0
      - NODE_OPTIONS=--max-old-space-size=256
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  es_data:
    driver: local
COMPOSE_EOF

chown -R jenkins:jenkins "$PROJECT_DIR"

# Wait for Jenkins to fully start, then print initial admin password
echo "===== Waiting for Jenkins to start... ====="
sleep 30
for i in $(seq 1 20); do
  if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "===== Jenkins Initial Admin Password ====="
    cat /var/lib/jenkins/secrets/initialAdminPassword
    echo "==========================================="
    break
  fi
  sleep 10
done

echo "===== EC2 Bootstrap Complete - $(date) ====="
echo "Jenkins: http://<PUBLIC_IP>:8080"
echo "Kibana:  http://<PUBLIC_IP>:5601"
echo "Elasticsearch: http://<PUBLIC_IP>:9200"
