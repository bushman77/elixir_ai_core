defmodule VerbIdentifier do
  @doc """
  Given a list of tokens (words), assigns likely POS tags using lexicon and heuristics.
  """
  def tag_verbs(tokens, brain) do
    tokens
    |> Enum.map(fn token ->
      case Brain.lookup_pos(token.word) do
        [:verb | _] -> %{token | pos: :verb}
        _ -> apply_heuristics(token, tokens)
      end
    end)
  end

  defp apply_heuristics(token, context_tokens) do
    if String.ends_with?(token.word, "ing") or String.ends_with?(token.word, "ed") do
      %{token | pos: :verb}
    else
      # Add more heuristic checks here...
      %{token | pos: :unknown}
    end
  end
end

