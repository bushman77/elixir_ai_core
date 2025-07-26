defmodule Core.IntentClassifier do
  @moduledoc """
  Intent classification with flexible pattern matching,
  confidence scoring, and keyword-based boosts.
  """

  @intents [:greeting, :farewell, :question, :command, :request, :statement, :affirmation, :negation, :exclamation]

  @patterns %{
    greeting: [
      [:interjection],
      [:interjection, :pronoun],
      [:interjection, {:optional, :pronoun}]
    ],
    farewell: [
      [:interjection, :pronoun],
      [:interjection, {:optional, :pronoun}]
    ],
    question: [
      [:verb, :pronoun],
      [:aux, :pronoun],
      [:aux, :pronoun, :noun]
    ],
    command: [
      [:verb],
      [:verb, :noun],
      [:verb, {:optional, :adverb}],
      [:verb, :noun, {:optional, :adverb}]
    ],
    request: [
      [:verb, :pronoun, :noun],
      [:verb, :noun],
      [:verb, :pronoun],
      [:verb]
    ],
    statement: [
      [:pronoun, :verb],
      [:noun, :verb]
    ],
    affirmation: [
      [:adverb],
      [:adverb, :verb]
    ],
    negation: [
      [:adverb, :verb],
      [:adverb, :pronoun]
    ],
    exclamation: [
      [:interjection, :noun]
    ]
  }

  # Keyword boosts: keyword => {intent, boost_amount}
  @keyword_boosts %{
    "please" => {:request, 0.4},
    "hey" => {:greeting, 0.25},
    "hello" => {:greeting, 0.3},
    "hi" => {:greeting, 0.3},
    "no" => {:negation, 0.4},
    "never" => {:negation, 0.5},
    "thanks" => {:affirmation, 0.3},
    "thank" => {:affirmation, 0.3}
  }

  def classify(tokens) do
    pos_lists = Enum.map(tokens, & &1.pos)
    combos = build_combinations(pos_lists)

    # Find candidate intents & base confidence from pattern matches
    candidates =
      for intent <- @intents,
          combo <- combos,
          match_pattern?(intent, combo),
          do: {intent, confidence(intent, combo)}

    # Aggregate confidence by intent (sum all matches)
    base_confidences = 
      candidates
      |> Enum.group_by(fn {intent, _} -> intent end, fn {_, conf} -> conf end)
      |> Enum.map(fn {intent, confs} -> {intent, Enum.sum(confs)} end)

    # Calculate keyword boosts for present keywords
    boosts = calculate_keyword_boosts(tokens)

    # Combine base confidence + boosts per intent
    combined_scores = 
      @intents
      |> Enum.map(fn intent -> 
        base = Keyword.get(base_confidences, intent, 0.0)
        boost = Map.get(boosts, intent, 0.0)
        {intent, base + boost}
      end)

    # Select intent with max combined score or :unknown if zero
{best_intent, best_conf} =
  combined_scores
  |> Enum.max_by(fn {_intent, score} -> score end, fn -> {:unknown, 0.0} end)

best_intent = if best_conf > 0.0, do: best_intent, else: :unknown
keyword = extract_keyword(tokens)  # 👈 Add this line

{:ok,
 %{
   tokens: tokens,
   intent: best_intent,
   confidence: best_conf,
   keyword: keyword,
   debug: %{
     base_confidences: base_confidences,
     keyword_boosts: boosts,
     combined_scores: combined_scores,
     tokens: tokens
   }
 }}
end

  defp calculate_keyword_boosts(tokens) do
    # Downcase all words for case-insensitive matching
    token_words = Enum.map(tokens, &String.downcase(&1.word))

    # Find all boosts from keywords present
    Enum.reduce(token_words, %{}, fn word, acc ->
      case Map.get(@keyword_boosts, word) do
        {intent, boost} ->
          Map.update(acc, intent, boost, &(&1 + boost))
        _ -> acc
      end
    end)
  end

  # Pattern matching with :any and {:optional, pos}
  defp match_pattern?(intent, pos_combo) do
    Enum.any?(@patterns[intent] || [], fn pattern ->
      match_pattern(pattern, pos_combo)
    end)
  end

  defp match_pattern([], []), do: true

  defp match_pattern([{:optional, _} | _], []), do: true

  defp match_pattern([{:optional, pos} | rest_pattern], [h | rest_combo]) do
    match_pattern(rest_pattern, [h | rest_combo]) or (pos == h and match_pattern(rest_pattern, rest_combo))
  end

  defp match_pattern([:any | rest_pattern], [_ | rest_combo]) do
    match_pattern(rest_pattern, rest_combo)
  end

  defp match_pattern([p | rest_pattern], [p | rest_combo]) do
    match_pattern(rest_pattern, rest_combo)
  end

  defp match_pattern(_, _), do: false

  defp confidence(_intent, pos_combo) do
    length(pos_combo) / 10.0
  end

  defp build_combinations(pos_lists) do
    pos_lists
    |> Enum.map(&Enum.uniq/1)
    |> combine()
  end

  defp combine([head | tail]) do
    Enum.reduce(tail, Enum.map(head, &[&1]), fn list, acc ->
      for x <- acc, y <- list, do: x ++ [y]
    end)
  end

  defp combine([]), do: []

  defp extract_keyword([%{word: word} | _]), do: word
  defp extract_keyword(_), do: "that"
end

