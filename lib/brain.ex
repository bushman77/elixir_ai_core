defmodule Brain do
  @moduledoc """
  Persistent store and manager for all brain cells.
  Uses DETS to persistently store BrainCells by ID.
  """

  alias BrainCell

  @table :brain

  def init(path \\ "brain_store") do
    :dets.open_file(@table, type: :set, file: String.to_charlist(path))
  end

  def close do
    :dets.close(@table)
  end

  def clear do
    :dets.delete_all_objects(@table)
  end

  def all_ids do
    :dets.match_object(@table, {:"$1", :_}) |> Enum.map(&elem(&1, 0))
  end

  def get(id) do
    case :dets.lookup(@table, id) do
      [{^id, cell}] -> cell
      _ -> nil
    end
  end

  def put(%BrainCell{id: id} = cell) do
    :dets.insert(@table, {id, cell})
    cell
  end

  def update_connections(id, connections) do
    case get(id) do
      nil ->
        :error

      cell ->
        new_cell = %{cell | connections: connections}
        put(new_cell)
    end
  end

  def connect(id1, id2, max_distance \\ 2.0) do
    case {get(id1), get(id2)} do
      {nil, _} ->
        {:error, :cell1_missing}

      {_, nil} ->
        {:error, :cell2_missing}

      {c1, c2} ->
        {c1_new, c2_new} = BrainCell.connect(c1, c2, max_distance)
        put(c1_new)
        put(c2_new)
        {:ok, {c1_new, c2_new}}
    end
  end
end
