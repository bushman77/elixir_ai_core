defmodule Brain do
  use GenServer

  @table :brain

  # ────────────────────────
  # 🧠 Public API
  # ────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get(pid_or_name, id), do: GenServer.call(pid_or_name, {:get, id})

  def put(pid_or_name, %BrainCell{} = cell), do: GenServer.call(pid_or_name, {:put, cell})

  def all_ids(pid_or_name), do: GenServer.call(pid_or_name, :all_ids)

  def connect(pid_or_name, from_id, to_id, weight \\ 1.0, delay_ms \\ 100) do
    GenServer.call(pid_or_name, {:connect, from_id, to_id, weight, delay_ms})
  end

  def update_connections(pid_or_name, id, new_conns) when is_list(new_conns) do
    GenServer.call(pid_or_name, {:update_connections, id, new_conns})
  end

  def clear(pid_or_name), do: GenServer.call(pid_or_name, :clear)

  def close(pid_or_name), do: GenServer.call(pid_or_name, :close)

  # ────────────────────────
  # 🧠 Server Callbacks
  # ────────────────────────

  def init(:ok) do
    case :dets.open_file(@table, type: :set) do
      {:ok, table} ->
        {:ok, %{table: table}}

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

  def handle_call(:all_ids, _from, state) do
    keys = :dets.match_object(@table, {:"$1", :_}) |> Enum.map(fn {k, _v} -> k end)
    {:reply, keys, state}
  end

  def handle_call(:clear, _from, state) do
    :ok = :dets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  def handle_call(:close, _from, state) do
    :ok = :dets.close(@table)
    {:reply, :ok, state}
  end

  def handle_call({:connect, from_id, to_id, weight, delay_ms}, _from, state) do
    updated =
      case :dets.lookup(@table, from_id) do
        [{^from_id, %BrainCell{} = cell}] ->
          new_conn = %{target_id: to_id, weight: weight, delay_ms: delay_ms}
          updated_cell = %{cell | connections: [new_conn | cell.connections]}
          :dets.insert(@table, {from_id, updated_cell})
          {:ok, updated_cell}

        _ ->
          {:error, :not_found}
      end

    {:reply, updated, state}
  end

  def handle_call({:update_connections, id, new_conns}, _from, state) do
    updated =
      case :dets.lookup(@table, id) do
        [{^id, %BrainCell{} = cell}] ->
          updated_cell = %{cell | connections: new_conns}
          :dets.insert(@table, {id, updated_cell})
          {:ok, updated_cell}

        _ ->
          {:error, :not_found}
      end

    {:reply, updated, state}
  end

  def terminate(_reason, _state) do
    :dets.close(@table)
    :ok
  end
end
