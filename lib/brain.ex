defmodule Brain do
  use GenServer

  @table :brain

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get(pid_or_name, id), do: GenServer.call(pid_or_name, {:get, id})
  def put(pid_or_name, %BrainCell{} = cell), do: GenServer.call(pid_or_name, {:put, cell})

  # Server callbacks

  def init(_opts) do
    case :dets.open_file(:brain, type: :set) do
      {:ok, table} ->
        state = %{
          table: table
          # optionally preload or initialize other fields here
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_call({:get, id}, _from, state) do
    result =
      case :dets.lookup(@table, id) do
        [{^id, cell}] -> cell
        _ -> nil
      end

    {:reply, result, state}
  end

  def handle_call({:put, %BrainCell{id: id} = cell}, _from, state) do
    :ok = :dets.insert(@table, {id, cell})
    {:reply, :ok, state}
  end

  def terminate(_reason, _state) do
    :dets.close(@table)
  end
end
