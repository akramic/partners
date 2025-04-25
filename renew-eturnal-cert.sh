#!/bin/bash
# renew-eturnal-cert.sh - Certificate renewal script for eturnal TURN server
# This script is designed to run as a cron job to automatically renew the TLS certificate
# Usage: bash renew-eturnal-cert.sh [domain-name]
# If domain name is not provided, it uses the value stored during initial setup

set -e

# Check if domain provided or use stored value
if [ -n "$1" ]; then
  DOMAIN=$1
else
  # Try to get domain from acme.sh config or use default
  DOMAIN_LIST=$(~/.acme.sh/acme.sh --list | grep -v "+" | grep "^" | awk '{print $1}')
  if [ -n "$DOMAIN_LIST" ]; then
    # Use the first domain found
    DOMAIN=$(echo "$DOMAIN_LIST" | head -n1)
  else
    echo "Error: No domain provided and no certificates found."
    echo "Usage: $0 your-domain.com"
    exit 1
  fi
fi

ETURNAL_TLS_DIR="/etc/eturnal/tls"
USER=$(whoami)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE=~/eturnal-cert-renewal.log

echo "[$TIMESTAMP] Starting certificate renewal for $DOMAIN" >> $LOG_FILE

# Check if certificate needs renewal
NEEDS_RENEWAL=$(~/.acme.sh/acme.sh --check -d ${DOMAIN} | grep "Renew")
if [[ "$NEEDS_RENEWAL" != *"not necessary"* ]]; then
  echo "[$TIMESTAMP] Certificate renewal needed, proceeding..." >> $LOG_FILE
else
  echo "[$TIMESTAMP] Certificate doesn't need renewal yet. Exiting." >> $LOG_FILE
  exit 0
fi

# Ensure directories exist
if [ ! -d "$ETURNAL_TLS_DIR" ]; then
  echo "[$TIMESTAMP] TLS directory doesn't exist, creating..." >> $LOG_FILE
  sudo mkdir -p $ETURNAL_TLS_DIR
fi

# Prepare webroot with correct permissions
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R ${USER}:${USER} /var/www/html/.well-known
sudo chmod -R 755 /var/www/html/.well-known

# Stop eturnal service during renewal
echo "[$TIMESTAMP] Stopping eturnal service..." >> $LOG_FILE
sudo systemctl stop eturnal

# Run the certificate renewal
echo "[$TIMESTAMP] Renewing certificate..." >> $LOG_FILE
~/.acme.sh/acme.sh --renew -d ${DOMAIN} --force

# Check if renewal was successful
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Certificate renewal failed!" >> $LOG_FILE
  # Start eturnal even if renewal failed to prevent service outage
  sudo systemctl start eturnal
  exit 1
fi

# Set permissions on certificate files
echo "[$TIMESTAMP] Updating certificate files and permissions..." >> $LOG_FILE
sudo chown ${USER}:${USER} $ETURNAL_TLS_DIR

# Install the renewed certificates
~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
  --key-file ${ETURNAL_TLS_DIR}/key.pem \
  --fullchain-file ${ETURNAL_TLS_DIR}/cert.pem

# Set proper permissions for eturnal
sudo chown -R eturnal:eturnal $ETURNAL_TLS_DIR
sudo chmod 600 $ETURNAL_TLS_DIR/*.pem

# Restore webroot permissions
sudo chown -R www-data:www-data /var/www/html/.well-known

# Start eturnal service with new certificate
echo "[$TIMESTAMP] Starting eturnal service..." >> $LOG_FILE
sudo systemctl start eturnal

# Verify service is running
if sudo systemctl is-active --quiet eturnal; then
  echo "[$TIMESTAMP] Certificate renewal completed successfully. eturnal service is running." >> $LOG_FILE
else
  echo "[$TIMESTAMP] WARNING: Certificate renewed but eturnal service failed to start!" >> $LOG_FILE
  exit 1
fi

exit 0
