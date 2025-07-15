defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on intent and optionally keyword/context.
  """

  alias Brain
  alias BrainCell
  alias PhraseGenerator

  # 🟢 Greeting — no keyword required
  def plan(%{intent: :greeting} = _data) do
    "Hey there! 👋 How can I assist you today?"
  end

  # 🔵 Farewell — no keyword required
  def plan(%{intent: :farewell} = _data) do
    "Goodbye for now. Take care out there."
  end

  # 🧠 Reflect — requires keyword
  def plan(%{intent: :reflect, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :reflective)
    "Hmm… #{word} makes me think of: #{phrase}"
  end

  # 🧠 Recall — requires keyword
  def plan(%{intent: :recall, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  # 📖 Define — requires keyword
  def plan(%{intent: :define, keyword: word} = _data) do
    case Brain.get(word) do
      %BrainCell{definition: defn} -> "#{word}: #{defn}"
      _ -> "I haven’t learned that word yet."
    end
  end

  # ⚠️ Unknown — requires keyword
  def plan(%{intent: :unknown, keyword: word} = _data) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :curious)
    "I'm not quite sure about that… but #{word} brings to mind: #{phrase}"
  end

  # 🔍 Generic fallback — any recognized intent but missing keyword
  def plan(%{intent: intent} = data) do
    IO.inspect(data, label: "⚠️ Unhandled intent structure in ResponsePlanner")

    case Map.get(data, :keyword) do
      nil -> "I noticed the intent `#{inspect(intent)}`, but I’m not sure how to proceed without more context."
      word -> "I noticed the intent `#{inspect(intent)}` with keyword `#{word}`, but couldn’t handle that form yet."
    end
  end

  # 🪵 Total fallback — not even an intent
  def plan(_other) do
    "Hmm… I didn’t quite understand that."
  end
end

