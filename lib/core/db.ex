defmodule Core.DB do
  use GenServer

  @table :brain
  @path ~c"priv/brain_store.dets"

  # Existing API...
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def select(word), do: GenServer.call(__MODULE__, {:select, word})
  def put({id, word, cell}), do: GenServer.cast(__MODULE__, {:put, {id, word, cell}})
  def clear, do: GenServer.call(__MODULE__, :clear)
  def stop, do: GenServer.stop(__MODULE__)

  # New batch insert API
  def insert_many(cells) when is_list(cells) do
    GenServer.cast(__MODULE__, {:insert_many, cells})
  end

  # GenServer Callbacks
  def init(:ok) do
    case :dets.open_file(@table, file: @path) do
      {:ok, _} -> {:ok, %{}}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:select, word}, _from, state) do
    result =
      :dets.foldl(
        fn {id, w, cell}, acc -> if w == word, do: [{id, w, cell} | acc], else: acc end,
        [],
        @table
      )
    {:reply, result, state}
  end

  def handle_call(:clear, _from, state) do
    :ok = :dets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  def handle_cast({:put, {id, word, cell}}, state) do
    :ok = :dets.insert(@table, {id, word, cell})
    {:noreply, state}
  end

  # Handle batch insertion
def handle_cast({:insert_many, cells}, state) do
  Enum.each(cells, fn %BrainCell{id: id, word: word} = cell ->
    :ok = :dets.insert(@table, {id, word, cell})
  end)

  {:noreply, state}
end

  def terminate(_reason, _state) do
    :dets.close(@table)
    :ok
  end
end

