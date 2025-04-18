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

  def footer(assigns) do
    ~H"""
    <footer
      class="relative mt-auto border-t border-gray-300 text-gray-900"
      role="contentinfo"
      aria-label="Site footer"
    >
      <div class="mx-auto px-3 py-2 sm:px-4 sm:py-4">
        <div class="flex flex-col items-center text-center">
          <div class="flex items-center justify-center gap-2 ">
            <h3 class="text-base font-semibold text-gray-900 sm:text-lg">
              Loving Partners
            </h3>
            <span class="inline-block">
              <.link href={~p"/"} aria-label="Loving Partners - Home">
                <svg
                  class="h-4 opacity-80 sm:h-5"
                  version="1.1"
                  viewBox="0 0 8 8"
                  xmlns="http://www.w3.org/2000/svg"
                  role="img"
                  aria-labelledby="footer-logo-title"
                >
                  <title id="footer-logo-title">Loving Partners Heart Logo</title>
                  >
                  <g transform="translate(-105.77 -147.51)">
                    <path
                      d="m107.81 154.52c0.0364-0.0376 0.46798-0.25452 0.95911-0.48205 0.49113-0.22752 1.1104-0.5417 1.3761-0.69816 1.3322-0.78442 2.3456-1.8509 2.6369-2.7749 0.10423-0.33066 0.10402-0.377-3e-3 -0.7674-0.15175-0.55137-0.36756-0.86481-0.75037-1.0898-0.28133-0.16536-0.37686-0.1851-0.87792-0.18138-0.46173 3e-3 -0.67396 0.0437-1.1872 0.22514-0.69083 0.24424-0.61982 0.2484-1.5578-0.0913-0.79461-0.28776-1.2584-0.21097-1.7032 0.282-0.23108 0.25608-0.24805 0.30328-0.24805 0.68998 0 0.76052 0.59501 1.7369 1.4151 2.3221 0.24033 0.17149 0.43695 0.34207 0.43695 0.37906 0 0.21485-1.0165-0.43425-1.5302-0.9771-0.46842-0.49503-0.70962-0.96747-0.8217-1.6095-0.1225-0.70169-0.0288-1.063 0.392-1.5114 0.54435-0.58005 1.3903-0.65757 2.5632-0.23487 0.55818 0.20116 0.62088 0.19879 1.0906-0.0413 1.0627-0.54307 2.4147-0.3756 2.9425 0.36449 0.26496 0.37152 0.41261 1.0055 0.37709 1.619-0.0247 0.42673-0.0694 0.57579-0.31256 1.0432-0.65 1.2494-2.1513 2.4306-4.0932 3.2206-0.73475 0.29888-1.2242 0.43789-1.1038 0.31353z"
                      fill="#fb3915"
                      stroke="#fb3915"
                      stroke-width=".26458"
                    />
                  </g>
                </svg>
              </.link>
            </span>
          </div>
          <p class="mt-1 max-w-md text-sm leading-snug text-gray-700 sm:mt-2 sm:leading-normal">
            Authentic smiles, mutual respect and genuine interactions.<br />
            Get started today to make that meaningful connection.
          </p>
          <nav aria-label="Footer links" class="mt-2 sm:mt-4">
            <ul class="flex gap-4 text-xs uppercase text-gray-800 sm:gap-8">
              <li>
                <.link
                  href="#"
                  class="[&:is(:hover,:focus)]:text-gray-900 [&:is(:hover,:focus)]:underline rounded-sm underline-offset-4 transition-colors duration-200 focus-visible:ring-primary-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2"
                  aria-label="About Loving Partners"
                >
                  About
                </.link>
              </li>
              <li>
                <.link
                  href="#"
                  class="[&:is(:hover,:focus)]:text-gray-900 [&:is(:hover,:focus)]:underline rounded-sm underline-offset-4 transition-colors duration-200 focus-visible:ring-primary-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2"
                  aria-label="Contact Loving Partners"
                >
                  Contact
                </.link>
              </li>
              <li>
                <.link
                  href="#"
                  class="[&:is(:hover,:focus)]:text-gray-900 [&:is(:hover,:focus)]:underline rounded-sm underline-offset-4 transition-colors duration-200 focus-visible:ring-primary-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2"
                  aria-label="Privacy Policy"
                >
                  Privacy
                </.link>
              </li>
            </ul>
          </nav>
        </div>
      </div>
      <div class="border-t border-gray-300 py-2 text-center sm:py-3">
        <span class="mx-1 inline-block w-8 sm:mx-2 sm:w-8">
          <svg
            role="img"
            aria-labelledby="opera-house-title opera-house-desc"
            viewBox="0 0 122.88 46.23"
          >
            <title id="opera-house-title">Sydney Opera House</title>
            <desc id="opera-house-desc">
              Iconic silhouette of the Sydney Opera House, representing our Australian heritage
            </desc>
            <path
              class="fill-primary-600"
              d="M0,39.24h122.88v6.98H0V39.24L0,39.24z M37.21,36.86H20.95c-2.41-9.67-7.33-15.69-13.46-19.87 c1.52,2.78,2.72,16.77,3.4,19.85l-3.75,0.01C7,34.48,5.96,17.93,4.72,15.42c5.46,0.21,10.69,1.4,15.65,4.09 c-0.24-3.34-1.99-9.1-3.69-12.54c8.24,0.32,16.11,2.24,23.53,6.68l-5.66-13.6c16.77-0.73,31.34,7.9,42.4,20.13 c2.5,2.76,4.8,5.83,6.83,9.33c3.8-5.19,8.19-9.8,13.78-13.23c6.73-4.13,11.96-5.25,19.57-5.65l-0.07,0.05 c-2.15,7.08-2.11,16.86-1.01,26.19h-4.69c-0.19-9.82,0.14-19.34,3.03-24.18c-8.6,6.84-14.69,15.31-16.41,24.17l-25.65,0.02 C68.43,19.48,54.91,7.99,41.63,4.26l5.06,14.02c5.36,4.5,10.47,10.57,15.27,18.58H39.3c-3.36-13.48-10.22-21.88-18.76-27.7 c2.05,3.76,4.43,9.85,5.43,14.13C29.92,26.55,33.68,30.98,37.21,36.86L37.21,36.86z"
            />
          </svg>
        </span>
        <p class="text-[10px] leading-tight text-gray-700 sm:text-xs sm:leading-normal">
          &copy; 2024 - {DateTime.utc_now().year} Loving Partners. A Proudly Australian Business
          <br class="sm:hidden" /> All rights reserved.
        </p>
      </div>
    </footer>
    """
  end
end
