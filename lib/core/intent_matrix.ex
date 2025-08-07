defmodule Core.IntentMatrix do
  @moduledoc """
  Scores input token patterns to determine likely intent.

  Uses POS tagging patterns and keyword boosting to infer user intent.
  """

  alias Core.{Token, SemanticInput}

  @typedoc "Intent guess and score"
  @type guess :: %{
          intent: atom,
          keyword: String.t() | nil,
          score: float,
          source: atom
        }

  @default_intent :unknown
  @default_score 0.5

  @patterns Map.new([
    {[:interjection], %{greeting: 1.5}},
    {[:interjection, :noun], %{greeting: 1.2}},
    {[:noun, :verb], %{statement: 1.0}},
    {[:noun, :verb, :noun], %{statement: 1.1}},
    {[:verb], %{command: 1.0}},
    {[:verb, :noun], %{command: 1.2}},
    {[:verb, :preposition, :noun], %{command: 1.3}},
    {[:adjective, :noun], %{statement: 1.0}},
    {[:pronoun, :verb], %{statement: 1.1}},
    {[:pronoun, :modal, :verb], %{inquiry: 1.3}},
    {[:modal, :verb], %{inquiry: 1.2}},
    {[:modal, :verb, :noun], %{inquiry: 1.4}},
    {[:verb, :adverb], %{command: 1.0}},
    {[:preposition, :noun], %{command: 0.9}}
  ])

  @keyword_boosts %{
    "help" => %{intent: :inquiry, boost: 0.4},
    "why" => %{intent: :why, boost: 1.1},
    "hello" => %{intent: :greeting, boost: 0.7},
    "hi" => %{intent: :greeting, boost: 0.6},
    "hey" => %{intent: :greeting, boost: 0.6},
    "how" => %{intent: :inquiry, boost: 0.8},
    "what" => %{intent: :inquiry, boost: 0.7},
    "when" => %{intent: :inquiry, boost: 0.6},
    "where" => %{intent: :inquiry, boost: 0.6},
    "who" => %{intent: :inquiry, boost: 0.5},
    "do" => %{intent: :command, boost: 0.4},
    "please" => %{intent: :command, boost: 0.5},
    "tell" => %{intent: :command, boost: 0.7}
  }

  @doc """
  Classifies intent from a SemanticInput.
  """
  @spec classify(SemanticInput.t()) :: guess
  def classify(%SemanticInput{pos_list: pos_list, tokens: tokens}) do
    pos_list
    |> match_pattern()
    |> maybe_boost_with_keyword(tokens)
    |> Map.put(:source, :matrix)
  end

  @doc """
  Fallback: classifies directly from a list of tokens.
  Useful when SemanticInput is not yet formed.
  """
  @spec classify([Token.t()]) :: guess
  def classify(tokens) when is_list(tokens) do
    pos_list = Enum.flat_map(tokens, & &1.pos)
    classify(%SemanticInput{pos_list: pos_list, tokens: tokens})
  end

  defp match_pattern(pos_list) do
    case Map.get(@patterns, pos_list) do
      nil ->
        %{intent: @default_intent, keyword: nil, score: @default_score}

      intent_scores ->
        {intent, score} = Enum.max_by(intent_scores, fn {_i, s} -> s end)
        %{intent: intent, keyword: nil, score: score}
    end
  end

  defp maybe_boost_with_keyword(guess, tokens) do
    Enum.find_value(tokens, fn %Token{phrase: phrase} ->
      with %{intent: intent, boost: boost} <- Map.get(@keyword_boosts, phrase),
           true <- intent == guess.intent do
        %{guess | keyword: phrase, score: guess.score + boost}
      else
        _ -> nil
      end
    end) || guess
  end
end

