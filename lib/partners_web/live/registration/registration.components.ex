defmodule PartnersWeb.Registration.RegistrationComponents do
  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.{Typography, Layout}

  def render_form(%{live_action: :new} = assigns) do
    ~H"""
    <div class="hero min-h-screen" style="background-image: url(/images/couple2.jpg);">
      <div class="hero-overlay"></div>
      <div class="hero-content text-neutral-content text-center">
        <div class="max-w-4xl space-y-6">
          <Typography.h3>Let's get your free trial underway</Typography.h3>,
          <Typography.p class="mb-5">
            We just need a few details to create your account.
          </Typography.p>,
          <button type="button" phx-click="ready" class="btn btn-lg btn-info">
            <Typography.p_lg>I'm ready</Typography.p_lg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def render_form(%{live_action: :email} = assigns) do
    ~H"""
    <div>
      Email form goes here
    </div>
    """
  end

  def render_form(%{live_action: :username} = assigns) do
    ~H"""
    <div>
      Username form goes here
    </div>
    """
  end

  def render_form(%{live_action: :phone} = assigns) do
    ~H"""
    <div>
      Phone form goes here
    </div>
    """
  end
end
