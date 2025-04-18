defmodule PartnersWeb.CustomComponents.Typography do
  @moduledoc """
    A collection of custom typography components.
    In the liveview template, you can use these components like this:

    import PartnersWeb.CustomComponents.Typography, only: [p: 1]

    <.p>
      This is a dynamic sized paragraph
    </.p>


  """

  use PartnersWeb, :html

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p(assigns) do
    ~H"""
    <p
      class={["text-[clamp(1rem,2vw,1.5rem)] leading-[calc(clamp(1rem,2vw,1.5rem)*1.6)]", @class]}
      @rest
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h1(assigns) do
    ~H"""
    <h1
      class={[
        "text-[clamp(2.25rem,8vw,8rem)] leading-[calc(clamp(2.25rem,8vw,8rem)*1.2)] font-extrabold tracking-tight",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h1>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h2(assigns) do
    ~H"""
    <h2
      class={[
        "text-[clamp(2rem,7vw,8rem)] leading-[calc(clamp(2rem,7vw,8rem)*1.2)] font-extrabold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h2>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h3(assigns) do
    ~H"""
    <h3
      class={[
        "text-[clamp(1.75rem,6vw,6rem)] leading-[calc(clamp(1.75rem,6vw,6rem)*1.2)] font-bold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h4(assigns) do
    ~H"""
    <h4
      class={[
        "text-[clamp(1.5rem,5vw,4rem)] leading-[calc(clamp(1.5rem,5vw,4rem)*1.2)] font-bold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h4>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h5(assigns) do
    ~H"""
    <h5
      class={[
        "text-[clamp(1.25rem,4vw,2rem)] leading-[calc(clamp(1.25rem,4vw,2rem)*1.2)] font-semibold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h6(assigns) do
    ~H"""
    <h6
      class={[
        "text-[clamp(1rem,3vw,1.75rem)] leading-[calc(clamp(1rem,3vw,1.75rem)*1.2)] font-semibold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h6>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def form_heading(assigns) do
    ~H"""
    <h5
      class={[
        "text-[clamp(1.125rem,2vw,1.5rem)] leading-[calc(clamp(1rem,2vw,1.5rem)*1.6)]] font-semibold",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end
end
