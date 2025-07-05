defmodule Brain do
  use GenServer

  @table Brain

  # ────────────────────────
  # 🧠 Public API
  # ────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, Brain))
  end

  def get(id), do: GenServer.call(Brain, {:get, id})

  def put(%BrainCell{} = cell), do: GenServer.call(Brain, {:put, cell})

  def all_ids, do: GenServer.call(Brain, :all_ids)

  def clear, do: GenServer.call(Brain, :clear)

  def close, do: GenServer.call(Brain, :close)

  def connect(from_id, to_id, weight \\ 1.0, delay_ms \\ 100) do
    GenServer.call(Brain, {:connect, from_id, to_id, weight, delay_ms})
  end

  def update_connections(id, new_conns) when is_list(new_conns) do
    GenServer.call(Brain, {:update_connections, id, new_conns})
  end

  def put_many(cells) when is_list(cells) do
    Enum.each(cells, fn cell -> put(cell) end)
  end

  # ────────────────────────
  # 🧠 GenServer Callbacks
  # ────────────────────────

  def init(:ok) do
    case :dets.open_file(@table, type: :set) do
      {:ok, table} -> {:ok, %{table: table}}
      {:error, reason} -> {:stop, reason}
    end
  end

  def terminate(_reason, _state) do
    :dets.close(@table)
    :ok
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
    keys = :dets.match_object(@table, {:"$1", :_}) |> Enum.map(fn {k, _} -> k end)
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
          conn = %{target_id: to_id, weight: weight, delay_ms: delay_ms}
          updated_cell = %{cell | connections: [conn | cell.connections]}
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

  # ────────────────────────
  # 🧠 Word Enrichment + Cell Activation
  # ────────────────────────

  def ensure_cells_running(word) do
    existing = get(word)

    cells =
      if existing == nil do
        case LexiconEnricher.enrich(word) do
          {:ok, enriched_cells} ->
            put_many(enriched_cells)
            enriched_cells

          {:error, reason} ->
            IO.puts("❌ Enrichment failed for #{word}: #{inspect(reason)}")
            {:error, reason}
        end
      else
        [existing]
      end

    case cells do
      {:error, _} = err ->
        err

      _ ->
        pids =
          Enum.map(cells, fn cell ->
            case ElixirAiCore.Supervisor.ensure_started(cell) do
              {:ok, pid} ->
                pid

              {:error, reason} ->
                IO.puts("❌ Could not start #{cell.id}: #{inspect(reason)}")
                nil
            end
          end)

        {:ok, Enum.filter(pids, & &1)}
    end
  end

  # ────────────────────────
  # 🧠 Optional: WordNet JSON Loader
  # ────────────────────────

  def store_word(%{"word" => word, "meanings" => meanings}) do
    Enum.each(meanings, fn meaning ->
      pos = meaning["partOfSpeech"]

      Enum.with_index(meaning["definitions"], fn defn, index ->
        id = "#{word}.#{pos}.#{index + 1}"

        cell = %BrainCell{
          id: id,
          type: String.to_atom(pos),
          activation: 0.0,
          connections: [],
          position: {0, 0, 0},
          serotonin: 1.0,
          dopamine: 1.0,
          last_dose_at: nil,
          last_substance: nil
        }

        put(cell)
      end)
    end)
  end
end
