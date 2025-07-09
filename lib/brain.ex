defmodule Brain do
  use GenServer

  import Ecto.Query

  alias Core.DB
  alias Core.Registry, as: BrainRegistry
  alias ElixirAiCore.Schemas.BrainCell
  alias LexiconEnricher

  # ────────────────────────
  # Public API
  # ────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Retrieves all brain cells associated with the given word.
  Follows 3-tier lookup: Registry -> Ecto (Mnesia) -> LexiconEnricher.
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
        persisted = DB.all(from(b in BrainCell, where: b.word == ^word))

        case persisted do
          [] ->
            case LexiconEnricher.enrich(word) do
              {:ok, []} ->
                {:reply, {:error, :no_definitions_found}, state}

              {:ok, enriched_cells} when is_list(enriched_cells) ->
                DB.insert_all(BrainCell, Enum.map(enriched_cells, &Map.from_struct/1))

                statuses =
                  Enum.map(enriched_cells, fn cell ->
                    with {:ok, pid} <- BrainRegistry.register(cell) do
                      safe_status(pid)
                    else
                      err -> IO.inspect(err, label: "Register failed")
                    end
                  end)

                {:reply, statuses, state}

              {:error, reason} ->
                {:reply, {:error, {:enrich_failed, reason}}, state}

              other ->
                {:reply, {:error, {:unexpected_return, other}}, state}
            end

          persisted_cells ->
            statuses =
              Enum.map(persisted_cells, fn cell ->
                with {:ok, pid} <- BrainRegistry.register(cell) do
                  safe_status(pid)
                else
                  err -> IO.inspect(err, label: "Register failed")
                end
              end)

            {:reply, statuses, state}
        end

      active_cells ->
        statuses =
          Enum.map(active_cells, fn {_id, pid, _cell} ->
            case safe_status(pid) do
              {:ok, status} -> status
              {:error, reason} -> {:error, reason}
            end
          end)

        {:reply, statuses, state}
    end
  end

  # Safely get status from a BrainCell GenServer
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
