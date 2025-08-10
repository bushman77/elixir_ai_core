defmodule Core.MultiwordPOS do
  @phrases ~w(
    good morning
    good afternoon
    good evening
    thank you
    how much
    what time
  )

  @map %{
    "good morning" => :interjection,
    "good afternoon" => :interjection,
    "good evening" => :interjection,
    "thank you" => :interjection,
    "how much" => :wh_phrase,
    "what time" => :wh_phrase
  }

  def phrases, do: @phrases
  def lookup(p), do: Map.get(@map, p)
end

