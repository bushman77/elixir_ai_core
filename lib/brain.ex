defmodule Brain do
  use GenServer

  alias Core.{SemanticInput, Token, DB, Vocab}
  alias BrainCell
  alias LexiconEnricher
  alias Core.IntentPOSProfile
  import Ecto.Query, only: [from: 2]

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

  # async update (what you asked for)
  def set_llm_ctx(ctx, model \\ nil),
    do: GenServer.cast(__MODULE__, {:set_llm_ctx, ctx, model})

  # convenience: clear/reset
  def clear_llm_ctx, do: GenServer.cast(__MODULE__, :clear_llm_ctx)

  # read (sync)
  def get_llm_ctx, do: GenServer.call(__MODULE__, :get_llm_ctx)


  @doc "Fast snapshot (attention / activation_log / active_cells) without :sys.get_state/1."
  def snapshot(), do: GenServer.call(@name, :snapshot)

  @doc "Registers an activation event for a brain cell by ID."
  @spec register_activation(String.t()) :: :ok
def register_activation(id) when is_binary(id) do
  GenServer.cast(@name, {:activation, id, System.system_time(:millisecond)})
  :ok
end
  @spec attention([Token.t()]) :: [BrainCell.t()]
  def attention(token_list), do: GenServer.call(@name, {:attention, token_list})

# in brain.ex
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
    w = String.downcase(word)

    short?      = String.length(w) < 3
    multiword?  = String.contains?(w, " ")
    functional? = match?([_ | _], Core.MultiwordPOS.lookup(w))

    if short? or multiword? or functional? do
      {:ok, []}
    else
      do_get_or_start(w)
    end
  end

  ## ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(state), do: {:ok, state}

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
      |> Enum.filter(fn {id, _pid} -> String.starts_with?(id, prefix) end)
      |> Enum.map(fn {id, _pid} -> id end)

    {:reply, cells, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:activation, id, ts}, state) do
    updated_log = [%{id: id, at: ts} | Enum.take(state.activation_log, @activation_log_max - 1)]

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

@impl true
def handle_info({:after_attention, ids}, state) do
  # ids may be phrases or cell IDs; normalize safely
  if ids != [] and mailbox_ok?() do
    strengthen_connections_lite_by_ids(ids)
  end
  {:noreply, state}
end


  # Bounded, cross-word strengthening to avoid N^2 blowups.
# Treat both "word|pos|idx" and "word" gracefully
defp strengthen_connections_lite_by_ids(ids) when is_list(ids) do
  cells =
    ids
    |> Enum.flat_map(&cells_for_id_or_phrase/1)   # returns a list of %BrainCell{}
    |> Enum.filter(& &1)                          # drop nils just in case

  # Need at least two distinct words to form pairs
  groups = Enum.group_by(cells, & &1.word)
  words  = Map.keys(groups)

  if length(words) < 2 do
    :ok
  else
    # Build unique, non-repeating word pairs without fragile integer ranges
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
    # Cell ID format "word|pos|idx"
    String.contains?(id_or_phrase, "|") ->
      case get(id_or_phrase) do
        %BrainCell{} = c -> [c]
        _ -> []
      end

    true ->
      # Phrase: fetch all braincells for that word
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

  ## ── Dataset Export (unchanged) ───────────────────────────────────────────────

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
  """
  @spec ensure_started(BrainCell.t() | Token.t() | String.t()) ::
          {:ok, pid()} | :ok | {:error, term()}
  def ensure_started(%BrainCell{} = cell), do: ensure_cell_started(cell)
  def ensure_started(%Token{phrase: phrase}), do: phrase |> get_or_start() |> first_pid_or_ok()
  def ensure_started(phrase) when is_binary(phrase), do: phrase |> get_or_start() |> first_pid_or_ok()
  defp first_pid_or_ok({:ok, [pid | _]}), do: {:ok, pid}
  defp first_pid_or_ok({:ok, []}),        do: :ok
  defp first_pid_or_ok(other),            do: other

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

  # Optional deterministic placeholder until you have a trained embedding layer
  defp deterministic_vec(token_id, dim) do
    a = rem(token_id, 65_536)
    b = rem(div(token_id, 65_536), 65_536)
    :rand.seed_s(:exsss, {a, b, 12345})
    vec = for _ <- 1..dim, do: :rand.uniform() - 0.5
    norm = :math.sqrt(Enum.reduce(vec, 0.0, fn x, acc -> acc + x * x end))
    Enum.map(vec, & &1 / (norm + 1.0e-8))
  end

  ## ── Enrichment & startup ─────────────────────────────────────────────────────

  defp do_get_or_start(word_id) do
    if Application.get_env(:elixir_ai_core, :enrichment_enabled, false) do
      case DB.get_braincells_by_word(word_id) do
        [] ->
          case LexiconEnricher.enrich(word_id) do
            {:ok, cells} when is_list(cells) ->
              cells
              |> Enum.each(fn tmpl ->
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
                |> ensure_cell_started()
              end)

              {:ok, []}

            _ ->
              {:error, :not_found}
          end

        cells ->
          Enum.each(cells, &ensure_cell_started/1)
          {:ok, []}
      end
    else
      case DB.get_braincells_by_word(word_id) do
        []    -> {:error, :enrichment_disabled}
        cells -> Enum.each(cells, &ensure_cell_started/1); {:ok, []}
      end
    end
  end

  ## ── Pipe-friendly pruning (soft) ─────────────────────────────────────────────

# Pipe-friendly: schedule pruning on the Brain process (not the caller).
@doc "Pipe-friendly: tries to prune non-top POS for the current intent, but returns `sem` unchanged."
def prune_by_intent_pos(%{intent: intent} = sem) when is_atom(intent) do
  if pid = Process.whereis(@name) do
    Process.send_after(pid, {:prune_soft, intent}, 0)
  end
  sem
end

def prune_by_intent_pos(sem), do: sem

  @impl true
  def handle_info({:prune_soft, intent}, state) do
    tags  = IntentPOSProfile.tags()
    proto = IntentPOSProfile.get(intent)

    top_k_pos =
      proto
      |> Enum.with_index()
      |> Enum.sort_by(fn {v, _i} -> -v end)
      |> Enum.take(@k)
      |> Enum.map(fn {_v, i} -> Enum.at(tags, i) end)
      |> MapSet.new()

    Enum.each(state.active_cells, fn {cell_id, pid} ->
      pos = pos_of(cell_id)
      if not MapSet.member?(top_k_pos, pos) do
        GenServer.cast(pid, {:attenuate, @atten})
      end
    end)

    {:noreply, state}
  end

  defp pos_of(id) do
    [_w, pos, _sense] = String.split(id, "|")
    case pos do
      "noun" -> :noun
      "verb" -> :verb
      "adjective" -> :adj
      "adverb" -> :adv
      "pronoun" -> :pron
      "determiner" -> :det
      "aux" -> :aux
      "adposition" -> :adp
      "conjunction" -> :conj
      "numeral" -> :num
      "particle" -> :part
      "interjection" -> :intj
      "punct" -> :punct
      _ -> :unknown
    end
  end


  def handle_cast({:set_llm_ctx, ctx, model}, state) do
    # keep model sticky unless caller provides a new one
    m = model || state.llm_model

    # optional guard: if model changes, you may want to reset instead
    state =
      if state.llm_model && m && state.llm_model != m do
        %{state | llm_ctx: nil, llm_model: m}
      else
        state
      end

    trimmed = trim_ctx(ctx, state.llm_max)

    {:noreply,
     %{state |
       llm_ctx: trimmed,
       llm_model: m,
       llm_ctx_updated_at: System.system_time(:millisecond)}}
  end

  def handle_cast(:clear_llm_ctx, state),
    do: {:noreply, %{state | llm_ctx: nil, llm_model: nil}}

  def handle_call(:get_llm_ctx, _from, state),
    do: {:reply, %{ctx: state.llm_ctx, model: state.llm_model}, state}

  # ── Helpers ───────────────────────────────────────────────────────────────
  defp trim_ctx(nil, _), do: nil
  defp trim_ctx(list, max) when is_list(list) do
    len = length(list)
    if len <= max, do: list, else: Enum.drop(list, len - max)
  end

end

