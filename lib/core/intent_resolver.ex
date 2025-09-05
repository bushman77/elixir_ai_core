defmodule Core.IntentResolver do
  @moduledoc """
  Classifier fast-path + profanity short-circuit + matrix fallback.
  Matrix is only used to upgrade low-confidence results.
  Adds speech-act annotation and a procedure-request fallback for 'how' questions.
  """

  alias Core.{IntentMatrix, SemanticInput, Profanity, SpeechAct, ProcedureRequest}
  alias MoodCore
  alias Core.IntentPOSProfile, as: POSIntentProfile
  alias FRP.Features, as: Features

  @fallback_threshold Application.compile_env(:elixir_ai_core, :fallback_threshold, 0.55)
  @default_confidence 0.0
  @pos_boost 0.20
  @min_conf  0.35

  @spec resolve_intent(SemanticInput.t()) :: SemanticInput.t()
  def resolve_intent(%SemanticInput{} = sem) do
    sem
    |> maybe_handle_profanity()
    |> maybe_annotate_speech_act()          # NEW: form (question/elliptical/etc.)
    |> maybe_keep_classifier_result()
    |> resolve_with_matrix_if_needed()
    |> maybe_procedure_request_fallback()   # NEW: meaning (procedure request) + slots
    |> refine_with_pos_profiles()
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

  # ---------- NEW: speech-act (form) ----------

  defp maybe_annotate_speech_act(%SemanticInput{} = sem) do
    text = sem.sentence || sem.original_sentence || ""
    {sa, kind} = SpeechAct.annotate(text)
    %{sem | speech_act: sa, question_kind: kind}
  end

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

  # ---------- NEW: procedure-request fallback (meaning) ----------

  # Fires when it's a question AND either intent is unknown or confidence is weak.
  defp maybe_procedure_request_fallback(%SemanticInput{} = sem) do
    weak? =
      (sem.intent in [nil, :unknown]) or
        (is_number(sem.confidence) and sem.confidence < @fallback_threshold)

    if sem.speech_act == :question and weak? do
      text = sem.sentence || sem.original_sentence || ""

      case ProcedureRequest.extract(text) do
        {:ok, task} ->
          %{
            sem
            | intent: :procedure_request,
              keyword: choose_keyword(task, sem.keyword),
              confidence: max(sem.confidence || 0.0, 0.72),
              pattern_roles: Map.put(sem.pattern_roles || %{}, :act, task),
              source: sem.source || :heuristic
          }

        :nomatch ->
          sem
      end
    else
      sem
    end
  end

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

  # ---------- POS-based refinement (keep your existing version) ----------

  # Pipe-friendly: takes a SemanticInput, returns a refined SemanticInput
  def refine_with_pos_profiles(%{pos_list: pos_list} = sem) when is_list(pos_list) do
    # If no POS info, no-op
    if Enum.all?(pos_list, fn x -> x in [nil, []] end) do
      sem
    else
      # Use the same histogram/order as FRP.Features to avoid drift
      pos_hist = Features.pos_hist(pos_list)

      intents = POSIntentProfile.intents()

      {best_intent, best_sim} =
        intents
        |> Enum.map(&{&1, POSIntentProfile.score(pos_hist, &1)})
        |> Enum.max_by(fn {_i, s} -> s end, fn -> {:unknown, 0.0} end)

      current = normalize_intent(sem.intent)

      sem2 =
        cond do
          (current in [nil, :unknown]) and best_sim > 0.5 ->
            %{sem | intent: best_intent, source: :pos_refine, confidence: max(best_sim, sem.confidence || 0.0)}

          (sem.confidence || 0.0) < @min_conf ->
            blended = min(1.0, (sem.confidence || 0.0) * (1.0 - @pos_boost) + best_sim * @pos_boost)
            %{sem | intent: best_intent, source: :pos_refine, confidence: blended}

          true ->
            nudged = min(1.0, (sem.confidence || 0.0) + @pos_boost * best_sim * 0.5)
            %{sem | confidence: nudged, intent: current}
        end

      # Online update the prototype (EMA)
      POSIntentProfile.observe(sem2.intent, pos_hist)
      sem2
    end
  end

  def refine_with_pos_profiles(sem), do: sem

  defp normalize_intent(:greet), do: :greeting
  defp normalize_intent(x) when is_atom(x), do: x
  defp normalize_intent(_), do: :unknown

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

