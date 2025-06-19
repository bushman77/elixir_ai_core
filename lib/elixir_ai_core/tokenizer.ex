defmodule ElixirAiCore.Tokenizer do
  @moduledoc """
  Pure Elixir tokenizer and embedding generator.
  """

  @base 128

  @doc """
  Convert a word to a unique numeric ID based on char positions.
  """
  def word_to_id(word) when is_binary(word) do
    word
    |> String.downcase()
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.map(fn {char, idx} ->
      (char - 96) * :math.pow(@base, idx)
    end)
    |> Enum.sum()
    |> round()
  end

  @doc """
  Normalize numeric ID to float between 0 and 1.
  """
  def embed(word, max \\ 1_000_000_000.0) do
    word_to_id(word) / max
  end
end