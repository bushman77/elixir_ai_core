defmodule Core.IntentResolver do
  @moduledoc "Classifier fast-path + profanity short-circuit + matrix fallback."
  alias Core.{IntentMatrix, SemanticInput, Profanity}

  @fallback_threshold Application.compile_env(:elixir_ai_core, :fallback_threshold, 1.2)
  @default_confidence 0.0

  @spec resolve_intent(SemanticInput.t()) :: SemanticInput.t()
  def resolve_intent(%SemanticInput{} = sem) do
    sem
    |> maybe_handle_profanity()
    |> maybe_keep_classifier_result()
    |> resolve_with_matrix_if_needed()
 |> maybe_reinforce_positive() 
  end

  defp maybe_handle_profanity(%SemanticInput{sentence: s} = sem) when is_binary(s) do
    if Profanity.hit?(s) do
      # optional mood nudge below in section 3
      MoodCore.apply(:negative, amount: 0.4, ttl: 90_000)
      %{sem | intent: :insult, keyword: nil, confidence: 1.0, source: :filter}
    else
      sem
    end
  end
  defp maybe_handle_profanity(sem), do: sem


# In Core.IntentResolver (right after you keep/resolve intent)
defp maybe_reinforce_positive(%SemanticInput{intent: intent, confidence: c} = sem)
     when intent in [:greeting, :thanks] and c >= 0.8 do
  try do
    MoodCore.apply(:positive, amount: 0.25, ttl: 20_000)  # short upbeat bump
  rescue
    _ -> :ok
  end
  sem
end
defp maybe_reinforce_positive(sem), do: sem


  defp maybe_keep_classifier_result(%SemanticInput{intent: i, confidence: c} = sem)
       when i != :unknown and c >= @fallback_threshold,
       do: %{sem | source: :classifier}
  defp maybe_keep_classifier_result(sem), do: sem

  # Important guard to preserve profanity decision
  defp resolve_with_matrix_if_needed(%SemanticInput{source: s} = sem) when s in [:classifier, :filter], do: sem

  defp resolve_with_matrix_if_needed(%SemanticInput{token_structs: tokens} = sem) do
    case (is_list(tokens) and tokens != [] and IntentMatrix.classify(tokens)) || nil do
      nil ->
        %SemanticInput{sem | intent: :unknown, confidence: @default_confidence, source: :matrix}

      %{intent: intent, score: score, keyword: kw, source: source} ->
        %SemanticInput{
          sem
          | intent: intent,
            confidence: score || @default_confidence,
            keyword: choose_keyword(kw, sem.keyword),
            source: source || :matrix
        }
    end
  end

  defp choose_keyword(nil, existing), do: existing
  defp choose_keyword("", existing), do: existing
  defp choose_keyword(new, _), do: new
end

