defmodule Brain do
  use GenServer

  alias Core.DB
  alias Core.Registry, as: BrainRegistry
  alias LexiconEnricher
  alias BrainCell

  # ────────────────────────
  # Public API
  # ────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Retrieves all brain cells associated with the given word.
  Follows 3-tier lookup: Registry -> DETS -> LexiconEnricher.
  """
  def get(word), do: GenServer.call(__MODULE__, {:get, word})

  # ────────────────────────
  # GenServer Callbacks
  # ────────────────────────

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
def handle_call({:get, word}, _from, state) do
  case BrainRegistry.query(word) do
    [] ->
      case DB.select(word) do
        [] ->
          case LexiconEnricher.enrich(word) do
            {:ok, []} ->
              {:reply, {:error, :no_definitions_found}, state}

            {:ok, enriched_cells} ->
              :ok = DB.insert_many(enriched_cells)

              statuses =
                enriched_cells
                |> Enum.map(fn cell ->
                  with {:ok, pid} <- BrainRegistry.register(cell) do
                    # Use a safe call to get status (implement safe_status/1)
                    safe_status(pid)
                  else
                    err -> IO.inspect(err, label: "Register failed")
                  end
                end)

              {:reply, statuses, state}

            {:error, reason} ->
              {:reply, {:error, {:enrich_failed, reason}}, state}
          end

        persisted when is_list(persisted) ->

          statuses =
            persisted
            |> Enum.map(fn {_id, _word, cell} ->
              with {:ok, pid} <- BrainRegistry.register(cell) do
                safe_status(pid)
              else
                err -> IO.inspect(err, label: "Register failed")
              end
            end)

          {:reply, statuses, state}
      end

    active when is_list(active) ->

      statuses =
        Enum.map(active, fn {_id, pid, _cell} ->

          case safe_status(pid) do
            {:ok, status} -> status
            {:error, reason} -> {:error, reason}
          end
        end)

      {:reply, statuses, state}
  end
end
defp safe_status(pid) do
  if Process.alive?(pid) do
    try do
      {:ok, GenServer.call(pid, :status, 5_000)}
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, reason}
    end
  else
    {:error, :dead_pid}
  end
end

end

