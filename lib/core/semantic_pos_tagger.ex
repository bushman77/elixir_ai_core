
defmodule Core.SemanticPOSTagger do
  @moduledoc """
  Infers the part-of-speech (POS) of a phrase using semantic patterns.
  Used when a phrase is not yet known in the lexicon.
  """

  alias Core.Lexicon

  @doc """
  Attempts to infer a POS for a multiword phrase using semantic composition rules.
  Returns a POS atom or :unknown.
  """
  def infer_pos(phrase) when is_binary(phrase) do
    words = String.split(phrase)
    pos_list = Enum.map(words, &Lexicon.pos_of/1)

    match_pos_pattern(words, pos_list)
  end

  # -------------------------------
  # Pattern Matching Rules
  # -------------------------------

  # e.g., "give up", "run into", "check out"
  defp match_pos_pattern([_, _], [:verb, :particle]), do: :phrasal_verb

  # e.g., "in spite of", "due to"
  defp match_pos_pattern([_, _, _], [:preposition, _, :preposition]), do: :prep_phrase

  # e.g., "as well as", "in addition to"
  defp match_pos_pattern(_, [:conjunction, _, :preposition]), do: :conj_phrase

  # catch-all
  defp match_pos_pattern(_, _), do: :unknown
end

