defmodule PhraseGenerator do
  alias Brain
  alias BrainCell

  @max_length 5

  def generate_phrase(start_word) do
    do_generate(start_word, @max_length, [])
    |> Enum.join(" ")
  end

  defp do_generate(_word, 0, acc), do: Enum.reverse(acc)

  defp do_generate(word, length, acc) do
    case Brain.get(Brain, word) do
      nil ->
        Enum.reverse(acc)

      %BrainCell{connections: []} ->
        Enum.reverse([word | acc])

      %BrainCell{connections: conns} ->
        # Pick the strongest connection (highest weight)
        next_word =
          conns
          |> Enum.max_by(& &1.weight)
          |> Map.get(:target_id)

        do_generate(next_word, length - 1, [word | acc])
    end
  end
end
