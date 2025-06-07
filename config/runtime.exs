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
# Environment Variable Naming Convention
# ----------------------------------
# We use environment-specific suffixes for all variables:
# - _DEV: Development environment variables
# - _STAGING: Staging environment variables
# - _PROD: Production environment variables
#
# This enables a single .env file to work across all environments without
# commenting/uncommenting variables when switching environments.
#
# File Organization
# ---------------
# 1. Development Environment Configuration
#    - Contains all settings specific to development/test
# 2. Production Environment Configuration
#    - Common settings for all production environments
#    - 2a. Staging-specific configuration
#    - 2b. Production-specific configuration
# 3. Global Service Configurations (shared across environments)
#
# Adding New Services
# -----------------
# When integrating new services (APIs, databases, etc), follow this pattern:
#
# 1. In .env file, add variables with environment-specific suffixes:
#    ```
#    export NEW_SERVICE_API_KEY_DEV="dev_sandbox_key"
#    export NEW_SERVICE_API_KEY_STAGING="staging_sandbox_key"
#    export NEW_SERVICE_API_KEY_PROD="production_live_key"
#    ```
#
# 2. In runtime.exs, add configuration in each environment section:
#
#    For Development:
#    ```elixir
#    if config_env() in [:dev, :test] do
#      config :partners, Partners.Services.NewService,
#        mode: :sandbox,
#        api_key: System.fetch_env!("NEW_SERVICE_API_KEY_DEV")
#    end
#    ```
#
#    For Staging:
#    ```elixir
#    if config_env() == :prod && System.get_env("RELEASE_ENV") == "staging" do
#      config :partners, Partners.Services.NewService,
#        mode: :sandbox,
#        api_key: System.fetch_env!("NEW_SERVICE_API_KEY_STAGING")
#    end
#    ```
#
#    For Production:
#    ```elixir
#    if config_env() == :prod && System.get_env("RELEASE_ENV") == "prod" do
#      config :partners, Partners.Services.NewService,
#        mode: :live,
#        api_key: System.fetch_env!("NEW_SERVICE_API_KEY_PROD")
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

# 1. DEVELOPMENT ENVIRONMENT CONFIGURATION
# ------------------------------------
if config_env() in [:dev, :test] do
  # Explicitly reference development environment variables

  # Development host configuration
  host = System.fetch_env!("PHX_HOST_DEV")

  # PayPal development configuration
  config :partners, Partners.Services.Paypal,
    mode: :sandbox,
    base_url: System.fetch_env!("PAYPAL_BASE_URL_DEV"),
    webhook_id: System.fetch_env!("PAYPAL_WEBHOOK_ID_DEV"),
    plan_id: System.fetch_env!("PAYPAL_PLAN_ID_AUD_DEV"),
    product_id: System.fetch_env!("PAYPAL_PRODUCT_ID_DEV"),
    webhook_url: "http://#{host}/webhooks/subscriptions/paypal",
    return_url: System.fetch_env!("PAYPAL_RETURN_URL_DEV"),
    cancel_url: System.fetch_env!("PAYPAL_CANCEL_URL_DEV")
end

# 2. PRODUCTION ENVIRONMENT CONFIGURATION
# -------------------------------------
if config_env() == :prod do
  # Common production settings (both staging and production)

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

  # Web endpoint common configuration for production
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  port = String.to_integer(System.get_env("PORT") || "4000")
  config :partners, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # 2a. STAGING ENVIRONMENT CONFIGURATION
  # ----------------------------------
  if System.get_env("RELEASE_ENV") == "staging" do
    # Explicitly reference staging environment variables
    host = System.fetch_env!("PHX_HOST_STAGING")

    # Staging-specific endpoint configuration
    config :partners, PartnersWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base

    # PayPal staging configuration
    config :partners, Partners.Services.Paypal,
      mode: :sandbox,
      base_url: System.fetch_env!("PAYPAL_BASE_URL_STAGING"),
      webhook_id: System.fetch_env!("PAYPAL_WEBHOOK_ID_STAGING"),
      plan_id: System.fetch_env!("PAYPAL_PLAN_ID_AUD_STAGING"),
      product_id: System.fetch_env!("PAYPAL_PRODUCT_ID_STAGING"),
      webhook_url: "https://#{host}/webhooks/subscriptions/paypal",
      return_url: System.fetch_env!("PAYPAL_RETURN_URL_STAGING"),
      cancel_url: System.fetch_env!("PAYPAL_CANCEL_URL_STAGING")
  end

  # 2b. PRODUCTION ENVIRONMENT CONFIGURATION
  # -------------------------------------
  if System.get_env("RELEASE_ENV") == "prod" do
    # Explicitly reference production environment variables
    host = System.fetch_env!("PHX_HOST_PROD")

    # Production-specific endpoint configuration
    config :partners, PartnersWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base

    # PayPal production configuration
    config :partners, Partners.Services.Paypal,
      mode: :live,
      base_url: System.fetch_env!("PAYPAL_BASE_URL_PROD"),
      webhook_id: System.fetch_env!("PAYPAL_WEBHOOK_ID_PROD"),
      plan_id: System.fetch_env!("PAYPAL_PLAN_ID_AUD_PROD"),
      product_id: System.fetch_env!("PAYPAL_PRODUCT_ID_PROD"),
      webhook_url: "https://#{host}/webhooks/subscriptions/paypal",
      return_url: System.fetch_env!("PAYPAL_RETURN_URL_PROD"),
      cancel_url: System.fetch_env!("PAYPAL_CANCEL_URL_PROD")
  end

  # Validate RELEASE_ENV if we're in production
  release_env = System.get_env("RELEASE_ENV")

  unless release_env in ["staging", "prod"] do
    raise "Unknown RELEASE_ENV value: #{release_env}. Expected 'staging' or 'prod'"
  end
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

big_data_api_key =
  System.get_env("BIG_DATA_API_KEY") ||
    raise """
    environment variable BIG_DATA_API_KEY is missing.
    """

config :partners,
  ip_registry_api_key: ip_registry_api_key,
  auth_socket_secret_key: auth_socket_secret_key,
  big_data_api_key: big_data_api_key
