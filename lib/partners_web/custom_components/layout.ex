defmodule PartnersWeb.CustomComponents.Layout do
  @moduledoc """
  A collection of custom typography components.
  In the liveview template, you can use these components like this:

  import PartnersWeb.CustomComponents.Layout, only: [section_container: 1]

  <.section_container>
    With dynamic vertical spacing and horizontal divider
      </.section_container>


  """

  use PartnersWeb, :html

  alias PartnersWeb.CustomComponents.{Typography, Atoms}

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  @doc """
  A section component with dynamic vertical spacing and horizontal divider.
  Use this as the container for other html section elements.
  """

  def page_container(assigns) do
    ~H"""
    <main class="mt-[clamp(2rem,8vw,8rem)]" role="main" aria-label="Main content" {@rest}>
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  @doc """
  A section component with dynamic vertical spacing and horizontal divider.
  Use this as the container for other html section elements.
  """

  def section_container(assigns) do
    ~H"""
    <main class="" role="main" aria-label="Section content" {@rest}>
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :header, required: true, doc: "the required block that renders the header text"
  slot :content, required: true, doc: "the required block that renders the content text"

  @doc """
  A section component for hero content
  """

  def hero_section(assigns) do
    ~H"""
    <section class="fade py-24 sm:py-32" {@rest}>
      <article class="mx-auto max-w-7xl space-y-6 px-6 text-center sm:space-y-12 sm:px-8">
        <Typography.h1 class="text-pretty font-semibold tracking-tight sm:text-balance">
          {render_slot(@header)}
        </Typography.h1>
        {render_slot(@content)}
      </article>
    </section>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :author, :string, required: true, doc: "the name of attributed to this quote"
  attr :bio, :string, required: true, doc: "brief bio of author"
  attr :quote, :string, required: true, doc: "the actual quote"
  attr :image_url, :string, required: true, doc: "the image associated with this quote"
  attr :alt_text, :string, required: true, doc: "the alt text image associated with the image"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"

  @doc """
  A section component with dynamic vertical spacing and horizontal divider.
  Use this as the container for other html section elements.
  """

  def section_quote(assigns) do
    ~H"""
    <section
      class={["fade isolate overflow-hidden px-6 py-16 sm:py-20 md:py-24 lg:px-8 lg:py-28", @class]}
      {@rest}
    >
      <article class="relative mx-auto max-w-2xl lg:max-w-4xl">
        <figure
          class="grid grid-cols-1 items-center gap-x-6 gap-y-8 lg:gap-x-10"
          aria-labelledby={"quote-author-#{@author}"}
        >
          <blockquote class="relative col-span-2 lg:col-start-1 lg:row-start-2">
            <svg
              viewBox="0 0 162 128"
              fill="none"
              aria-hidden="true"
              class="stroke-gray-100/10 absolute -top-10 left-0 -z-10 h-24 sm:-top-12 sm:h-32"
            >
              <path
                id={@author}
                d="M65.5697 118.507L65.8918 118.89C68.9503 116.314 71.367 113.253 73.1386 109.71C74.9162 106.155 75.8027 102.28 75.8027 98.0919C75.8027 94.237 75.16 90.6155 73.8708 87.2314C72.5851 83.8565 70.8137 80.9533 68.553 78.5292C66.4529 76.1079 63.9476 74.2482 61.0407 72.9536C58.2795 71.4949 55.276 70.767 52.0386 70.767C48.9935 70.767 46.4686 71.1668 44.4872 71.9924L44.4799 71.9955L44.4726 71.9988C42.7101 72.7999 41.1035 73.6831 39.6544 74.6492C38.2407 75.5916 36.8279 76.455 35.4159 77.2394L35.4047 77.2457L35.3938 77.2525C34.2318 77.9787 32.6713 78.3634 30.6736 78.3634C29.0405 78.3634 27.5131 77.2868 26.1274 74.8257C24.7483 72.2185 24.0519 69.2166 24.0519 65.8071C24.0519 60.0311 25.3782 54.4081 28.0373 48.9335C30.703 43.4454 34.3114 38.345 38.8667 33.6325C43.5812 28.761 49.0045 24.5159 55.1389 20.8979C60.1667 18.0071 65.4966 15.6179 71.1291 13.7305C73.8626 12.8145 75.8027 10.2968 75.8027 7.38572C75.8027 3.6497 72.6341 0.62247 68.8814 1.1527C61.1635 2.2432 53.7398 4.41426 46.6119 7.66522C37.5369 11.6459 29.5729 17.0612 22.7236 23.9105C16.0322 30.6019 10.618 38.4859 6.47981 47.558L6.47976 47.558L6.47682 47.5647C2.4901 56.6544 0.5 66.6148 0.5 77.4391C0.5 84.2996 1.61702 90.7679 3.85425 96.8404L3.8558 96.8445C6.08991 102.749 9.12394 108.02 12.959 112.654L12.959 112.654L12.9646 112.661C16.8027 117.138 21.2829 120.739 26.4034 123.459L26.4033 123.459L26.4144 123.465C31.5505 126.033 37.0873 127.316 43.0178 127.316C47.5035 127.316 51.6783 126.595 55.5376 125.148L55.5376 125.148L55.5477 125.144C59.5516 123.542 63.0052 121.456 65.9019 118.881L65.5697 118.507Z"
              />
              <use href={"#{@author}"} x="86" />
            </svg>
            <p class="text-xl/8 font-medium sm:text-2xl/9">
              {@quote}
            </p>
          </blockquote>
          <figure class="col-end-1 w-24 lg:row-span-4 lg:w-72">
            <img class="rounded-xl lg:rounded-3xl" src={@image_url} alt={@alt_text} loading="lazy" />
          </figure>
          <figcaption class="text-base lg:col-start-1 lg:row-start-3">
            <cite class="font-semibold block" id={"quote-author-#{@author}"}>{@author}</cite>
            <span class="mt-1 block">
              {@bio}
            </span>
          </figcaption>
        </figure>
      </article>
    </section>
    """
  end

  def site_header(assigns) do
    ~H"""
    <header role="banner">
      <div class="flex justify-between items-center px-4 w-full py-2 bg-transparent z-10">
        <div class="flex items-center gap-4">
          <h1>
            <.link href={~p"/"}>
              <img
                src={~p"/images/heart.svg"}
                alt="Logo"
                class="transition transform ease-in duration-300 hover:-rotate-360 h-6 w-6"
              />
            </.link>
          </h1>

          <PartnersWeb.Layouts.theme_toggle />
        </div>
        <div class="flex items-center gap-4">
          <nav>
            <ul
              class="bg-base-100 rounded-full text-sm text-base-content flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end"
              role="menu"
              aria-label="User account navigation"
            >
              <%= if @current_scope do %>
                <li>
                  <.link navigate={~p"/users/settings"}>Settings</.link>
                </li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">Log out</.link>
                </li>
              <% else %>
                <li>
                  <.link navigate={~p"/users/register"}>Register</.link>
                </li>
                <li>
                  <.link navigate={~p"/users/log-in"}>Log in</.link>
                </li>
              <% end %>
            </ul>
          </nav>
          <nav class="relative" aria-label="Main menu navigation">
            <label
              phx-click={
                %JS{}
                |> JS.toggle(
                  to: "#backdrop",
                  in: {"ease-in-out duration-300 ", "-translate-x-full ", "translate-x-0 "},
                  out: {"ease-in-out duration-300 ", "translate-x-0 ", "-translate-x-full "},
                  time: 200
                )
              }
              class="z-20 btn btn-circle swap swap-rotate"
              aria-haspopup="true"
              aria-controls="side-bar"
              aria-expanded="false"
              aria-label="Toggle main menu"
            >
              <!-- this hidden checkbox controls the state -->
              <input type="checkbox" aria-hidden="true" />

    <!-- hamburger icon -->
              <svg
                class="swap-off fill-current"
                xmlns="http://www.w3.org/2000/svg"
                width="32"
                height="32"
                viewBox="0 0 512 512"
                aria-hidden="true"
                focusable="false"
              >
                <path d="M64,384H448V341.33H64Zm0-106.67H448V234.67H64ZM64,128v42.67H448V128Z" />
              </svg>

    <!-- close icon -->
              <svg
                class="swap-on fill-current"
                xmlns="http://www.w3.org/2000/svg"
                width="32"
                height="32"
                viewBox="0 0 512 512"
                aria-hidden="true"
                focusable="false"
              >
                <polygon points="400 145.49 366.51 112 256 222.51 145.49 112 112 145.49 222.51 256 112 366.51 145.49 400 256 289.49 366.51 400 400 366.51 289.49 256 400 145.49" />
              </svg>
            </label>

            <%!--  --%>
          </nav>
        </div>
      </div>

      <%!-- This is the overlay with menu--%>
      <dialog
        id="backdrop"
        class="backdrop-blur-[2px] h-dvh w-full max-w-[1980px] mx-auto z-10 absolute top-0 hidden bg-base-100/0"
        role="dialog"
        aria-modal="true"
        aria-labelledby="menu-heading"
      >
        <%!-- This is the element for both the menu and any backdrop content --%>
        <section class="flex flex-row h-full w-full justify-start">
          <%!-- Menu sidebar --%>
          <aside
            id="side-bar"
            class="w-full p-4 md-p-8 basis-2/3 bg-base-100 h-full flex flex-col"
            role="navigation"
            aria-labelledby="menu-heading"
          >
            <nav
              class="space-y-6 flex flex-col items-center justify-between h-full w-full"
              aria-label="Main navigation "
            >
              <div class="space-y-6 w-full">
                <h2 class="text-center" id="menu-heading" tabindex="-1">Where to?</h2>

                <%!-- Menu items for logged in users --%>
                <%= if @current_scope do %>
                  <ul class="menu bg-base-200 rounded-box w-full space-y-2" role="menu">
                    <li role="menuitem">
                      <Atoms.menu_item
                        url={~p"/users/settings"}
                        hero_icon_name="hero-home"
                        menu_label="Settings"
                      />
                    </li>
                    <li role="menuitem">
                      <Atoms.menu_item
                        nav_method={:href}
                        url={~p"/users/log-out"}
                        method="delete"
                        hero_icon_name="hero-home"
                        menu_label="Log out"
                      />
                    </li>
                  </ul>
                <% else %>
                  <%!-- Menu items for users not logged in --%>
                  <ul class="menu bg-base-200 rounded-box w-full space-y-2" role="menu">
                    <li role="menuitem">
                      <Atoms.menu_item
                        url={~p"/users/register"}
                        hero_icon_name="hero-home"
                        menu_label="Register"
                      />
                    </li>
                    <li role="menuitem">
                      <Atoms.menu_item
                        url={~p"/users/log-in"}
                        hero_icon_name="hero-home"
                        menu_label="Log in"
                      />
                    </li>
                  </ul>
                <% end %>
                <%!-- Menu items for all users--%>
                <ul class="menu bg-base-200 rounded-box w-full space-y-2" role="menu">
                  <li role="menuitem">
                    <Atoms.menu_item url={~p"/"} hero_icon_name="hero-home" menu_label="Home" />
                  </li>
                  <li role="menuitem">
                    <Atoms.menu_item url={~p"/"} hero_icon_name="hero-home" menu_label="Home" />
                  </li>
                </ul>
              </div>
              <footer>
                <Atoms.company_logo />
              </footer>
            </nav>
          </aside>

          <section
            class="flex h-full w-full basis-1/3 justify-center items-center"
            role="presentation"
          >
            <p class="bg-base-200 invisible md:visible p-4 rounded-xl" aria-hidden="true">
              Choose your poison
            </p>
          </section>
        </section>
      </dialog>
    </header>
    """
  end

  def site_footer(assigns) do
    ~H"""
    <footer class="w-full max-w-[1980px] mx-auto border-t border-zinc-500/50 footer footer-horizontal footer-center bg-base-300 text-base-content p-4">
      <p class="text-lg">Share and get 100 video call minutes on us!</p>
      <nav class="w-full max-w-2xl p-4 rounded-full bg-base-100" aria-label="Social media links">
        <div class="w-full max-w-lg flex justify-around items-center">
          <a href="#" aria-label="Share on Facebook">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
              aria-hidden="true"
              focusable="false"
            >
              <path d="M9 8h-3v4h3v12h5v-12h3.642l.358-4h-4v-1.667c0-.955.192-1.333 1.115-1.333h2.885v-5h-3.808c-3.596 0-5.192 1.583-5.192 4.615v3.385z">
              </path>
            </svg>
          </a>
          <a href="#" aria-label="Share on X (Twitter)">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
              aria-hidden="true"
              focusable="false"
            >
              <path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932L18.901 1.153ZM17.61 20.644h2.039L6.486 3.24H4.298L17.61 20.644Z" />
            </svg>
          </a>
          <a href="#" aria-label="Share on WhatsApp">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
              aria-hidden="true"
              focusable="false"
            >
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z M12 0C5.373 0 0 5.373 0 12c0 2.027.503 3.938 1.386 5.613L.05 23.5l6.033-1.359c1.613.8 3.42 1.235 5.29 1.284h.467c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.6c-1.78 0-3.548-.48-5.08-1.394l-.365-.217-3.778.99 1.01-3.686-.239-.378c-1.007-1.602-1.537-3.448-1.538-5.338 0-5.52 4.48-10 10-10s10 4.48 10 10c0 5.52-4.48 10-10 10z" />
            </svg>
          </a>
          <a href="#" aria-label="Share via Email">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
              aria-hidden="true"
              focusable="false"
            >
              <path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" />
            </svg>
          </a>
          <a href="#" aria-label="Share on Telegram">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="30"
              height="30"
              viewBox="0 0 24 24"
              class="fill-current"
              aria-hidden="true"
              focusable="false"
            >
              <path d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z" />
            </svg>
          </a>
        </div>
      </nav>
      <aside>
        <%!-- Company logo of kangaroo --%>
       <div class="w-12">
          <Atoms.company_logo />
        </div>

        <p class="text-sm font-semibold opacity-60">
          Really Useful Software Pty Limited.
        </p>
        <p class="text-sm opacity-70">
          We're proudly Australian owned and operated.
        </p>
        <p class="text-xs opacity-60">
          Copyright © 2024 - {Date.utc_today().year} - All right reserved
        </p>
      </aside>
    </footer>
    """
  end
end
