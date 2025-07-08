defmodule PartnersWeb.Registration.RegistrationComponents do
  @moduledoc """
  Orchestrates the multi-step registration process components.

  This module serves as the central hub for the registration user interface,
  coordinating the display and interaction between various step-specific components.
  It handles:

  * Rendering the appropriate component based on the current registration step
  * Managing transitions between registration steps
  * Providing a consistent layout and styling across all registration steps
  * Passing common properties and state to child components

  Each step of the registration process is implemented as a separate component,
  which this module coordinates into a cohesive flow.
  """

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
      class="hero min-h-svh"
      style="background-image: url(/images/couple2.jpg);"
      phx-hook="IPRegistryHook"
    >
      <div class="hero-overlay"></div>
      <div class="hero-content text-neutral-content text-center">
        <div class="max-w-4xl space-y-6">
          <Typography.h1 class="font-semibold">Let's get your free trial underway</Typography.h1>
          <Typography.p_lg class="mb-5">
            First, we just need a few details to create your account.<br />
            Then we'll transfer you to Paypal to start your free subscription.
          </Typography.p_lg>,
          <button
            type="button"
            phx-click={
              %JS{}
              |> JS.push("start", value: %{direction: "forward"})
            }
            class="btn btn-xl btn-info"
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
      form_params={@form_params}
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
      form_params={@form_params}
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
      form_params={@form_params}
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
      form_params={@form_params}
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
      form_params={@form_params}
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
      form_params={@form_params}
      id="terms"
    />
    """
  end
end
