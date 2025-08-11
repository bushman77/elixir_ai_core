defmodule Brain do
  use GenServer

alias Core.{SemanticInput, Token, DB}
  alias BrainCell
  alias LexiconEnricher
# at top of Brain.ex with the other aliases
import Ecto.Query, only: [from: 2]


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

def get_all_phrases do
  Brain.get_all()
  |> Enum.map(& &1.word)
  |> Enum.filter(&String.contains?(&1, " "))
end


def get_cells(token) do
  GenServer.call(Brain, {:get_cells, token})
end

def link_cells(%SemanticInput{token_structs: tokens} = input) do
    cells =
      tokens
      |> Enum.map(&BrainCell.get(&1.phrase))
      |> Enum.filter(& &1) # remove nils

    %{input | cells: cells}
  end

@doc "Fetches a BrainCell struct directly from the DB by ID or Token."
def get(%Core.Token{phrase: phrase}), do: get(phrase)
def get(id) when is_binary(id), do: DB.get(BrainCell, id)
def get(_), do: nil  # fallback for unsupported types

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
def handle_call({:get_cells, token}, _from, state) do
 cells =
 state.active_cells
 |> Map.keys()
 |> Enum.filter(fn key ->
   String.starts_with?(key, "#{token.phrase}|")
 end)
 |> Enum.filter(& &1)  # Remove any nils
  {:reply, cells, state}
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
  case Registry.lookup(Core.Registry, id) do
    [] ->
      {:ok, _pid} = BrainCell.start_link(cell)
    _ ->
      :ok  # already started
  end
end

# ...

@doc """
Export labeled training pairs from BrainCell rows.

Rules:
  * Uses `example` as the training text (must be present and non-empty).
  * Uses `type` as the intent label. Accepts "intent:greeting", :greeting, "greeting".
  * Cleans text (lowercase, remove non-alnum except spaces and apostrophes).
  * Deduplicates by {text,intent}.
Options:
  * :intents      -> restrict to a list of allowed intents (strings or atoms)
  * :min_len      -> drop examples with text shorter than this (default 1)
  * :limit_per    -> cap items per intent to avoid class skew (default: nil = no cap)
"""
def training_pairs(opts \\ []) do
  intents_opt  = Keyword.get(opts, :intents, nil)
  min_len      = Keyword.get(opts, :min_len, 1)
  limit_per    = Keyword.get(opts, :limit_per, nil)

  # Pull only rows that can yield supervised pairs
  q =
    from c in BrainCell,
      where: not is_nil(c.example) and c.example != "" and not is_nil(c.type),
      select: %{text: c.example, intent: c.type}

  Core.DB.all(q)
  |> Enum.map(fn %{text: t, intent: i} ->
    %{text: clean_text(t), intent: normalize_intent(i)}
  end)
  |> Enum.filter(& &1.intent)                          # keep only rows with a usable intent
  |> Enum.filter(fn %{text: t} -> String.length(t) >= min_len end)
  |> maybe_restrict_intents(intents_opt)
  |> dedup_by_text_intent()
  |> maybe_cap_per_intent(limit_per)
end

# ---------- helpers ----------

defp normalize_intent(i) when is_atom(i), do: Atom.to_string(i)
defp normalize_intent(i) when is_binary(i) do
  i
  |> String.downcase()
  |> String.trim()
  |> String.replace_prefix("intent:", "")
  |> String.replace_prefix("int:", "")
  |> case do
    "" -> nil
    s  -> s
  end
end
defp normalize_intent(_), do: nil

defp clean_text(s) do
  s
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9\s']/u, " ")
  |> String.replace(~r/\s+/, " ")
  |> String.trim()
end

defp dedup_by_text_intent(rows) do
  rows
  |> Enum.reduce({MapSet.new(), []}, fn %{text: t, intent: i} = row, {seen, acc} ->
    key = {t, i}
    if MapSet.member?(seen, key), do: {seen, acc}, else: {MapSet.put(seen, key), [row | acc]}
  end)
  |> elem(1)
  |> Enum.reverse()
end

defp maybe_restrict_intents(rows, nil), do: rows
defp maybe_restrict_intents(rows, intents) do
  allow =
    intents
    |> Enum.map(fn x -> if is_atom(x), do: Atom.to_string(x), else: String.downcase(to_string(x)) end)
    |> MapSet.new()

  Enum.filter(rows, fn %{intent: i} -> MapSet.member?(allow, i) end)
end

defp maybe_cap_per_intent(rows, nil), do: rows
defp maybe_cap_per_intent(rows, cap) when is_integer(cap) and cap > 0 do
  rows
  |> Enum.group_by(& &1.intent)
  |> Enum.flat_map(fn {_i, rs} -> rs |> Enum.shuffle() |> Enum.take(cap) end)
end

end

