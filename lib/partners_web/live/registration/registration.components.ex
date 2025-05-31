defmodule PartnersWeb.Registration.RegistrationComponents do
  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.{Typography}

  attr :transition_direction, :any,
    default: {"ease-out duration-300", "translate-x-full", "translate-x-0"},
    doc: "transition going forwards"

  def render_form(%{live_action: :new} = assigns) do
    ~H"""
    <div id="welcome" class="hero min-h-screen" style="background-image: url(/images/couple2.jpg);">
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
              |> JS.push("next_step", value: %{direction: "forward"})
            }
            phx-disable-with="Starting..."
            class="btn btn-lg btn-info"
          >
            <Typography.p_lg>I'm ready</Typography.p_lg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def render_form(%{live_action: :email} = assigns) do
    ~H"""
    <div class="w-full">
      <div
        id="email"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Email
      </div>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.push("next_step", value: %{direction: "forward"})
        }
        class={}
      >
        next
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :username} = assigns) do
    ~H"""
    <div>
      <div
        id="username"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Username
      </div>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.push("next_step", value: %{direction: "forward"})
        }
        class={}
      >
        next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.transition(
            {"ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300,
            to: "#username"
          )
          |> JS.push("prev_step", value: %{direction: "backward"})
        }
        class={}
      >
        back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :phone} = assigns) do
    ~H"""
    <div>
      <div
        id="phone"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Phone
      </div>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.push("next_step", value: %{direction: "forward"})
        }
        class={}
      >
        next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.transition(
            {"ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300,
            to: "#phone"
          )
          |> JS.push("prev_step", value: %{direction: "backward"})
        }
        class={}
      >
        back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :dob} = assigns) do
    ~H"""
    <div>
      <div
        id="dob"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Date of Birth
      </div>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.push("next_step", value: %{direction: "forward"})
        }
        class={}
      >
        next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.transition(
            {"ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300,
            to: "#dob"
          )
          |> JS.push("prev_step", value: %{direction: "backward"})
        }
        class={}
      >
        back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :gender} = assigns) do
    ~H"""
    <div>
      <div
        id="gender"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Gender
      </div>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.push("next_step", value: %{direction: "forward"})
        }
        class={}
      >
        next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.transition(
            {"ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300,
            to: "#gender"
          )
          |> JS.push("prev_step", value: %{direction: "backward"})
        }
        class={}
      >
        back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :terms} = assigns) do
    ~H"""
    <div>
      <div
        id="terms"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
      >
        Terms and Conditions
      </div>

      <button
        type="button"
        phx-click={
          %JS{}
          |> JS.transition(
            {"ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300,
            to: "#terms"
          )
          |> JS.push("prev_step", value: %{direction: "backward"})
        }
        class={}
      >
        back
      </button>
    </div>
    """
  end
end
