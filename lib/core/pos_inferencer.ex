defmodule Core.POSInferencer do
  @moduledoc """
  Infers part-of-speech tags using synonym context from known brain cells.
  """

  alias BrainCell

  @doc """
  Given a phrase and a list of known brain cells, infer a likely POS by checking for synonym overlap.
  """
  def infer_pos_from_synonyms(phrase, known_cells) do
    phrase_down = String.downcase(phrase)

    known_cells
    |> Enum.flat_map(fn %BrainCell{pos: pos, synonyms: syns} ->
      if phrase_down in Enum.map(syns, &String.downcase/1), do: [pos], else: []
    end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_pos, count} -> count end, fn -> {:unknown, 0} end)
    |> case do
      {:unknown, _} -> nil
      {pos, _} -> pos
    end
  end
end

