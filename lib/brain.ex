defmodule Brain do
  use GenServer
  require Logger

  alias Core.{SemanticInput, Token, DB, Vocab}
  alias BrainCell
  alias LexiconEnricher
  alias Core.IntentPOSProfile

  import Ecto.Query, only: [from: 2]  # queries still go through Core.DB

  @registry Core.Registry
  @name __MODULE__

  @embedding_dim 256
  @k 4          # keep top-k POS for the winning intent
  @atten 0.6    # multiply activation by this for non-matching POS

  # Background work caps / knobs
  @strengthen_max_pairs 80
  @activation_log_max  100

  ## ── Public API ───────────────────────────────────────────────────────────────

  def start_link(_args) do
    GenServer.start_link(
      __MODULE__,
      %{
        active_cells: %{},
        activation_log: [],
        attention: MapSet.new(),
        llm_ctx: nil,
        llm_model: nil,
        llm_max: 8192,
        llm_ctx_updated_at: nil
      },
      name: @name
    )
  end

# ── Pipe-friendly pruning (soft) ─────────────────────────────────────────────
@doc "Pipe-friendly: schedule pruning on the Brain process; returns `sem` unchanged."
def prune_by_intent_pos(%{intent: intent} = sem) when is_atom(intent) do
  if pid = Process.whereis(__MODULE__) do
    Process.send_after(pid, {:prune_soft, intent}, 0)
  end
  sem
end

def prune_by_intent_pos(sem), do: sem


  # LLM ctx (unchanged behavior)
  def set_llm_ctx(ctx, model \\ nil),
    do: GenServer.cast(__MODULE__, {:set_llm_ctx, ctx, model})

  def clear_llm_ctx, do: GenServer.cast(__MODULE__, :clear_llm_ctx)
  def get_llm_ctx,   do: GenServer.call(__MODULE__, :get_llm_ctx)

  @doc "Fast snapshot (attention / activation_log / active_cells)."
  def snapshot(), do: GenServer.call(@name, :snapshot)

  @doc "Remember a running cell pid under its id (e.g., \"word|pos|idx\")."
  def register_active(id, pid) when is_binary(id) and is_pid(pid) do
    GenServer.cast(__MODULE__, {:register_active, id, pid})
  end

  @doc "Find a cell pid by its registry id."
  def whereis(id) when is_binary(id) do
    if is_pid(Process.whereis(@registry)) do
      case Registry.lookup(@registry, id) do
        [{pid, _} | _] -> pid
        _ -> nil
      end
    else
      nil
    end
  end

  @doc "Registers an activation event for a brain cell by ID (or phrase on cold start)."
  @spec register_activation(String.t()) :: :ok
  def register_activation(id) when is_binary(id) do
    GenServer.cast(@name, {:activation, id, System.system_time(:millisecond)})
    :ok
  end

  @spec attention([Token.t()]) :: [BrainCell.t()]
  def attention(token_list), do: GenServer.call(@name, {:attention, token_list})

  def attention_phrases(list) when is_list(list) do
    tokens = Enum.map(list, &%Core.Token{phrase: &1})
    attention(tokens)
  end

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
      |> Enum.flat_map(fn
        %Token{phrase: p} when is_binary(p) -> get_all(p)   # word -> [BrainCell, ...]
        _other -> []
      end)

    %{input | cells: cells}
  end

  @doc "Fetch a BrainCell struct from the DB by id or from a token."
  @spec get(Token.t() | String.t()) :: BrainCell.t() | nil
  def get(%Token{phrase: phrase}), do: get(phrase)
  def get(id) when is_binary(id), do: DB.get(BrainCell, id)
  def get(_), do: nil

# lib/brain.ex

@doc """
Ensure processes exist for all cells tied to `word`.
DB-first. If DB is empty: try remote enrichment.
If enrichment returns nothing: create a minimal placeholder cell so we still start a PID.
"""
@spec get_or_start(String.t()) :: {:ok, [pid()]} | {:error, term()}
def get_or_start(word) when is_binary(word) do
  w = String.downcase(word)

  cells =
    case DB.get_braincells_by_word(w) do
      [] ->
        # 1) Try remote enrichment unconditionally on DB miss
        case safe_enrich(w) do
          {:ok, enriched_any?} when enriched_any? ->
            DB.get_braincells_by_word(w)

          _ ->
            # 2) Remote has nothing → create a minimal placeholder row and proceed
            # (keeps console happy, reduces "dead air", later runs can rehydrate richer data)
            pos = fallback_pos_for(w)
            _   = ensure_braincell(w, pos)
            DB.get_braincells_by_word(w)
        end

      rs ->
        rs
    end

  case cells do
    [] ->
      # should be rare (e.g., ensure failed), but don’t crash the pipeline
      {:error, :not_found}

    list ->
      pids =
        list
        |> Enum.map(&ensure_cell_started/1)
        |> Enum.map(fn
          {:ok, pid} when is_pid(pid) -> pid
          :ok -> nil
          other ->
            Logger.debug("ensure_cell_started returned #{inspect(other)}")
            nil
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, pids}
  end
end

# --- helpers (place these anywhere in Brain) ---

# Run enricher safely; return {:ok, true} if it inserted anything
defp safe_enrich(w) do
  try do
    case LexiconEnricher.enrich(w) do
      {:ok, templates} when is_list(templates) and templates != [] ->
        Enum.each(templates, fn tmpl ->
          idx  = parse_idx!(tmpl.id)
          cell = ensure_braincell(tmpl.word, tmpl.pos, sense_index: idx)

          changes = %{
            definition:     tmpl.definition,
            example:        tmpl.example,
            synonyms:       tmpl.synonyms,
            antonyms:       tmpl.antonyms,
            semantic_atoms: tmpl.semantic_atoms,
            type:           tmpl.type,
            function:       tmpl.function,
            status:         tmpl.status
          }

          cell
          |> BrainCell.changeset(changes)
          |> DB.update!()
        end)

        {:ok, true}

      _ ->
        {:ok, false}
    end
  rescue
    e ->
      Logger.debug("enrich(#{w}) failed: #{Exception.message(e)}")
      {:error, e}
  end
end

# Conservative POS guess so we can at least start a process on first touch.
# (You can refine this anytime.)
defp fallback_pos_for(w) do
  low = String.downcase(w)
  cond do
    low in ~w(hello hi hey howdy yo) -> "interjection"
    low in ~w(there here away abroad) -> "adverb"
    String.match?(low, ~r/^\d+$/) -> "numeral"
    true -> "noun"
  end
end

# Let Core call get_or_start/2; we just delegate and return a single pid if present
def get_or_start(word, _pos) when is_binary(word) do
  case get_or_start(word) do
    {:ok, [pid | _]} when is_pid(pid) -> {:ok, pid}
    {:ok, list} when is_list(list) ->
      case Enum.find(list, &is_pid/1) do
        nil -> {:ok, []}
        pid -> {:ok, pid}
      end
    other -> other
  end
end


  ## ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    state = %{
      attention: MapSet.new(),
      activation_log: [],
      active_cells: %{},
      llm_ctx: nil,
      llm_model: nil,
      llm_ctx_updated_at: nil,
      llm_max: 8192
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    reply = Map.take(state, [:attention, :activation_log, :active_cells])
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:attention, tokens}, _from, state) do
    # DB-backed cells (may be empty initially)
    cells = tokens |> Enum.flat_map(&get_all/1)
    ids   = Enum.map(cells, & &1.id)

    # Fallback to phrases so we still log activity on a cold start
    phrases =
      tokens
      |> Enum.map(fn
        %Token{phrase: p} when is_binary(p) -> String.downcase(p)
        other -> to_string(other)
      end)

    log_ids = if ids == [], do: phrases, else: ids

    new_attention = Enum.reduce(log_ids, state.attention, &MapSet.put(&2, &1))
    ts = System.system_time(:millisecond)

    new_log =
      log_ids
      |> Enum.map(&%{id: &1, at: ts})
      |> Kernel.++(state.activation_log)
      |> Enum.take(@activation_log_max)

    if log_ids != [] do
      Process.send_after(self(), {:after_attention, log_ids}, 0)
      Enum.each(log_ids, &register_activation/1)
    end

    {:reply, cells, %{state | attention: new_attention, activation_log: new_log}}
  end

  @impl true
  def handle_call({:get_cells, %Token{phrase: phrase}}, _from, state) do
    prefix = "#{phrase}|"

    cells =
      state.active_cells
      |> Enum.filter(fn {id, _entry} -> String.starts_with?(id, prefix) end)
      |> Enum.map(fn {id, _entry} -> id end)

    {:reply, cells, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:register_active, id, pid}, state) do
    ref   = Process.monitor(pid)
    entry = %{pid: pid, ref: ref, since: System.system_time(:millisecond)}
    active = Map.put(state.active_cells || %{}, id, entry)
    {:noreply, %{state | active_cells: active}}
  end

  @impl true
  def handle_cast({:activation, id, ts}, state) do
    updated_log = [%{id: id, at: ts} | Enum.take(state.activation_log, @activation_log_max - 1)]

    # Optional: Mood coupling if a cell row exists
    if function_exported?(MoodCore, :register_activation, 1) do
      with %BrainCell{} = cell <- get(id) do
        MoodCore.register_activation(cell)
      end
    end

    {:noreply, %{state | activation_log: updated_log}}
  end

  @impl true
  def handle_info({:after_attention, ids}, state) do
    if ids != [] and mailbox_ok?() do
      strengthen_connections_lite_by_ids(ids)
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {dead_id, _entry} =
      Enum.find(state.active_cells || %{}, fn {_id, m} -> match?(%{ref: ^ref}, m) end) || {nil, nil}

    active =
      if dead_id, do: Map.delete(state.active_cells || %{}, dead_id), else: (state.active_cells || %{})

    {:noreply, %{state | active_cells: active}}
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
      [{pid, _} | _] ->
        register_active(id, pid)
        {:ok, pid}

      [] ->
        normalize_start(BrainCell.start_link(cell))
        |> case do
          {:ok, pid} ->
            register_active(id, pid)
            {:ok, pid}

          :ok ->
            # Already started without pid info; try to find then register.
            case whereis(id) do
              pid when is_pid(pid) ->
                register_active(id, pid)
                {:ok, pid}

              _ -> :ok
            end

          other ->
            other
        end
    end
  end

  defp normalize_start({:ok, pid}),                        do: {:ok, pid}
  defp normalize_start({:error, {:already_started, pid}}), do: {:ok, pid}
  defp normalize_start({:error, {:already_started, _}}),   do: :ok
  defp normalize_start(other),                              do: other

  ## ── Connection strengthening (safe & bounded) ───────────────────────────────

  defp strengthen_connections_lite_by_ids(ids) when is_list(ids) do
    cells =
      ids
      |> Enum.flat_map(&cells_for_id_or_phrase/1)
      |> Enum.filter(& &1)

    groups = Enum.group_by(cells, & &1.word)
    words  = Map.keys(groups)

    if length(words) < 2 do
      :ok
    else
      pairs =
        for {wa, ia} <- Enum.with_index(words),
            {wb, ib} <- Enum.with_index(words),
            ia < ib,
            a <- Map.fetch!(groups, wa),
            b <- Map.fetch!(groups, wb) do
          {a, b}
        end

      pairs
      |> Enum.take(@strengthen_max_pairs)
      |> Enum.each(fn {a, b} -> increase_connection_strength(a, b) end)

      :ok
    end
  end

  defp cells_for_id_or_phrase(id_or_phrase) when is_binary(id_or_phrase) do
    cond do
      String.contains?(id_or_phrase, "|") ->
        case get(id_or_phrase) do
          %BrainCell{} = c -> [c]
          _ -> []
        end

      true ->
        DB.get_braincells_by_word(String.downcase(id_or_phrase)) || []
    end
  end

  defp increase_connection_strength(from, to) do
    updated_connections =
      case Enum.find(from.connections, fn conn -> conn["to"] == to.id end) do
        nil ->
          [%{"to" => to.id, "strength" => 0.1} | from.connections]

        %{"to" => _to_id, "strength" => strength} ->
          rest = Enum.reject(from.connections, fn c -> c["to"] == to.id end)
          [%{"to" => to.id, "strength" => min(strength + 0.1, 1.0)} | rest]
      end

    _ = update_braincell_connections!(from.id, updated_connections)
    :ok
  end

  defp update_braincell_connections!(id, new_connections) do
    DB.get!(BrainCell, id)
    |> BrainCell.changeset(%{connections: new_connections})
    |> DB.update!()
  end

  defp mailbox_ok?() do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, n} -> n < 200
      _ -> true
    end
  end

  ## ── Dataset Export (kept) ───────────────────────────────────────────────────

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

  defp maybe_cap_per_intent(rows, cap) when is_integer(cap) and cap > 0 do
    rows
    |> Enum.group_by(& &1.intent)
    |> Enum.flat_map(fn {_i, rs} -> rs |> Enum.shuffle() |> Enum.take(cap) end)
  end

  ## ── Back-compat shim ─────────────────────────────────────────────────────────

  @doc "Compatibility for older callers that use `Brain.ensure_started/1`."
  @spec ensure_started(BrainCell.t() | Token.t() | String.t()) ::
          {:ok, pid()} | :ok | {:error, term()}
  def ensure_started(%BrainCell{} = cell),              do: ensure_cell_started(cell)
  def ensure_started(%Token{phrase: phrase}),           do: phrase |> get_or_start() |> first_pid_or_ok()
  def ensure_started(phrase) when is_binary(phrase),    do: phrase |> get_or_start() |> first_pid_or_ok()
  defp first_pid_or_ok({:ok, [pid | _]}),               do: {:ok, pid}
  defp first_pid_or_ok({:ok, []}),                      do: :ok
  defp first_pid_or_ok(other),                          do: other

  ## ── ID helpers ───────────────────────────────────────────────────────────────

  defp id_for(word, pos, sense_index), do: "#{word}|#{pos}|#{sense_index}"

  defp parse_idx!(id) do
    case String.split(id, "|") do
      [_w, _p, idx] -> String.to_integer(idx)
      _ -> raise ArgumentError, "bad id format: #{inspect(id)}"
    end
  end

  defp next_index_for(word, pos) do
    ids =
      DB.all(
        from c in BrainCell,
          where: c.word == ^word and c.pos == ^pos,
          select: c.id
      )

    case ids do
      [] -> 1
      ids -> ids |> Enum.map(&parse_idx!/1) |> Enum.max() |> Kernel.+(1)
    end
  end

  ## ── BrainCell creation (composite id "word|pos|idx") ─────────────────────────

  def ensure_braincell(word, pos, opts \\ []) when is_binary(word) and is_binary(pos) do
    sense_index = Keyword.get(opts, :sense_index) || next_index_for(word, pos)
    id = id_for(word, pos, sense_index)

    case DB.get(BrainCell, id) do
      nil ->
        token_id =
          case Vocab.get(word) do
            nil -> Vocab.upsert!(word).id
            v -> v.id
          end

        embedding = nil

        %BrainCell{
          id: id,
          word: word,
          pos: pos,
          token_id: token_id,
          embedding: embedding,
          embedding_model: if(embedding, do: "placeholder-#{@embedding_dim}"),
          embedding_updated_at: if(embedding, do: NaiveDateTime.utc_now())
        }
        |> BrainCell.changeset(%{})
        |> DB.insert!()

      cell ->
        cell
    end
  end

  # Optional deterministic embedding placeholder (kept for completeness)
  defp deterministic_vec(token_id, dim) do
    a = rem(token_id, 65_536)
    b = rem(div(token_id, 65_536), 65_536)
    :rand.seed_s(:exsss, {a, b, 12345})
    vec = for _ <- 1..dim, do: :rand.uniform() - 0.5
    norm = :math.sqrt(Enum.reduce(vec, 0.0, fn x, acc -> acc + x * x end))
    Enum.map(vec, & &1 / (norm + 1.0e-8))
  end

@impl true
def handle_info({:prune_soft, intent}, state) do
  tags  = Core.IntentPOSProfile.tags()
  proto = Core.IntentPOSProfile.get(intent)

  top_k =
    proto
    |> Enum.with_index()
    |> Enum.sort_by(fn {v, _i} -> -v end)
    |> Enum.take(@k)  # @k = 4
    |> Enum.map(fn {_v, i} -> Enum.at(tags, i) end)
    |> MapSet.new()

  Enum.each(state.active_cells || %{}, fn
    {cell_id, %{pid: pid}} ->
      pos = pos_of(cell_id)
      if is_atom(pos) and not MapSet.member?(top_k, pos) do
        GenServer.cast(pid, {:attenuate, @atten})
      end

    {cell_id, pid} when is_pid(pid) ->
      pos = pos_of(cell_id)
      if is_atom(pos) and not MapSet.member?(top_k, pos) do
        GenServer.cast(pid, {:attenuate, @atten})
      end

    _other ->
      :ok
  end)

  {:noreply, state}
end

# Parse POS out of the composite id "word|pos|idx"
defp pos_of(id) do
  case String.split(id, "|") do
    [_w, pos, _sense] ->
      case pos do
        "noun"        -> :noun
        "verb"        -> :verb
        "adjective"   -> :adj
        "adverb"      -> :adv
        "pronoun"     -> :pron
        "determiner"  -> :det
        "aux"         -> :aux
        "adposition"  -> :adp
        "conjunction" -> :conj
        "numeral"     -> :num
        "particle"    -> :part
        "interjection"-> :intj
        "punct"       -> :punct
        _             -> :unknown
      end

    _ -> :unknown
  end
end

# Handles {:cell_started, {id, pid}} sent by BrainCell.start_link/1 (or friends)
@impl true
def handle_info({:cell_started, {id, pid}}, state)
    when is_binary(id) and is_pid(pid) do
  ref    = Process.monitor(pid)
  entry  = %{pid: pid, ref: ref, since: System.system_time(:millisecond)}
  active = Map.put(state.active_cells || %{}, id, entry)
  {:noreply, %{state | active_cells: active}}
end

# Catch-all to avoid future unexpected-message crashes
@impl true
def handle_info(msg, state) do
  Logger.debug("Brain ignored message: #{inspect(msg)}")
  {:noreply, state}
end

end

