defmodule LexiconExpander do
  def expand_from_entry(%BrainCell{examples: examples}) do
    examples
    |> Enum.flat_map(&Tokenizer.tokenize/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
    |> Enum.filter(fn word -> not Brain.known_word?(word) end)
    |> Enum.each(fn word -> Brain.enrich_word(word) end)
  end

def expand_with_limit(entry, limit \\ 10) do
  examples = entry.examples || []
  new_words = 
    examples
    |> Enum.flat_map(&Tokenizer.tokenize/1)
    |> Enum.uniq()
    |> Enum.filter(fn w -> not Brain.known_word?(w) end)
    |> Enum.take(limit)

  Enum.each(new_words, &Brain.enrich_word/1)
end

end

