# lib/core/multiword_pos.ex
defmodule Core.MultiwordPOS do
  @moduledoc """
  Stores and matches known multiword POS expressions.
  """

  @multiword_phrases %{
    "give up" => :phrasal_verb,
    "look after" => :phrasal_verb,
    "as well as" => :conj_phrase,
    "in spite of" => :prep_phrase,
    "due to" => :prep_phrase,
    "kick the bucket" => :idiom,
    "take care of" => :phrasal_verb
    # You can expand this with hundreds more
  }

  def phrases, do: Map.keys(@multiword_phrases)

  def lookup(phrase) do
    Map.get(@multiword_phrases, phrase)
  end
end

