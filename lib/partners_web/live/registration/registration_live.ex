defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <PartnersWeb.CustomComponents.Layout.page_container>
        <div class="container mx-auto px-4 sm:px-6 lg:px-8">
          <div
            class="hero min-h-screen"
            style="background-image: url(https://img.daisyui.com/images/stock/photo-1507358522600-9f71e620c44e.webp);"
          >
            <div class="hero-overlay"></div>
            <div class="hero-content text-neutral-content text-center">
              <div class="max-w-md">
                <h1 class="mb-5 text-5xl font-bold">Hello there</h1>
                <p class="mb-5">
                  Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
                  quasi. In deleniti eaque aut repudiandae et a id nisi.
                </p>
                <button class="btn btn-primary">Get Started</button>
              </div>
            </div>
          </div>
        </div>
      </PartnersWeb.CustomComponents.Layout.page_container>
    </PartnersWeb.Layouts.app>
    """
  end
end
