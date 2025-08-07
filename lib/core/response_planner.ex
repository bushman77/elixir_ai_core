defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on SemanticInput (intent, keyword, confidence, mood, cell).
  """

  alias Core.{MemoryCore, SemanticInput}
  alias BrainCell
  alias PhraseGenerator

  @high_confidence 0.6
  @low_confidence  0.3

  @greeting_msgs [
    "Hey there! 👋 How can I assist you today?",
    "Hello! What can I do for you?",
    "Hi there! How’s it going?"
  ]

  @clarify_msg "Hmm… I didn’t quite understand that."

  @farewell_msg "Goodbye for now. Take care!"

  # Public API
  @doc "Attach a `response` to the SemanticInput based on its fields."
  @spec analyze(SemanticInput.t()) :: SemanticInput.t()
  def analyze(%SemanticInput{} = sem) do
    response = plan(sem)
    %{sem | response: response}
  end

  #— Core dispatch

  # 1) If a BrainCell is attached, use that for context-rich replies
  defp plan(%SemanticInput{cell: %BrainCell{} = cell} = sem) do
    plan_by_cell(sem.intent, sem.confidence, sem.keyword, cell, sem.mood)
  end

  # 2) If only a keyword is present, try question/legacy fallback
  defp plan(%SemanticInput{keyword: kw} = sem) when not is_nil(kw) do
    plan_by_keyword(sem.intent, sem.confidence, kw)
  end

  # 3) Pure intent-based defaults
  defp plan(%SemanticInput{intent: :greeting} = sem) do
    Enum.random(@greeting_msgs)
  end

  defp plan(%SemanticInput{intent: :farewell}), do: @farewell_msg

  # 4) Low-confidence or unknown
  defp plan(%SemanticInput{confidence: conf}) when conf <= 0.0, do: @clarify_msg
  defp plan(_), do: @clarify_msg

  #— Helpers for cell-based planning

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

  # Generic fallback for other cell-based intents
  defp plan_by_cell(intent, _conf, _kw, %BrainCell{word: w}, _mood) do
    "I see intent `#{intent}` around '#{w}', but I'm not ready for that yet."
  end

  #— Helpers for keyword-only planning

  defp plan_by_keyword(:question, conf, "why") when conf >= @high_confidence do
    "Why questions are my favorite! Let’s explore."
  end

  defp plan_by_keyword(:question, conf, "how") when conf >= @low_confidence do
    "How things work can be fascinating — what specifically?"
  end

  defp plan_by_keyword(:question, _, "what") do
    "What would you like to explore more?"
  end

  defp plan_by_keyword(:question, conf, kw) when conf < @low_confidence do
    "I think you're asking about \"#{kw}\", but could you clarify?"
  end

  defp plan_by_keyword(:question, _conf, kw) do
    "Great question about \"#{kw}\". Let me try to help!"
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

