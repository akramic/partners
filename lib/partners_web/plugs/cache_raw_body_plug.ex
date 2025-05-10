defmodule PartnersWeb.Plugs.CacheRawBodyPlug do
  import Plug.Conn
  require Logger

  @moduledoc """
  This module provides a custom body reader for Plug.Parsers.
  It reads the request body, caches it in conn.assigns.raw_body,
  and then returns the body to Plug.Parsers for further processing.
  """

  @doc """
  The function to be used as a :body_reader with Plug.Parsers.

  It reads the entire body, caches it in the connection's assigns under
  `:raw_body`, and returns the body. This is useful for cases where you
  want to access the raw request body later in the connection lifecycle,
  or when you have custom parsing needs that require the raw body.

  ## Options

    * `:length` - maximum length of the body to read (default: `:infinity`)
    * `:read_timeout` - timeout for reading the body, in milliseconds
      (default: `15000`)
    * `:read_length` - an alternative to `:length`, this specifies the
      exact length of the body to read. It can be useful in cases where
      the length is known a priori.

  ## Examples

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        body_reader: {PartnersWeb.Plugs.CacheRawBodyPlug, :read_body_and_cache, []}

  """
  @spec read_body_and_cache(Plug.Conn.t(), Plug.Parsers.opts()) ::
          {:ok, binary(), Plug.Conn.t()}
          | {:error, :timeout}
          | {:error, :too_large}
          | {:error, atom()}
  def read_body_and_cache(conn, opts) do
    # Ensure default read options are respected, merge with any parser-specific opts
    # The opts passed here by Plug.Parsers are typically for the parser itself,
    # but read_body also takes length, read_length, read_timeout.
    # We'll use some sensible defaults if not overridden by parser opts that might map to these.
    # Plug.Parsers uses :length for max body size
    read_length = Keyword.get(opts, :length, :infinity)
    # Default read timeout
    read_timeout = Keyword.get(opts, :read_timeout, 15_000)

    effective_read_opts = [
      length: read_length,
      # read_length can be different from total length
      read_length: Keyword.get(opts, :read_length, read_length),
      read_timeout: read_timeout
    ]

    case Plug.Conn.read_body(conn, effective_read_opts) do
      {:ok, body, conn_after_read} ->
        # Store the raw body in assigns
        conn_with_cached_body = assign(conn_after_read, :raw_body, body)
        # Return the body and the (potentially modified) conn to Plug.Parsers
        {:ok, body, conn_with_cached_body}

      {:error, :timeout} = error ->
        Logger.error("Timeout reading request body in CacheRawBodyPlug.read_body_and_cache")
        # Propagate the error
        error

      {:error, :too_large} = error ->
        Logger.error(
          "Request body too large in CacheRawBodyPlug.read_body_and_cache (limit: #{inspect(read_length)})"
        )

        # Propagate the error
        error

      # This case should ideally not be hit if this is the *first* reader.
      {:error, :already_read} = _error ->
        Logger.warning(
          "Request body already read when CacheRawBodyPlug.read_body_and_cache was called. This is unexpected if it\\'s the primary body reader."
        )

        # If it\\'s already read, we can\\'t cache it. Return empty or error.
        # Plug.Parsers might still work if conn.body_params is populated by a previous parser.
        # For safety, let's return an empty body, which might lead to parsing errors downstream if unexpected.
        # Or propagate `error`
        {:ok, "", conn}

      {:error, reason} = error ->
        Logger.error(
          "Error reading request body in CacheRawBodyPlug.read_body_and_cache: #{inspect(reason)}"
        )

        # Propagate the error
        error
    end
  end
end
