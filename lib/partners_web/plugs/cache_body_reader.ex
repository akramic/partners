defmodule PartnersWeb.Plugs.CacheBodyReader do
  @moduledoc """
  A plug module that caches the raw body of HTTP requests for specific routes.

  This is particularly important for webhook endpoints (like PayPal webhooks) that require
  access to the original, unmodified request body for signature verification. Most API
  webhooks use cryptographic verification that requires the exact byte-for-byte body
  content that was sent.

  Phoenix normally consumes the request body during JSON parsing, which makes it
  unavailable for subsequent verification. This plug reads and caches the body in
  `conn.assigns[:raw_body]` before it's consumed by the parser.

  ## Usage

  This module should be used as a body reader for `Plug.Parsers` in your endpoint configuration:

  ```elixir
  # In endpoint.ex
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    body_reader: {PartnersWeb.Plugs.CacheBodyReader, :maybe_cache_raw_body?, []}
  ```

  The cached body will then be available in the controller as `conn.assigns.raw_body`.
  """

  require Logger

  @doc """
  Selectively caches the raw body based on the request path.

  This function serves as the entry point when used as a body reader for `Plug.Parsers`.
  It only caches the raw body for specific routes (currently webhooks), and passes
  other routes through unmodified.

  ## Parameters

  - `conn` - The connection struct
  - `opts` - Options passed to the body reader (forwarded to `Plug.Conn.read_body/2`)

  ## Returns

  - For webhook routes: The result of `read_raw_body/2`, which caches and returns the body
  - For other routes: The unmodified `conn`
  """
  def maybe_cache_raw_body?(conn, opts) do
    # Check if the request path is in the list of paths to cache
    case conn.path_info do
      # Pattern match on api/webhooks routes
      ["api", "webhooks" | _providers] ->
        Logger.info("✅ Caching raw body for path: #{conn.request_path}")
        read_raw_body(conn, opts)

      _ ->
        conn
    end
  end

  # Reads and caches the raw body of a request.
  #
  # This function handles reading the request body, potentially in multiple chunks for
  # larger payloads, and accumulates all chunks in conn.assigns[:raw_body].
  #
  # Implementation details:
  # - Handles all three possible return values from Plug.Conn.read_body/2
  # - For :ok, the final chunk is appended and the result is returned
  # - For :more, the partial chunk is appended and the function recursively calls
  #   itself to read more chunks until the full body is read
  # - For :error, the error is logged and returned
  #
  # Parameters:
  # - conn - The connection struct
  # - opts - Options passed to Plug.Conn.read_body/2
  #
  # Returns:
  # - {:ok, body, conn} - When the body is successfully read and cached
  # - {:error, reason} - When there's an error reading the body
  defp read_raw_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        # Final chunk received, append it and return
        conn = update_in(conn.assigns[:raw_body], &((&1 || "") <> body))
        {:ok, body, conn}

      {:more, partial_body, conn} ->
        # More chunks to read, append this chunk and continue reading
        conn = update_in(conn.assigns[:raw_body], &((&1 || "") <> partial_body))
        # Recursively call to get next chunk
        read_raw_body(conn, opts)

      {:error, reason} ->
        # Handle the error case
        Logger.error("Failed to read body: #{inspect(reason)}")
        {:error, "Failed to read body: #{inspect(reason)}"}
    end
  end
end
