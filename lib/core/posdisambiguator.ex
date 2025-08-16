defmodule POSDisambiguator do
  @moduledoc "Shortlist by POS; rank with POS-patterns + simple context."
  alias Core.{DB, Token}
  alias BrainCell

  # Use raw tuples: {:opt, tag}, {:many, tag}, {:oneof, [tags]}
  # NOTE: tags here are lowercase atoms; adjust pos_norm/1 if your tagger differs.
  @patterns [
    {:np_basic,    [{:opt, :det}, {:many, :adj}, :noun],                                1.0},
    {:vp_trans,    [{:opt, :pron}, {:opt, :aux}, :verb, {:oneof, [:noun, :pron]}],      1.0},
    {:exist_there, [:pron, {:oneof, [:aux, :verb]}],                                    1.2}, # “there is/are…”
    {:greeting,    [:intj, {:opt, :pron}],                                              0.8}  # “hello there”
  ]

  @spec disambiguate([Token.t()]) :: %{integer() => BrainCell.t()}
  def disambiguate(tokens) do
    tags = Enum.map(tokens, &top_pos/1)  # normalized to lowercase atoms

    tokens
    |> Enum.with_index()
    |> Enum.map(fn {tok, i} ->
      cands = shortlist(tok)

      best =
        cands
        |> Enum.map(fn c -> {score_candidate(c, i, tags), c} end)
        |> Enum.sort_by(&elem(&1, 0), :desc)
        |> case do
          [{_s, c} | _] -> c
          _ -> nil
        end

      {i, best}
    end)
    |> Enum.reject(fn {_i, v} -> is_nil(v) end)
    |> Map.new()
  end

  # ---------- shortlist by POS ----------
  defp shortlist(%Token{phrase: w, pos: pos_list}) do
    word = String.downcase(w || "")
    rows = DB.get_braincells_by_word(word)

    pos_strings =
      pos_list
      |> List.wrap()
      |> Enum.map(&pos_to_string/1)
      |> Enum.reject(&is_nil/1)

    if pos_strings == [] do
      rows
    else
      Enum.filter(rows, fn %BrainCell{pos: p} -> p in pos_strings end)
    end
  end

  defp pos_to_string(nil), do: nil
  defp pos_to_string(a) when is_atom(a),   do: a |> Atom.to_string() |> String.downcase()
  defp pos_to_string(s) when is_binary(s), do: String.downcase(s)

  # ---------- scoring ----------
  defp score_candidate(%BrainCell{} = c, i, tags) do
    pos_bonus = if norm_pos(c.pos) == Enum.at(tags, i), do: 1.0, else: 0.5
    pat_bonus = pattern_score(i, tags)
    conn_bonus = 0.25  # TODO: add neighborhood/connection coherence
    pos_bonus + pat_bonus + conn_bonus
  end

  defp norm_pos(nil), do: nil
  defp norm_pos(p) when is_binary(p), do: p |> String.downcase() |> String.to_atom()
  defp norm_pos(a) when is_atom(a),   do: a |> Atom.to_string() |> String.downcase() |> String.to_atom()

  # ---------- pattern engine ----------
  defp pattern_score(i, tags) do
    ctx = Enum.slice(tags, max(i - 1, 0), 3)  # [prev, here, next]

    Enum.reduce(@patterns, 0.0, fn {_name, pat, w}, best ->
      if pat_match?(ctx, pat), do: max(best, w), else: best
    end)
  end

  # Avoid clashing with Kernel.match?/2 by naming this pat_match?/2

  # Base: empty pattern
  defp pat_match?(seq, []), do: seq in [[], nil]

  # Optional: skip if absent
  defp pat_match?([], [{:opt, _} | rest]) do
    pat_match?([], rest)
  end

  # Optional: consume if present, otherwise continue
  defp pat_match?([h | t], [{:opt, x} | rest]) do
    if h == x, do: pat_match?(t, rest), else: pat_match?([h | t], rest)
  end

  # Many: zero or more occurrences (greedy with fallback)
  defp pat_match?(seq, [{:many, x} = m | rest]) do
    pat_match?(seq, rest) ||
      case seq do
        [h | t] when h == x -> pat_match?(t, [m | rest])
        _ -> false
      end
  end

  # One-of: must match one from the set
  defp pat_match?([h | t], [{:oneof, xs} | rest]) do
    (h in xs) and pat_match?(t, rest)
  end

  # Exact match for the next tag
  defp pat_match?([h | t], [h | rest]) do
    pat_match?(t, rest)
  end

  # Fallback: no match
  defp pat_match?(_seq, _pat), do: false

  # ---------- POS normalization ----------
  defp top_pos(%Token{pos: [h | _]}), do: pos_norm(h)
  defp top_pos(%Token{pos: h}) when is_atom(h) or is_binary(h), do: pos_norm(h)
  defp top_pos(_), do: nil

  defp pos_norm(tag) when is_atom(tag),
    do: tag |> Atom.to_string() |> String.downcase() |> String.to_atom()

  defp pos_norm(tag) when is_binary(tag),
    do: tag |> String.downcase() |> String.to_atom()

  defp pos_norm(_), do: nil
end

