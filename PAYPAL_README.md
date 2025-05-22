# PayPal Subscription Integration

This document provides an overview of the PayPal subscription integration in the Loving Partners application, including the subscription flow, webhook events, and data structures.

## Table of Contents

- [Overview](#overview)
- [Subscription Flow](#subscription-flow)
- [PayPal Webhook Events](#paypal-webhook-events)
- [Resource Data Structure](#resource-data-structure)
- [Implementation Details](#implementation-details)
- [Troubleshooting](#troubleshooting)
- [Testing PayPal Webhooks Locally](#testing-paypal-webhooks-locally)

## Overview

The Loving Partners application implements a PayPal subscription system with a 7-day free trial. The integration consists of:

1. A subscription initialization flow through the LiveView interface
2. PayPal webhook handling for real-time subscription status updates
3. PubSub messaging to keep the UI in sync with subscription changes

The system uses Phoenix LiveView for the frontend, with PayPal's REST API for subscription management and webhook notifications for event handling.

## Subscription Flow

The subscription process follows these steps:

1. **Subscription Initiation**
   - User completes registration and is redirected to `/subscriptions/start_trial`
   - User clicks "Start Trial with PayPal" button
   - Application creates a PayPal subscription with the trial plan

2. **PayPal Approval**
   - User is redirected to PayPal to approve the subscription
   - PayPal presents subscription details, including trial information
   - User approves or cancels the subscription

3. **Return to Application**
   - If approved: PayPal redirects to our return URL (`/paypal/return`)
   - If cancelled: PayPal redirects to our cancel URL (`/paypal/cancel`)
   - Application redirects to either `/subscriptions/success` or `/subscriptions/cancel`

4. **Subscription Status Updates**
   - Initial state after approval is `:pending`
   - PayPal sends asynchronous webhook events (see below)
   - Application processes events and updates subscription status
   - UI reflects current status (pending, active, failed, cancelled)

## PayPal Webhook Events

PayPal sends webhook notifications for various subscription lifecycle events. The key events include:

| Event Type | Description | Our Status Mapping |
|------------|-------------|-------------------|
| `BILLING.SUBSCRIPTION.CREATED` | Initial subscription creation | `:pending` |
| `BILLING.SUBSCRIPTION.ACTIVATED` | Subscription successfully set up and activated (sent immediately upon user approval, even with a free trial) | `:active` |
| `BILLING.SUBSCRIPTION.CANCELLED` | Subscription cancelled by user or admin | `:cancelled` |
| `PAYMENT.SALE.COMPLETED` | Payment successfully processed | `:active` |
| `PAYMENT.SALE.DENIED` | Payment was denied | `:failed` |

Other possible events (currently not explicitly handled):
- `BILLING.SUBSCRIPTION.UPDATED` - Subscription details were updated
- `BILLING.SUBSCRIPTION.SUSPENDED` - Subscription was suspended
- `BILLING.SUBSCRIPTION.EXPIRED` - Subscription reached its natural end date
- `PAYMENT.SALE.PENDING` - Payment is pending processing
- `PAYMENT.SALE.REFUNDED` - Payment was refunded

## Resource Data Structure

Each webhook contains a `resource` object with subscription details. The structure varies by event type but typically includes:

```json
{
  "resource": {
    "id": "I-SR18H5TSRG6X",                   // PayPal subscription ID
    "custom_id": "28c8a507-4...",             // Our user ID
    "status": "APPROVAL_PENDING",             // PayPal status
    "plan_id": "P-1A446093FD195141FNALUJUY",  // Plan ID
    "start_time": "2025-05-13T07:26:54Z",     // Start timestamp
    "create_time": "2025-05-13T07:26:54Z",    // Creation timestamp
    "quantity": "1",                          // Number of subscriptions
    "plan_overridden": false,                 // Whether plan was modified
    "links": [                                // Related action links
      {
        "href": "https://...",
        "rel": "approve",                     // Relationship type
        "method": "GET"                       // HTTP method
      },
      // Additional links...
    ]
  }
}
```

Critical fields:
- `id`: The PayPal subscription ID, used for API calls
- `custom_id`: Contains our user ID, used for PubSub topic construction
- `status`: PayPal's status value (e.g., `APPROVAL_PENDING`, `ACTIVE`, `CANCELLED`)

Additional fields may be present depending on the event type, such as:
- Payment details (`amount`, `currency`)
- Billing cycle information
- Customer details
- Payer information

## Implementation Details

### PubSub Messages

Our application uses the `custom_id` from PayPal (containing our user ID) to broadcast subscription updates via PubSub. Messages are sent to the topic `paypal_subscription:#{user_id}` and include:

1. Subscription updates:
```elixir
%{event: "subscription_updated", subscription_state: state}
```

2. Subscription errors:
```elixir
%{event: "subscription_error", error: error_message}
```

3. Verification failures:
```elixir
%{
  event: "subscription_verification_failed",
  details: %{reason: reason, message: flash_message}
}
```

### Webhook Verification

Webhooks are verified using PayPal's signature verification process:
1. Extract headers: `paypal-transmission-id`, `paypal-transmission-time`, etc.
2. Fetch and validate the certificate from `paypal-cert-url`
3. Construct the signature verification payload
4. Verify the signature with the certificate's public key

### LiveView Communication

The `SubscriptionLive` module subscribes to PubSub events and updates the UI accordingly:
- Updates subscription status (pending → active, etc.)
- Shows error messages when verification fails
- Redirects users as needed based on subscription state

## Troubleshooting

Common issues to check when debugging PayPal subscription problems:

1. **Webhook Verification Failures**
   - Check PayPal certificate validity
   - Ensure webhook ID is correctly configured
   - Verify the raw body is properly preserved for signature verification

2. **Missing Events**
   - Confirm webhook URL is correctly registered with PayPal
   - Check server logs for incoming webhook requests
   - Verify network connectivity to PayPal's servers

3. **UI Not Updating**
   - Ensure PubSub topics match between broadcast and subscription
   - Check that the user ID in `custom_id` is correct
   - Verify the LiveView is properly handling incoming messages

## Testing PayPal Webhooks Locally

To test PayPal webhooks in your local development environment, you need to expose your local server to the internet. The application includes scripts for using two different tunneling services: localtunnel and serveo.

### Setup Requirements

Before testing webhooks, you must:

1. **Update the PayPal Developer Dashboard**:
   - Log in to the [PayPal Developer Dashboard](https://developer.paypal.com/dashboard/)
   - Navigate to Webhooks under your app
   - Update the webhook URL to your tunnel URL (e.g., `https://loving-partners.loca.lt/api/paypal/webhook`)
   - Make sure to save these changes

2. **Update Environment Variables**:
   Update the following variables in your `.env` file with the correct tunnel URL:

   ```bash
   # For localtunnel
   export PAYPAL_SANDBOX_WEBHOOK_ID="1X225865137037934"
   export PAYPAL_SANDBOX_RETURN_URL="https://loving-partners.loca.lt/subscriptions/paypal_return?live_action=paypal_return"
   export PAYPAL_SANDBOX_CANCEL_URL="https://loving-partners.loca.lt/subscriptions/paypal_cancel?live_action=paypal_cancel"

   # For serveo (commented out when not in use)
   # export PAYPAL_SANDBOX_WEBHOOK_ID="1X225865137037934"
   # export PAYPAL_SANDBOX_RETURN_URL="https://partners-dev-1808.serveo.net/subscriptions/paypal_return?live_action=paypal_return"
   # export PAYPAL_SANDBOX_CANCEL_URL="https://partners-dev-1808.serveo.net/subscriptions/paypal_cancel?live_action=paypal_cancel"
   ```

3. **Source the updated environment variables**:
   ```bash
   source .env
   ```

### Using Localtunnel

Localtunnel provides a stable subdomain that remains consistent between sessions.

1. **Start the tunnel**:
   ```bash
   ./start_localtunnel_paypal_webhook.sh
   ```

2. The script will:
   - Install localtunnel if it's not already installed
   - Create a tunnel with the subdomain "loving-partners"
   - Make your local Phoenix server available at `https://loving-partners.loca.lt`

3. Keep the terminal window open while testing.

### Using Serveo (Alternative)

Serveo is another option that can provide a consistent subdomain, but its service may occasionally experience downtime.

1. **Start the tunnel**:
   ```bash
   ./start_serveo_paypal_webhook.sh
   ```

2. The script will:
   - Establish an SSH tunnel to serveo.net
   - Provide a URL like `https://partners-dev-1808.serveo.net`

3. Keep the terminal window open while testing.

### Testing Workflow

1. Start your Phoenix server (`mix phx.server`)
2. Start the tunnel of your choice in a separate terminal
3. Update the PayPal Developer Dashboard with your webhook URL
4. Update and source your `.env` file
5. Trigger webhook events by performing actions in the PayPal Sandbox
6. Monitor your Phoenix server logs for incoming webhook events

### Troubleshooting Tunnel Issues

- **Connection refused errors**: The tunneling service may be temporarily down. Try the alternative tunneling service.
- **Webhook verification failures**: Ensure your webhook URL in the PayPal dashboard exactly matches your tunnel URL.
- **Random subdomains**: For localtunnel, if the requested subdomain is already taken, a random one will be assigned. Update your PayPal dashboard and `.env` accordingly.




