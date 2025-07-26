defmodule Core.Tokenizer do
  @max_ngram_length 3

  def resolve_phrases(sentence) when is_binary(sentence) do
    sentence
    |> clean()
    |> phrase_ngrams()
  end

  defp clean(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, "")
    |> String.trim()
  end

  defp phrase_ngrams(sentence) do
    words = String.split(sentence, " ", trim: true)
    max_len = min(@max_ngram_length, length(words))

    1..max_len
    |> Enum.reverse()
    |> Enum.flat_map(fn n -> build_phrases(words, n) end)
    |> Enum.uniq_by(& &1.phrase)
  end

  defp build_phrases(words, n) do
    Enum.chunk_every(words, n, 1, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      %{phrase: Enum.join(chunk, " "), index: index}
    end)
  end

def fragment_phrases(phrase) do
  words = String.split(phrase)

  # Generate all combinations of 2 or more words
  1..(length(words) - 1)
  |> Enum.flat_map(fn i ->
    Enum.chunk_every(words, i, 1, :discard)
    |> Enum.map(&Enum.join(&1, " "))
  end)
  |> Enum.uniq()
end


end

