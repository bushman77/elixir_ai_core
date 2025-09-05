defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on SemanticInput (intent, keyword, confidence, mood, cell).
  Adds a high-confidence 'grump' override using ML.GrumpModel for insults.
  """

  alias Core.{MemoryCore, SemanticInput}
  alias ML.GrumpModel
  alias BrainCell
  alias PhraseGenerator
  alias MoodCore

  @high_confidence 0.6
  @low_confidence  0.3

  # Grump override settings
  @grump_threshold 0.75  # was 0.85 — a touch more permissive

  # keep this light; avoid anything sensitive
  @mild_insult_regex ~r/\b(heck|darn|poo|poopy|noob|clown|loser|dummy|idiot|stupid)\b/i

  # Strong, morphology-tolerant apology matcher
  @apology_regex ~r/
    \b(?:sorry)\b
    | \bmy\s+(?:bad|apolog(?:y|ies))\b
    | \b(?:excuse|pardon)[\s,.\-]*me\b
    | \bapolog(?:y|ies|etic|etically)\b
    | \bapologi[sz](?:e|ed|es|ing)\b
  /ix

  # Trust IntentMatrix when it emits :apology above this confidence
  @apology_conf 0.55

  @grump_blocklist ~w(race religion gender sexuality slur slurs hate violent kill die nazi)

  @greeting_msgs [
    "Hey there! 👋 How can I assist you today?",
    "Hello! What can I do for you?",
    "Hi there! How’s it going?"
  ]

  @greeting_neutral [
    "Hey there! 👋 How can I assist you today?",
    "Hello! What can I do for you?",
    "Hi there! How’s it going?"
  ]

  @greeting_positive [
    "Hey hey! Great to see you 🙌",
    "Hello! I’m pumped to help today!",
    "Hi! Ready when you are 😄"
  ]

  @greeting_calm [
    "Hello there.",
    "Hi. How can I help?",
    "Hey—what would you like to do next?"
  ]

  @greeting_grumpy [
    "Yeah… what do you want?",
    "Hi. Let’s just get this over with.",
    "Oh, it’s you. What now?"
  ]

  @clarify_msg  "Hmm… I didn’t quite understand that."
  @farewell_msg "Goodbye for now. Take care!"

  # Mood-aware boundaries for insults
  @gentle_boundaries [
    "Let’s keep it respectful. I’m here to help.",
    "I get that you’re upset. I’ll help, but let’s keep the language clean.",
    "I’m listening—please avoid insults so we can solve this."
  ]
  @firm_boundaries [
    "That crosses a line. If you want help, drop the insults.",
    "Not okay. I’ll continue when we’re respectful.",
    "We can proceed, but not with that language."
  ]
  @snarky_boundaries [
    "Bold strategy. How about we try respect instead?",
    "Sure. And now, anything useful you actually need?",
    "If venting’s done, we can solve your problem."
  ]

  @doc "Attach a `response` and a tiny trace to the SemanticInput based on its fields."
  @spec analyze(SemanticInput.t()) :: SemanticInput.t()
  def analyze(%SemanticInput{} = sem) do
    sem = %{sem | intent: normalize_intent(sem.intent)}

    response = plan(sem)
    dbg = Process.get(:planner_dbg) || %{}   # ← pull debug from plan/1

    trace =
      %{
        intent: sem.intent,
        kw: sem.keyword,
        conf: sem.confidence,
        mood: sem.mood
      }
      |> Map.merge(dbg)

    %{sem | response: response, planned_response: response, activation_summary: trace}
  end

  # ---------- Intent normalization ----------
  defp normalize_intent(i) do
    case i do
      :greet    -> :greeting
      :bye      -> :farewell
      :thanks   -> :thank
      :insult   -> :insult
      :question -> :question
      :command  -> :command
      :confirm  -> :confirm
      :deny     -> :deny
      :inform   -> :inform
      :why      -> :why
      other     -> other || :unknown
    end
  end

  # ---------- Act normalization for procedure recipes ----------
  defp normalize_act(act0) do
    act0
    |> String.downcase()
    |> String.replace(~r/\b(my|our|your)\b/, "")            # drop pronouns
    |> String.replace(~r/\b(to|do|does|did|can|could|should|would|will)\b/, "") # drop aux/fillers
    |> String.replace(~r/[^\w\s]/, " ")                    # drop punctuation to spaces (safety)
    |> String.replace(~r/\s+/, " ")                        # squish multiple spaces → one
    |> String.trim()
  end

  defp key_for_recipe(act0) do
    case normalize_act(act0) do
      "brush teeth" -> "brush teeth"
      # Add more aliases as you grow recipes:
      # "wash hands" -> "wash hands"
      # "tie shoes"  -> "tie shoes"
      other -> other
    end
  end

  # ---------- Helpers: apology & grump gating ----------

  # Prefer IntentMatrix signal when present; otherwise regex fallback
  defp apology?(%SemanticInput{intent: :apology, confidence: c}) when is_number(c),
    do: c >= @apology_conf
  defp apology?(%SemanticInput{sentence: s}) when is_binary(s),
    do: Regex.match?(@apology_regex, s)
  defp apology?(_), do: false

  # Are we inside the forgiveness window?
  defp forgiven?(),
    do: (Process.get(:forgive_until) || 0) > System.monotonic_time(:millisecond)

  # Treat these as benign; don't let a noisy model hijack them.
  defp benign_intent?(i),
    do: i in [:procedure_request, :question, :inform, :thank, :greeting, :farewell, :confirm, :deny, :define, :why, :apology]

  defp should_use_grump?(intent, safe, label, conf, mild_hit) do
    cond do
      # Always allow boundaries if we see explicit insult tokens.
      mild_hit ->
        safe

      # For benign intents, ignore model-only "insult" predictions (reduce false positives).
      benign_intent?(intent) ->
        false

      # Otherwise, require confident insult + safety.
      true ->
        safe and (label == "insult" and conf >= @grump_threshold)
    end
  end

  # Top-level planner:
  # Order: apology → (conditional) grump override → core flow
  defp plan(%SemanticInput{sentence: s, mood: mood} = sem) when is_binary(s) do
    # default debug
    dbg = %{path: :core, grump_label: nil, grump_conf: nil, mild_hit: false, safe: true}
    Process.put(:planner_dbg, dbg)

    # Apology short-circuit (matrix or regex)
    if apology?(sem) do
      Process.put(:planner_dbg, Map.merge(dbg, %{path: :apology}))
      return_apology_reply(mood)
    else
      {label, conf} = GrumpModel.predict(s)
      safe     = safe_for_grump?(s)
      mild_hit = Regex.match?(@mild_insult_regex, s)

      apply_grump? = should_use_grump?(sem.intent, safe, label, conf, mild_hit)

      # Forgiveness window (skip grump replies for a short time after an apology)
      forgiven = forgiven?()
      apply_grump? = apply_grump? and not forgiven

      Process.put(:planner_dbg,
        %{
          path: (apply_grump? && :grump_reply) || :core,
          grump_label: label,
          grump_conf: conf,
          mild_hit: mild_hit,
          safe: safe,
          benign_intent: benign_intent?(sem.intent),
          forgiven?: forgiven
        }
      )

      if apply_grump? do
        case mood do
          :grumpy   -> Enum.random(@snarky_boundaries)
          :negative -> Enum.random(@firm_boundaries)
          _         -> Enum.random(@gentle_boundaries)
        end
      else
        plan_core(sem)
      end
    end
  end

  defp plan(sem), do: plan_core(sem)  # no sentence

  # After an apology, cool down mood and set a short forgiveness window
  defp return_apology_reply(mood) do
    # Actively cool down mood (best-effort; ignore if MoodCore isn't available)
    try do
      MoodCore.apply(:positive, amount: 0.35, ttl: 30_000)
    rescue
      _ -> :ok
    end

    # 20s forgiveness: during this, skip grump/snark
    Process.put(:forgive_until, System.monotonic_time(:millisecond) + 20_000)

    case mood do
      :grumpy   -> "We’re good. Let’s move on. 👍"
      :negative -> "Thanks for saying that. Let’s reset and keep going."
      _         -> "All good! Thanks for the apology—how can I help now?"
    end
  end

  defp maybe_grump(text) do
    {label, conf} = GrumpModel.predict(text)
    if label == "insult", do: {:insult, conf}, else: :neutral
  end

  defp safe_for_grump?(text) do
    down = String.downcase(text)
    not Enum.any?(@grump_blocklist, &String.contains?(down, &1))
  end

  # ---------- Core flow (plan_core/*) ----------

  # 0) Explicit apology intent even without sentence (e.g., upstream routed)
  defp plan_core(%SemanticInput{intent: :apology, mood: mood}), do: return_apology_reply(mood)

  # 1) If a BrainCell is attached, use that for context-rich replies
  defp plan_core(%SemanticInput{cell: %BrainCell{} = cell} = sem) do
    plan_by_cell(sem.intent, sem.confidence, sem.keyword, cell, sem.mood)
  end

  # 2) Explicit intents (before keyword fallback)

  # procedure requests (“how to…”, “how do we…”) → numbered steps
  defp plan_core(%SemanticInput{intent: :procedure_request} = si) do
    act   = Map.get(si.pattern_roles || %{}, :act) || si.keyword || "the task"
    steps = steps_for(act)
    render_steps(act, steps)
  end

  defp plan_core(%SemanticInput{intent: :greeting, mood: mood, confidence: conf}) do
    # Prefer friendly tone if we're inside forgiveness window
    if forgiven?() do
      # After an apology → lean overtly friendly to reinforce the reset
      Enum.random(@greeting_positive)
    else
      cond do
        mood == :grumpy ->
          if conf >= @high_confidence and :rand.uniform() < 0.2,
            do: Enum.random(@greeting_calm),
            else: Enum.random(@greeting_grumpy)

        mood == :positive ->
          Enum.random(@greeting_positive)

        mood == :calm ->
          Enum.random(@greeting_calm)

        true ->
          Enum.random(@greeting_neutral)
      end
    end
  end

  defp plan_core(%SemanticInput{intent: :farewell}), do: @farewell_msg

  defp plan_core(%SemanticInput{intent: :insult, mood: mood}) do
    if forgiven?() do
      # We just accepted an apology — keep it de-escalated
      "We just reset—let’s keep it productive. How can I help?"
    else
      case mood do
        :grumpy   -> Enum.random(@snarky_boundaries)
        :negative -> Enum.random(@firm_boundaries)
        _         -> Enum.random(@gentle_boundaries)
      end
    end
  end

  defp plan_core(%SemanticInput{intent: :thank, confidence: conf}) do
    if conf >= @low_confidence,
      do: "You're welcome! Anything else you need?",
      else: "I think you’re thanking me—happy to help!"
  end

  defp plan_core(%SemanticInput{intent: :confirm, confidence: conf}) do
    if conf >= @low_confidence,
      do: "Great—I'll proceed.",
      else: "Sounds like a yes—should I go ahead?"
  end

  defp plan_core(%SemanticInput{intent: :deny, confidence: conf}) do
    if conf >= @low_confidence,
      do: "No problem. I won’t do that.",
      else: "Got it—do you want something else instead?"
  end

  defp plan_core(%SemanticInput{intent: :command, keyword: kw, confidence: conf}) do
    cond do
      conf < @low_confidence ->
        "I think you're asking me to do something#{if kw, do: " with \"#{kw}\""}—mind clarifying?"

      kw ->
        "Okay, acting on \"#{kw}\"."

      true ->
        "Okay—what exactly should I do?"
    end
  end

  defp plan_core(%SemanticInput{intent: :inform, keyword: kw, confidence: conf}) do
    if conf >= @low_confidence and kw do
      "Thanks for the info about \"#{kw}\". Want me to log or use that?"
    else
      "Thanks for the update. Should I save this?"
    end
  end

  defp plan_core(%SemanticInput{intent: :why, confidence: conf, keyword: kw}) do
    msg =
      if conf >= @high_confidence, do: "Why is a great question.", else: "I think you’re asking why."

    msg <>
      case kw do
        nil -> " Can you tell me which part you’re curious about?"
        k   -> " Let’s dig into why around \"#{k}\"—what angle interests you?"
      end
  end

  defp plan_core(%SemanticInput{intent: :question, keyword: kw, confidence: conf}) do
    cond do
      conf >= @high_confidence and kw in ["time", "price", "weather"] ->
        "Great question about \"#{kw}\". I can help with that."

      conf >= @low_confidence and kw ->
        "Good question about \"#{kw}\"—tell me a bit more."

      conf < @low_confidence and kw ->
        "I think you're asking about \"#{kw}\"—could you clarify?"

      true ->
        "Happy to help—what exactly are you asking?"
    end
  end

  # 3) Keyword-based generic fallback (after explicit handlers)
  defp plan_core(%SemanticInput{keyword: kw} = _sem) when not is_nil(kw) do
    plan_by_keyword(_sem.intent, _sem.confidence, kw)
  end

  # 4) Low-confidence or unknown
  defp plan_core(%SemanticInput{confidence: conf}) when conf <= 0.0, do: @clarify_msg
  defp plan_core(_), do: @clarify_msg

  # ---------- Cell-based planning helpers (kept intact) ----------

  defp plan_by_cell(:greeting, conf, _kw, _cell, _mood) when conf >= @high_confidence do
    Enum.random(@greeting_msgs)
  end

  defp plan_by_cell(:farewell, conf, _kw, _cell, _mood) when conf >= @low_confidence do
    @farewell_msg
  end

  defp plan_by_cell(:define, _conf, _kw, %BrainCell{word: w, definition: d}, _mood) do
    "#{w}: #{d}"
  end

  defp plan_by_cell(:reflect, _conf, _kw, %BrainCell{word: w}, :reflective) do
    phrase = PhraseGenerator.generate_phrase(w, mood: :reflective)
    "Hmm… #{w} makes me think of: #{phrase}"
  end

  defp plan_by_cell(:recall, _conf, _kw, %BrainCell{word: w}, :nostalgic) do
    phrase = PhraseGenerator.generate_phrase(w, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  defp plan_by_cell(:unknown, _conf, _kw, %BrainCell{word: w}, _mood) do
    phrase = PhraseGenerator.generate_phrase(w, mood: :curious)
    "I'm not quite sure about that… but '#{w}' brings to mind: #{phrase}"
  end

  defp plan_by_cell(:insult, _conf, _kw, _cell, :grumpy) do
    Enum.random([
      "Watch your language. 😠",
      "That's uncalled for.",
      "Easy there, no need for that."
    ])
  end

  defp plan_by_cell(:insult, _conf, _kw, _cell, _mood) do
    "That wasn't very nice."
  end

  # ---------- Keyword-only planning ----------
  defp plan_by_keyword(:greeting, _conf, _kw),
    do: Enum.random(@greeting_msgs)

  defp plan_by_keyword(:question, conf, kw) do
    cond do
      conf >= @high_confidence and kw in ["why", "how", "what"] ->
        "Let’s explore #{kw}—what specifically?"

      conf >= @low_confidence ->
        "Great question about \"#{kw}\". Want a quick overview or details?"

      true ->
        "I think you're asking about \"#{kw}\"—could you clarify?"
    end
  end

  defp plan_by_keyword(intent, conf, kw) when conf < @low_confidence do
    "I noticed `#{intent}` and keyword `#{kw}`, but I'm not sure. Can you clarify?"
  end

  defp plan_by_keyword(intent, _conf, kw) do
    case MemoryCore.recent(1) do
      [%{intent: last_intent, keyword: last_kw}] ->
        cond do
          last_intent == intent ->
            "You're still on \"#{kw}\" — let's keep going."

          last_kw == kw ->
            "You brought up \"#{kw}\" again — here's another angle."

          true ->
            generic_keyword_fallback(intent, kw)
        end

      _ ->
        generic_keyword_fallback(intent, kw)
    end
  end

  defp generic_keyword_fallback(intent, kw) do
    "I saw intent `#{intent}` and keyword `#{kw}`, but couldn't handle that combo yet."
  end

  # ---------- Minimal steps renderer (kept local to this file) ----------
  defp steps_for(act0) do
    case key_for_recipe(act0) do
      "brush teeth" ->
        [
          "Grab a soft-bristled toothbrush and fluoride toothpaste.",
          "Wet the bristles and apply a pea-sized amount of toothpaste.",
          "Angle the brush ~45° to the gumline; use gentle, small circles.",
          "Spend ~30s per quadrant (≈2 minutes total): outer, inner, chewing surfaces.",
          "Gently brush the tongue and roof of the mouth.",
          "Spit; avoid heavy rinsing so a thin fluoride film remains.",
          "Rinse the brush and let it air-dry. Floss once per day."
        ]

      _other ->
        [
          "Gather what you need for #{act0}.",
          "Prepare the space/tools; remove blockers.",
          "Do the main action in small, controlled steps.",
          "Check the result; repeat or adjust as needed.",
          "Clean up and store tools for next time."
        ]
    end
  end

  defp render_steps(act, steps) do
    header = "Here’s a simple way to #{String.replace_leading(String.trim(act), "to ", "")}:"
    numbered =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {s, i} -> "#{i}. #{s}" end)
      |> Enum.join("\n")

    header <> "\n\n" <> numbered
  end
end

