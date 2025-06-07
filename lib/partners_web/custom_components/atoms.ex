defmodule PartnersWeb.CustomComponents.Atoms do
  use Phoenix.Component

  alias PartnersWeb.CustomComponents.{Typography, Layout}

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
          <Layout.company_logo />
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
end
