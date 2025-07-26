defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on intent, keyword, confidence, and context.
  """

  alias Brain
  alias BrainCell
  alias PhraseGenerator
  alias Core.MemoryCore

  @high 0.6
  @low 0.3

  # === Primary entry point ===
  def plan(%{intent: :greeting, confidence: conf}) when conf >= @high do
    "Hey there! 👋 How can I assist you today?"
  end

  def plan(%{intent: :farewell, confidence: conf}) when conf >= @low do
    "Goodbye for now. Take care out there."
  end

  def plan(%{intent: :question, keyword: word, confidence: conf}) do
    case {word, conf} do
      {"why", c} when c > @high -> "Why questions are my favorite! Let’s explore."
      {"how", c} when c > @low -> "How things work can be fascinating — what specifically?"
      {"what", _} -> "What would you like to explore more?"
      {w, c} when c < @low -> "That sounds like a question about \"#{w}\", but I’m not too sure. Could you clarify?"
      {w, _} -> "Great question on \"#{w}\". Let me try to help!"
    end
  end

  def plan(%{intent: :reflect, keyword: word, confidence: conf}) when conf > @low do
    phrase = PhraseGenerator.generate_phrase(word, mood: :reflective)
    "Hmm… #{word} makes me think of: #{phrase}"
  end

  def plan(%{intent: :recall, keyword: word, confidence: conf}) when conf > @low do
    phrase = PhraseGenerator.generate_phrase(word, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  def plan(%{intent: :define, keyword: word, confidence: conf}) when conf > @low do
    case Brain.get(word) do
      %BrainCell{definition: defn} -> "#{word}: #{defn}"
      _ -> "I haven’t learned that word yet."
    end
  end

  def plan(%{intent: :unknown, keyword: word}) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :curious)
    "I'm not quite sure about that… but '#{word}' brings to mind: #{phrase}"
  end

  # === Context-aware fallback ===
  def plan(%{intent: intent, keyword: word, confidence: conf}) when conf < @low do
    "I noticed the intent `#{intent}` with `#{word}`, but I'm unsure. Want to clarify?"
  end

  def plan(%{intent: intent, keyword: word}) do
    recent = MemoryCore.recent(1)

    case recent do
      [%{intent: last_intent, keyword: last_word}] ->
        cond do
          last_intent == :question and intent == :question ->
            "Still thinking about that? Let’s dive deeper into \"#{word}\"."

          last_word == word and intent in [:reflect, :recall] ->
            "You mentioned \"#{word}\" again — here’s a fresh take."

          true ->
            fallback_response(intent, word)
        end

      _ ->
        fallback_response(intent, word)
    end
  end

  def plan(_), do: "Hmm… I didn’t quite understand that."

  # === Helpers ===
  defp fallback_response(intent, nil),
    do: "I picked up `#{intent}`, but I need a bit more to go on."

  defp fallback_response(intent, word),
    do: "I noticed `#{intent}` and `#{word}`, but couldn’t handle that combo just yet."
end

