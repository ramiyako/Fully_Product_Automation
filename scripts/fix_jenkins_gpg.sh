#!/bin/bash
# Quick fix for Jenkins GPG key issue

echo "Fixing Jenkins GPG key..."

# Clean up old key
sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /usr/share/keyrings/jenkins-keyring.gpg
sudo rm -f /usr/share/keyrings/jenkins-keyring.asc

# Download the correct 2026 key (current official key)
echo "Downloading Jenkins 2026 GPG key..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Verify download
if [ ! -f /usr/share/keyrings/jenkins-keyring.asc ]; then
    echo "ERROR: Failed to download Jenkins key"
    exit 1
fi

# Add repository
echo "Adding Jenkins repository..."
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install
echo "Updating apt..."
sudo apt-get update

echo "Installing Jenkins..."
sudo apt-get install -y jenkins

# Start Jenkins
echo "Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

echo ""
echo "Done! Jenkins should be starting now."
echo "Access Jenkins at: http://localhost:8080"
echo ""
echo "Get initial password with: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
