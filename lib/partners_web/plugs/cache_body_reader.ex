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

  ## Implementation Details

  This module has two key behaviors:

  1. For webhook routes (/api/webhooks/*): Reads and caches the raw body in `conn.assigns[:raw_body]`
     for later cryptographic verification and signature validation.

  2. For all other routes: Reads the body without caching, but importantly returns the proper
     tuple format that Plug.Parsers expects. This ensures that features like method overrides
     (converting POST with _method=DELETE to actual DELETE requests) continue to work.

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

  The cached body will then be available in the controller as `conn.assigns.raw_body`,
  but only for routes that match the webhook pattern.
  """

  require Logger

  @doc """
  Selectively caches the raw body based on the request path.

  This function serves as the entry point when used as a body reader for `Plug.Parsers`.
  It only caches the raw body for specific routes (currently webhooks), while for other
  routes it simply reads the body without caching.

  ## Important Note on Return Values

  As a body reader for Plug.Parsers, this function MUST always return one of:
  - `{:ok, body, conn}` - When the body has been successfully read
  - `{:more, partial_body, conn}` - When more chunks are available (handled internally)
  - `{:error, reason}` - When an error occurs

  Failing to return these exact tuple formats will break downstream plug functionality,
  such as method overrides (which convert POST requests with `_method` parameter to
  DELETE, PUT, etc.) and form submissions.

  ## Parameters

  - `conn` - The connection struct
  - `opts` - Options passed to the body reader (forwarded to `Plug.Conn.read_body/2`)

  ## Returns

  - For webhook routes: The result of `read_raw_body/2`, which caches and returns the body in the proper format
  - For other routes: A properly structured `{:ok, body, conn}` tuple without caching the body
  """
  def maybe_cache_raw_body?(conn, opts) do
    # Check if the request path is in the list of paths to cache
    case conn.path_info do
      # Pattern match on api/webhooks routes
      ["api", "webhooks" | _providers] ->
        Logger.info("✅ Caching raw body for path: #{conn.request_path}")
        read_raw_body(conn, opts)

      _ ->
        # Read the body but WITHOUT caching it in conn.assigns[:raw_body]
        # CRITICAL: We must return the proper tuple format expected by Plug.Parsers
        # This ensures proper handling of form submissions and method overrides
        # (like converting POST with _method=DELETE to actual DELETE requests)
        # Pattern matching ensures we handle potential errors from read_body
        case Plug.Conn.read_body(conn, opts) do
          {:ok, body, conn} -> {:ok, body, conn}
          {:more, chunk, conn} -> {:more, chunk, conn}
          {:error, reason} -> {:error, reason}
        end
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
