defmodule Core.MultiwordMatcher do
  alias Core.MultiwordPOS

  def merge_multiwords(tokens) do
    words = Enum.map(tokens, & &1.word)
    merge_recursive(words, 0, [], words)
  end

  defp merge_recursive(words, index, acc, all_words) when index >= length(all_words), do: Enum.reverse(acc)

  defp merge_recursive(words, index, acc, all_words) do
    word = Enum.at(all_words, index)

    matches =
      MultiwordPOS.phrases()
      |> Enum.filter(fn phrase -> String.starts_with?(phrase, word) end)

    found =
      Enum.find(matches, fn phrase ->
        phrase_words = String.split(phrase, " ")
        slice = Enum.slice(all_words, index, length(phrase_words))
        slice == phrase_words
      end)

    if found do
      type = MultiwordPOS.lookup(found)
      token = %{word: found, pos: [type]}
      skip = length(String.split(found, " ")) - 1
      merge_recursive(words, index + skip + 1, [token | acc], all_words)
    else
      merge_recursive(words, index + 1, [%{word: word, pos: [:unknown]} | acc], all_words)
    end
  end
end

