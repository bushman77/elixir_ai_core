
defmodule SentenceIntent do
  @moduledoc """
  Determines the intent of a sentence based on POS tag patterns.
  """

  @question_patterns [
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
  ]

  @doc """
  Given a list of lists of POS tags (one list per word),
  tries all possible combinations to find a matching known signature.

  Returns:
    - :question if matched,
    - :unknown otherwise.
  """
  def intent_from_word_pos_list(pos_lists) when is_list(pos_lists) do
    combos = cartesian_product(pos_lists)

    case Enum.find(combos, fn combo -> combo in @question_patterns end) do
      nil -> :unknown
      _ -> :question
    end
  end

  # Computes the cartesian product of a list of lists
  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    for h <- head, t <- cartesian_product(tail), do: [h | t]
  end
end

