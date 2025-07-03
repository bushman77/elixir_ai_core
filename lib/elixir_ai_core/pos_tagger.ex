defmodule ElixirAiCore.POSTagger do
  @moduledoc """
  Basic Part-of-Speech tagger with grammar-first dictionary, suffix heuristics,
  and runtime learning of unknown word tags.
  """

  # ✅ Adds child_spec/1 for supervision
  use Agent

  @initial_function_words %{
    "this" => :determiner,
    "that" => :determiner,
    "a" => :determiner,
    "the" => :determiner,
    "no" => :interjection,
    "well" => :interjection,
    "not" => :adverb,
    "about" => :preposition,
    "how" => :adverb,
    "what" => :pronoun,
    "i" => :pronoun,
    "you" => :pronoun,
    "we" => :pronoun,
    "they" => :pronoun,
    "is" => :verb,
    "are" => :verb,
    "am" => :verb,
    "was" => :verb,
    "were" => :verb,
    "do" => :verb,
    "does" => :verb,
    "want" => :verb,
    "see" => :verb,
    "testing" => :verb,
    "suppose" => :verb,
    "start" => :noun,
    "console" => :noun,
    "it" => :pronoun,
    "its" => :pronoun,
    "hows" => :verb,
    "great" => :adjective,
    "so" => :adverb,
    "far" => :adverb,
    "heck" => :noun,
    "parrot" => :noun,
    "be" => :verb,
    "fine" => :adjective,
    "way" => :noun,
    "hello" => :interjection,
    "there" => :adverb,
    "pleasure" => :noun,
    "to" => :preposition,
    "meet" => :verb,
    "interesting" => :adjective
  }

  # Agent to track learned word types during runtime
  def start_link(_), do: Agent.start_link(fn -> @initial_function_words end, name: __MODULE__)

  def tag(word) do
    Agent.get_and_update(__MODULE__, fn dict ->
      case Map.get(dict, word) do
        nil ->
          tag = suffix_tag(word)
          {tag, Map.put(dict, word, tag)}

        existing ->
          {existing, dict}
      end
    end)
  end

  def suffix_tag(word) do
    if Map.has_key?(@exceptions, word) do
      @exceptions[word]
    else
      cond do
        String.ends_with?(word, "ing") -> :verb
        String.ends_with?(word, "ed") -> :verb
        String.ends_with?(word, "ly") -> :adverb
        String.ends_with?(word, "ion") -> :noun
        String.ends_with?(word, "ness") -> :noun
        true -> :unknown
      end
    end
  end

  def tag_sentence(sentence) when is_binary(sentence) do
    sentence
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.map(fn word -> {word, tag(word)} end)
  end
end
