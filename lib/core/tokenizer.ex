defmodule Core.Tokenizer do
  @moduledoc """
  Converts input sentences into structured token objects (phrases).
  Generates n-gram tokens up to a specified length and prepares for enrichment.
  """

  alias Core.Token

  @max_ngram_length 3

  @doc """
  Takes a raw sentence and returns a list of n-gram `%Token{}` structs.
  """
  def resolve_phrases(sentence) when is_binary(sentence) do
    sentence
    |> clean()
    |> build_ngrams()
  end

  @doc """
  Breaks a phrase into all smaller sub-phrases of two or more words.
  """
  def fragment_phrases(phrase) when is_binary(phrase) do
    words = String.split(phrase)

    2..(length(words))
    |> Enum.flat_map(fn size ->
      Enum.chunk_every(words, size, 1, :discard)
      |> Enum.map(&Enum.join(&1, " "))
    end)
    |> Enum.uniq()
  end

  # -- PRIVATE FUNCTIONS --

  defp clean(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, "")
    |> String.trim()
  end

  defp build_ngrams(sentence) do
    words = String.split(sentence, " ", trim: true)
    max_len = min(@max_ngram_length, length(words))

    1..max_len
    |> Enum.reverse()
    |> Enum.flat_map(&build_phrases(words, &1))
    |> Enum.uniq_by(& &1.phrase)
  end

defp build_phrases(words, n) do
  Enum.chunk_every(words, n, 1, :discard)
  |> Enum.with_index()
  |> Enum.map(fn {chunk, index} ->
    %Token{
      phrase: Enum.join(chunk, " "),
      index: index
    }
  end)
end


end

