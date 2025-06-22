defmodule ElixirAiCore.Dataset.Examples do
  @moduledoc """
  Provides minimal example dataset for test/dev use.
  """

  alias ElixirAiCore.Dataset.Entry

  @spec minimal() :: [Entry.t()]
  def minimal do
    [
      %Entry{input: "Hello", label: :greeting, context: %{lang: :en}},
      %Entry{input: %{species: "cat", has_tail: true}, label: :mammal},
      %Entry{input: [:wake_up, :eat, :train], label: :routine}
    ]
  end
end
