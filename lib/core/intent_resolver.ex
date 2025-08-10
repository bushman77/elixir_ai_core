defmodule Core.IntentResolver do
  @moduledoc """
  Classifier fast-path + profanity short-circuit + matrix fallback.
  Matrix is only used to upgrade low-confidence results.
  """

  alias Core.{IntentMatrix, SemanticInput, Profanity}
  alias MoodCore

  @fallback_threshold Application.compile_env(:elixir_ai_core, :fallback_threshold, 0.55)
  @default_confidence 0.0

  @spec resolve_intent(SemanticInput.t()) :: SemanticInput.t()
  def resolve_intent(%SemanticInput{} = sem) do
    sem
    |> maybe_handle_profanity()
    |> maybe_keep_classifier_result()
    |> resolve_with_matrix_if_needed()
    |> maybe_reinforce_positive()
  end

  # ---------- profanity short-circuit ----------

  defp maybe_handle_profanity(%SemanticInput{sentence: s} = sem) when is_binary(s) do
    if Profanity.hit?(s) do
      try do
        MoodCore.apply(:negative, amount: 0.4, ttl: 90_000)
      rescue
        _ -> :ok
      end

      %{sem | intent: :insult, keyword: nil, confidence: 1.0, source: :filter}
    else
      sem
    end
  end

  defp maybe_handle_profanity(sem), do: sem

  # ---------- keep strong classifier results ----------

  defp maybe_keep_classifier_result(%SemanticInput{intent: i, confidence: c} = sem)
       when i not in [nil, :unknown] and is_number(c) and c >= @fallback_threshold do
    %{sem | source: :classifier}
  end

  defp maybe_keep_classifier_result(sem), do: sem

  # ---------- matrix fallback (upgrade-only) ----------

  # preserve profanity/classifier decisions
  defp resolve_with_matrix_if_needed(%SemanticInput{source: s} = sem)
       when s in [:classifier, :filter],
       do: sem

  defp resolve_with_matrix_if_needed(%SemanticInput{token_structs: tokens} = sem)
       when is_list(tokens) and tokens != [] do
    case normalize_matrix(IntentMatrix.classify(tokens)) do
      {:unknown, _conf, _kw, _src} ->
        sem

      {intent, conf, kw, src} ->
        if better?(conf, sem.confidence) do
          %SemanticInput{
            sem
            | intent: intent,
              confidence: conf,
              keyword: choose_keyword(kw, sem.keyword),
              source: src || :matrix
          }
        else
          sem
        end
    end
  end

  defp resolve_with_matrix_if_needed(%SemanticInput{} = sem), do: sem

  # ---------- positive reinforcement on clear greetings/thanks ----------

  defp maybe_reinforce_positive(%SemanticInput{intent: intent, confidence: c} = sem)
       when intent in [:greeting, :thank] and is_number(c) and c >= 0.8 do
    try do
      MoodCore.apply(:positive, amount: 0.25, ttl: 20_000)
    rescue
      _ -> :ok
    end

    sem
  end

  defp maybe_reinforce_positive(sem), do: sem

  # ---------- helpers ----------

  defp better?(new, old) when is_number(new) and is_number(old), do: new > old
  defp better?(new, nil) when is_number(new), do: true
  defp better?(_new, _old), do: false

  defp choose_keyword(nil, existing), do: existing
  defp choose_keyword("", existing),  do: existing
  defp choose_keyword(new, _),        do: new

  # Accept {intent, conf}, %{intent:, confidence:|score:}, or atom
  defp normalize_matrix({intent, conf}) when is_atom(intent) and is_number(conf),
    do: {intent, conf, nil, :matrix}

  defp normalize_matrix(%{intent: i, confidence: c} = m) when is_atom(i) and is_number(c),
    do: {i, c, Map.get(m, :keyword), Map.get(m, :source, :matrix)}

  defp normalize_matrix(%{intent: i, score: c} = m) when is_atom(i) and is_number(c),
    do: {i, c, Map.get(m, :keyword), Map.get(m, :source, :matrix)}

  defp normalize_matrix(intent) when is_atom(intent),
    do: {intent, 0.6, nil, :matrix}

  defp normalize_matrix(_), do: {:unknown, @default_confidence, nil, :matrix}
end

