defmodule PartnersWeb.UserAuth do
  @moduledoc """
  Authentication and authorization module for Partners web application.

  This module provides functionality for user authentication, including:

  * Regular user authentication (login/logout)
  * Session management
  * Protection for authenticated-only routes
  * Protection for sensitive routes via sudo mode
  * Prevention of authenticated users accessing login pages
  * LiveView authentication hooks and controller plugs

  ## Authentication Components

  The authentication system consists of two main components:

  1. **Controller Plugs** - For traditional controller-based routes
  2. **LiveView Hooks** - For LiveView routes using `on_mount` callbacks

  ### Mapping between LiveView hooks and controller plugs

  | LiveView (on_mount)            | Controller Plug                   | Purpose                          |
  |--------------------------------|-----------------------------------|----------------------------------|
  | `:mount_current_scope`         | `:fetch_current_scope_for_user`   | Assign current user to context   |
  | `:require_authenticated`       | `:require_authenticated_user`     | Require user to be logged in     |
  | `:redirect_if_authenticated`   | `:redirect_if_authenticated_user` | Prevent access if logged in      |
  | `:require_sudo_mode`           | (No direct controller equivalent) | Require recent authentication    |

  ## Sudo Mode Authentication

  Sudo mode provides enhanced security for sensitive operations (like account settings) by
  requiring re-authentication even if the user is already logged in. The system checks if
  the user has authenticated recently (within 10 minutes by default).

  ### Sudo Mode Flow:

  1. User attempts to access a sensitive route (e.g., `/users/settings`)
  2. System checks if they've authenticated recently
  3. If not, redirects to login with special parameters:
     * `sudo=true` - Indicates this is a sudo mode re-authentication
     * `return_to=<original_path>` - Preserves the destination
  4. Login page permits access despite user already being logged in
  5. After re-authentication, user is redirected back to the original page

  ## Return-To Functionality

  The `return_to` parameter is used to redirect users back to their intended destination
  after authentication. It works in two ways:

  ### 1. Regular Authentication:

  When an unauthenticated user attempts to access a protected route:

  * The `maybe_store_return_to/1` function stores the current path in the session
  * After login, `log_in_user/3` redirects to this stored path
  * If no stored path exists, it uses `signed_in_path/1`

  ### 2. Sudo Mode Re-Authentication:

  The sudo mode flow uses query parameters instead of session storage:

  * The `on_mount(:require_sudo_mode, ...)` function adds `return_to=<path>` to the URL
  * The login page receives and preserves this parameter
  * After login, `log_in_user/3` checks query params first, then session
  * This preserves the return path across the re-authentication flow

  This approach prevents circular redirects while maintaining proper destination tracking.
  """

  use PartnersWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Partners.Accounts
  alias Partners.Accounts.Scope

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_partners_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  ## Authentication Flow

  This function handles both standard login and sudo mode re-authentication:

  1. Standard login: When a user logs in for the first time, they're redirected
     based on the `user_return_to` session value or the `signed_in_path/1`.

  2. Sudo mode re-authentication: For security-sensitive operations (like settings pages),
     we require re-authentication even for logged-in users. When initiated:
     - URL contains `sudo=true` param to indicate it's a re-auth request
     - The `return_to` path is preserved for post-authentication redirection
     - The sudo timestamp is updated to mark recent authentication

  ## Session Security

  It renews the session ID and clears the whole session to avoid fixation attacks.
  See the renew_session function to customize this behavior.

  It also sets a `:live_socket_id` key in the session, so LiveView sessions are
  identified and automatically disconnected on log out.

  ## Authentication Persistence

  In case the user re-authenticates for sudo mode, the existing remember_me
  setting is kept, writing a new remember_me cookie.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    # Check for return_to in query params first (for sudo mode), then session
    return_to =
      conn.query_params["return_to"] ||
        get_session(conn, :user_return_to)

    remember_me = get_session(conn, :user_remember_me)

    # Update sudo mode timestamp if this is a sudo re-auth
    # This timestamp is used by Accounts.sudo_mode?/2 to determine if the user
    # has recently authenticated for access to security-sensitive routes
    conn =
      if conn.query_params["sudo"] == "true" do
        # When a successful sudo login occurs, update the sudo timestamp in the session
        # This marks the user as recently authenticated for sudo-protected routes
        put_session(conn, :sudo_timestamp, System.system_time(:second))
      else
        conn
      end

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
    |> redirect(to: return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PartnersWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_scope, Scope.for_user(user))
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## Function Heads

  ### on_mount(:mount_current_scope, _params, session, socket)

  Basic hook that only assigns the current user scope without restricting access.
  Used for pages that should be accessible to all users but need to know the
  authentication state.

  ### on_mount(:require_authenticated, _params, session, socket)

  Ensures the user is logged in. If not authenticated, redirects to login page
  with an error message. Used for pages that require authentication.

  ### on_mount(:require_sudo_mode, _params, session, socket)

  Ensures the user has recently authenticated (within 10 minutes by default) for
  security-sensitive routes. If not recently authenticated, redirects to the login
  page with special `sudo=true` parameter.

  This hook handles the first part of the sudo mode flow, which enables enhanced
  security for sensitive operations like account settings changes.

  ### on_mount(:redirect_if_authenticated, params, session, socket)

  Prevents logged-in users from accessing login/registration pages, but with special
  handling for sudo mode re-authentication. When the `sudo=true` parameter is present,
  it allows authenticated users to access the login page to re-authenticate.

  ## Sudo Mode Authentication Flow

  The sudo mode feature provides enhanced security through re-authentication:

  1. User accesses a sensitive route (e.g., settings)
  2. The `:require_sudo_mode` hook checks if authentication is recent
  3. If re-authentication is needed, user is redirected to login with:
     - `sudo=true` to indicate it's a sudo mode request
     - `return_to` to preserve the destination path
  4. The `:redirect_if_authenticated` hook detects the sudo parameter and allows
     access to the login page despite the user already being logged in
  5. After re-authentication, `log_in_user` updates the sudo timestamp and
     redirects back to the original protected page

  This design prevents circular redirect loops while maintaining security for
  sensitive operations.

  ## Examples

  Use in LiveViews:

      defmodule PartnersWeb.PageLive do
        use PartnersWeb, :live_view
        on_mount {PartnersWeb.UserAuth, :mount_current_scope}
        # ...
      end

  Use in router's `live_session`:

      live_session :require_sudo_mode, on_mount: [{PartnersWeb.UserAuth, :require_sudo_mode}] do
        live "/users/settings", UserLive.Settings, :edit
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      # Store the return path to avoid the circular redirect issue
      path = Phoenix.LiveView.get_connect_params(socket)["path"] || "/users/settings"

      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :info,
          "Please re-authenticate for security purposes to access your settings."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in?sudo=true&return_to=#{path}")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, params, session, socket) do
    socket = mount_current_scope(socket, session)

    # Check if this is a sudo mode re-authentication from URL params or connect params
    connect_params = Phoenix.LiveView.get_connect_params(socket) || %{}
    sudo_auth? = params["sudo"] == "true" || connect_params["sudo"] == "true"

    if socket.assigns.current_scope && socket.assigns.current_scope.user && !sudo_auth? do
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You are already logged in.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        if user_token = session["user_token"] do
          Accounts.get_user_by_session_token(user_token)
        end

      Scope.for_user(user)
    end)
  end

  @doc """
  Used for routes that should not be accessible by authenticated users, such as
  login and registration pages.

  ## Part of the Sudo Mode Authentication Flow

  This function is the controller-based counterpart to the LiveView
  `:redirect_if_authenticated` hook. Both serve the same purpose:

  1. For regular requests: Prevent logged-in users from accessing authentication pages
  2. For sudo mode requests: Allow access when the `sudo=true` parameter is present,
     enabling the re-authentication flow for sensitive operations

  By checking both `conn.params` and `conn.query_params`, we ensure this works
  consistently regardless of how the parameters are passed.
  """
  def redirect_if_authenticated_user(conn, _opts) do
    # Check if this is a sudo mode re-authentication
    sudo_auth? = conn.params["sudo"] == "true" || conn.query_params["sudo"] == "true"

    if conn.assigns.current_scope && conn.assigns.current_scope.user && !sudo_auth? do
      conn
      |> put_flash(:error, "You are already logged in.")
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      PartnersWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc "Returns the path to redirect to after log in."
  # the user was already logged in, redirect to settings
  def signed_in_path(%Plug.Conn{assigns: %{current_scope: %Scope{user: %Accounts.User{}}}}) do
    ~p"/users/settings"
  end

  def signed_in_path(_), do: ~p"/"
end
