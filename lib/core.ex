defmodule Core do
  @moduledoc "Central Core pipeline for tokenizing, linking, classifying, and planning AI behavior."

  require Logger
import Nx.Defn
  alias Axon


  alias Core.{
    Tokenizer,
    IntentClassifier,
    IntentResolver,
    POSEngine,
    ResponsePlanner,
    SemanticInput,
    Token,
    DB
  }

  alias LexiconEnricher
  alias MoodCore
  alias Brain
  alias BrainCell

  @spec infer(Axon.Model.t(), Nx.Tensor.t() | list()) :: any()
  def infer(nil, _input), do: {:error, :no_model_loaded}

  def infer(model, input) do
    # Ensure input is a tensor
    input_tensor = Nx.tensor(input)

    # Do inference (assuming model is a {model, params} tuple)
    {compiled_model, params} = model
    Axon.predict(compiled_model, params, input_tensor)
  end

def activate_tokens(%SemanticInput{token_structs: tokens} = semantic) do
  updated_tokens =
    Enum.map(tokens, fn token ->
      activated = activate_cells(token)
      Brain.get_or_start(activated.phrase)
      activated
    end)

  %{semantic | token_structs: updated_tokens}
end

  @doc """
  Master pipeline: from raw input to fully processed SemanticInput.
  """

def resolve_input(input) when is_binary(input) do
  input
  |> Tokenizer.tokenize()
  |> Core.activate_tokens()
  |> POSEngine.tag()
  |> IntentClassifier.classify_tokens()
  |> IntentResolver.resolve_intent()
  |> MoodCore.attach_mood()
  |> ResponsePlanner.analyze()
  |> then(&{:ok, &1})
end

  # Token → ensure BrainCell is started
  def activate_cells(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [] -> 
        LexiconEnricher.enrich  token.text
        activate_cells token
      cells ->
        Enum.each(cells, &Brain.ensure_started/1)
        token
    end
  end

  # Token → attach BrainCell info (pos, keyword, etc.)
  def update_token_with_cell(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [%BrainCell{} = cell | _] ->
        Brain.ensure_running(cell)
        %{token | cell: cell, pos: cell.pos, keyword: cell.word}

      _ ->
        Logger.warning("⚠️ No BrainCell found for #{inspect(phrase)}")
        token
    end
  end

  # Deprecated: separate enrich call (handled now in other flows)
  defp enrich_if_missing(word) do
    case LexiconEnricher.enrich(word) do
      {:ok, cells} ->
        Enum.each(cells, &store_cell/1)
        cells

      {:error, reason} ->
        Logger.warning("⚠️ Enrichment failed for '#{word}': #{inspect(reason)}")
        []
    end
  end

  defp store_cell(%BrainCell{} = cell) do
    normalized =
      cell
      |> Map.from_struct()
      |> Map.drop([:__meta__, :__struct__])
      |> then(&struct(BrainCell, &1))

    unless DB.cell_exists?(normalized.id) do
      DB.insert_cell!(normalized)
    end

    Brain.store(normalized)
  end

  # (Optional) legacy fallback hook
  def resolve_and_classify(input), do: resolve_input(input)
end

