#!/bin/zsh
# This script helps with PayPal integration testing using ngrok

# Start by checking if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Please install it first: https://ngrok.com/download"
    exit 1
fi

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Please install it first: sudo apt install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl is not installed. Please install it first: sudo apt install curl"
    exit 1
fi

# Check if we have an ngrok session already running
if pgrep -f "ngrok http 4000" > /dev/null; then
    echo "⚠️ An ngrok session is already running. Please check the existing session."
    echo "If you want to start a new session, kill the existing one first with: pkill -f ngrok"
    exit 1
fi

# Source the .env file first to get environment variables (like PAYPAL credentials)
echo "🔄 Loading environment variables from .env..."
source .env

# Start ngrok in the background
echo "🚀 Starting ngrok tunnel to port 4000..."
ngrok http 4000 > /dev/null &
NGROK_PID=$!

# Wait for ngrok to start and get the URL
echo "⏳ Waiting for ngrok to establish connection..."
sleep 3

# Get the ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL. Please check if ngrok is running properly."
    kill $NGROK_PID
    exit 1
fi

echo "✅ ngrok tunnel established at: $NGROK_URL"

# Now create a new webhook with PayPal API
echo "🔄 Registering the webhook with PayPal Sandbox..."

# First, get an access token
echo "🔑 Generating PayPal access token..."
echo "Using credentials: $PAYPAL_CLIENT_ID (Client ID)"
echo "Credential length check - Client ID: ${#PAYPAL_CLIENT_ID} chars, Secret: ${#PAYPAL_SECRET} chars"

# Debug environment variables
echo "Testing credentials with direct curl..."
curl -s -X POST "https://api-m.sandbox.paypal.com/v1/oauth2/token" \
  -H "Accept: application/json" \
  -H "Accept-Language: en_US" \
  -u "$PAYPAL_CLIENT_ID:$PAYPAL_SECRET" \
  -d "grant_type=client_credentials" > /tmp/paypal_test_response.json

cat /tmp/paypal_test_response.json
echo ""

# Now use the same credentials in our script
AUTH_RESPONSE=$(curl -s -X POST "https://api-m.sandbox.paypal.com/v1/oauth2/token" \
  -H "Accept: application/json" \
  -H "Accept-Language: en_US" \
  -u "$PAYPAL_CLIENT_ID:$PAYPAL_SECRET" \
  -d "grant_type=client_credentials")

echo "Response from script request: $AUTH_RESPONSE"

ACCESS_TOKEN=$(echo $AUTH_RESPONSE | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "❌ Failed to get PayPal access token. Response: $AUTH_RESPONSE"
    kill $NGROK_PID
    exit 1
fi

echo "✅ Access token generated successfully"

# Create a new webhook
WEBHOOK_URL="${NGROK_URL}/webhooks/subscriptions/paypal"
echo "📝 Creating new webhook for URL: $WEBHOOK_URL"

WEBHOOK_RESPONSE=$(curl -s -X POST "https://api-m.sandbox.paypal.com/v1/notifications/webhooks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{
    \"url\": \"$WEBHOOK_URL\",
    \"event_types\": [
      {\"name\": \"BILLING.SUBSCRIPTION.CREATED\"},
      {\"name\": \"BILLING.SUBSCRIPTION.ACTIVATED\"},
      {\"name\": \"BILLING.SUBSCRIPTION.UPDATED\"},
      {\"name\": \"BILLING.SUBSCRIPTION.CANCELLED\"},
      {\"name\": \"BILLING.SUBSCRIPTION.SUSPENDED\"},
      {\"name\": \"BILLING.SUBSCRIPTION.PAYMENT.FAILED\"},
      {\"name\": \"PAYMENT.SALE.COMPLETED\"}
    ]
  }")

# Extract webhook ID
WEBHOOK_ID=$(echo $WEBHOOK_RESPONSE | jq -r '.id')

if [ -z "$WEBHOOK_ID" ] || [ "$WEBHOOK_ID" = "null" ]; then
    echo "❌ Failed to create webhook. Response: $WEBHOOK_RESPONSE"
    # Continue anyway, maybe using existing webhook ID
    echo "⚠️ Will use the existing webhook ID from .env file: $PAYPAL_SANDBOX_WEBHOOK_ID"
else
    echo "✅ Webhook created successfully with ID: $WEBHOOK_ID"
    # Export the new webhook ID for the Phoenix server
    export PAYPAL_SANDBOX_WEBHOOK_ID=$WEBHOOK_ID
    echo "🔄 Updated PAYPAL_SANDBOX_WEBHOOK_ID to: $WEBHOOK_ID"
fi

# Set the environment variable for the Phoenix server
echo "🔄 Setting NGROK_URL environment variable..."
export NGROK_URL

echo "🌐 Starting Phoenix server with PayPal webhook URL: $WEBHOOK_URL"
echo "💡 Press Ctrl+C to stop the server and tunnel"

# Debug: Output the current environment variables for verification
echo "🔍 Debug: PayPal environment variables:"
echo "PAYPAL_CLIENT_ID: ${PAYPAL_CLIENT_ID}"
echo "PAYPAL_SECRET: [REDACTED]"
echo "PAYPAL_SANDBOX_WEBHOOK_ID: ${PAYPAL_SANDBOX_WEBHOOK_ID}"
echo "PAYPAL_SANDBOX_PLAN_ID_AUD: ${PAYPAL_SANDBOX_PLAN_ID_AUD}"
echo "PAYPAL_SANDBOX_PRODUCT_ID: ${PAYPAL_SANDBOX_PRODUCT_ID}"
echo "NGROK_URL: ${NGROK_URL}"

# Start the Phoenix server with explicit environment variables
PAYPAL_CLIENT_ID="$PAYPAL_CLIENT_ID" \
PAYPAL_SECRET="$PAYPAL_SECRET" \
PAYPAL_SANDBOX_WEBHOOK_ID="$PAYPAL_SANDBOX_WEBHOOK_ID" \
PAYPAL_SANDBOX_PLAN_ID_AUD="$PAYPAL_SANDBOX_PLAN_ID_AUD" \
PAYPAL_SANDBOX_PRODUCT_ID="$PAYPAL_SANDBOX_PRODUCT_ID" \
NGROK_URL="$NGROK_URL" \
MIX_ENV=dev mix phx.server

# Clean up ngrok when the script exits
function cleanup {
    echo "🧹 Cleaning up - stopping ngrok tunnel..."
    kill $NGROK_PID
    echo "✅ Done!"
}

trap cleanup EXIT

# Wait for server to exit
wait
