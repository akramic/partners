defmodule PartnersWeb.Registration.RegistrationComponents do
  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.Typography

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

  # Welcome screen component (no navigation buttons)
  attr :id, :string, required: true
  slot :inner_block, required: true

  def welcome_container(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={entry_animation(assigns, "##{@id}")}
      class="hero min-h-screen"
      style="background-image: url(/images/couple2.jpg);"
    >
      <div class="hero-overlay"></div>
      <div class="hero-content text-neutral-content text-center">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Reusable component for form containers with animations
  attr :id, :string, required: true
  attr :show_nav, :boolean, default: true
  slot :inner_block, required: true
  slot :custom_nav, required: false

  def form_container(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={entry_animation(assigns, "##{@id}")}
      class={"transition-transform duration-300 w-full #{initial_position_class(assigns)}"}
    >
      {render_slot(@inner_block)}

      <%= if @show_nav && !render_slot(@custom_nav) do %>
        <.form_nav form_id={@id} />
      <% else %>
        {render_slot(@custom_nav)}
      <% end %>
    </div>
    """
  end

  # Reusable navigation buttons for forms
  attr :form_id, :string, required: true
  attr :show_back, :boolean, default: true
  attr :show_next, :boolean, default: true
  attr :back_label, :string, default: "Back"
  attr :next_label, :string, default: "Next"
  attr :back_class, :string, default: "btn btn-primary"
  attr :next_class, :string, default: "btn btn-primary"

  def form_nav(assigns) do
    ~H"""
    <div class="flex justify-between mt-4">
      <%= if @show_back do %>
        <button
          type="button"
          phx-click={
            %JS{}
            |> move(:exit_right, "##{@form_id}")
            |> JS.push("prev_step")
          }
          class={@back_class}
        >
          {@back_label}
        </button>
      <% else %>
        <div></div>
        <!-- Spacer when back button is hidden -->
      <% end %>

      <%= if @show_next do %>
        <button
          type="button"
          phx-click={
            %JS{}
            |> move(:exit_left, "##{@form_id}")
            |> JS.push("next_step")
          }
          class={@next_class}
        >
          {@next_label}
        </button>
      <% else %>
        <div></div>
        <!-- Spacer when next button is hidden -->
      <% end %>
    </div>
    """
  end

  def render_form(%{live_action: :new} = assigns) do
    ~H"""
    <.welcome_container id="welcome" {assigns}>
      <div class="max-w-4xl space-y-6">
        <Typography.h3>Let's get your free trial underway</Typography.h3>
        <Typography.p class="mb-5">
          We just need a few details to create your account.
        </Typography.p>
        <button type="button" phx-click={JS.push("ready")} class="btn btn-lg btn-info">
          <Typography.p_lg>I'm ready</Typography.p_lg>
        </button>
      </div>
    </.welcome_container>
    """
  end

  def render_form(%{live_action: :email} = assigns) do
    ~H"""
    <.form_container id="email" {assigns}>
      <p>Email form goes here</p>
    </.form_container>
    """
  end

  def render_form(%{live_action: :username} = assigns) do
    ~H"""
    <.form_container id="username" {assigns}>
      <p>Username form goes here</p>
    </.form_container>
    """
  end

  def render_form(%{live_action: :phone} = assigns) do
    ~H"""
    <.form_container id="phone" {assigns}>
      <p>Phone form goes here</p>
    </.form_container>
    """
  end

  def render_form(%{live_action: :dob} = assigns) do
    ~H"""
    <.form_container id="dob" {assigns}>
      <p>Date of Birth form goes here</p>
    </.form_container>
    """
  end

  def render_form(%{live_action: :gender} = assigns) do
    ~H"""
    <.form_container id="gender" {assigns}>
      <p>Gender form goes here</p>
    </.form_container>
    """
  end

  def render_form(%{live_action: :terms} = assigns) do
    ~H"""
    <.form_container id="terms" {assigns}>
      <p>Terms and Conditions form goes here</p>

      <:custom_nav>
        <div class="flex justify-between mt-4">
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
          <button
            type="button"
            phx-click={
              %JS{}
              |> move(:exit_left, "#terms")
              |> JS.push("complete_registration")
            }
            class="btn btn-success"
          >
            Complete Registration
          </button>
        </div>
      </:custom_nav>
    </.form_container>
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
