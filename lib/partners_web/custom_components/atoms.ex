defmodule PartnersWeb.CustomComponents.Atoms do
  use Phoenix.Component

  alias PartnersWeb.CustomComponents.{Typography}

  @doc """
  A menu item component for the sidebar menu.
  """
  attr :menu_label, :string, required: true, doc: "the label for the menu item"
  attr :hero_icon_name, :string, required: true, doc: "the name of the hero icon to use"
  attr :url, :string, required: true, doc: "the URL to link to"
  attr :nav_method, :atom, default: :navigate, doc: "whether to use a link or a button"
  attr :method, :string, default: "get", doc: "the HTTP method to use for the link"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"

  def menu_item(%{nav_method: :href} = assigns) do
    ~H"""
    <li role="menuitem">
      <.link href={@url} method={@method} class="flex justify-between items-center">
        <PartnersWeb.CoreComponents.icon name={@hero_icon_name} class="h-6 w-6" />
        {@menu_label}
      </.link>
    </li>
    """
  end

  def menu_item(%{nav_method: :patch} = assigns) do
    ~H"""
    <li role="menuitem">
      <.link patch={@url} method={@method} class="flex justify-between items-center">
        <PartnersWeb.CoreComponents.icon name={@hero_icon_name} class="h-6 w-6" />
        {@menu_label}
      </.link>
    </li>
    """
  end

  def menu_item(assigns) do
    ~H"""
    <li role="menuitem">
      <.link navigate={@url} method={@method} class="flex justify-between items-center">
        <PartnersWeb.CoreComponents.icon name={@hero_icon_name} class="h-6 w-6" />
        {@menu_label}
      </.link>
    </li>
    """
  end

  attr :text, :string, default: "Loading", doc: "The text to display while loading"

  slot :inner_block,
    required: false,
    doc: "Optional inner block for additional content or styling"

  def full_page_loader(assigns) do
    ~H"""
    <div
      class="w-full h-full fixed top-0 left-0 bg-base-100 opacity-90 z-[100]"
      role="dialog"
      aria-modal="true"
      aria-labelledby="loading-status"
    >
      <div
        class="flex flex-col space-y-3 justify-center items-center h-full w-full"
        role="status"
        aria-live="polite"
      >
        <div class="animate-bounce" aria-hidden="true">
          <.company_logo />
        </div>
        {render_slot(@inner_block)}
        <div class="flex justify-center items-end space-x-2">
          <Typography.p_xs class="gap-2" id="loading-status">
            {@text}
          </Typography.p_xs>
          <span class="loading loading-dots loading-xs" aria-hidden="true"></span>
        </div>
        <div class="sr-only">Please wait while content is loading</div>
      </div>
    </div>
    """
  end

  def company_logo(assigns) do
    ~H"""
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
    """
  end
end
