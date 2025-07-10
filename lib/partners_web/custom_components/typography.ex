defmodule PartnersWeb.CustomComponents.Typography do
  @moduledoc """
  A collection of custom responsive typography components aligned with Tailwind CSS v4 size ratios.

  The components use CSS clamp() function to create fluid typography that scales smoothly
  between minimum and maximum sizes based on viewport width.

  ## Size Relationships

  All sizing follows Tailwind CSS v4 proportional relationships:
  - p: Base font (equivalent to Tailwind's text-base)
  - p_xxs: 62.5% of base size (smaller than Tailwind's text-xs)
  - p_xs: 75% of base size (equivalent to Tailwind's text-xs)
  - p_sm: 87.5% of base size (equivalent to Tailwind's text-sm)
  - p_lg: 112.5% of base size (equivalent to Tailwind's text-lg)

  Line height and letter spacing are adjusted for optimal readability at each size.

  ## Usage Example

  ```elixir
  import PartnersWeb.CustomComponents.Typography, only: [p: 1, p_sm: 1, p_xs: 1, p_xxs: 1, p_lg: 1]

  <.p>
    This is a dynamic sized paragraph using the base font.
  </.p>

  <.p_xxs>
    This is an extra small paragraph that still scales responsively.
  </.p_xxs>
  ```
  """

  use PartnersWeb, :html

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(1.125rem,2.25vw,1.75rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.125rem,2.25vw,1.75rem)*1.5)] tracking-[clamp(0.01em,0.02vw,0.02em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_xxs(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(0.703rem,1.41vw,1.09rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(0.703rem,1.41vw,1.09rem)*1.7)] tracking-[clamp(0.01em,0.018vw,0.018em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_xs(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(0.845rem,1.69vw,1.31rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(0.845rem,1.69vw,1.31rem)*1.6)] tracking-[clamp(0.01em,0.016vw,0.016em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_sm(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(0.985rem,1.97vw,1.53rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(0.985rem,1.97vw,1.53rem)*1.5)] tracking-[clamp(0.01em,0.017vw,0.017em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def p_lg(assigns) do
    ~H"""
    <p
      class={[
        "text-[clamp(1.27rem,2.53vw,1.97rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.27rem,2.53vw,1.97rem)*1.4)] tracking-[clamp(0.005em,0.015vw,0.015em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h1(assigns) do
    ~H"""
    <h1
      class={[
        "text-[clamp(2.5rem,6vw,4rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(2.5rem,6vw,4rem)*1.1)] font-extrabold tracking-[clamp(-0.02em,-0.01vw,-0.01em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h1>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h2(assigns) do
    ~H"""
    <h2
      class={[
        "text-[clamp(2.25rem,5.5vw,3.5rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(2.25rem,5.5vw,3.5rem)*1.1)] font-bold tracking-[clamp(-0.015em,-0.01vw,-0.01em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h2>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h3(assigns) do
    ~H"""
    <h3
      class={[
        "text-[clamp(2rem,5vw,3rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(2rem,5vw,3rem)*1.1)]  tracking-[clamp(-0.01em,-0.005vw,-0.005em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h4(assigns) do
    ~H"""
    <h4
      class={[
        "text-[clamp(1.75rem,4.5vw,2.5rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.75rem,4.5vw,2.5rem)*1.1)]  tracking-[clamp(-0.005em,0em,0em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h4>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h5(assigns) do
    ~H"""
    <h5
      class={[
        "text-[clamp(1.5rem,4vw,2.25rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.5rem,4vw,2.25rem)*1.15)]  tracking-[clamp(-0.005em,0em,0em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def h6(assigns) do
    ~H"""
    <h6
      class={[
        "text-[clamp(1.25rem,3.5vw,2rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.25rem,3.5vw,2rem)*1.15)]  tracking-[clamp(0em,0.01vw,0.01em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h6>
    """
  end

  attr :class, :string, default: "", doc: "the CSS classes to add to the component"

  attr :opacity, :integer,
    default: 100,
    doc: "the opacity to apply (default is 100 for 100% opacity)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the component"
  slot :inner_block, doc: "the optional inner block that renders the text"

  def form_heading(assigns) do
    ~H"""
    <h5
      class={[
        "text-[clamp(1.25rem,2.5vw,1.75rem)] opacity-#{@opacity}",
        "leading-[calc(clamp(1.25rem,2.5vw,1.75rem)*1.4)]  tracking-[clamp(0em,0.01vw,0.01em)]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end
end
