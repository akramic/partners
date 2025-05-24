defmodule PartnersWeb.Router do
  use PartnersWeb, :router

  import PartnersWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PartnersWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    # Defined below
    plug :put_user_token
  end

  # plug for above pipeline
  defp put_user_token(conn, _) do
    if conn.assigns.current_scope do
      token =
        Phoenix.Token.sign(
          conn,
          Application.get_env(:partners, :auth_socket_secret_key),
          conn.assigns.current_scope.user.id
        )

      assign(conn, :auth_token, token)
    else
      assign(conn, :auth_token, nil)
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Pipeline for routes that shouldn't be accessible to authenticated users
  pipeline :redirect_if_authenticated do
    plug :redirect_if_authenticated_user
  end

  # Webhook endpoint
  scope "/api", PartnersWeb do
    # Use the standard API pipeline for webhook endpoints
    pipe_through :api
    #  PayPal webhook endpoint
    post "/webhooks/paypal", Api.Webhooks.PaypalWebhookController, :paypal
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:partners, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PartnersWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # Public routes - accessible to all users
  scope "/", PartnersWeb do
    pipe_through [:browser]

    # Authentication actions
    delete "/users/log-out", UserSessionController, :delete

    # Home and other public pages
    live_session :current_user,
      on_mount: [{PartnersWeb.UserAuth, :mount_current_scope}] do
      live "/", Home.HomeLive
    end
  end

  # Routes that require authentication - protected pages
  scope "/", PartnersWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PartnersWeb.UserAuth, :require_authenticated}] do
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    # Routes that require sudo mode (reauthentication)
    live_session :require_sudo_mode,
      on_mount: [{PartnersWeb.UserAuth, :require_sudo_mode}] do
      live "/users/settings", UserLive.Settings, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  # Routes that should redirect if user is already authenticated - sign up/in flow
  scope "/", PartnersWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    post "/users/log-in", UserSessionController, :create

    live_session :redirect_if_authenticated,
      on_mount: [{PartnersWeb.UserAuth, :redirect_if_authenticated}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new

      # Subscription routes - part of new user registration flow
      # New route for starting a trial
      live "/subscriptions/start_trial", SubscriptionLive, :start_trial
      live "/subscriptions/paypal/return", SubscriptionLive, :paypal_return
      # Route if user decides to cancel on paypal's site and decides not to proceed with completing the subscription
      live "/subscriptions/paypal/cancel", SubscriptionLive, :paypal_cancel
      # Route for when the subscription is activated
      live "/subscriptions/paypal/subscription_activated",
           SubscriptionLive,
           :subscription_activated
      # Route for when the subscription is rejected
      live "/subscriptions/paypal/subscription_rejected", SubscriptionLive, :subscription_rejected
    end
  end
end
