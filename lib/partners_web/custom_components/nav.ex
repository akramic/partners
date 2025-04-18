defmodule PartnersWeb.CustomComponents.Nav do
  @moduledoc """
  Navigation components for the application.
  """

  use PartnersWeb, :html

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :home_nav, :boolean,
    default: false,
    doc: "if true, the home navigation absolute bar is used"

  attr :current_user, :map, default: nil, doc: "the current user logged in"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"

  def main_menu(assigns) do
    ~H"""
    <nav class="relative w-full">
      <ul
        class={[
          "z-10 flex items-center justify-end gap-4 px-4 sm:px-6 lg:px-8",
          "absolute top-0 right-0 left-0 z-10 font-thin "
        ]}
        role="menu"
        aria-label="User account navigation"
      >
        <%!-- <ul
        class={[
          "z-10 flex items-center justify-end gap-4 px-4 sm:px-6 lg:px-8",
          @home_nav && "absolute top-0 right-0 left-0 z-10 font-thin "
        ]}
        role="menu"
        aria-label="User account navigation"
      > --%>
        <%= if @current_scope do %>
          <li role="menuitem">
            <.link
              href={~p"/users/settings"}
              class="text-[0.8125rem] font-semibold leading-6 "
              aria-label="Account settings"
            >
              Settings
            </.link>
          </li>
          <li role="menuitem">
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="text-[0.8125rem] font-semibold leading-6 "
              aria-label="Log out of your account"
            >
              Log out
            </.link>
          </li>
        <% else %>
          <li role="menuitem">
            <.link
              href={~p"/users/register"}
              class="text-[0.8125rem] font-semibold leading-6 "
              aria-label="Register a new account"
            >
              Register
            </.link>
          </li>
          <li role="menuitem">
            <.link
              href={~p"/users/log-in"}
              class="text-[0.8125rem] font-semibold leading-6 "
              aria-label="Log in to your account"
            >
              Log in
            </.link>
          </li>
        <% end %>
      </ul>
    </nav>
    """
  end
end
