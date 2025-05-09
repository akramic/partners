# PayPal API configuration
config :partners, :paypal,
  client_id: System.get_env("PAYPAL_CLIENT_ID"),
  secret: System.get_env("PAYPAL_SECRET"),
  # Default plan ID for subscriptions
  plan_id: System.get_env("PAYPAL_PLAN_ID", "P-DEFAULT_PLAN_ID")
