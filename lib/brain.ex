defmodule Brain do
  use GenServer

  alias Core.{SemanticInput, Token, DB}
  alias BrainCell
  alias LexiconEnricher

  import Ecto.Query, only: [from: 2]

  @registry Core.Registry
  @name __MODULE__

  ## ── Public API ────────────────────────────────────────────────────────────────

  def start_link(_args) do
    GenServer.start_link(
      __MODULE__,
      %{active_cells: %{}, activation_log: [], attention: MapSet.new()},
      name: @name
    )
  end

  @spec attention([Token.t()]) :: [BrainCell.t()]
  def attention(token_list), do: GenServer.call(@name, {:attention, token_list})

  @spec get_all_phrases() :: [String.t()]
  def get_all_phrases do
    DB.all(from c in BrainCell, select: c.word)
    |> Enum.filter(&String.contains?(&1, " "))
  end

  @spec get_cells(Token.t()) :: [String.t()]
  def get_cells(%Token{} = token), do: GenServer.call(@name, {:get_cells, token})

  @spec link_cells(SemanticInput.t()) :: SemanticInput.t()
  def link_cells(%SemanticInput{token_structs: tokens} = input) do
    cells =
      tokens
      |> Enum.map(&get/1)
      |> Enum.filter(&match?(%BrainCell{}, &1))

    %{input | cells: cells}
  end

  @doc "Fetch a BrainCell struct from the DB by id or from a token."
  @spec get(Token.t() | String.t()) :: BrainCell.t() | nil
  def get(%Token{phrase: phrase}), do: get(phrase)
  def get(id) when is_binary(id), do: DB.get(BrainCell, id)
  def get(_), do: nil

  @doc """
  Ensure processes exist for all cells tied to `word`.
  If none exist in DB, attempts to enrich and then start.
  Returns {:ok, pids} (may be empty) or {:error, reason}.
  """
  @spec get_or_start(String.t()) :: {:ok, [pid()]} | {:error, term()}
  def get_or_start(word) when is_binary(word) do
    word_id = String.downcase(word)

    cells =
      case DB.get_braincells_by_word(word_id) do
        [] ->
          case LexiconEnricher.enrich(word_id) do
            {:ok, new_cells} when is_list(new_cells) -> new_cells
            _ -> []
          end

        cs ->
          cs
      end

    case cells do
      [] ->
        {:error, :not_found}

      cs ->
        pids =
          cs
          |> Enum.map(&ensure_cell_started/1)
          |> Enum.flat_map(fn
            {:ok, pid} -> [pid]
            :ok -> []
            _ -> []
          end)

        {:ok, pids}
    end
  end

  @doc "Registers an activation event for a brain cell by ID."
  def register_activation(id),
    do: GenServer.cast(@name, {:activation, id, System.system_time(:second)})

  @doc "Returns the current internal state of the brain."
  def get_state, do: GenServer.call(@name, :get_state)

  ## ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:attention, tokens}, _from, state) do
    {found_cells, new_attention} =
      Enum.reduce(tokens, {[], state.attention}, fn %Token{phrase: phrase}, {acc, attn} ->
        case get(phrase) do
          %BrainCell{} = cell -> {[cell | acc], MapSet.put(attn, cell.id)}
          _ -> {acc, attn}
        end
      end)

    strengthen_connections(found_cells)

    {:reply, Enum.reverse(found_cells), %{state | attention: new_attention}}
  end

  @impl true
  def handle_call({:get_cells, %Token{phrase: phrase}}, _from, state) do
    prefix = "#{phrase}|"

    cells =
      state.active_cells
      |> Enum.filter(fn {id, _pid} -> String.starts_with?(id, prefix) end)
      |> Enum.map(fn {id, _pid} -> id end)

    {:reply, cells, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:activation, id, ts}, state) do
    updated_log = [%{id: id, at: ts} | Enum.take(state.activation_log, 99)]

    if function_exported?(MoodCore, :register_activation, 1) do
      with %BrainCell{} = cell <- get(id) do
        MoodCore.register_activation(cell)
      end
    end

    {:noreply, %{state | activation_log: updated_log}}
  end

  @impl true
  def handle_info({:cell_started, {id, pid}}, state) do
    {:noreply, put_in(state.active_cells[id], pid)}
  end

  ## ── Hebbian Helpers ──────────────────────────────────────────────────────────

  defp strengthen_connections(cells) when length(cells) > 1 do
    for a <- cells, b <- cells, a.id != b.id, do: increase_connection_strength(a, b)
  end

  defp strengthen_connections(_), do: :ok

  defp increase_connection_strength(from, to) do
    updated_connections =
      case Enum.find(from.connections, fn conn -> conn["to"] == to.id end) do
        nil -> [%{"to" => to.id, "strength" => 0.1} | from.connections]
        %{"to" => _to_id, "strength" => strength} ->
          rest = Enum.reject(from.connections, fn c -> c["to"] == to.id end)
          [%{"to" => to.id, "strength" => min(strength + 0.1, 1.0)} | rest]
      end

    _ = update_braincell_connections(from.id, updated_connections)
    :ok
  end

  defp update_braincell_connections(id, new_connections) do
    id
    |> DB.get!(BrainCell)
    |> BrainCell.changeset(%{connections: new_connections})
    |> DB.update()
  end

  ## ── Lookups ─────────────────────────────────────────────────────────────────

  @spec get_all(Token.t()) :: [BrainCell.t()]
  def get_all(%Token{phrase: phrase}), do: get_all(phrase)

  @spec get_all([Token.t()]) :: [BrainCell.t()]
  def get_all(tokens) when is_list(tokens), do: Enum.flat_map(tokens, &get_all/1)

  @spec get_all(String.t()) :: [BrainCell.t()]
  def get_all(phrase) when is_binary(phrase),
    do: DB.get_braincells_by_word(String.downcase(phrase))

  ## ── Process Management ───────────────────────────────────────────────────────

  @spec ensure_cell_started(BrainCell.t()) :: {:ok, pid()} | :ok | {:error, term()}
  def ensure_cell_started(%BrainCell{id: id} = cell) do
    case Registry.lookup(@registry, id) do
      [{pid, _} | _] -> {:ok, pid}
      [] -> normalize_start(BrainCell.start_link(cell))
    end
  end

  defp normalize_start({:ok, pid}), do: {:ok, pid}
  defp normalize_start({:error, {:already_started, pid}}), do: {:ok, pid}
  defp normalize_start({:error, {:already_started, _}}), do: :ok
  defp normalize_start(other), do: other

  ## ── Dataset Export ──────────────────────────────────────────────────────────

  @doc """
  Export labeled training pairs from BrainCell rows.

  Options:
    * :intents   -> restrict to a list of allowed intents (strings or atoms)
    * :min_len   -> minimum text length (default 1)
    * :limit_per -> cap items per intent
  """
  @spec training_pairs(keyword()) :: [%{text: String.t(), intent: String.t()}]
  def training_pairs(opts \\ []) do
    intents_opt  = Keyword.get(opts, :intents, nil)
    min_len      = Keyword.get(opts, :min_len, 1)
    limit_per    = Keyword.get(opts, :limit_per, nil)

    q =
      from c in BrainCell,
        where: not is_nil(c.example) and c.example != "" and not is_nil(c.type),
        select: %{text: c.example, intent: c.type}

    DB.all(q)
    |> Enum.map(fn %{text: t, intent: i} -> %{text: clean_text(t), intent: normalize_intent(i)} end)
    |> Enum.filter(& &1.intent)
    |> Enum.filter(fn %{text: t} -> String.length(t) >= min_len end)
    |> maybe_restrict_intents(intents_opt)
    |> dedup_by_text_intent()
    |> maybe_cap_per_intent(limit_per)
  end

  # helpers

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
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    Enum.filter(rows, fn %{intent: i} -> MapSet.member?(allow, i) end)
  end

  defp maybe_cap_per_intent(rows, nil), do: rows
  defp maybe_cap_per_intent(rows, cap) when is_integer(cap) and cap > 0 do
    rows
    |> Enum.group_by(& &1.intent)
    |> Enum.flat_map(fn {_i, rs} -> rs |> Enum.shuffle() |> Enum.take(cap) end)
  end

  ## ── Back-compat shim ─────────────────────────────────────────────────────────

  @doc """
  Compatibility for older callers that use `Brain.ensure_started/1`.

  Accepts:
    * %BrainCell{} -> ensures that cell's process is running
    * %Token{}     -> ensures processes for the token's phrase
    * binary       -> ensures processes for the phrase (word)

  Normalizes results so `{:already_started, pid}` becomes `{:ok, pid}`.
  """
  @spec ensure_started(BrainCell.t() | Token.t() | String.t()) ::
          {:ok, pid()} | :ok | {:error, term()}
  def ensure_started(%BrainCell{} = cell), do: ensure_cell_started(cell)

  def ensure_started(%Token{phrase: phrase}), do:
    phrase |> get_or_start() |> first_pid_or_ok()

  def ensure_started(phrase) when is_binary(phrase), do:
    phrase |> get_or_start() |> first_pid_or_ok()

  defp first_pid_or_ok({:ok, [pid | _]}), do: {:ok, pid}
  defp first_pid_or_ok({:ok, []}),        do: :ok
  defp first_pid_or_ok(other),            do: other


end

