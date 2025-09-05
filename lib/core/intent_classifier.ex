defmodule Core.IntentClassifier do
  @moduledoc """
  Determines user intent using weighted POS patterns + lexical bonuses
  with top-2 margin confidence and keyword extraction.

  Small overrides:
    * deny:  "no" / "nope" / "nah"
    * greet: sentences starting with "thank you" (but not when tokens contain `thanks_mwe`)
  """
  alias Core.POS

  @intent_patterns %{
    greet: [
      [:interjection, :noun],
      [:interjection],
      [:interjection, :verb],
      [:interjection, :pronoun],
      [:interjection, :adverb],
      [:noun, :verb, :interjection]
    ],
    bye: [
      [:interjection],
      [:verb, :adverb],
      [:interjection, :verb],
      [:verb, :noun],
      [:interjection, :noun]
    ],
    question: [
      [:adverb, :auxiliary, :pronoun],
      [:verb, :pronoun],
      [:adverb, :verb],
      [:auxiliary, :noun, :verb],
      [:interjection, :auxiliary, :pronoun],
      [:pronoun, :verb, :noun],
      [:modal, :pronoun, :verb]
    ],
    command: [
      [:verb, :noun],
      [:verb],
      [:verb, :determiner, :noun],
      [:verb, :preposition, :noun],
      [:interjection, :verb],
      [:noun, :verb, :noun]
    ],
    confirm: [
      [:interjection],
      [:adverb],
      [:verb],
      [:interjection, :verb]
    ],
    deny: [
      [:adverb, :verb],
      [:interjection],
      [:interjection, :adverb],
      [:verb, :adverb]
    ],
    thank: [
      [:interjection, :pronoun],
      [:interjection],
      [:verb, :pronoun],
      [:verb, :noun]
    ],
    inform: [
      [:noun, :verb, :noun],
      [:pronoun, :verb, :noun],
      [:noun, :verb],
      [:pronoun, :verb],
      [:verb, :determiner, :noun]
    ],
    why: [
      [:adverb, :auxiliary, :pronoun],
      [:adverb, :verb, :noun],
      [:interjection, :adverb, :verb],
      [:adverb, :modal, :pronoun, :verb]
    ]
  }

  @intent_base %{
    greet: 1.6,
    bye: 1.4,
    question: 1.5,
    command: 1.5,
    confirm: 1.1,
    deny: 1.1,
    thank: 1.4,
    inform: 1.2,
    why: 1.6
  }

  @thanks_lex ~w(thanks thank thx ty thankyou)
  @insult_lex ~w(fuck idiot stupid dumb asshole jerk)
  @bye_lex    ~w(bye goodbye later cya farewell)
  @deny_lex   ~w(no nope nah)

  @doc """
  Classifies intent based on weighted patterns, bonuses, and top-2 margin confidence.
  Adds :intent (atom), :confidence (0..1), :keyword (string | nil), :source (:classifier).
  """
  def classify_tokens(%{token_structs: token_structs} = struct) do
    pos_lists = Enum.map(token_structs, & &1.pos)
    combos    = POS.cartesian_product(pos_lists)

    texts =
      token_structs
      |> Enum.map(&String.downcase((&1.phrase || &1.text || "") |> String.trim()))
      |> Enum.reject(&(&1 == ""))

    scored =
      @intent_patterns
      |> Enum.map(fn {intent, patterns} ->
        base = Map.get(@intent_base, intent, 1.0)
        pattern_hit = if any_pattern_match?(patterns, combos), do: base, else: 0.0
        bonus = bonus_for_intent(intent, token_structs, texts)
        {intent, Float.round(pattern_hit + bonus, 4)}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)

    {intent, confidence} = decide(scored, token_structs, texts, pos_lists)
    keyword = extract_keyword(intent, token_structs, texts)

    struct
    |> Map.merge(%{intent: intent, confidence: confidence, keyword: keyword, source: :classifier})
    |> apply_overrides(token_structs, texts)
  end

  def classify(%{token_structs: _} = struct), do: classify_tokens(struct)
  def classify(other), do: other

  # ---------- scoring helpers ----------

  defp any_pattern_match?(patterns, combos),
    do: Enum.any?(patterns, &(&1 in combos))

  defp bonus_for_intent(:greet, token_structs, texts) do
    greetingish =
      Enum.any?(texts, &(&1 in ~w(hi hello hey yo sup))) or
      has_mwe?(token_structs, "greeting_mwe")

    cond do
      greetingish and match_first?(token_structs, :interjection) -> 0.7
      greetingish -> 0.5
      true -> 0.0
    end
  end

  defp bonus_for_intent(:thank, toks, texts) do
    if Enum.any?(texts, &(&1 in @thanks_lex)) or has_mwe?(toks, "thanks_mwe"),
      do: 0.7, else: 0.0
  end

  defp bonus_for_intent(:bye, _toks, texts) do
    if Enum.any?(texts, &(&1 in @bye_lex)), do: 0.45, else: 0.0
  end

  defp bonus_for_intent(:question, token_structs, texts) do
    wh = Enum.any?(token_structs, fn t -> Enum.member?(t.pos, :wh) end)
    qm = ends_with_qmark?(texts)
    front_aux = starts_with_any_pos?(token_structs, [:auxiliary, :modal])

    cond do
      wh and qm       -> 0.7
      wh or front_aux -> 0.5
      qm              -> 0.35
      true            -> 0.0
    end
  end

  defp bonus_for_intent(:why, token_structs, _texts) do
    if Enum.any?(token_structs, &Enum.member?(&1.pos, :wh)), do: 0.25, else: 0.0
  end

  defp bonus_for_intent(:command, token_structs, _texts) do
    case token_structs do
      [t1 | rest] ->
        verb_start   = Enum.member?(t1.pos, :verb)
        not_question = not Enum.any?(token_structs, &Enum.member?(&1.pos, :wh))
        next_blocker =
          Enum.any?(rest, fn t -> Enum.any?(t.pos, &(&1 in [:modal, :auxiliary])) end)

        if verb_start and not_question and not next_blocker, do: 0.45, else: 0.0

      _ -> 0.0
    end
  end

  defp bonus_for_intent(:deny, _toks, texts) do
    if Enum.any?(texts, &(&1 in ~w(no nah nope negative not dont can't cannot))), do: 0.5, else: 0.0
  end

  defp bonus_for_intent(:confirm, _toks, texts) do
    if Enum.any?(texts, &(&1 in ~w(yes yeah yup ok okay sure correct exactly))), do: 0.5, else: 0.0
  end

  defp bonus_for_intent(:inform, token_structs, _texts) do
    sv_like =
      contains_sequence?(token_structs, [:noun, :verb]) or
      contains_sequence?(token_structs, [:pronoun, :verb])

    if sv_like, do: 0.25, else: 0.0
  end

  defp bonus_for_intent(_other, _toks, _texts), do: 0.0

  # ---------- decision & confidence ----------

  defp decide([], _toks, _texts, _pos), do: {:unknown, 0.0}

  defp decide([{intent, top} | rest], token_structs, texts, pos_lists) do
    if top <= 0.0 do
      rescue_decide(token_structs, texts, pos_lists)
    else
      second =
        case rest do
          [{_, s} | _] -> s
          _ -> 0.0
        end

      margin = max(top - second, 0.0)

      conf =
        cond do
          margin >= 1.0  -> 1.0
          margin >= 0.6  -> 0.85
          margin >= 0.35 -> 0.7
          margin >= 0.2  -> 0.6
          true           -> 0.55
        end

      {intent, conf}
    end
  end

  defp rescue_decide(_toks, texts, pos_lists) do
    insult = Enum.any?(texts, &(&1 in @insult_lex))

    questionish =
      Enum.any?(List.flatten(pos_lists), &(&1 == :wh)) or
      Enum.any?(texts, &String.ends_with?(&1, "?"))

    cond do
      insult      -> {:insult, 0.9}
      questionish -> {:question, 0.65}
      true        -> {:unknown, 0.0}
    end
  end

  # ---------- keyword extraction ----------

  defp extract_keyword(:greet, token_structs, texts) do
    Enum.find(texts, &(&1 in ~w(hi hello hey yo sup))) ||
      first_pos(token_structs, :interjection)
  end

  defp extract_keyword(:thank, toks, texts) do
    cond do
      has_mwe?(toks, "thanks_mwe") -> "thank you"
      true -> Enum.find(texts, &(&1 in @thanks_lex))
    end
  end

  defp extract_keyword(:bye, _toks, texts),
    do: Enum.find(texts, &(&1 in @bye_lex))

  defp extract_keyword(:question, token_structs, texts) do
    Enum.find(texts, &String.ends_with?(&1, "?")) ||
      first_pos(token_structs, :wh) ||
      Enum.find(texts, &(&1 in ~w(time price weather)))
  end

  defp extract_keyword(:command, token_structs, _texts),
    do: first_pos(token_structs, :verb)

  defp extract_keyword(:inform, token_structs, _texts),
    do: first_pos(token_structs, :noun)

  defp extract_keyword(_other, _toks, _texts), do: nil

  # ---------- post-classification overrides ----------

  defp apply_overrides(%{sentence: _} = sem, toks, _texts) do
    s =
      (Map.get(sem, :original_sentence) || Map.get(sem, :sentence) || "")
      |> to_string()
      |> String.downcase()
      |> String.trim()

    cond do
      # clear negatives → :deny
      s in @deny_lex ->
        %{sem | intent: :deny, keyword: nil,
                confidence: max(sem.confidence || 0.0, 0.85),
                source: :classifier}

      # “thank you …” → greet only when we DIDN’T get thanks_mwe from tokenizer
      String.starts_with?(s, "thank you") and not has_mwe?(toks, "thanks_mwe") ->
        %{sem | intent: :greet, keyword: "thank you",
                confidence: max(sem.confidence || 0.0, 0.6),
                source: :classifier}

      true ->
        sem
    end
  end

  # ---------- utilities ----------

  defp first_pos(tokens, pos_tag) do
    tokens
    |> Enum.find_value(fn t ->
      if Enum.member?(t.pos, pos_tag) do
        (t.phrase || t.text || "") |> String.downcase()
      else
        nil
      end
    end)
  end

  defp contains_sequence?(tokens, sequence) do
    pos_atoms = Enum.map(tokens, &List.first(&1.pos))
    Enum.chunk_every(pos_atoms, length(sequence), 1, :discard)
    |> Enum.any?(fn chunk -> chunk == sequence end)
  end

  defp match_first?([t | _], tag), do: Enum.member?(t.pos, tag)
  defp match_first?(_, _), do: false

  defp starts_with_any_pos?([t | _], tags),
    do: Enum.any?(tags, fn tag -> Enum.member?(t.pos, tag) end)

  defp starts_with_any_pos?(_, _), do: false

  defp ends_with_qmark?(texts) do
    case List.last(texts) do
      nil -> false
      last -> String.ends_with?(last, "?")
    end
  end

  defp has_mwe?(tokens, mwe_name),
    do: Enum.any?(tokens, fn t ->
      String.downcase(t.phrase || t.text || "") == mwe_name
    end)
end

