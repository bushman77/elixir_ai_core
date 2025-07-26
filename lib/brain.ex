defmodule Brain do
  use GenServer

  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  ## Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      active_cells: %{},   # %{id => pid}
      activation_log: [],  # list of %{id, at}
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
  Now relies on BrainCell processes to register themselves after start.
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
                Enum.each(cells, fn cell -> BrainCell.start_link(cell) end)
                {:ok, :started}

              _ ->
                {:error, :not_found}
            end

          cells ->
            Enum.each(cells, fn cell -> BrainCell.start_link(cell) end)
            {:ok, :started}
        end
    end
  end

  @doc "Registers an activation event for a brain cell by ID."
  def register_activation(id) do
    GenServer.cast(__MODULE__, {:activation, id, System.system_time(:second)})
  end

  @doc "Returns the current internal state of the brain."
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  ## GenServer Callbacks

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:attention, tokens}, _from, state) do
    {found_cells, new_attention} =
      Enum.reduce(tokens, {[], state.attention}, fn %{phrase: phrase}, {acc, attn} ->
        case Brain.get(phrase) do
          %BrainCell{} = cell ->
            {[cell | acc], MapSet.put(attn, cell.id)}
          _ ->
            {acc, attn}
        end
      end)

    {:reply, found_cells, %{state | attention: new_attention}}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:activation, id, ts}, state) do
    updated_log = [%{id: id, at: ts} | Enum.take(state.activation_log, 99)]
    if function_exported?(MoodCore, :register_activation, 1) do
      if %BrainCell{} = cell = get(id) do
        MoodCore.register_activation(cell)
      end
    end
    {:noreply, %{state | activation_log: updated_log}}
  end

  @impl true
  def handle_info({:cell_started, {id, pid}}, state) do
    new_state = put_in(state.active_cells[id], pid)
    {:noreply, new_state}
  end
end

