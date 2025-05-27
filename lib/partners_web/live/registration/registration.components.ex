defmodule PartnersWeb.Registration.RegistrationComponents do
  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.{Typography, Layout}

  alias Phoenix.LiveView.JS

  # Wrapper component to ensure consistent layout during transitions
  slot :inner_block

  def form_wrapper(assigns) do
    ~H"""
    <div class="relative overflow-hidden w-full overscroll-none" role="group" aria-live="polite">
      {render_slot(@inner_block)}
    </div>
    """
  end

  def render_form(%{live_action: :new} = assigns) do
    ~H"""
    <div
      id="welcome"
      phx-mounted={entry_animation(assigns, "#welcome")}
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
          <button type="button" phx-click={JS.push("ready")} class="btn btn-lg btn-info">
            <Typography.p_lg>I'm ready</Typography.p_lg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def render_form(%{live_action: :email} = assigns) do
    ~H"""
    <div
      id="email"
      phx-mounted={entry_animation(assigns, "#email")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Email form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#email")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#email")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :username} = assigns) do
    ~H"""
    <div
      id="username"
      phx-mounted={entry_animation(assigns, "#username")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Username form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#username")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#username")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :phone} = assigns) do
    ~H"""
    <div
      id="phone"
      phx-mounted={entry_animation(assigns, "#phone")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Phone form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#phone")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#phone")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :dob} = assigns) do
    ~H"""
    <div
      id="dob"
      phx-mounted={entry_animation(assigns, "#dob")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Date of Birth form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#dob")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#dob")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :gender} = assigns) do
    ~H"""
    <div
      id="gender"
      phx-mounted={entry_animation(assigns, "#gender")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Gender form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#gender")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#gender")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  def render_form(%{live_action: :terms} = assigns) do
    ~H"""
    <div
      id="terms"
      phx-mounted={entry_animation(assigns, "#terms")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      <p>Terms and Conditions form goes here</p>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_left, "#terms")
          |> JS.push("next_step")
        }
        class="btn btn-primary"
      >
        Next
      </button>
      <button
        type="button"
        phx-click={
          %JS{}
          |> move(:exit_right, "#terms")
          |> JS.push("prev_step")
        }
        class="btn btn-primary"
      >
        Back
      </button>
    </div>
    """
  end

  # Carousel-style animation functions
  def move(js \\ %JS{}, direction, to) do
    case direction do
      # Exit animations: When current form leaves the view
      :exit_left ->
        js
        |> JS.transition({"ease-out duration-300", "translate-x-0", "-translate-x-full"},
          time: 300,
          to: to
        )

      :exit_right ->
        js
        |> JS.transition({"ease-out duration-300", "translate-x-0", "translate-x-full"},
          time: 300,
          to: to
        )

      # Entry animations: When new form enters the view
      :enter_right ->
        js
        |> JS.transition({"ease-out duration-300", "translate-x-full", "translate-x-0"},
          time: 300,
          to: to
        )

      :enter_left ->
        js
        |> JS.transition({"ease-out duration-300", "-translate-x-full", "translate-x-0"},
          time: 300,
          to: to
        )
    end
  end

  # Helper function for entry animations in carousel
  def entry_animation(assigns, element_id) do
    case Map.get(assigns, :nav_direction) do
      :forward ->
        # When moving forward (next), new form enters from the right
        move(:enter_right, element_id)

      :backward ->
        # When moving backward (prev), new form enters from the left
        move(:enter_left, element_id)

      # No animation if direction is not specified
      _ ->
        %JS{}
    end
  end

  # Helper function to determine initial position class based on navigation direction
  def initial_position_class(assigns) do
    case Map.get(assigns, :nav_direction) do
      # Start off-screen to the right
      :forward -> "translate-x-full"
      # Start off-screen to the left
      :backward -> "-translate-x-full"
      # No initial offset
      _ -> ""
    end
  end
end
