defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Registration Page</h1>
      <p>Welcome to the registration page. Please fill out the form to register.</p>
      <!-- Registration form will go here -->
    </div>
    """
  end
end
