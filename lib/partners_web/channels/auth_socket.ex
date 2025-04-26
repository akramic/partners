defmodule PartnersWeb.AuthSocket do
  use Phoenix.Socket

  require Logger
  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Uncomment the following line to define a "room:*" topic
  # pointing to the `PartnersWeb.RoomChannel`:
  #
  # channel "room:*", PartnersWeb.RoomChannel
  #
  # To create a channel file, use the mix task:
  #
  #     mix phx.gen.channel Room
  #
  # See the [`Channels guide`](https://hexdocs.pm/phoenix/channels.html)
  # for further details.

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, [define an error handler in the
  # websocket
  # configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @one_day 86400

  @impl true
  def connect(%{"auth_token" => token}, socket) do
    case verify(socket, token) do
      {:ok, _user_id} ->
        {:ok, socket}

      {:error, err} ->
        Logger.error("#{__MODULE__} connect error #{inspect(err)}")
        :error
    end
  end

  @impl true
  def connect(_, _socket) do
    Logger.error("#{__MODULE__} connect error missing params", ansi: :red)
    :error
  end

  defp verify(socket, token) do
    Phoenix.Token.verify(
      socket,
      Application.get_env(:partners, :auth_socket_secret_key),
      token,
      max_age: @one_day
    )
  end

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.PartnersWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(%{assigns: %{current_scope: %{user: user}}}), do: "auth_socket:#{user.id}"
end
