#!/bin/bash

# Script to create a public tunnel for PayPal webhooks using localtunnel
# This will give you a consistent URL for webhook testing

# Configuration - change this to your preferred subdomain
SUBDOMAIN="loving-partners"

echo "Starting localtunnel for PayPal webhooks..."
echo "This will expose your local Phoenix server (port 4000) to the internet."
echo "The webhook URL will be: https://$SUBDOMAIN.loca.lt"
echo "Press Ctrl+C to stop the tunnel."
echo ""

# Check if localtunnel is installed
if ! command -v lt &> /dev/null; then
    echo "localtunnel is not installed. Installing now with npm..."
    npm install -g localtunnel

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install localtunnel. Please make sure npm is installed."
        exit 1
    fi

    echo "localtunnel successfully installed."
fi

# Start localtunnel with the custom subdomain
lt --port 4000 --subdomain $SUBDOMAIN

# Note: If the subdomain is already in use, localtunnel will assign a random subdomain.
# The actual URL will be displayed in the output.
