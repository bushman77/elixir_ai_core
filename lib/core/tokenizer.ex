defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizer that merges known multiword phrases and generates token structs
  with position and source metadata. Accepts either a raw sentence or a
  %Core.SemanticInput{}.
  """

  alias Core.{Token, SemanticInput}
  alias Core.MultiwordMatcher
  alias Brain

  # — Public API —

  @doc """
  Tokenizes a %SemanticInput{} in place.
  """
  @spec tokenize(SemanticInput.t()) :: SemanticInput.t()
  def tokenize(%SemanticInput{sentence: s} = input) when is_binary(s) do
    {tokens, token_structs} = do_tokenize(s, input.source || :user)

    # Optional: only activate when source is :user (keeps tests/systems quieter)
    if (input.source || :user) == :user do
      Enum.each(token_structs, fn t -> Brain.get_or_start(t.phrase) end)
    end

    %SemanticInput{input | tokens: tokens, token_structs: token_structs}
  end

  @doc """
  Tokenizes a raw sentence string and returns a fresh %SemanticInput{}.
  """
  @spec tokenize(binary()) :: SemanticInput.t()
  def tokenize(sentence) when is_binary(sentence) do
    {tokens, token_structs} = do_tokenize(sentence, :user)

    # Activate braincells for now (matches your current behavior)
    Enum.each(token_structs, fn t -> Brain.get_or_start(t.phrase) end)

    %SemanticInput{
      sentence: sentence,
      source: :user,
      tokens: tokens,
      token_structs: token_structs
    }
  end

  # — Internal —

  defp do_tokenize(sentence, source) do
    phrase_list =
      MultiwordMatcher.get_phrases()
      |> Enum.map(&String.downcase/1)

    words =
      sentence
      |> normalize_text()
      |> String.split(~r/\s+/, trim: true)

    merged = merge_phrases(words, phrase_list)

    token_structs =
      merged
      |> Enum.with_index()
      |> Enum.map(fn {phrase, index} ->
        %Token{
          phrase: phrase,
          text: phrase,
          position: index,
          source: source,
          pos: [] # filled by POSEngine later
        }
      end)

    {Enum.map(token_structs, & &1.phrase), token_structs}
  end

  defp normalize_text(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s\?]/u, "") # keep letters/numbers/space/? (optional)
    |> String.trim()
  end

  # Recursive phrase merger
  defp merge_phrases(words, phrases), do: do_merge_phrases(words, phrases, [])

  defp do_merge_phrases([], _phrases, acc), do: Enum.reverse(acc)

  defp do_merge_phrases(words, phrases, acc) do
    match =
      Enum.find(phrases, fn phrase ->
        phrase_words = String.split(phrase, ~r/\s+/, trim: true)
        Enum.take(words, length(phrase_words)) == phrase_words
      end)

    case match do
      nil ->
        [head | tail] = words
        do_merge_phrases(tail, phrases, [head | acc])

      matched_phrase ->
        skip_count = matched_phrase |> String.split(~r/\s+/, trim: true) |> length()
        rest = Enum.drop(words, skip_count)
        do_merge_phrases(rest, phrases, [matched_phrase | acc])
    end
  end
end

