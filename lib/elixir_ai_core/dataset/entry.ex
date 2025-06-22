defmodule ElixirAiCore.Dataset.Entry do
  @moduledoc """
  Represents a single unit of knowledge in the AI system.

  This structure is intentionally general and future-flexible.
  """

  @type t :: %__MODULE__{
          input: any(),
          label: any() | nil,
          context: map(),
          output: any() | nil
        }

  defstruct input: nil, label: nil, context: %{}, output: nil
end
