#!/bin/bash
# setup-eturnal-tls.sh - Initial TLS setup script for eturnal TURN server
# This script should be run on a fresh Ubuntu VPS to set up TLS for eturnal

set -e

# Prompt for domain and email
DOMAIN=""
EMAIL=""

# Function to validate domain format
validate_domain() {
  local domain_regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
  if [[ $1 =~ $domain_regex ]]; then
    return 0
  else
    return 1
  fi
}

# Function to validate email format
validate_email() {
  local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  if [[ $1 =~ $email_regex ]]; then
    return 0
  else
    return 1
  fi
}

# Get domain with validation
while [ -z "$DOMAIN" ]; do
  read -p "Enter your TURN server domain name (e.g., turn.example.com): " DOMAIN
  if ! validate_domain "$DOMAIN"; then
    echo "Invalid domain format. Please enter a valid domain name."
    DOMAIN=""
  fi
done

# Get email with validation
while [ -z "$EMAIL" ]; do
  read -p "Enter your email address for certificate notifications: " EMAIL
  if ! validate_email "$EMAIL"; then
    echo "Invalid email format. Please enter a valid email address."
    EMAIL=""
  fi
done

ETURNAL_TLS_DIR="/etc/eturnal/tls"
USER=$(whoami)

echo "===== Installing acme.sh client ====="
curl https://get.acme.sh | sh -s email=${EMAIL}
source ~/.bashrc

echo "===== Creating TLS directory for eturnal ====="
sudo mkdir -p ${ETURNAL_TLS_DIR}

# Create the required directories in the webroot with proper permissions
echo "===== Setting up challenge directory ====="
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R ${USER}:${USER} /var/www/html/.well-known
sudo chmod -R 755 /var/www/html/.well-known

# Stop eturnal service before requesting a certificate
echo "===== Stopping eturnal service ====="
sudo systemctl stop eturnal || echo "eturnal service not running or not installed"

# Issue the certificate using the webroot method
echo "===== Requesting TLS certificate ====="
~/.acme.sh/acme.sh --issue -d ${DOMAIN} --webroot /var/www/html --alpn --tlsport 5349

# Temporarily give user access to write to the TLS directory
echo "===== Setting up permissions for certificate installation ====="
sudo chown -R ${USER}:${USER} ${ETURNAL_TLS_DIR}

# Install the certificate to eturnal's TLS directory
echo "===== Installing certificate to eturnal ====="
~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
  --key-file ${ETURNAL_TLS_DIR}/key.pem \
  --fullchain-file ${ETURNAL_TLS_DIR}/cert.pem \
  --reloadcmd "sudo systemctl restart eturnal"

# Set the correct permissions for eturnal to use the certificates
echo "===== Setting proper permissions ====="
sudo chown -R eturnal:eturnal ${ETURNAL_TLS_DIR}
sudo chmod 600 ${ETURNAL_TLS_DIR}/*.pem

# Restore webroot permissions
echo "===== Restoring webroot permissions ====="
sudo chown -R www-data:www-data /var/www/html/.well-known

# Update eturnal configuration
echo "===== Updating eturnal configuration ====="
if [ -f "/etc/eturnal.yml" ]; then
  # Create a backup of the original config file
  sudo cp /etc/eturnal.yml /etc/eturnal.yml.bak

  # Check if TLS section already exists in config
  if grep -q "^tls:" /etc/eturnal.yml; then
    echo "TLS section already exists in config, updating paths"
    # Use sed to update the existing TLS section
    sudo sed -i "/^tls:/,/^[a-z]/ s|certfile:.*|certfile: ${ETURNAL_TLS_DIR}/cert.pem|" /etc/eturnal.yml
    sudo sed -i "/^tls:/,/^[a-z]/ s|keyfile:.*|keyfile: ${ETURNAL_TLS_DIR}/key.pem|" /etc/eturnal.yml
  else
    echo "Adding TLS section to eturnal config"
    # Append TLS config to the end of the file
    echo -e "\ntls:\n  certfile: ${ETURNAL_TLS_DIR}/cert.pem\n  keyfile: ${ETURNAL_TLS_DIR}/key.pem" | sudo tee -a /etc/eturnal.yml
  fi
else
  echo "WARNING: eturnal configuration file not found at /etc/eturnal.yml"
  echo "You will need to manually configure eturnal to use the certificate files at:"
  echo "Certificate: ${ETURNAL_TLS_DIR}/cert.pem"
  echo "Private key: ${ETURNAL_TLS_DIR}/key.pem"
fi

# Create renewal script
echo "===== Creating certificate renewal script ====="
cat > ~/renew-eturnal-cert.sh << EOF
#!/bin/bash
# Script to renew eturnal TLS certificate
# This is automatically created by setup-eturnal-tls.sh

# Set up variables
DOMAIN=${DOMAIN}
ETURNAL_TLS_DIR=${ETURNAL_TLS_DIR}
USER=\$(whoami)

# Prepare webroot with correct permissions
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R \${USER}:\${USER} /var/www/html/.well-known

# Stop eturnal during renewal
sudo systemctl stop eturnal

# Run the renewal
~/.acme.sh/acme.sh --renew -d \${DOMAIN} --force

# Fix permissions on certificate files
sudo chown -R eturnal:eturnal \${ETURNAL_TLS_DIR}
sudo chmod 600 \${ETURNAL_TLS_DIR}/*.pem

# Restore webroot permissions
sudo chown -R www-data:www-data /var/www/html/.well-known

# Start eturnal with new certificate
sudo systemctl start eturnal

# Log successful renewal
echo "Certificate for \${DOMAIN} renewed on \$(date)" >> ~/eturnal-cert-renewal.log
EOF

chmod +x ~/renew-eturnal-cert.sh

# Set up cron job for monthly renewal
echo "===== Setting up monthly cron job for certificate renewal ====="
(crontab -l 2>/dev/null | grep -v "renew-eturnal-cert.sh"; echo "0 0 1 * * /home/${USER}/renew-eturnal-cert.sh") | crontab -

# Start eturnal service
echo "===== Starting eturnal service ====="
sudo systemctl start eturnal
sudo systemctl enable eturnal

echo "===== Setup complete ====="
echo "eturnal TURN server is now configured with TLS for ${DOMAIN}"
echo "Certificate files installed at ${ETURNAL_TLS_DIR}"
echo "Automatic renewal is configured via cron on the 1st of each month"
echo "You can manually renew the certificate at any time by running:"
echo "  ~/renew-eturnal-cert.sh"

# Check eturnal service status
sudo systemctl status eturnal
