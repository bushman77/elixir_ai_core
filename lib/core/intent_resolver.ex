defmodule Core.IntentResolver do
  alias Core.{IntentMatrix, SemanticInput}

  @fallback_threshold Application.compile_env(:elixir_ai_core, :fallback_threshold, 1.2)

  @doc """
  Resolves intent on a fully populated SemanticInput.
  """
  def resolve_intent(%SemanticInput{intent: intent, confidence: conf} = semantic)
      when intent != :unknown and conf >= @fallback_threshold do
    semantic
    |> Map.put(:source, :classifier)
  end

def resolve_intent(%SemanticInput{token_structs: tokens, keyword: kw} = semantic) do
  %{
    intent: intent,
    score: score,
    keyword: keyword,
    source: source
  } = IntentMatrix.classify(tokens)

  %SemanticInput{
    semantic
    | intent: intent,
      confidence: score,
      keyword: keyword || kw,
      source: source
  }
end

end

