defmodule Core.ViterbiLite do
  @moduledoc """
  Tiny Viterbi decoder for POS tagging with heuristics.
  Combines emission(word, tag) + transition(prev_tag, tag) + intent bias.
  """

  alias Core.POS
  alias Core.IntentPOSProfile

  @tags POS.canonical_tags()

  @type tag :: atom()

  @doc """
  Tag a list of token strings. Options:
    * :intent        -> atom (e.g., :greeting)
    * :candidates_fn -> (token -> [tag]) returns candidate tags per token
    * :beam          -> integer beam width (default 5)
  Returns: %{tags: [tag], confidences: [0.0..1.0]}
  """
  def tag(tokens, opts \\ []) when is_list(tokens) do
    tokens = Enum.map(tokens, &normalize_tok/1)
    beam   = opts[:beam] || 5
    intent = normalize_intent(opts[:intent])

    cand_fn =
      case opts[:candidates_fn] do
        fun when is_function(fun, 1) -> fun
        _ -> &default_candidates/1
      end

    cand_lists =
      Enum.map(tokens, fn tok ->
        cands = cand_fn.(tok)
        cands = if cands == [], do: @tags, else: cands
        cands |> Enum.map(&POS.normalize/1) |> Enum.uniq()
      end)

    # optional: intent bias vector over canonical order
    intent_bias =
      case intent do
        nil       -> List.duplicate(0.0, length(@tags))
        :unknown  -> List.duplicate(0.0, length(@tags))
        _         -> IntentPOSProfile.get(intent)
      end

    # dynamic program: each column is %{tag => {score, prev_tag}}
    columns =
      cand_lists
      |> Enum.with_index()
      |> Enum.reduce([], fn {cands, t}, acc ->
        col =
          if t == 0 do
            # start column: only emission + start bonus
            init_col(cands, tokens |> Enum.at(0), intent_bias)
          else
            prev_col = List.last(acc)
            build_col(prev_col, cands, tokens |> Enum.at(t), intent_bias, beam)
          end

        acc ++ [col]
      end)

    # backtrack best path
    last_col = List.last(columns)
    {last_tag, _best_score} = Enum.max_by(last_col, fn {_tag, {s, _prev}} -> s end, fn -> {:noun, {0.0, nil}} end)

    tags =
      columns
      |> Enum.reverse()
      |> Enum.reduce({last_tag, []}, fn col, {cur, acc} ->
        {_s, prev} = Map.get(col, cur)
        {prev, [cur | acc]}
      end)
      |> elem(1)

    # quick confidences per position: softmax over state scores at each column
    confidences =
      columns
      |> Enum.map(fn col ->
        scores = for {_tag, {s, _}} <- col, do: s
        soft_choice_probability(scores, Map.get(col, Enum.at(tags, Enum.find_index(columns, &(&1 == col)))) |> elem(0))
      end)

    %{tags: tags, confidences: confidences}
  end

  # ── internals ─────────────────────────────────────────────────────────────

  defp init_col(cands, tok, bias_vec) do
    Enum.into(cands, %{}, fn tag ->
      idx   = index_of(@tags, tag)
      bias  = Enum.at(bias_vec, idx) || 0.0
      score = start_score(tag) + emission_score(tok, tag) + bias_weight() * bias
      {tag, {score, nil}}
    end)
  end

  defp build_col(prev_col, cands, tok, bias_vec, beam) do
    # beam prune previous states
    prev_states =
      prev_col
      |> Enum.sort_by(fn {_t, {s, _}} -> -s end)
      |> Enum.take(beam)

    Enum.into(cands, %{}, fn tag ->
      idx   = index_of(@tags, tag)
      bias  = Enum.at(bias_vec, idx) || 0.0

      {best_prev_tag, best_score} =
        Enum.reduce(prev_states, {nil, -1.0e9}, fn {ptag, {ps, _}}, {best_t, best_s} ->
          s = ps + transition_score(ptag, tag) + emission_score(tok, tag) + bias_weight() * bias
          if s > best_s, do: {ptag, s}, else: {best_t, best_s}
        end)

      {tag, {best_score, best_prev_tag}}
    end)
  end

  # ——— scoring pieces ———

  defp start_score(tag) do
    # Nudge plausible sentence starts (adjs/nouns/verbs/interjections) a bit
    case tag do
      :intj -> 0.4
      :noun -> 0.2
      :verb -> 0.2
      :adj  -> 0.1
      _     -> 0.0
    end
  end

  defp transition_score(prev, cur) do
    # Minimal, sane transitions; tune/extend or learn online.
    cond do
      prev == nil -> 0.0
      prev == :det and cur in [:noun, :adj, :num, :pron] -> 0.6
      prev == :adj and cur in [:noun, :adj]              -> 0.4
      prev == :noun and cur in [:verb, :punct, :conj]    -> 0.3
      prev == :verb and cur in [:det, :adv, :noun, :pron]-> 0.4
      prev == :adv  and cur in [:verb, :adj]             -> 0.3
      prev == :pron and cur in [:verb, :aux]             -> 0.5
      prev == :aux  and cur == :verb                     -> 0.6
      prev == :adp  and cur in [:det, :noun, :pron]      -> 0.5
      prev == :conj                                     -> 0.2
      prev == :punct and cur in [:intj, :det, :noun]     -> 0.2
      true                                               -> -0.05
    end
  end

  defp emission_score(tok, tag) do
    # Very cheap lexical/shape cues
    lc = String.downcase(tok)
    has_digit = String.match?(tok, ~r/\d/)
    cap = case String.first(tok) do
      nil -> false
      c   -> c =~ ~r/[A-Z]/
    end

    base =
      cond do
        tag == :punct and String.length(tok) == 1 and tok =~ ~r/[[:punct:]]/ -> 0.8
        tag == :num   and has_digit                                          -> 0.7
        tag == :adv   and String.ends_with?(lc, "ly")                        -> 0.4
        tag == :adj   and String.ends_with?(lc, "ive")                       -> 0.2
        tag == :noun  and cap                                                -> 0.2   # proper-ish
        tag == :intj and lc in ~w(hey hi hello wow uh um)                    -> 0.9
        true -> 0.0
      end

    # Light penalty for mismatch-y tags on obvious tokens
    penalty =
      cond do
        tag == :punct and String.length(tok) > 1 -> -0.6
        true -> 0.0
      end

    base + penalty
  end

  defp bias_weight, do: 0.75  # how strong the intent POS profile should pull

  # ——— helpers ———

  defp normalize_tok(t) when is_binary(t), do: t
  defp normalize_tok(%{text: s}) when is_binary(s), do: s
  defp normalize_tok(other), do: to_string(other)

  defp index_of(list, x), do: Enum.find_index(list, &(&1 == x)) || 0

  # return P(best_state) among states via softmax
  defp soft_choice_probability(scores, best_score) do
    m = Enum.max(scores, fn -> 0.0 end)
    exps = Enum.map(scores, &(:math.exp(&1 - m)))
    denom = Enum.sum(exps) + 1.0e-12
    :math.exp(best_score - m) / denom
  end

  defp normalize_intent(nil), do: nil
  defp normalize_intent(:greet), do: :greeting
  defp normalize_intent(x) when is_atom(x), do: x
  defp normalize_intent(_), do: nil

  # Default candidates: allow most common POS; keep it small and fast.

defp default_candidates(tok) do
  lc = String.downcase(tok)
  cond do
    lc in ~w(hello hi hey) -> [:intj, :noun, :verb]
    String.match?(tok, ~r/^[[:punct:]]+$/u)     -> [:punct]   # was: /^\p{Punct}+$/u
    String.match?(tok, ~r/^\d+([.,]\d+)?$/u)    -> [:num]
    true -> [:noun, :verb, :adj, :adv, :pron, :det, :aux, :adp, :conj, :num, :part, :intj, :punct]
  end
end
end

