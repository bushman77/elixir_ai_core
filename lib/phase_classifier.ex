defmodule PhraseClassifier do
  @moduledoc """
  Classifies known multi-word phrases and single-word greetings into semantic roles.
  """

  @phrases %{
    ["as", "fuck"] => %{meaning: "intensifier", pos: :adverb},
    ["cut", "it", "out"] => %{meaning: "stop", pos: :verb_phrase},
    ["blow", "up"] => %{meaning: "explode", pos: :verb_phrase},
    ["hello"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["hi"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["hey"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["yo"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["sup"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["hey", "there"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["good", "morning"] => %{meaning: "greeting", pos: :interjection, intent: :greeting},
    ["good", "evening"] => %{meaning: "greeting", pos: :interjection, intent: :greeting}
  }

  @spec classify([map()]) :: {list(String.t()), map()} | nil
  def classify(tokens) do
    words = Enum.map(tokens, & &1.word) |> Enum.map(&String.downcase/1)

    Enum.find_value(@phrases, fn {phrase, meta} ->
      if phrase in Enum.chunk_every(words, length(phrase), 1, :discard) do
        {phrase, meta}
      else
        nil
      end
    end)
  end
end

