defmodule Dataset.Parser.CLINC do
  alias Core.{Tokenizer, IntentResolver, SemanticInput, POSEngine, Brain}

  def parse_entry(%{"text" => text, "intent" => gold_intent}) do
    tokens =
      text
      |> Tokenizer.tokenize()
      |> POSEngine.tag()
      |> Enum.map(&Core.update_token_with_cell/1)

    {resolved_intent, keyword, confidence, source} =
      IntentResolver.resolve(tokens)

    cells =
      Enum.flat_map(tokens, fn %{cell: nil} -> [] ; %{cell: cell} -> [cell] end)

    %SemanticInput{
      sentence: text,
      tokens: Enum.map(tokens, & &1.text),
      token_structs: tokens,
      pos_list: Enum.map(tokens, & &1.pos),
      cells: cells,
      intent: resolved_intent,
      gold_intent: gold_intent,
      keyword: keyword,
      confidence: confidence,
      mood: nil,
      phrase_matches: [],
      source: source,
      activation_summary: nil,
      pattern_roles: %{}
    }
  end

  def parse_file(filepath) do
    filepath
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(&parse_entry/1)
  end
end

