defmodule POSTagger do
  @moduledoc """
  Dynamic Part-of-Speech tagger using WordNet DETS with suffix fallback.
  """

  @fallback_pos_exceptions %{
    "be" => :verb,
    "is" => :verb,
    "are" => :verb,
    "was" => :verb,
    "were" => :verb
  }

  def tag_word(word) do
    case Core.lookup_input(word) do
      %{} = result ->
        case result[word] do
          [%{synsets: [%{pos: pos} | _]} | _] ->
            pos_code_to_tag(pos)

          _ ->
            fallback_tag(word)
        end

      _ ->
        fallback_tag(word)
    end
  end

  defp pos_code_to_tag("n"), do: :noun
  defp pos_code_to_tag("v"), do: :verb
  defp pos_code_to_tag("a"), do: :adjective
  defp pos_code_to_tag("r"), do: :adverb
  defp pos_code_to_tag("c"), do: :conjunction
  defp pos_code_to_tag("i"), do: :interjection
  defp pos_code_to_tag(_), do: :unknown

  defp fallback_tag(word) do
    cond do
      Map.has_key?(@fallback_pos_exceptions, word) -> @fallback_pos_exceptions[word]
      String.ends_with?(word, "ing") -> :verb
      String.ends_with?(word, "ed") -> :verb
      String.ends_with?(word, "ly") -> :adverb
      String.ends_with?(word, "ion") -> :noun
      String.ends_with?(word, "ness") -> :noun
      true -> :unknown
    end
  end

  def tag_sentence(sentence) when is_binary(sentence) do
    sentence
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.map(fn word -> {word, tag_word(word)} end)
  end
end
