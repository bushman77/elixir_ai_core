defmodule Core.IntentClassifier do
  @moduledoc """
  Determines user intent based on POS patterns or fallback logic.
  """

  alias Core.POS
  alias Core.SemanticInput

@intent_patterns %{
  greet: [
    [:interjection, :noun],
    [:interjection],
    [:interjection, :verb],
    [:interjection, :pronoun],
    [:interjection, :adverb],
    [:noun, :verb, :interjection]
  ],
  
  bye: [
    [:interjection],
    [:verb, :adverb],
    [:interjection, :verb],
    [:verb, :noun],
    [:interjection, :noun]
  ],

  question: [
    [:adverb, :auxiliary, :pronoun],
    [:verb, :pronoun],
    [:adverb, :verb],
    [:auxiliary, :noun, :verb],
    [:interjection, :auxiliary, :pronoun],
    [:pronoun, :verb, :noun],
    [:modal, :pronoun, :verb]
  ],

  command: [
    [:verb, :noun],
    [:verb],
    [:verb, :determiner, :noun],
    [:verb, :preposition, :noun],
    [:interjection, :verb],
    [:noun, :verb, :noun]
  ],

  confirm: [
    [:interjection],
    [:adverb],
    [:verb],
    [:interjection, :verb]
  ],

  deny: [
    [:adverb, :verb],
    [:interjection],
    [:interjection, :adverb],
    [:verb, :adverb]
  ],

  thank: [
    [:interjection, :pronoun],
    [:interjection],
    [:verb, :pronoun],
    [:verb, :noun]
  ],

  inform: [
    [:noun, :verb, :noun],
    [:pronoun, :verb, :noun],
    [:noun, :verb],
    [:pronoun, :verb],
    [:verb, :determiner, :noun]
  ],

  why: [
    [:adverb, :auxiliary, :pronoun],
    [:adverb, :verb, :noun],
    [:interjection, :adverb, :verb],
    [:adverb, :modal, :pronoun, :verb]
  ]
}

  @doc """
  Classifies intent based on token POS patterns or fallback heuristics.
  Adds `:intent`, `:confidence`, and optionally `:keyword` to SemanticInput.
  """
  def classify_tokens(%{token_structs: token_structs} = struct) do
IO.inspect struct
    pos_lists = Enum.map(token_structs, & &1.pos)
    combos = POS.cartesian_product(pos_lists)

    intent =
      Enum.find_value(@intent_patterns, nil, fn {intent, patterns} ->
        Enum.any?(patterns, &(&1 in combos)) && intent
      end)

    cond do
      intent ->
        Map.merge(struct, %{intent: intent, confidence: 1.0})

      true ->
        fallback = fallback_intent(pos_lists)
        Map.merge(struct, %{intent: fallback, confidence: 0.5})
    end
  end

  @doc """
  Fallback intent classification using POS role counts.
  """
  def fallback_intent(pos_list) do
    flat_pos = List.flatten(pos_list)

    cond do
      Enum.any?(flat_pos, &(&1 == :interjection)) -> :greet
      contains_sequence?(pos_list, [:pronoun, :verb]) -> :status
      contains_sequence?(pos_list, [:noun, :verb]) -> :statement
      flat_pos == [] -> :unknown
      Enum.all?(flat_pos, &(&1 == :verb)) -> :command
      Enum.any?(flat_pos, &(&1 == :adjective)) -> :description
      Enum.any?(flat_pos, &(&1 == :determiner)) -> :request_info
      Enum.any?(flat_pos, &(&1 == :conjunction)) -> :continuation
      true -> :unknown
    end
  end

  defp contains_sequence?(pos_list, sequence) do
    pos_atoms = Enum.map(pos_list, &List.first/1)
    Enum.chunk_every(pos_atoms, length(sequence), 1, :discard)
    |> Enum.any?(fn chunk -> chunk == sequence end)
  end
end

