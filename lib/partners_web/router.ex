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

  scope "/", PartnersWeb do
    pipe_through :browser

    # PayPal subscription return URLs
    get "/subscriptions/paypal/return", Api.Webhooks.WebhookController, :subscription_return,
      action: "success"

    get "/subscriptions/paypal/cancel", Api.Webhooks.WebhookController, :subscription_return,
      action: "cancel"

    # Add other public browser routes here
  end


  # PayPal webhook endpoint
  scope "/webhooks", PartnersWeb do
    # Use the standard API pipeline for webhook endpoints
    pipe_through :api

    post "/subscriptions/paypal", Api.Webhooks.WebhookController, :paypal
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

  scope "/", PartnersWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PartnersWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", PartnersWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PartnersWeb.UserAuth, :mount_current_scope}] do
      live "/", Home.HomeLive
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new

      # Subscription routes
      live "/subscriptions", SubscriptionLive, :index
      live "/subscriptions/new", SubscriptionLive, :new
      live "/subscriptions/success", SubscriptionLive, :success
      live "/subscriptions/cancel", SubscriptionLive, :cancel
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
