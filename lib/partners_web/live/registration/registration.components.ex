defmodule PartnersWeb.Registration.RegistrationComponents do
  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.{Typography}

  alias PartnersWeb.Registration.Components.{
    EmailComponent,
    UsernameComponent,
    GenderComponent,
    DobComponent,
    TelephoneComponent,
    TermsComponent
  }

  attr :transition_direction, :any,
    default: {"ease-out duration-300", "translate-x-full", "translate-x-0"},
    doc: "transition going forwards"

  def render(%{current_step: "start"} = assigns) do
    ~H"""
    <div
      phx-mounted={
        %JS{}
        |> JS.transition(@transition_direction,
          time: 300
        )
      }
      id="welcome"
      class="hero min-h-screen"
      style="background-image: url(/images/couple2.jpg);"
    >
      <div class="hero-overlay"></div>
      <div class="hero-content text-neutral-content text-center">
        <div class="max-w-4xl space-y-6">
          <Typography.h3>Let's get your free trial underway</Typography.h3>,
          <Typography.p class="mb-5">
            We just need a few details to create your account.
          </Typography.p>,
          <button
            type="button"
            phx-click={
              %JS{}
              |> JS.push("start", value: %{direction: "forward"})
            }
            class="btn btn-lg btn-info"
          >
            <Typography.p_lg>I'm ready</Typography.p_lg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def render(%{current_step: "email"} = assigns) do
    ~H"""
    <.live_component
      module={EmailComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="email"
    />
    """
  end

  def render(%{current_step: "username"} = assigns) do
    ~H"""
    <.live_component
      module={UsernameComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="username"
    />
    """
  end

  def render(%{current_step: "gender"} = assigns) do
    ~H"""
    <.live_component
      module={GenderComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="gender"
    />
    """
  end

  def render(%{current_step: "dob"} = assigns) do
    ~H"""
    <.live_component
      module={DobComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="dob"
    />
    """
  end

  def render(%{current_step: "telephone"} = assigns) do
    ~H"""
    <.live_component
      module={TelephoneComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="telephone"
    />
    """
  end

  def render(%{current_step: "terms"} = assigns) do
    ~H"""
    <.live_component
      module={TermsComponent}
      current_step={@current_step}
      transition_direction={@transition_direction}
      id="terms"
    />
    """
  end
end
