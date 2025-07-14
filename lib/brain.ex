defmodule Brain do
  use GenServer
  import Ecto.Query
  require Logger

  alias Core.DB
  alias Core.Registry, as: BrainRegistry
  alias BrainCell
  alias LexiconEnricher

  # ────────────────────────
  # Public API
  # ────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Retrieves all brain cells associated with the given word.
  Follows 3-tier lookup: Registry -> Ecto DB -> LexiconEnricher.
  """
  def get(word), do: GenServer.call(__MODULE__, {:get, word})

  @doc """
  Activates brain cells relevant to the given intent and tokens.
  """
  def activate_for_intent_and_tokens(intent, tokens) do
    intent_keywords = intent_keywords(intent)

    to_activate =
      tokens
      |> Enum.flat_map(fn %{word: w, pos: pos_list} ->
        Enum.map(pos_list, fn pos -> {w, pos} end)
      end)
      |> Enum.filter(fn {word, _pos} -> word in intent_keywords end)

    maybe_fire_cells([to_activate])
  end

  defp intent_keywords(:greeting), do: ["hello", "hi", "hey"]
  defp intent_keywords(:command), do: ["run", "start", "execute"]
  defp intent_keywords(_), do: []

  @doc """
  Iterates over lists of {word, pos} tuples and fires corresponding brain cells.
  If a cell doesn't exist, it enriches and starts it.
  """
  def maybe_fire_cells(pos_lists) do
    Enum.each(pos_lists, fn word_pos_list ->
      Enum.each(word_pos_list, fn
        {word, pos} ->
          Logger.debug("[Brain] Activating cell for #{word} (#{pos})")

          id = BrainCell.build_id(word, pos)

          case get_cell(id) do
            {:ok, _cell} ->
              fire_cell(id)

            :not_found ->
              case enrich_and_start(word, pos) do
                {:ok, new_cell} ->
                  fire_cell(new_cell.id)

                {:error, reason} ->
                  Logger.warn("[Brain] Failed to enrich and start cell for #{word} (#{pos}): #{inspect(reason)}")
              end
          end

        _ -> :noop
      end)
    end)
  end

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
                    case BrainRegistry.register(cell) do
                      {:ok, pid} -> safe_status(pid)
                      err -> 
                        Logger.error("[Brain] Register failed: #{inspect(err)}")
                        {:error, err}
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
                case BrainRegistry.register(cell) do
                  {:ok, pid} -> safe_status(pid)
                  err -> 
                    Logger.error("[Brain] Register failed: #{inspect(err)}")
                    {:error, err}
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

  # ────────────────────────
  # Helpers
  # ────────────────────────

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

  def get_cell(id) do
    case Registry.lookup(BrainRegistry, id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :not_found
    end
  end

  def fire_cell(id) do
    case get_cell(id) do
      {:ok, pid} ->
        GenServer.cast(pid, :fire)
        :ok

      :not_found ->
        {:error, :cell_not_found}
    end
  end

  def enrich_and_start(word, pos) do
    with {:ok, enriched_cells} <- LexiconEnricher.enrich(word),
         %BrainCell{} = cell <- Enum.find(enriched_cells, fn c -> pos in c.pos end) do
      DB.insert!(cell)

      case BrainRegistry.register(cell) do
        {:ok, pid} -> {:ok, cell}
        err ->
          Logger.error("[Brain] Failed to register cell: #{inspect(err)}")
          {:error, err}
      end
    else
      _ ->
        Logger.warn("[Brain] No matching cell found for #{word} with pos #{pos}")
        {:error, :no_matching_cell_found}
    end
  end
end

