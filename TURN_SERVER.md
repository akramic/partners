# TURN Server TLS Configuration Guide

This guide explains how to set up and maintain TLS certificates for an eturnal TURN server on Ubuntu.

## About eturnal TURN Server

The eturnal TURN server requires TLS certificates to provide secure WebRTC connections for applications like LovingPartners. This document provides instructions for:

1. Initial setup of TLS certificates
2. Automatic certificate renewal
3. Troubleshooting certificate issues

## Initial Setup Script

The `setup-eturnal-tls.sh` script automates the entire process of setting up TLS certificates for your eturnal TURN server.

### Usage Instructions

1. **Download the script**

   ```bash
   wget https://raw.githubusercontent.com/yourusername/yourrepo/main/setup-eturnal-tls.sh
   # or if downloaded already:
   # cp /path/to/setup-eturnal-tls.sh .
   ```

2. **Make the script executable**

   ```bash
   chmod +x setup-eturnal-tls.sh
   ```

3. **Run the script**

   ```bash
   ./setup-eturnal-tls.sh
   ```

4. **Follow the interactive prompts**

   The script will prompt you for:

   - Your TURN server domain name (e.g., turn.loving.partners)
   - An email address for certificate notifications

5. **The script performs these actions automatically**:

   - Installs the acme.sh certificate client
   - Creates required directories with proper permissions
   - Issues a TLS certificate from Let's Encrypt
   - Installs the certificate in the correct location for eturnal
   - Updates the eturnal configuration file
   - Sets up automatic renewal
   - Starts and enables the eturnal service

6. **Verify successful setup**

   When the script completes, it will display the eturnal service status. If everything is working correctly, you should see `active (running)` in the output.

## Certificate Renewal Script

The renewal script `renew-eturnal-cert.sh` is automatically created by the setup script. This script handles certificate renewal and is set up to run monthly via cron.

### Manual Renewal Instructions

If you need to manually trigger a certificate renewal:

1. **Run the renewal script**

   ```bash
   ~/renew-eturnal-cert.sh
   ```

2. **Check renewal logs**

   ```bash
   cat ~/eturnal-cert-renewal.log
   ```

### Customizing the Renewal Schedule

The default renewal schedule is set to run at midnight on the first day of each month. To change this:

1. **Edit your crontab**

   ```bash
   crontab -e
   ```

2. **Modify the renewal schedule**

   The default schedule looks like:

   ```
   0 0 1 * * /home/yourusername/renew-eturnal-cert.sh
   ```

   You can adjust this according to your needs. For example, to run weekly on Sunday at 2:30 AM:

   ```
   30 2 * * 0 /home/yourusername/renew-eturnal-cert.sh
   ```

## Certificate Files and Locations

The TLS certificates are stored in:

- `/etc/eturnal/tls/cert.pem` - The certificate chain
- `/etc/eturnal/tls/key.pem` - The private key

These paths are configured in the eturnal configuration file:

- `/etc/eturnal.yml`

## Troubleshooting

### Check Certificate Status

```bash
~/.acme.sh/acme.sh --list
```

### View Certificate Expiration

```bash
openssl x509 -enddate -noout -in /etc/eturnal/tls/cert.pem
```

### Check eturnal Service Status

```bash
sudo systemctl status eturnal
```

### View Renewal Logs

```bash
cat ~/eturnal-cert-renewal.log
```

### Check Acme.sh Logs

```bash
cat ~/.acme.sh/acme.sh.log
```

### Common Issues

1. **Port 80 already in use**

   - Apache or another web server is likely using this port
   - The setup script handles this automatically using a webroot method

2. **Permission errors**

   - The renewal script fixes permissions automatically
   - If issues persist, check the ownership of `/etc/eturnal/tls/` and `/var/www/html/.well-known/`

3. **Certificate validation failures**
   - Ensure your domain correctly resolves to the server's IP address
   - Check for firewall rules blocking ports 80 (HTTP) or 5349 (TURN TLS)

# MANUAL CERTIFICATES

This section provides step-by-step instructions for manually setting up and renewing TLS certificates without using the automated scripts.

## INITIAL INSTALL

Follow these steps to manually install TLS certificates for your eturnal TURN server:

1. **Connect to your VPS via SSH**

   ```bash
   ssh username@your-server-ip
   ```

2. **Install acme.sh client**

   ```bash
   curl https://get.acme.sh | sh -s email=your-email@example.com
   ```

3. **Load acme.sh into your current shell**

   ```bash
   source ~/.bashrc  # or source ~/.zshrc if using zsh
   ```

4. **Create required directories**

   ```bash
   # Create directory for certificate files
   sudo mkdir -p /etc/eturnal/tls

   # Create directory for acme challenge files
   sudo mkdir -p /var/www/html/.well-known/acme-challenge
   ```

5. **Set appropriate permissions for the acme challenge directory**

   ```bash
   # Give your user permission to write to the challenge directory
   sudo chown -R $USER:$USER /var/www/html/.well-known
   sudo chmod -R 755 /var/www/html/.well-known
   ```

6. **Stop the eturnal service**

   ```bash
   sudo systemctl stop eturnal
   ```

7. **Request a new certificate using webroot validation**

   ```bash
   ~/.acme.sh/acme.sh --issue -d your-domain.com --webroot /var/www/html --alpn --tlsport 5349
   ```

8. **Set permissions for the certificate directory**

   ```bash
   sudo chown $USER:$USER /etc/eturnal/tls
   ```

9. **Install the certificate for eturnal**

   ```bash
   ~/.acme.sh/acme.sh --install-cert -d your-domain.com \
     --key-file /etc/eturnal/tls/key.pem \
     --fullchain-file /etc/eturnal/tls/cert.pem \
     --reloadcmd "sudo systemctl restart eturnal"
   ```

10. **Set proper permissions for the certificate files**

    ```bash
    sudo chown -R eturnal:eturnal /etc/eturnal/tls
    sudo chmod 600 /etc/eturnal/tls/*.pem
    ```

11. **Restore webroot permissions**

    ```bash
    sudo chown -R www-data:www-data /var/www/html/.well-known
    ```

12. **Update eturnal configuration**

    ```bash
    sudo nano /etc/eturnal.yml
    ```

    Add or modify the TLS section:

    ```yaml
    tls:
      certfile: /etc/eturnal/tls/cert.pem
      keyfile: /etc/eturnal/tls/key.pem
    ```

13. **Start eturnal service**

    ```bash
    sudo systemctl start eturnal
    sudo systemctl enable eturnal
    ```

14. **Verify the service is running**

    ```bash
    sudo systemctl status eturnal
    ```

## RENEWING CERTIFICATES

Follow these steps to manually renew your TLS certificates:

1. **Set appropriate permissions for the challenge directory**

   ```bash
   sudo mkdir -p /var/www/html/.well-known/acme-challenge
   sudo chown -R $USER:$USER /var/www/html/.well-known
   sudo chmod -R 755 /var/www/html/.well-known
   ```

2. **Stop the eturnal service**

   ```bash
   sudo systemctl stop eturnal
   ```

3. **Force certificate renewal**

   ```bash
   ~/.acme.sh/acme.sh --renew -d your-domain.com --force
   ```

   The `--force` flag will renew the certificate even if it's not near expiration.

4. **Set permissions for the certificate directory**

   ```bash
   sudo chown $USER:$USER /etc/eturnal/tls
   ```

5. **Reinstall the renewed certificate**

   ```bash
   ~/.acme.sh/acme.sh --install-cert -d your-domain.com \
     --key-file /etc/eturnal/tls/key.pem \
     --fullchain-file /etc/eturnal/tls/cert.pem
   ```

6. **Set proper permissions for the certificate files**

   ```bash
   sudo chown -R eturnal:eturnal /etc/eturnal/tls
   sudo chmod 600 /etc/eturnal/tls/*.pem
   ```

7. **Restore webroot permissions**

   ```bash
   sudo chown -R www-data:www-data /var/www/html/.well-known
   ```

8. **Start eturnal service**

   ```bash
   sudo systemctl start eturnal
   ```

9. **Verify the service is running with the renewed certificate**

   ```bash
   sudo systemctl status eturnal
   ```

10. **Check the certificate's new expiry date**

    ```bash
    openssl x509 -enddate -noout -in /etc/eturnal/tls/cert.pem
    ```

These manual steps are useful if you need to troubleshoot certificate issues or if you prefer to have more control over the certificate issuance and renewal process.

### Example working yml file for configuration

# eturnal STUN/TURN server configuration file.
#
# This file is written in YAML. The YAML format is indentation-sensitive, please
# MAKE SURE YOU INDENT CORRECTLY.
#
# See: https://eturnal.net/doc/#Global_Configuration

eturnal:

  ## Shared secret for deriving temporary TURN credentials (default: $RANDOM):
  secret: "mylongsecret"

  ## The server's public IPv4 address (default: autodetected):
  relay_ipv4_addr: "103.16.128.115"
  ## The server's public IPv6 address (optional):
  #relay_ipv6_addr: "2001:db8::4"

  listen:
    -
      ip: "::"
      port: 3478
      transport: udp
      enable_turn: true
    -
      ip: "::"
      port: 3478
      transport: tcp
      enable_turn: true
    -
      ip: "::"
      port: 5349
      transport: tls
      enable_turn: true

  ## TLS certificate/key files (must be readable by 'eturnal' user!):
  tls_crt_file: /etc/eturnal/tls/cert.pem
  tls_key_file: /etc/eturnal/tls/key.pem

  ## UDP relay port range (usually, several ports per A/V call are required):
  relay_min_port: 49152     # This is the default.
  relay_max_port: 65535     # This is the default.

  ## Reject TURN relaying to the following addresses/networks:
  blacklist_peers:
    - recommended           # Expands to various addresses/networks recommended
                            # to be blocked. This is the default.

  ## If 'true', close established calls on expiry of temporary TURN credentials:
  strict_expiry: true      # This is the default.

  ## Logging configuration:
  log_level: info           # critical | error | warning | notice | info | debug
  log_rotate_size: 10485760 # 10 MiB (default: unlimited, i.e., no rotation).
  log_rotate_count: 10      # Keep 10 rotated log files.
  #log_dir: stdout          # Enable for logging to the terminal/journal.

  ## See: https://eturnal.net/doc/#Module_Configuration
  modules:
    mod_log_stun: {}        # Log STUN queries (in addition to TURN sessions).
    #mod_stats_influx: {}   # Log STUN/TURN events into InfluxDB.
    #mod_stats_prometheus:  # Expose STUN/TURN and VM metrics to Prometheus.
    #  ip: any              # This is the default: Listen on all interfaces.
    #  port: 8081           # This is the default.
    #  tls: false           # This is the default.
    #  vm_metrics: true     # This is the default.
