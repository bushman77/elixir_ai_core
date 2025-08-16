defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on SemanticInput (intent, keyword, confidence, mood, cell).
  Adds a high-confidence 'grump' override using ML.GrumpModel for insults.
  """

  alias Core.{MemoryCore, SemanticInput}
  alias ML.GrumpModel
  alias BrainCell
  alias PhraseGenerator

  @high_confidence 0.6
  @low_confidence  0.3

  # Grump override settings
  @grump_threshold 0.75  # was 0.85 — a touch more permissive

  # keep this light; avoid anything sensitive
  @mild_insult_regex ~r/\b(heck|darn|poo|poopy|noob|clown|loser|dummy|idiot|stupid)\b/i
  @apology_regex      ~r/\b(sorry|my\s+bad|apolog(?:y|ize|ising|izing))\b/i
  
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

  @clarify_msg "Hmm… I didn’t quite understand that."
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

  trace = %{
    intent: sem.intent,
    kw: sem.keyword,
    conf: sem.confidence,
    mood: sem.mood
  } |> Map.merge(dbg)

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

  # ---------- Grump override → Core fallback ----------

  # Top-level planner:
# Order: apology → grump override → core flow
defp plan(%SemanticInput{sentence: s, mood: mood} = sem) when is_binary(s) do
  # default debug
  dbg = %{path: :core, grump_label: nil, grump_conf: nil, mild_hit: false, safe: true}
  Process.put(:planner_dbg, dbg)

  # Apology short-circuit
  if Regex.match?(@apology_regex, s) do
    Process.put(:planner_dbg, Map.merge(dbg, %{path: :apology}))
    return_apology_reply(mood)
  else
    {label, conf} = ML.GrumpModel.predict(s)
    safe     = safe_for_grump?(s)
    mild_hit = Regex.match?(@mild_insult_regex, s)

    Process.put(:planner_dbg,
      %{path: :grump_check, grump_label: label, grump_conf: conf, mild_hit: mild_hit, safe: safe})

    if safe and ((label == "insult" and conf >= @grump_threshold) or mild_hit) do
      Process.put(:planner_dbg, Map.merge(Process.get(:planner_dbg), %{path: :grump_reply}))
      case mood do
        :grumpy   -> Enum.random(@snarky_boundaries)
        :negative -> Enum.random(@firm_boundaries)
        _         -> Enum.random(@gentle_boundaries)
      end
    else
      Process.put(:planner_dbg, Map.merge(Process.get(:planner_dbg), %{path: :core}))
      plan_core(sem)
    end
  end
end

defp plan(sem), do: plan_core(sem)  # no sentence

  defp return_apology_reply(mood) do
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

  # ---------- Original flow (moved to plan_core/*) ----------

  # 1) If a BrainCell is attached, use that for context-rich replies
  defp plan_core(%SemanticInput{cell: %BrainCell{} = cell} = sem) do
    plan_by_cell(sem.intent, sem.confidence, sem.keyword, cell, sem.mood)
  end

  # 2) Explicit intents (before keyword fallback)
  defp plan_core(%SemanticInput{intent: :greeting, mood: mood, confidence: conf}) do
    case mood do
      :grumpy ->
        if conf >= @high_confidence and :rand.uniform() < 0.2,
          do: Enum.random(@greeting_calm),
          else: Enum.random(@greeting_grumpy)

      :positive -> Enum.random(@greeting_positive)
      :calm     -> Enum.random(@greeting_calm)
      _         -> Enum.random(@greeting_neutral)
    end
  end

  defp plan_core(%SemanticInput{intent: :farewell}), do: @farewell_msg

  defp plan_core(%SemanticInput{intent: :insult, mood: mood}) do
    case mood do
      :grumpy   -> Enum.random(@snarky_boundaries)
      :negative -> Enum.random(@firm_boundaries)
      _         -> Enum.random(@gentle_boundaries)
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
  defp plan_core(%SemanticInput{keyword: kw} = sem) when not is_nil(kw) do
    plan_by_keyword(sem.intent, sem.confidence, kw)
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
end

