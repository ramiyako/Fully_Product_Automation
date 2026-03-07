#!/bin/bash
###############################################################################
# Jenkins Repository Cleanup Script
# Removes old/broken Jenkins repository configuration
###############################################################################

set -e

echo "Cleaning up old Jenkins repository configuration..."

# Remove old Jenkins repository files
sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /usr/share/keyrings/jenkins-keyring.asc
sudo rm -f /usr/share/keyrings/jenkins-keyring.gpg

echo "Jenkins repository configuration cleaned"
echo ""
echo "Now you can re-run the integration setup script:"
echo "  sudo bash scripts/integration_setup.sh --mode=nuc --environment=integration --verbose"
