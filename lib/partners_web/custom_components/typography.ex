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
      class={[
        "text-[clamp(1.125rem,2.25vw,1.75rem)] leading-[calc(clamp(1.125rem,2.25vw,1.75rem)*1.5)] tracking-[clamp(0.01em,0.02vw,0.02em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_xs(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(0.845rem,1.69vw,1.31rem)] leading-[calc(clamp(0.845rem,1.69vw,1.31rem)*1.6)] tracking-[clamp(0.01em,0.016vw,0.016em)] font-light",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_sm(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(0.985rem,1.97vw,1.53rem)] leading-[calc(clamp(0.985rem,1.97vw,1.53rem)*1.5)] tracking-[clamp(0.01em,0.017vw,0.017em)] font-light",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_lg(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(1.27rem,2.53vw,1.97rem)] leading-[calc(clamp(1.27rem,2.53vw,1.97rem)*1.4)] tracking-[clamp(0.005em,0.015vw,0.015em)]",
        @class
      ]}
      {@rest}
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
        "text-[clamp(2.5rem,6vw,4rem)] leading-[calc(clamp(2.5rem,6vw,4rem)*1.1)] font-extrabold tracking-[clamp(-0.02em,-0.01vw,-0.01em)]",
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
        "text-[clamp(2.25rem,5.5vw,3.5rem)] leading-[calc(clamp(2.25rem,5.5vw,3.5rem)*1.1)] font-extrabold tracking-[clamp(-0.015em,-0.01vw,-0.01em)]",
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
        "text-[clamp(2rem,5vw,3rem)] leading-[calc(clamp(2rem,5vw,3rem)*1.1)] font-bold tracking-[clamp(-0.01em,-0.005vw,-0.005em)]",
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
        "text-[clamp(1.75rem,4.5vw,2.5rem)] leading-[calc(clamp(1.75rem,4.5vw,2.5rem)*1.1)] font-bold tracking-[clamp(-0.005em,0em,0em)]",
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
        "text-[clamp(1.5rem,4vw,2.25rem)] leading-[calc(clamp(1.5rem,4vw,2.25rem)*1.15)] font-semibold tracking-[clamp(-0.005em,0em,0em)]",
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
        "text-[clamp(1.25rem,3.5vw,2rem)] leading-[calc(clamp(1.25rem,3.5vw,2rem)*1.15)] font-semibold tracking-[clamp(0em,0.01vw,0.01em)]",
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
        "text-[clamp(1.25rem,2.5vw,1.75rem)] leading-[calc(clamp(1.25rem,2.5vw,1.75rem)*1.4)] font-semibold tracking-[clamp(0em,0.01vw,0.01em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end
end
