defmodule PartnersWeb.SubscriptionLive do
  use PartnersWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>Subscription Live View</h1>
    </div>
    """
  end
end
