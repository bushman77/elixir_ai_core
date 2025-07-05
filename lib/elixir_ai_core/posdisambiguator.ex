defmodule POSDisambiguator do
  @moduledoc """
  Resolves ambiguous POS lists to a single POS per word based on a known POS signature.
  """

  @doc """
  Resolves each word's POS list by matching the POS signature at the same index.

  ## Examples

      iex> tokenized = [
              ...>   %{word: "how", pos: [:adverb, :conjunction]},
        ...>   %{word: "are", pos: [:verb]},
        ...>   %{word: "you", pos: [:pronoun]}
      ...> ]
      iex> signature = [:adverb, :verb, :pronoun]
      iex> POSDisambiguator.resolve_pos(tokenized, signature)
      [
                %{word: "how", pos: :adverb},
                %{word: "are", pos: :verb},
                %{word: "you", pos: :pronoun}
              ]

  """
  def resolve_pos(word_maps, pos_signature) when is_list(word_maps) and is_list(pos_signature) do
    Enum.zip(word_maps, pos_signature)
    |> Enum.map(fn {%{word: word, pos: possible_pos}, target_pos} ->
      resolved_pos =
        if target_pos in possible_pos do
          target_pos
        else
          # fallback: pick first POS or :unknown
          List.first(possible_pos) || :unknown
        end

      %{word: word, pos: resolved_pos}
    end)
  end
end
