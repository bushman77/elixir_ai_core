defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on intent and optionally keyword/context.
  """

  alias Brain
  alias BrainCell
  alias PhraseGenerator
  alias Core.MemoryCore

  def plan(%{intent: :greeting} = _data) do
    "Hey there! 👋 How can I assist you today?"
  end

  def plan(%{intent: :farewell} = _data) do
    "Goodbye for now. Take care out there."
  end

  def plan(%{intent: :reflect, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :reflective)
    "Hmm… #{word} makes me think of: #{phrase}"
  end

  def plan(%{intent: :recall, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  def plan(%{intent: :define, keyword: word} = _data) do
    case Brain.get(word) do
      %BrainCell{definition: defn} -> "#{word}: #{defn}"
      _ -> "I haven’t learned that word yet."
    end
  end

  def plan(%{intent: :unknown, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :curious)
    "I'm not quite sure about that… but #{word} brings to mind: #{phrase}"
  end

  # 🔄 NEW: Intent continuity handler
  def plan(%{intent: intent, keyword: word} = data) do
    recent = MemoryCore.recent(1)

    case recent do
      [%{intent: last_intent, keyword: last_word}] ->
        cond do
          last_intent == :question and intent == :question ->
            "Still thinking about that? Let's dive deeper into \"#{word}\"."

          last_word == word and intent in [:reflect, :recall] ->
            "You brought up \"#{word}\" again — let’s look at it differently."

          true ->
            fallback_response(intent, word)
        end

      _ ->
        fallback_response(intent, word)
    end
  end

  # 💬 Catch-all for known intent + keyword
  defp fallback_response(intent, nil),
    do: "I noticed the intent `#{inspect(intent)}`, but I’m not sure how to proceed without more context."

  defp fallback_response(intent, word),
    do: "I noticed the intent `#{inspect(intent)}` with keyword `#{word}`, but couldn’t handle that form yet."

  # 🪵 Ultimate fallback
  def plan(_other) do
    "Hmm… I didn’t quite understand that."
  end
end

