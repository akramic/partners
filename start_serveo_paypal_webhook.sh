#!/bin/bash

# Script to create an SSH tunnel with Serveo for PayPal webhooks

# The local port where your Phoenix application is running (default is 4000)
LOCAL_PORT=4000

# The fixed subdomain for your Serveo URL
SUBDOMAIN="partners-dev-1808"

echo "Starting Serveo tunnel for PayPal webhooks..."
echo "This will expose your local Phoenix server (port $LOCAL_PORT) to the internet."
echo "The webhook URL will be displayed once the connection is established."
echo "Press Ctrl+C to stop the tunnel."
echo ""

# Start the SSH tunnel with Serveo
ssh -R "$SUBDOMAIN:80:localhost:$LOCAL_PORT" serveo.net

# Note: The above command will maintain an open connection until terminated
# PayPal webhook URL will be: https://partners-dev-1808.serveo.net/api/webhooks/paypal
