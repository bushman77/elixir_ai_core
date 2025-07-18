defmodule Brain do
  use GenServer

  alias Core.DB
  alias BrainCell
  alias LexiconEnricher
  alias Core.Registry, as: BrainRegistry

  ## Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Fetches a single active BrainCell for the given word.
  Returns nil if none found.
  """
  def get(word), do: GenServer.call(__MODULE__, {:get, word})

  @doc """
  Fetches all active BrainCells for the given word.
  """
  def get_all(word), do: GenServer.call(__MODULE__, {:get_all, word})

  @doc """
  Starts a BrainCell process for a given word and state if not already started.
  """
  def start_cell(%BrainCell{id: id} = cell) do
    case Registry.lookup(BrainRegistry, id) do
      [{_pid, _value}] -> :ok
      [] -> BrainCell.start_link(cell)
    end
  end

  @doc """
  Clears all registered brain cells (dangerous, for dev use only).
  """
  def reset_all do
    GenServer.call(__MODULE__, :reset)
  end

  ## Server Callbacks

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:get, word}, _from, state) do
    word_id = String.downcase(word)

    cell =
      BrainRegistry.query(word_id)
      |> Enum.find_value(fn {_id, pid, _value} ->
        case safe_status(pid) do
          {:ok, %BrainCell{} = c} -> c
          _ -> nil
        end
      end)

    {:reply, cell, state}
  end

  def handle_call({:get_all, word}, _from, state) do
    word_id = String.downcase(word)

    cells =
      BrainRegistry.query(word_id)
      |> Enum.map(fn {_id, pid, _value} ->
        case safe_status(pid) do
          {:ok, %BrainCell{} = c} -> c
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:reply, cells, state}
  end

  def handle_call(:reset, _from, state) do
    Registry.select(BrainRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
    |> Enum.each(fn pid -> Process.exit(pid, :kill) end)

    {:reply, :ok, state}
  end

  ## Private

  defp safe_status(pid) do
    try do
      BrainCell.status(pid)
    catch
      _, _ -> {:error, :crashed}
    end
  end
end

