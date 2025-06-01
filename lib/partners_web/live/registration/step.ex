defmodule PartnersWeb.Registration.Step do
   @moduledoc "Describe a step in the multi-step form and where it can go."
  defstruct [:name, :prev, :next]

  def new do
    %__MODULE__{}
  end

end
