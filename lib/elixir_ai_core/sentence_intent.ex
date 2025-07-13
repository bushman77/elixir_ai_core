defmodule SentenceIntent do
  @moduledoc """
  Determines the intent of a sentence based on POS tag patterns.
  Supported intents:
    - :question
    - :command
    - :statement
    - :greeting
    - :exclamation
    - :negation
    - :request
    - :affirmation
  """

  @greeting_words ~w(hello hi hey greetings welcome)
  @affirmative_words ~w(yes yeah yup sure certainly absolutely)

  @intent_patterns %{
    question: [
      [:adverb, :verb, :pronoun],
      [:wh_pronoun, :verb, :noun],
      [:wh_determiner, :noun, :verb],
      [:verb, :pronoun],
      [:aux, :pronoun, :verb],
      [:modal, :pronoun, :base_verb],
      [:preposition, :noun, :verb],
      [:wh_adverb, :aux, :subject],
      [:interjection, :verb, :pronoun],
      [:pronoun, :verb, :pronoun, :verb]
    ],
    command: [
      [:verb],
      [:verb, :noun],
      [:verb, :object],
      [:verb, :preposition, :noun],
      [:verb, :pronoun],
      [:modal, :verb]
    ],
statement: [
  [:pronoun, :verb],
  [:noun, :verb],
  [:subject, :verb, :object],
  [:pronoun, :aux, :verb],
  [:noun, :aux, :verb],
  [:determiner, :noun, :verb]   # 👈 ADD THIS LINE
],
    greeting: [
      [:interjection],
      [:interjection, :pronoun],
      [:interjection, :noun]
    ],
    exclamation: [
      [:interjection, :exclamation],
      [:adjective, :exclamation],
      [:interjection, :adjective]
    ],
    negation: [
      [:pronoun, :aux, :negation, :verb],
      [:noun, :aux, :negation, :verb],
      [:aux, :negation, :verb]
    ],
    request: [
      [:modal, :pronoun, :verb],
      [:verb, :pronoun, :please],
      [:please, :verb, :noun]
    ],
    affirmation: [
      [:yes],
      [:affirmative],
      [:pronoun, :verb, :noun],
      [:pronoun, :aux, :verb],
      [:pronoun, :modal, :base_verb],
      [:interjection, :affirmative],
      [:pronoun, :verb, :affirmative]
    ]
  }

  @doc """
  Attempts to classify intent by POS signature or fallback keywords.
  """
 def intent_from_word_pos_list(pos_lists) when is_list(pos_lists) do
  combos =
    cartesian_product(pos_lists)
    |> Enum.map(fn tuple_list ->
      Enum.map(tuple_list, fn
        {_, pos} -> pos
        _ -> nil
      end)
    end)

  # Fire associated brain cells
  Brain.maybe_fire_cells(pos_lists)

  Enum.find_value(
    [:greeting, :question, :exclamation, :negation, :request, :affirmation, :statement, :command],
    :unknown,
    fn intent ->
      patterns = Map.get(@intent_patterns, intent, [])
      Enum.find(patterns, fn pattern -> pattern in combos end) && intent
    end
  )
  |> fallback_intent(pos_lists)
end
 
  defp fallback_intent(:unknown, pos_lists) do
    words = Enum.map(pos_lists, fn
      [{word, _} | _] -> String.downcase(word)
      {word, _} -> String.downcase(word)
      _ -> nil
    end)

    cond do
      Enum.any?(words, &(&1 in @greeting_words)) -> :greeting
      Enum.any?(words, &(&1 in @affirmative_words)) -> :affirmation
      true -> :unknown
    end
  end

  defp fallback_intent(intent, _pos_lists), do: intent

  defp cartesian_product([]), do: [[]]
  defp cartesian_product([head | tail]) do
    for h <- head, t <- cartesian_product(tail), do: [h | t]
  end
end

