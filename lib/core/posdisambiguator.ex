defmodule Core.POSDisambiguator do
  @moduledoc "Shortlist by attention+POS (soft); rank with intent/POS/recency/attention, then add POS-bigram coherence."

  alias Core.{DB, Token, POS, IntentPOSProfile}
  alias Brain
  alias BrainCell

  # ---------- weights (tune-friendly) ----------
  @w_intent    0.28
  @w_pos       0.22
  @w_recency   0.10
  @w_attn      0.15
  @w_cohere    0.25

  @pos_match_reward  1.0
  @pos_miss_penalty  0.35   # instead of zeroing; keeps recall
  @attn_hit_prior    1.0
  @attn_miss_prior   0.65   # not zero; just a softer prior

  # Tiny POS bigram prior to avoid wild switches (very small, safe defaults)
  @pos_bigram %{
    # prev => %{next => bonus}
    interjection: %{noun: 0.05, pron: 0.05, verb: 0.03},
    det:          %{adj: 0.07, noun: 0.12},
    adj:          %{noun: 0.10},
    noun:         %{verb: 0.06, aux: 0.04, prep: 0.05},
    pron:         %{aux: 0.05, verb: 0.06, noun: 0.03},
    aux:          %{verb: 0.10},
    verb:         %{det: 0.05, pron: 0.05, adv: 0.04, prep: 0.04},
    prep:         %{det: 0.10, pron: 0.06, noun: 0.05},
    adv:          %{verb: 0.05, adj: 0.04}
  }

  @doc """
  Disambiguate to one BrainCell per token index.

  Options:
    * :intent     - current intent atom (defaults :unknown)
    * :vtags      - list of canonical POS ([:noun, :verb, ...]) for each token (optional)
    * :debug?     - if true, returns {final_map, debug_map} where debug_map shows scored candidates

  Returns: %{index => %BrainCell{}} or {map, debug} if :debug? true
  """
  @spec disambiguate([Token.t()], keyword()) :: %{integer() => BrainCell.t()} | {map, map}
  def disambiguate(tokens, opts \\ []) do
    intent = opts[:intent] || :unknown
    vtags  = opts[:vtags]  || Enum.map(tokens, &first_pos_or_nil/1)
    debug? = opts[:debug?] || false

    state = safe_sys_state(Brain)
    attn  = Map.get(state, :attention, MapSet.new())
    log   = Map.get(state, :activation_log, [])

    # 1) shortlist candidates per token (soft attention & POS)
    cands_by_ix =
      tokens
      |> Enum.with_index()
      |> Enum.map(fn {tok, i} -> {i, shortlist_soft(tok, attn)} end)
      |> Enum.into(%{})

    # bail fast if truly nothing
    if Enum.all?(cands_by_ix, fn {_i, cs} -> cs == [] end) do
      if debug?, do: {%{}, %{}}, else: %{}
    else
      run_disambiguation(cands_by_ix, vtags, intent, log, debug?)
    end
  end

  # ------------ main two-pass ------------
  defp run_disambiguation(cands_by_ix, vtags, intent, log, debug?) do
    bias_for = build_intent_bias(intent)

    # pass 1: local scores (intent + pos + recency + attention prior)
    first_pick_with_dbg =
      Enum.map(cands_by_ix, fn {i, cells} ->
        scored =
          cells
          |> Enum.map(fn {c, priors} ->
            {local_score(c, Enum.at(vtags, i), bias_for, log, priors), c, priors}
          end)
          |> Enum.sort_by(&elem(&1, 0), :desc)

        best = scored |> List.first() |> case do {_, c, _} -> c; _ -> nil end
        {{i, best}, {i, scored}}
      end)

    first_pick = first_pick_with_dbg |> Enum.map(&elem(&1, 0)) |> Enum.into(%{})
    dbg_local  = first_pick_with_dbg |> Enum.map(&elem(&1, 1)) |> Enum.into(%{})

    # pass 2: add coherence using POS bigram against neighbors' provisional POS
    final_with_dbg =
      Enum.map(cands_by_ix, fn {i, cells} ->
        prev_pos = pick_pos(first_pick, i - 1)
        next_pos = pick_pos(first_pick, i + 1)

        scored =
          cells
          |> Enum.map(fn {c, priors} ->
            s_local = local_score(c, Enum.at(vtags, i), bias_for, log, priors)
            s_coh   = coherence_score_bigram(c, prev_pos, next_pos)
            {s_local + s_coh, c, priors, %{local: s_local, cohere: s_coh}}
          end)
          |> Enum.sort_by(&elem(&1, 0), :desc)

        best = scored |> List.first() |> case do {_, c, _, _} -> c; _ -> nil end
        {{i, best}, {i, scored}}
      end)

    final_pick = final_with_dbg |> Enum.map(&elem(&1, 0)) |> Enum.into(%{})
    dbg_cohere = final_with_dbg |> Enum.map(&elem(&1, 1)) |> Enum.into(%{})

    if debug? do
      debug = %{local: dbg_local, final: dbg_cohere}
      {final_pick, debug}
    else
      final_pick
    end
  end

  # ------------ scoring pieces ------------

  defp local_score(%BrainCell{} = c, vpos, bias_for, log, priors) do
    pos = POS.normalize(c.pos)

    s_intent  = @w_intent  * bias_for.(pos)
    s_pos     = @w_pos     * (if(vpos && pos == vpos, do: @pos_match_reward, else: @pos_miss_penalty))
    s_recency = @w_recency * recency_boost(c.id, log)
    s_attn    = @w_attn    * Map.get(priors, :attn_prior, @attn_miss_prior)

    s_intent + s_pos + s_recency + s_attn
  end

  defp coherence_score_bigram(%BrainCell{} = c, prev_pos, next_pos) do
    pos = POS.normalize(c.pos)
    left  = if prev_pos, do: get_in(@pos_bigram, [prev_pos, pos]) || 0.0, else: 0.0
    right = if next_pos, do: get_in(@pos_bigram, [pos, next_pos]) || 0.0, else: 0.0
    @w_cohere * (left + right) |> min(@w_cohere) # clamp
  end

  defp build_intent_bias(intent) do
    tags = POS.canonical_tags()
    vec  = IntentPOSProfile.get(intent) # normalized vector over tags
    fn pos ->
      idx = Enum.find_index(tags, &(&1 == POS.normalize(pos))) || 0
      Enum.at(vec, idx) || 0.0
    end
  end

  defp recency_boost(id, log) do
    # newest first in your log; fade as index grows (1.0, 0.5, 0.33, …)
    case Enum.find_index(log, fn e -> e.id == id end) do
      nil -> 0.0
      idx -> 1.0 / (1 + idx)
    end
  end

  # ------------ shortlist (SOFT) ------------

  # Returns [{%BrainCell{}, %{attn_prior: float}}]
  defp shortlist_soft(%Token{phrase: w, pos: pos_list}, attn) do
    word = String.downcase(w || "")
    rows = DB.get_braincells_by_word(word)

    # If no lexicon rows, nothing to rank
    if rows == [] do
      []
    else
      wanted =
        pos_list
        |> List.wrap()
        |> Enum.map(&POS.normalize/1)
        |> Enum.uniq()

      # POS soft filter: prefer matches, but keep a few non-matches
      {matches, nonmatches} =
        Enum.split_with(rows, fn %BrainCell{pos: p} ->
          wanted == [] or POS.normalize(p) in wanted
        end)

      kept =
        case {matches, nonmatches} do
          {[], []}      -> []
          {[], nm}      -> Enum.take(nm, 3)         # backoff if POS gave nothing
          {m, []}       -> m
          {m, nm}       -> m ++ Enum.take(nm, 2)    # keep a couple as safety net
        end

      Enum.map(kept, fn c ->
        prior =
          if MapSet.member?(attn, c.id),
            do: @attn_hit_prior,
            else: @attn_miss_prior

        {c, %{attn_prior: prior}}
      end)
    end
  end

  # ------------ utils ------------

  defp pick_pos(map, idx) do
    case Map.get(map, idx) do
      %BrainCell{pos: p} -> POS.normalize(p)
      _ -> nil
    end
  end

  defp safe_sys_state(server), do: (try do :sys.get_state(server) rescue _ -> %{} end)
  defp first_pos_or_nil(%Token{pos: [h | _]}), do: POS.normalize(h)
  defp first_pos_or_nil(%Token{pos: h}) when is_atom(h) or is_binary(h), do: POS.normalize(h)
  defp first_pos_or_nil(_), do: nil
end

