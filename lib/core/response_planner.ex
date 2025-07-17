defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on intent and optionally keyword/context.
  """

  alias Brain
  alias BrainCell
  alias PhraseGenerator
  alias Core.MemoryCore

  def plan(%{intent: :greeting}), do: "Hey there! 👋 How can I assist you today?"

  def plan(%{intent: :farewell}), do: "Goodbye for now. Take care out there."

  def plan(%{intent: :reflect, keyword: word}) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :reflective)
    "Hmm… #{word} makes me think of: #{phrase}"
  end

  def plan(%{intent: :recall, keyword: word}) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  def plan(%{intent: :define, keyword: word}) do
    case Brain.get(word) do
      %BrainCell{definition: defn} -> "#{word}: #{defn}"
      _ -> "I haven’t learned that word yet."
    end
  end

  def plan(%{intent: :unknown, keyword: word}) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :curious)
    "I'm not quite sure about that… but #{word} brings to mind: #{phrase}"
  end

  def plan(%{intent: :question, keyword: word}) do
    case word do
      "how" -> "How something works can be complex! Could you specify a bit more?"
      "what" -> "What exactly are you curious about?"
      "why" -> "Why questions are the best! What’s got you wondering?"
      _ -> "That’s an interesting question about '#{word}'. I'll do my best to help!"
    end
  end

  def plan(%{intent: intent, keyword: word} = data) when intent != :question do
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

  defp fallback_response(intent, nil),
    do: "I noticed the intent `#{inspect(intent)}`, but I’m not sure how to proceed without more context."

  defp fallback_response(intent, word),
    do: "I noticed the intent `#{inspect(intent)}` with keyword `#{word}`, but couldn’t handle that form yet."

  def plan(_other), do: "Hmm… I didn’t quite understand that."
end

