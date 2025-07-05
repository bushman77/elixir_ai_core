defmodule Core.POS do
  @moduledoc """
  Identifies input structure based on POS patterns.
  Returns structured intent response.
  """

  @type pos_signature :: [[atom()]]

  @question_signatures [
    [[:adverb], [:verb], [:pronoun]],       # how are you
    [[:pronoun], [:verb]],                  # you are
    [[:verb], [:adjective, :noun], [:pronoun]], # is good you
    [[:verb], [:pronoun]],                  # is it
    [[:modal], [:pronoun], [:verb]],        # can you go
    [[:wh_determiner], [:noun], [:verb]],   # what dog runs
    [[:adverb], [:pronoun], [:verb]]        # why you scream
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
        {:answer, %{
          intent: :unknown,
          pos: pos_sequence,
          input: tokens
        }}

      matched_sig ->
        {:answer, %{
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

