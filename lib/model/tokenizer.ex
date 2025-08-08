defmodule Model.Tokenizer do
  @vocab %{
    "hello" => 1,
    "how" => 2,
    "are" => 3,
    "you" => 4,
    "goodbye" => 5,
    "i" => 6,
    "am" => 7,
    "fine" => 8,
    "what" => 9,
    "is" => 10,
    "up" => 11
  }

  @pad_id 0
  @sequence_length 16

  def tokenize(sentence) do
    sentence
    |> String.downcase()
    |> String.split()
    |> Enum.map(&Map.get(@vocab, &1, @pad_id))
    |> pad_to_length(@sequence_length)
  end

  defp pad_to_length(tokens, length) do
    tokens ++ List.duplicate(@pad_id, max(length - length(tokens), 0))
    |> Enum.take(length)
  end
end

