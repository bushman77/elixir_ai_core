defmodule ElixirAiCore.Dataset do
  @moduledoc """
  Manages the dataset lifecycle—loading, querying, and preparing entries.
  """

  alias ElixirAiCore.Dataset.Entry

  @type dataset :: [Entry.t()]

  @doc """
  Loads a minimal starter dataset manually.
  """
  @spec load_minimal() :: dataset()
  def load_minimal do
    [
      %Entry{
        input: "Hello",
        label: :greeting,
        context: %{lang: :en}
      },
      %Entry{
        input: %{species: "cat", has_tail: true},
        label: :mammal
      },
      %Entry{
        input: [:wake_up, :eat, :train],
        label: :routine,
        context: %{goal: :performance}
      }
    ]
  end
end
