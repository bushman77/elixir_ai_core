defmodule ElixirAiCore.SentenceStructureParser do
  @moduledoc """
  Parses tagged sentences into grammar structure like SVO, VO, etc.
  """

  def parse_tagged_sentence(tagged_words) do
    pos = Enum.map(tagged_words, fn {_w, tag} -> tag end)

    cond do
      pos == [:pronoun, :verb, :noun] ->
        {:ok, %{structure: :svo, tokens: tagged_words}}

      pos == [:pronoun, :verb] ->
        {:ok, %{structure: :sv, tokens: tagged_words}}

      pos == [:verb, :noun] ->
        {:ok, %{structure: :vo, tokens: tagged_words, implied_subject: :you}}

      pos == [:interjection, :pronoun] ->
        {:ok, %{structure: :interjection, tokens: tagged_words}}

      pos == [:interjection, :determiner, :verb, :determiner, :noun, :pronoun, :verb] ->
        {:ok, %{structure: :affirmation, tokens: tagged_words}}

      pos == [:interjection, :determiner, :verb, :noun] ->
        {:ok, %{structure: :declarative, tokens: tagged_words}}

      pos == [:pronoun, :verb, :adjective] ->
        {:ok, %{structure: :subject_verb_adj, tokens: tagged_words}}

      pos == [:pronoun, :verb, :determiner, :noun] ->
        {:ok, %{structure: :subject_verb_noun_phrase, tokens: tagged_words}}

      pos == [:interjection, :pronoun, :verb, :determiner, :noun] ->
        {:ok, %{structure: :interjection_statement, tokens: tagged_words}}

      pos == [:verb, :adjective, :adverb, :adverb] ->
        {:ok, %{structure: :observation, tokens: tagged_words}}

      pos == [:interjection] ->
        {:ok, %{structure: :solo_emotion, tokens: tagged_words}}

      pos == [:interjection, :verb, :determiner, :noun] ->
        {:ok, %{structure: :impulse_action, tokens: tagged_words}}

      pos == [:interjection, :adverb] ->
        {:ok, %{structure: :greeting, tokens: tagged_words}}

        pos == [:determiner, :verb, :adjective] ->
          {:ok, %{structure: :statement, tokens: tagged_words}}


      true ->
        {:unknown, %{tokens: tagged_words, reason: "Structure not matched"}}
    end
  end
end
