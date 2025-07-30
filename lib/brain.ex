defmodule Brain do
  use GenServer

  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  ## Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      active_cells: %{},     # %{id => pid}
      activation_log: [],    # list of %{id, at}
      attention: MapSet.new()
    }, name: __MODULE__)
  end

  def attention(token_list) do
    GenServer.call(__MODULE__, {:attention, token_list})
  end

  @doc "Fetches a BrainCell struct directly from the DB by ID."
  def get(id), do: DB.get(BrainCell, id)

  @doc """
  Gets or starts BrainCell processes for a given word.
  Relies on BrainCell processes to register themselves after start.
  """
  def get_or_start(word) when is_binary(word) do
    word_id = String.downcase(word)

    case Registry.lookup(Core.Registry, word_id) do
      [{pid, _} | _] ->
        {:ok, pid}

      [] ->
        case DB.get_braincells_by_word(word_id) do
          [] ->
            case LexiconEnricher.enrich(word_id) do
              {:ok, cells} when is_list(cells) ->
                Enum.each(cells, &BrainCell.start_link/1)
                {:ok, :started}

              _ ->
                {:error, :not_found}
            end

          cells ->
            Enum.each(cells, &BrainCell.start_link/1)
            {:ok, :started}
        end
    end
  end

  @doc "Registers an activation event for a brain cell by ID."
  def register_activation(id) do
    GenServer.cast(__MODULE__, {:activation, id, System.system_time(:second)})
  end

  @doc "Returns the current internal state of the brain."
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  ## GenServer Callbacks

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:attention, tokens}, _from, state) do
    {found_cells, new_attention} =
      Enum.reduce(tokens, {[], state.attention}, fn %{phrase: phrase}, {acc, attn} ->
        case get(phrase) do
          %BrainCell{} = cell ->
            {[cell | acc], MapSet.put(attn, cell.id)}

          _ ->
            {acc, attn}
        end
      end)

    # Hebbian learning: fire together, wire together
    strengthen_connections(found_cells)

    {:reply, found_cells, %{state | attention: new_attention}}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:activation, id, ts}, state) do
    updated_log = [%{id: id, at: ts} | Enum.take(state.activation_log, 99)]

    if function_exported?(MoodCore, :register_activation, 1) do
      case get(id) do
        %BrainCell{} = cell -> MoodCore.register_activation(cell)
        _ -> :noop
      end
    end

    {:noreply, %{state | activation_log: updated_log}}
  end

  @impl true
  def handle_info({:cell_started, {id, pid}}, state) do
    new_state = put_in(state.active_cells[id], pid)
    {:noreply, new_state}
  end

  ## Hebbian Helpers

  defp strengthen_connections(cells) when length(cells) > 1 do
    for a <- cells, b <- cells, a.id != b.id, do: increase_connection_strength(a, b)
  end

  defp strengthen_connections(_), do: :ok

  defp increase_connection_strength(from, to) do
    updated_connections =
      case Enum.find(from.connections, fn conn -> conn["to"] == to.id end) do
        nil ->
          [%{"to" => to.id, "strength" => 0.1} | from.connections]

        %{"to" => _to_id, "strength" => strength} = conn ->
          rest = Enum.reject(from.connections, fn c -> c["to"] == to.id end)
          [%{"to" => to.id, "strength" => min(strength + 0.1, 1.0)} | rest]
      end

    update_braincell_connections(from.id, updated_connections)
  end

  defp update_braincell_connections(id, new_connections) do
    id
    |> DB.get!(BrainCell)
    |> BrainCell.changeset(%{connections: new_connections})
    |> DB.update()
  end

# Public: Fetches all BrainCells for a single phrase or a list of tokens
def get_all(%Core.Token{phrase: phrase}), do: get_all(phrase)

def get_all(tokens) when is_list(tokens) do
  tokens
  |> Enum.flat_map(&get_all/1)
end

def get_all(phrase) when is_binary(phrase) do
  DB.get_braincells_by_word(String.downcase(phrase))
end

def ensure_started(%BrainCell{} = cell) do
  case GenServer.whereis({:via, Registry, {Core.Registry, cell.id}}) do

    nil ->
      {:ok, _pid} = BrainCell.start_link(cell)
    _pid ->
      :ok
  end
end

def store(%BrainCell{} = cell) do
  ensure_cell_started(cell)
end

def store(_), do: :ok


def ensure_cell_started(%BrainCell{id: id} = cell) do
  case Registry.lookup(Brain.Registry, id) do
    [] ->
      {:ok, _pid} = BrainCell.start_link(cell)
    _ ->
      :ok  # already started
  end
end

end

