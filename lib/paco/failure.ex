defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.Input.position,
                         what: String.t,
                         because: t | nil}

  defstruct at: {0, 0, 0}, what: "", because: nil

  def format(%Paco.Failure{at: {_, line, column}, what: what, because: nil}) do
    """
    Failed to match #{what} at #{line}:#{column}
    """
  end
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: failure}) do
    failure = Regex.replace(~r/^F/, String.strip(format(failure)), "f")
    """
    Failed to match #{what} at #{line}:#{column}, because it #{failure}
    """
  end
end
