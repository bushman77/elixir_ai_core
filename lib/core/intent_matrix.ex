defmodule Core.IntentMatrix do
  @moduledoc "Pattern-weighted intent scorer (compile-order safe, with classify/1 shim)."

  @type intent :: atom()
  @type confidence :: float()

  # ---------- helpers (defined first) ----------

  defp down(t) do
    (t.phrase || t.text || "")
    |> String.downcase()
  end

  defp has_mwe?(tokens, name),
    do: Enum.any?(tokens, &(down(&1) == name))

  defp starts_with_interjection?(tokens) do
    case tokens do
      [t | _] -> Enum.member?(t.pos, :interjection)
      _ -> false
    end
  end

  defp has_interjection?(tokens, lexemes) do
    Enum.any?(tokens, fn t ->
      Enum.member?(t.pos, :interjection) and down(t) in lexemes
    end)
  end

  defp wh_about_noun?(tokens, noun) do
    Enum.any?(tokens, &Enum.member?(&1.pos, :wh)) and
      Enum.any?(tokens, fn t ->
        w = down(t)
        w == noun or (Enum.member?(t.pos, :noun) and w == noun)
      end)
  end

  defp contains_any?(tokens, words),
    do: Enum.any?(tokens, &(down(&1) in words))

  defp conf_from_margin(top, second) do
    margin = max(top - second, 0.0)

    cond do
      top == 0.0     -> 0.0
      margin >= 1.0  -> 1.0
      margin >= 0.5  -> 0.8
      margin >= 0.25 -> 0.6
      true           -> 0.5
    end
  end

  # ---------- rules as a function (no capture-order traps) ----------

  defp rules do
    [
      {:greeting, 2.0, fn toks ->
        starts_with_interjection?(toks) or has_mwe?(toks, "greeting_mwe")
      end},
      {:thanks, 1.6, fn toks ->
        has_interjection?(toks, ~w(thanks thank)) or has_mwe?(toks, "thanks_mwe")
      end},
      {:insult, 2.0, fn toks ->
        contains_any?(toks, ~w(fuck idiot stupid))
      end},
      {:question_time, 1.8, fn toks ->
        has_mwe?(toks, "what_time_mwe") or wh_about_noun?(toks, "time")
      end},
      {:price_query, 1.6, fn toks ->
        has_mwe?(toks, "how_much_mwe") or wh_about_noun?(toks, "price")
      end}
    ]
  end

  # ---------- public scoring ----------

  @spec score(list()) :: {intent, confidence}
  def score(tokens) do
    scored =
      for {intent, w, fun} <- rules() do
        if fun.(tokens), do: {intent, w}, else: {intent, 0.0}
      end
      |> Enum.sort_by(&elem(&1, 1), :desc)

    case scored do
      [{top_intent, top}, {_, second} | _] ->
        {top_intent, conf_from_margin(top, second)}

      [{top_intent, top}] ->
        {top_intent, if(top > 0.0, do: 0.7, else: 0.0)}

      _ ->
        {:unknown, 0.0}
    end
  end

  # ---------- back-compat shim (no struct patterns) ----------

  @doc """
  Accepts:
    * %Core.SemanticInput{}  (uses .token_structs)
    * [Core.Token.t()]       (direct token list)
    * [[Core.Token.t()]]     (nested; takes first list)
  Returns {intent, confidence}.
  """
  @spec classify(any()) :: {intent, confidence}
  def classify(input) do
    cond do
      is_semantic_input?(input) ->
        score(Map.get(input, :token_structs) || [])

      is_token_list?(input) ->
        score(input)

      is_list(input) and input != [] and is_token_list?(hd(input)) ->
        score(hd(input))

      true ->
        {:unknown, 0.0}
    end
  end

  # runtime checks (no compile-time struct expansion)
  defp is_semantic_input?(x) when is_map(x),
    do: Map.get(x, :__struct__) == Core.SemanticInput
  defp is_semantic_input?(_), do: false

  defp is_token?(x) when is_map(x),
    do: Map.get(x, :__struct__) == Core.Token
  defp is_token?(_), do: false

  defp is_token_list?(xs) when is_list(xs) and xs != [],
    do: is_token?(hd(xs))
  defp is_token_list?(_), do: false
end

