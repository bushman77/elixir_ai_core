defmodule Tokenizer do
  @moduledoc """
  Tokenizes text into words and resolves part-of-speech (POS) tags
  using a built-in fallback dictionary.
  """

  @base 128

  # Local fallback POS data for words
  @pos_data %{
    "how" => [:adverb, :conjunction],
    "are" => [:verb],
    "you" => [:pronoun],
    "what" => [:wh_determiner, :pronoun],
    "is" => [:verb],
    "your" => [:possessive],
    "name" => [:noun],
    "can" => [:aux, :modal],
    "i" => [:pronoun],
    "help" => [:verb, :noun],
    "do" => [:verb, :aux],
    "think" => [:verb],
    "he" => [:pronoun],
    "go" => [:base_verb, :verb]
  }

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

  @doc """
  Tokenizes a sentence into a list of maps with word and possible POS tags.
  """
  @spec tokenize(String.t()) :: [%{word: String.t(), pos: [atom()]}]
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.map(fn word ->
      %{
        word: word,
        pos: Map.get(@pos_data, word, [:unknown])
      }
    end)
  end
end
