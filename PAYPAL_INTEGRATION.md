# PayPal Integration Configuration Guide

This document provides guidance on how to configure and use the PayPal subscription integration across different environments (development, staging, and production).

## Environment Configuration

The PayPal integration has been configured to work seamlessly across three environments:

1. **Development** - Local development with PayPal Sandbox
2. **Staging** - Testing on internet-facing server (Digital Ocean) with PayPal Sandbox
3. **Production** - Live website with PayPal Production

## Environment Variables

The PayPal integration requires several environment variables to function properly:

### Common Variables (Required in all environments)
- `PAYPAL_CLIENT_ID` - Your PayPal API client ID
- `PAYPAL_SECRET` - Your PayPal API secret

### Development Environment
- `PAYPAL_SANDBOX_WEBHOOK_ID` - ID of the webhook configured in PayPal Sandbox
- `PAYPAL_SANDBOX_PLAN_ID_AUD` - ID of the subscription plan created in PayPal Sandbox
- `PAYPAL_SANDBOX_PRODUCT_ID` - ID of the product created in PayPal Sandbox
- `PAYPAL_DEV_BASE_URL` - Base URL for local development (default: "http://localhost:4000")
- `NGROK_URL` - (Optional) URL for ngrok tunnel when testing webhooks locally

### Staging Environment
- `APP_ENV=staging` - Identifies the environment as staging
- `PHX_HOST` - Your staging server's domain (e.g., "your-app.digitalocean.app")
- `PAYPAL_SANDBOX_WEBHOOK_ID` - Same ID used in development
- `PAYPAL_SANDBOX_PLAN_ID_AUD` - Same plan ID used in development
- `PAYPAL_SANDBOX_PRODUCT_ID` - Same product ID used in development

### Production Environment
- `APP_ENV=production` - Identifies the environment as production
- `PHX_HOST` - Your production domain (e.g., "lovingpartners.com.au")
- `PAYPAL_PRODUCTION_WEBHOOK_ID` - ID of the webhook configured in PayPal Production
- `PAYPAL_PRODUCTION_PLAN_ID_AUD` - ID of the subscription plan created in PayPal Production
- `PAYPAL_PRODUCTION_PRODUCT_ID` - ID of the product created in PayPal Production

## Setup Process

1. **Development Setup**
   - The app uses the `.env` file for local development
   - Source it before running the server: `source .env && mix phx.server`
   - For webhook testing, use ngrok:
     ```bash
     # Terminal 1: Start ngrok
     ngrok http 4000

     # Terminal 2: Run server with ngrok URL
     export NGROK_URL="https://your-ngrok-url.ngrok.io"
     source .env
     mix phx.server
     ```

2. **Staging Setup**
   - Configure environment variables on your Digital Ocean app
   - Make sure to set `APP_ENV=staging`
   - Webhooks will use the sandbox but with your real staging domain

3. **Production Setup**
   - Before going live, create a product and subscription plan in the PayPal Production environment
   - Configure the production webhook in PayPal Developer Dashboard
   - Set all required environment variables on your production server

## One-Time Setup Steps

When setting up a new environment, you'll need to:

1. **Create a Product** (if not using an existing one)
   - This can be done via the PayPal dashboard or API
   - The product ID should be stored in the appropriate environment variable

2. **Create a Subscription Plan**
   - This can be done via the PayPal dashboard or API
   - The plan should include your 7-day free trial
   - The plan ID should be stored in the appropriate environment variable

3. **Configure Webhooks**
   - In the PayPal Developer Dashboard, create a webhook
   - For staging/production, point it to `https://your-domain.com/webhooks/subscriptions/paypal`
   - Subscribe to all billing events (especially `BILLING.SUBSCRIPTION.*`)
   - Store the webhook ID in the appropriate environment variable

## Using the PayPal Module

The `Partners.Services.Paypal` module provides functions for:

- Creating subscription URLs for users
- Managing subscriptions (activate, suspend, cancel)
- Processing webhook events
- Checking subscription status

Example usage:

```elixir
# Create a subscription URL for a user
{:ok, %{subscription_id: sub_id, approve_url: url}} =
  Partners.Services.Paypal.create_subscription_url(user.profile_id)

# Store the subscription ID in your database
Repo.update(user, %{paypal_subscription_id: sub_id, subscription_status: "PENDING"})

# Redirect the user to the PayPal approval page
conn |> redirect(external: url)
```

## Testing

For testing the subscription flow:

1. Use the sandbox personal account credentials:
   - Email: `sb-tpnob41394833@personal.example.com`
   - Password: `")[Eq@33K`

2. Test webhook events using the PayPal Developer Dashboard webhook simulator

## Troubleshooting

If you encounter issues:

1. Check that all environment variables are set correctly
2. Verify webhook configurations in the PayPal Developer Dashboard
3. Check the application logs for detailed error messages
4. For webhook issues, verify the webhook signature verification process

## Additional Resources

- [PayPal Developer Documentation](https://developer.paypal.com/docs/api/subscriptions/v1/)
- [PayPal Subscription API Reference](https://developer.paypal.com/docs/api/subscriptions/v1/)
- [PayPal Webhook Guide](https://developer.paypal.com/docs/api-basics/notifications/webhooks/)

## Application Initialization

The PayPal module includes a `maybe_create_subscription_plan()` function that should be called during application startup to ensure your subscription plan exists. This function:

1. Checks if the configured plan (from environment variables) exists in PayPal
2. Only creates a new plan if the configured one doesn't exist
3. Logs the result for monitoring

You can add this to your application's startup by modifying the `lib/partners/application.ex` file:

```elixir
defmodule Partners.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Other children...
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    opts = [strategy: :one_for_one, name: Partners.Supervisor]
    Supervisor.start_link(children, opts)

    # Initialize PayPal after supervisor starts
    initialize_paypal()

    {:ok, self()}
  end

  defp initialize_paypal do
    if Application.get_env(:partners, :initialize_paypal, true) do
      Task.start(fn ->
        case Partners.Services.Paypal.maybe_create_subscription_plan() do
          {:ok, :plan_exists} ->
            IO.puts("PayPal subscription plan exists, ready for use")
          {:ok, plan_id} ->
            IO.puts("Created new PayPal subscription plan: #{plan_id}")
          error ->
            IO.puts("Error initializing PayPal subscription plan: #{inspect(error)}")
        end
      end)
    end
  end
end
```

This ensures that your application always has a valid subscription plan, without requiring manual setup in each environment.
