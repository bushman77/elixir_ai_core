defmodule Core.Tokenizer do
  alias Brain

  @max_ngram_length 3

  @doc """
  Tokenizes a sentence into phrases and words by
  generating n-grams and resolving known BrainCells.
  """
  def tokenize(sentence) when is_binary(sentence) do
    sentence
    |> clean()
    |> generate_ngrams()
    |> resolve_known_phrases()
  end

  defp clean(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, "")
    |> String.trim()
  end

  defp generate_ngrams(sentence) do
    words = String.split(sentence, " ", trim: true)
    max_len = min(@max_ngram_length, length(words))
    for n <- Enum.reverse(1..max_len), reduce: [] do
      acc ->
        acc ++ ngrams(words, n)
    end
    |> Enum.uniq()
  end

  defp ngrams(words, n) when n > 0 do
    Enum.chunk_every(words, n, 1, :discard)
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp resolve_known_phrases(ngrams) do
    # This returns a deduplicated list of BrainCells
    ngrams
    |> Enum.reduce({[], MapSet.new()}, fn phrase, {acc, seen} ->
      if MapSet.member?(seen, phrase) do
        {acc, seen}
      else
        case Brain.get_or_start(phrase) || Brain.load(phrase) do
          %BrainCell{} = cell ->
            {[cell | acc], MapSet.put(seen, phrase)}

          _ ->
            {acc, seen}
        end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end

