defmodule Core.Registry do
  @registry BrainCell.Registry

  @doc """
  Starts a BrainCell process and registers it with the Registry under its `id`.

  Returns: `{:ok, pid}`.
  """
  def register(%BrainCell{id: id} = cell) do
    case DynamicSupervisor.start_child(BrainCellSupervisor, {BrainCell, cell}) do
      {:ok, pid} ->
        # You register FROM the child process itself
        send(pid, {:register_self, @registry, id, cell})
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  @doc """
  Selects all active BrainCells whose `word` field matches the given input.
  Returns a list of `{id, pid, %BCell{}}` tuples.
  """
  def query(word) when is_binary(word) do
    Registry.select(@registry, [
      {
        {:"$1", :"$2", :"$3"},
        [
          {:==, {:map_get, :word, :"$3"}, word}
        ],
        [{{:"$1", :"$2", :"$3"}}]
      }
    ])
  end
end
