# lib/core/multiword_pos.ex
defmodule Core.MultiwordPOS do
  @phrases %{
    "on top of" => :preposition,
    "according to" => :preposition,
    "in spite of" => :prep_phrase,
    "as well as" => :conjunction,
    "give up" => :phrasal_verb,
    "look after" => :phrasal_verb,
    "due to" => :prep_phrase,
    "kick the bucket" => :idiom,
    "take care of" => :phrasal_verb
    # You can expand this with hundreds more

  }

  def phrases, do: Map.keys(@phrases)
  def lookup(phrase), do: Map.get(@phrases, phrase, :unknown)
end

