defmodule Core.POS do
  @moduledoc """
  Identifies input structure based on POS patterns.
  Returns structured intent response.
  """

  @type pos_signature :: [[atom()]]

  @question_signatures [
    # how are you
    [[:adverb], [:verb], [:pronoun]],
    # you are
    [[:pronoun], [:verb]],
    # is good you
    [[:verb], [:adjective, :noun], [:pronoun]],
    # is it
    [[:verb], [:pronoun]],
    # can you go
    [[:modal], [:pronoun], [:verb]],
    # what dog runs
    [[:wh_determiner], [:noun], [:verb]],
    # why you scream
    [[:adverb], [:pronoun], [:verb]]
  ]

  @doc """
  Classifies token sequence into {:answer, %{intent, signature, input}}.
  """
  @spec classify_input([map()]) :: {:answer, map()}
  def classify_input(tokens) do
    pos_sequence = Enum.map(tokens, fn %{pos: pos} -> List.wrap(pos) end)

    case Enum.find(@question_signatures, fn sig ->
           matches_signature?(pos_sequence, sig)
         end) do
      nil ->
        {:answer,
         %{
           intent: :unknown,
           pos: pos_sequence,
           input: tokens
         }}

      matched_sig ->
        {:answer,
         %{
           intent: :question,
           signature: matched_sig,
           input: tokens
         }}
    end
  end

  defp matches_signature?(pos_seq, signature) do
    len = length(signature)
    window = Enum.take(pos_seq, len)

    Enum.zip(window, signature)
    |> Enum.all?(fn {actual, expected} ->
      Enum.any?(expected, &(&1 in actual))
    end)
  end
end
