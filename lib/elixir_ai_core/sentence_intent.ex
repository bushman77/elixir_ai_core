defmodule SentenceIntent do
  @moduledoc """
  Determines the intent of a sentence based on POS tag patterns.
  """

  @question_patterns [
    # How are you?
    [:adverb, :verb, :pronoun],
    # Who is she?
    [:wh_pronoun, :verb, :noun],
    # What time is it?
    [:wh_determiner, :noun, :verb],
    # Are you?
    [:verb, :pronoun],
    # Can you swim?
    [:aux, :pronoun, :verb],
    # Should I go?
    [:modal, :pronoun, :base_verb],
    # In what way did he act?
    [:preposition, :noun, :verb],
    # Why did he leave?
    [:wh_adverb, :aux, :subject],
    # Eh, do you?
    [:interjection, :verb, :pronoun],
    # You think I care?
    [:pronoun, :verb, :pronoun, :verb]
  ]

  @doc """
  Matches the intent of a sentence based on POS list.

  Returns:
    - :question
    - :unknown
  """
  def intent_from_pos(pos_list) when is_list(pos_list) do
    if pos_list in @question_patterns do
      :question
    else
      :unknown
    end
  end
end
