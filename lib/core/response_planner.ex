defmodule Core.ResponsePlanner do
  @moduledoc """
  Chooses a response based on intent, keyword, confidence, and optionally mood or prior context.
  """

  alias Core.{MemoryCore, SemanticInput}
  alias BrainCell
  alias PhraseGenerator

  @high 0.6
  @low 0.3

  # === Entry Point ===
  def analyze(%SemanticInput{} = semantic) do
    response =
      cond do
        not is_nil(semantic.cell) -> plan_with_cell(semantic)
        not is_nil(semantic.keyword) -> plan_with_keyword(semantic)
        true -> "Hmm… I didn’t quite understand that."
      end

    %SemanticInput{semantic | response: response}
  end

  # === Intent Routing with Cell ===
  defp plan_with_cell(%SemanticInput{intent: :greeting, confidence: conf}) when conf >= @high,
    do: "Hey there! 👋 How can I assist you today?"

  defp plan_with_cell(%SemanticInput{intent: :farewell, confidence: conf}) when conf >= @low,
    do: "Goodbye for now. Take care out there."

  defp plan_with_cell(%SemanticInput{intent: :define, cell: %BrainCell{word: w, definition: d}, confidence: conf})
       when conf > @low,
    do: "#{w}: #{d}"

  defp plan_with_cell(%SemanticInput{intent: :reflect, cell: %BrainCell{word: word}, confidence: conf})
       when conf > @low do
    phrase = PhraseGenerator.generate_phrase(word, mood: :reflective)
    "Hmm… #{word} makes me think of: #{phrase}"
  end

  defp plan_with_cell(%SemanticInput{intent: :recall, cell: %BrainCell{word: word}, confidence: conf})
       when conf > @low do
    phrase = PhraseGenerator.generate_phrase(word, mood: :nostalgic)
    "I remember something like: #{phrase}"
  end

  defp plan_with_cell(%SemanticInput{intent: :unknown, cell: %BrainCell{word: word}}) do
    phrase = PhraseGenerator.generate_phrase(word, mood: :curious)
    "I'm not quite sure about that… but '#{word}' brings to mind: #{phrase}"
  end

  defp plan_with_cell(%SemanticInput{intent: intent, cell: %BrainCell{word: word}, confidence: conf}) do
    fallback_response(intent, word, conf)
  end

  # === Intent Routing with Keyword Only (Legacy Fallback) ===
  defp plan_with_keyword(%SemanticInput{intent: :question, keyword: word, confidence: conf}) do
    case {word, conf} do
      {"why", c} when c > @high -> "Why questions are my favorite! Let’s explore."
      {"how", c} when c > @low -> "How things work can be fascinating — what specifically?"
      {"what", _} -> "What would you like to explore more?"
      {w, c} when c < @low -> "That sounds like a question about \"#{w}\", but I’m not too sure. Could you clarify?"
      {w, _} -> "Great question on \"#{w}\". Let me try to help!"
    end
  end

  defp plan_with_keyword(%SemanticInput{intent: intent, keyword: word, confidence: conf}) when conf < @low do
    "I noticed the intent `#{intent}` with `#{word}`, but I'm unsure. Want to clarify?"
  end

  defp plan_with_keyword(%SemanticInput{intent: intent, keyword: word}) do
    recent = MemoryCore.recent(1)

    case recent do
      [%{intent: last_intent, keyword: last_word}] ->
        cond do
          last_intent == :question and intent == :question ->
            "Still thinking about that? Let’s dive deeper into \"#{word}\"."

          last_word == word and intent in [:reflect, :recall] ->
            "You mentioned \"#{word}\" again — here’s a fresh take."

          true ->
            fallback_response(intent, word, nil)
        end

      _ ->
        fallback_response(intent, word, nil)
    end
  end

  # === Fallback ===
  defp fallback_response(intent, nil, _),
    do: "I picked up `#{intent}`, but I need a bit more to go on."

  defp fallback_response(intent, word, _),
    do: "I noticed `#{intent}` and `#{word}`, but couldn’t handle that combo just yet."
end

