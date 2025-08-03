defmodule Core.Tokenizer do
  alias Core.{Token, SemanticInput}

  def tokenize(%SemanticInput{sentence: sentence} = semantic) do
    phrase_list = Brain.get_all_phrases() |> Enum.map(&String.downcase/1)

    words = sentence
            |> String.downcase()
            |> String.split()

    merged = merge_phrases(words, phrase_list)

    tokens = Enum.with_index(merged, fn phrase, index ->
      %Token{
        phrase: phrase,
        position: index,
        source: :user
      }
    end)

    %{semantic | tokens: Enum.map(tokens, & &1.phrase), token_structs: tokens}
  end

  # merges known phrases, returns ["how are you", "doing"] from ["how", "are", "you", "doing"]
  defp merge_phrases(words, phrases) do
    merge_phrases(words, phrases, [])
  end

  defp merge_phrases([], _phrases, acc), do: Enum.reverse(acc)

  defp merge_phrases(words, phrases, acc) do
    matched =
      Enum.find(phrases, fn phrase ->
        phrase_words = String.split(phrase)
        Enum.take(words, length(phrase_words)) == phrase_words
      end)

    if matched do
      skip = String.split(matched) |> length()
      rest = Enum.drop(words, skip)
      merge_phrases(rest, phrases, [matched | acc])
    else
      [head | tail] = words
      merge_phrases(tail, phrases, [head | acc])
    end
  end
end

