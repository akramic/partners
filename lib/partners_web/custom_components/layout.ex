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

  alias PartnersWeb.CustomComponents.Typography

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  @doc """
  A section component with dynamic vertical spacing and horizontal divider.
  Use this as the container for other html section elements.
  """

  def page_container(assigns) do
    ~H"""
    <main class="mt-20" {@rest}>
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
    <main class="" {@rest}>
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
      <div class="mx-auto max-w-7xl space-y-6 px-6 text-center sm:space-y-12 sm:px-8">
        <Typography.h1 class="text-pretty font-semibold tracking-tight sm:text-balance">
          {render_slot(@header)}
        </Typography.h1>
        {render_slot(@content)}
      </div>
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
      <div class="relative mx-auto max-w-2xl lg:max-w-4xl">
        <figure
          class="grid grid-cols-1 items-center gap-x-6 gap-y-8 lg:gap-x-10"
          aria-labelledby={"quote-author-#{@author}"}
        >
          <div class="relative col-span-2 lg:col-start-1 lg:row-start-2">
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
            <blockquote class="text-xl/8 font-medium sm:text-2xl/9">
              <p>
                {@quote}
              </p>
            </blockquote>
          </div>
          <div class="col-end-1 w-24 lg:row-span-4 lg:w-72">
            <img class="rounded-xl lg:rounded-3xl" src={@image_url} alt={@alt_text} loading="lazy" />
          </div>
          <figcaption class="text-base lg:col-start-1 lg:row-start-3">
            <div class="font-semibold " id={"quote-author-#{@author}"}>{@author}</div>
            <div class="mt-1 ">
              {@bio}
            </div>
          </figcaption>
        </figure>
      </div>
    </section>
    """
  end

  def site_header(assigns) do
    ~H"""
    <header class=" flex justify-between items-center px-4 w-full py-2 bg-transparent z-10">
      <div>
        <.link href={~p"/"}>
          <img
            src={~p"/images/heart.svg"}
            alt="Logo"
            class=" transition transform ease-in duration-300 hover:-rotate-360  h-6 w-6"
          />
        </.link>
      </div>

      <PartnersWeb.Layouts.theme_toggle />

      <ul
        class="bg-base-100 rounded-full text-sm text-base-content flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end"
        role="menu"
        aria-label="User account navigation"
      >
        <%= if @current_scope do %>
          <li>
            <.link href={~p"/users/settings"}>Settings</.link>
          </li>
          <li>
            <.link href={~p"/users/log-out"} method="delete">Log out</.link>
          </li>
        <% else %>
          <li>
            <.link href={~p"/users/register"}>Register</.link>
          </li>
          <li>
            <.link href={~p"/users/log-in"}>Log in</.link>
          </li>
        <% end %>
      </ul>
      <nav>
      <label class="btn btn-circle swap swap-rotate">
        <!-- this hidden checkbox controls the state -->
        <input type="checkbox" />

    <!-- hamburger icon -->
        <svg
          class="swap-off fill-current"
          xmlns="http://www.w3.org/2000/svg"
          width="32"
          height="32"
          viewBox="0 0 512 512"
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
        >
          <polygon points="400 145.49 366.51 112 256 222.51 145.49 112 112 145.49 222.51 256 112 366.51 145.49 400 256 289.49 366.51 400 400 366.51 289.49 256 400 145.49" />
        </svg>
      </label>
      </nav>
    </header>
    """
  end

  def site_footer(assigns) do
    ~H"""
    <footer class="w-full max-w-[1980px] mx-auto border-t border-zinc-500/50 footer footer-horizontal footer-center bg-base-300 text-base-content p-4">
      <p class="text-lg">Share and get 100 video call minutes on us!</p>
      <nav class="w-full max-w-2xl p-4 rounded-full bg-base-100">
        <div class="w-full max-w-lg flex justify-around items-center">
          <a>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
            >
              <path d="M9 8h-3v4h3v12h5v-12h3.642l.358-4h-4v-1.667c0-.955.192-1.333 1.115-1.333h2.885v-5h-3.808c-3.596 0-5.192 1.583-5.192 4.615v3.385z">
              </path>
            </svg>
          </a>
          <a>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
            >
              <path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932L18.901 1.153ZM17.61 20.644h2.039L6.486 3.24H4.298L17.61 20.644Z" />
            </svg>
          </a>
          <a>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
            >
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z M12 0C5.373 0 0 5.373 0 12c0 2.027.503 3.938 1.386 5.613L.05 23.5l6.033-1.359c1.613.8 3.42 1.235 5.29 1.284h.467c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.6c-1.78 0-3.548-.48-5.08-1.394l-.365-.217-3.778.99 1.01-3.686-.239-.378c-1.007-1.602-1.537-3.448-1.538-5.338 0-5.52 4.48-10 10-10s10 4.48 10 10c0 5.52-4.48 10-10 10z" />
            </svg>
          </a>
          <a>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              class="fill-current"
            >
              <path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" />
            </svg>
          </a>
          <a>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="30"
              height="30"
              viewBox="0 0 24 24"
              class="fill-current"
            >
              <path d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z" />
            </svg>
          </a>
        </div>
      </nav>
      <aside>
        <a>
          <svg xmlns="http://www.w3.org/2000/svg" width="50" height="50" viewBox="0 0 1280 1016">
            <g transform="translate(0,1016) scale(0.1,-0.1)" class="fill-yellow-500" stroke="none">
              <path d="M11715 10153 c-230 -56 -396 -142 -525 -272 -100 -102 -134 -160
                -158 -271 -21 -96 -62 -421 -62 -495 0 -42 -20 -75 -57 -94 -32 -17 -215 -41
                -309 -41 l-80 0 -185 183 c-215 215 -349 329 -511 437 -190 126 -352 180 -456
                151 -83 -23 -96 -59 -68 -191 36 -170 123 -332 364 -680 121 -176 173 -242
                203 -262 l41 -27 -31 -15 c-37 -20 -38 -25 -45 -204 l-6 -143 -39 -47 c-106
                -127 -165 -261 -190 -429 -16 -103 -14 -137 10 -188 72 -154 236 -236 542
                -272 l68 -8 -176 -190 -177 -190 -151 -17 c-383 -44 -689 -121 -975 -247 -294
                -128 -611 -365 -1136 -850 -184 -170 -291 -291 -396 -447 -253 -378 -412 -873
                -475 -1477 -19 -183 -38 -635 -30 -698 l6 -45 -140 -169 c-90 -108 -141 -177
                -141 -192 0 -54 -119 -252 -268 -447 -71 -92 -346 -358 -494 -477 -268 -215
                -543 -360 -883 -464 -129 -40 -125 -39 -935 -100 -118 -8 -541 -40 -940 -70
                -399 -30 -795 -60 -880 -66 -106 -8 -296 -36 -600 -90 -245 -43 -499 -87 -565
                -99 -357 -62 -746 -132 -792 -141 -45 -9 -53 -14 -62 -41 -30 -85 -2 -168 80
                -242 l54 -49 405 7 c439 7 1284 20 2410 36 393 6 979 15 1301 20 l586 9 224
                80 c531 188 857 320 1161 471 254 127 366 216 1033 819 319 288 594 537 612
                554 l31 29 92 -38 c51 -21 94 -45 96 -53 10 -33 66 -139 94 -177 23 -32 41
                -44 87 -58 74 -23 169 -71 180 -90 5 -8 5 -73 1 -143 -3 -70 -12 -227 -18
                -348 -24 -472 -70 -816 -132 -992 -19 -56 -20 -68 -10 -114 12 -50 59 -155 88
                -193 15 -22 24 -23 514 -81 791 -92 1584 -157 2375 -194 519 -25 485 -25 550
                -2 116 41 176 103 161 167 -9 37 -126 151 -189 184 -26 14 -47 27 -47 30 0 3
                44 2 98 -3 53 -4 212 -8 352 -9 326 -2 426 14 546 85 39 23 54 39 54 58 0 47
                -150 165 -305 241 -45 22 -57 23 -120 16 -99 -12 -241 -1 -375 29 -130 29
                -213 57 -355 121 l-100 45 -195 8 c-107 4 -384 15 -615 24 -815 31 -795 30
                -842 54 -49 24 -86 75 -104 141 -13 52 -7 266 17 540 40 468 108 828 209 1119
                47 135 75 188 120 231 78 74 173 233 229 382 l24 62 0 -170 c0 -132 4 -190 20
                -266 25 -122 81 -242 122 -263 56 -29 81 -18 97 45 9 35 10 35 22 12 20 -37
                82 -102 112 -118 34 -17 71 -18 87 -2 16 16 15 60 0 77 -11 10 -5 19 26 44 22
                18 53 43 69 57 l29 25 -15 76 -14 76 45 102 44 102 -91 267 -91 267 43 35
                c221 181 450 470 695 879 79 131 80 133 96 110 29 -45 64 -154 81 -254 19
                -112 23 -455 6 -513 -5 -18 -71 -129 -147 -248 l-137 -215 -93 -256 c-84 -231
                -92 -259 -81 -282 15 -32 47 -38 82 -15 l27 17 -31 -48 c-38 -59 -41 -101 -8
                -116 18 -8 36 -4 91 21 73 33 96 33 96 0 0 -25 -33 -92 -68 -139 -25 -33 -25
                -34 -6 -48 14 -11 38 -14 90 -10 89 5 177 44 251 111 83 75 95 120 233 916
                l119 685 21 475 c12 261 27 601 34 755 7 158 9 319 5 370 -29 345 -201 785
                -504 1289 l-73 121 -72 355 -73 355 7 280 7 280 61 60 c166 164 285 442 379
                885 31 144 36 225 23 336 l-6 51 -106 16 c-59 9 -118 18 -132 21 -14 2 -34 2
                -45 -1z m-2480 -7440 c-3 -21 -16 -123 -30 -228 -44 -330 -90 -555 -118 -572
                -14 -9 -1 542 16 662 8 55 18 108 22 119 8 18 77 55 103 56 8 0 11 -11 7 -37z" />
            </g>
          </svg>
        </a>

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
