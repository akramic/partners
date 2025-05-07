import Config

# Runtime Configuration Structure
# =============================
#
# This configuration file is structured to handle different runtime environments
# and is executed for all environments during releases. It is executed after
# compilation and before the system starts, making it ideal for runtime configuration
# and secrets management.
#
# Environment Types
# ---------------
# - Development (:dev) - Local development environment
# - Test (:test) - Testing environment
# - Production (:prod) - Live environments with staging/production variants
#
# File Organization
# ---------------
# 1. Global settings (applicable to all environments)
# 2. Production-specific settings (with staging/prod variants)
# 3. Development/test specific settings
# 4. Service-specific configurations
#
# Adding New Services
# -----------------
# When integrating new services (APIs, databases, etc), follow this pattern:
#
# 1. For production environments:
#    ```elixir
#    if config_env() == :prod do
#      case release_env do
#        "staging" ->
#          config :partners, Partners.Services.NewService,
#            mode: :sandbox,
#            api_key: System.fetch_env!("NEW_SERVICE_STAGING_API_KEY")
#        "prod" ->
#          config :partners, Partners.Services.NewService,
#            mode: :live,
#            api_key: System.fetch_env!("NEW_SERVICE_PRODUCTION_API_KEY")
#      end
#    end
#    ```
#
# 2. For development/test:
#    ```elixir
#    if config_env() in [:dev, :test] do
#      config :partners, Partners.Services.NewService,
#        mode: :sandbox,
#        api_key: System.get_env("NEW_SERVICE_API_KEY", "default_dev_key")
#    end
#    ```
#
# Release Configuration
# ===================
#
# Using releases with Phoenix requires specific configuration:
#
# 1. Server Configuration
#    Enable the server by setting PHX_SERVER=true:
#    ```bash
#    PHX_SERVER=true bin/partners start
#    ```
#    Or use `mix phx.gen.release` to generate a `bin/server` script
#
# 2. SSL Support (Production)
#    To enable SSL:
#    ```elixir
#    config :partners, PartnersWeb.Endpoint,
#      https: [
#        port: 443,
#        cipher_suite: :strong,
#        keyfile: System.get_env("SSL_KEY_PATH"),
#        certfile: System.get_env("SSL_CERT_PATH")
#      ]
#    ```
#
# 3. Mailer Configuration (Production)
#    Configure the mailer adapter:
#    ```elixir
#    config :partners, Partners.Mailer,
#      adapter: Swoosh.Adapters.Mailgun,
#      api_key: System.get_env("MAILGUN_API_KEY"),
#      domain: System.get_env("MAILGUN_DOMAIN")
#    ```
#
# Note: This file should not contain compile-time configuration as it won't be applied.
if System.get_env("PHX_SERVER") do
  config :partners, PartnersWeb.Endpoint, server: true
end

if config_env() == :prod do
  # Production Environment Configuration
  # --------------------------------
  #
  # Database configuration - Required for all production environments
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :partners, Partners.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Web endpoint configuration
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.fetch_env!("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4000")
  release_env = System.fetch_env!("RELEASE_ENV")

  config :partners, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :partners, PartnersWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Service-specific Production Configurations
  # -------------------------------------
  # Using release_env to differentiate between staging and production settings.
  # This pattern can be replicated for other services that need different
  # configurations between environments.
  case release_env do
    "staging" ->
      config :partners, Partners.Services.Paypal,
        mode: :sandbox,
        base_url: "https://api-m.sandbox.paypal.com",
        webhook_id: System.fetch_env!("PAYPAL_SANDBOX_WEBHOOK_ID"),
        plan_id: System.fetch_env!("PAYPAL_SANDBOX_PLAN_ID_AUD"),
        product_id: System.fetch_env!("PAYPAL_SANDBOX_PRODUCT_ID"),
        webhook_url: "https://#{host}/webhooks/subscriptions/paypal",
        return_url: "https://#{host}/subscriptions/paypal/return",
        cancel_url: "https://#{host}/subscriptions/paypal/cancel"

    "prod" ->
      config :partners, Partners.Services.Paypal,
        mode: :live,
        base_url: "https://api-m.paypal.com",
        webhook_id: System.fetch_env!("PAYPAL_PRODUCTION_WEBHOOK_ID"),
        plan_id: System.fetch_env!("PAYPAL_PRODUCTION_PLAN_ID_AUD"),
        product_id: System.fetch_env!("PAYPAL_PRODUCTION_PRODUCT_ID"),
        webhook_url: "https://#{host}/webhooks/subscriptions/paypal",
        return_url: "https://#{host}/subscriptions/paypal/return",
        cancel_url: "https://#{host}/subscriptions/paypal/cancel"

    other ->
      raise "Unknown RELEASE_ENV value: #{other}. Expected 'staging' or 'prod'"
  end
end

# Development and Test Environment Configurations
# -----------------------------------------
# Service configurations for local development and testing.
# Add new service configurations here for :dev and :test environments.
if config_env() in [:dev, :test] do
  host = System.get_env("PHX_HOST", "localhost:4000")

  config :partners, Partners.Services.Paypal,
    mode: :sandbox,
    base_url: "https://api-m.sandbox.paypal.com",
    webhook_id: System.get_env("PAYPAL_SANDBOX_WEBHOOK_ID"),
    plan_id: System.get_env("PAYPAL_SANDBOX_PLAN_ID_AUD"),
    product_id: System.get_env("PAYPAL_SANDBOX_PRODUCT_ID"),
    webhook_url: "http://#{host}/webhooks/subscriptions/paypal",
    return_url: "http://#{host}/subscriptions/paypal/return",
    cancel_url: "http://#{host}/subscriptions/paypal/cancel"
end

# Global Service Configurations
# ---------------------------
# Settings that apply across all environments but may have
# environment-specific values. These are typically external
# service credentials that are required regardless of environment.

# IP Registry Service Configuration
ip_registry_api_key =
  System.get_env("IP_REGISTRY_API_KEY") ||
    raise """
    environment variable IP_REGISTRY_API_KEY is missing.
    """

auth_socket_secret_key =
  System.get_env("AUTH_SOCKET_SECRET_KEY") ||
    raise """
    environment variable AUTH_SOCKET_SECRET_KEY is missing.

    """

config :partners,
  ip_registry_api_key: ip_registry_api_key,
  auth_socket_secret_key: auth_socket_secret_key
