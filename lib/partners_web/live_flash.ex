defmodule PartnersWeb.LiveFlash do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :flash, :handle_info, &handle_flash/2)}
  end

  def push_flash(key, msg) do
    send(self(), {:flash, key, msg})
  end

  defp handle_flash({:flash, key, msg}, socket) do
    {:halt, put_flash(socket, key, msg)}
  end

  defp handle_flash(_otherwise, socket) do
    {:cont, socket}
  end
end
