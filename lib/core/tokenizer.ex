defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizer that merges known multiword phrases and generates token structs
  with position and source metadata.
  """

  alias Core.{Token, SemanticInput}
  alias Core.MultiwordMatcher
  alias Brain

  @doc """
  Tokenizes a raw sentence string, merges known multiword phrases,
  and returns a new %SemanticInput{} struct.
  """
  def tokenize(sentence) when is_binary(sentence) do
    phrase_list =
      MultiwordMatcher.get_phrases()
      |> Enum.map(&String.downcase/1)

    words =
      sentence
      |> String.downcase()
      |> String.split()

    merged = merge_phrases(words, phrase_list)

    token_structs =
      Enum.with_index(merged, fn phrase, index ->
        %Token{
          phrase: phrase,
          position: index,
          source: :user
        }
      end)

    # Activate braincells for now
    Enum.each(token_structs, fn token ->
      Brain.get_or_start(token.phrase)
    end)

    %SemanticInput{
      sentence: sentence,
      tokens: Enum.map(token_structs, & &1.phrase),
      token_structs: token_structs
    }
  end

  # Recursive phrase merger
  defp merge_phrases(words, phrases), do: do_merge_phrases(words, phrases, [])

  defp do_merge_phrases([], _phrases, acc), do: Enum.reverse(acc)

  defp do_merge_phrases(words, phrases, acc) do
    match =
      Enum.find(phrases, fn phrase ->
        phrase_words = String.split(phrase)
        Enum.take(words, length(phrase_words)) == phrase_words
      end)

    case match do
      nil ->
        [head | tail] = words
        do_merge_phrases(tail, phrases, [head | acc])

      matched_phrase ->
        skip_count = length(String.split(matched_phrase))
        rest = Enum.drop(words, skip_count)
        do_merge_phrases(rest, phrases, [matched_phrase | acc])
    end
  end
end

