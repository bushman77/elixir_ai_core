defmodule Console do
  use GenServer

  import Ecto.Query
  alias Core.{Tokenizer, DB, Brain}
  alias Core
  alias LexiconEnricher
  alias BrainCell
alias Core.SemanticInput

  @moduledoc """
  Interactive console for AI Brain.

  Type any sentence and the system will tokenize it,
  enrich unknown words, register brain cells, and show analysis.
  """

  # -- Public API --
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def start, do: GenServer.cast(__MODULE__, :prompt)

  # -- GenServer Lifecycle --

  def init(:ok) do
    IO.puts("🧠 AI Brain Console started. Type anything to begin.")
    GenServer.cast(self(), :prompt)
    {:ok, %{}}
  end

  def handle_cast(:prompt, state) do
    case IO.gets("> ") do
      nil ->
        IO.puts("\n👋 Goodbye!")
        {:stop, :normal, state}

      input ->
        handle_input(String.trim(input))
        GenServer.cast(self(), :prompt)
        {:noreply, state}
    end
  rescue
    error ->
      IO.puts("⚠️ Error: #{Exception.message(error)}")
      IO.inspect(__STACKTRACE__, label: "Stacktrace")
      GenServer.cast(self(), :prompt)
      {:noreply, state}
  end

  # -- Input Handling --

  defp handle_input(""), do: :ok
  defp handle_input(".enrich"), do: IO.puts("Usage: .enrich <word>")
  defp handle_input(".enrich " <> word), do: enrich_word(String.trim(word))

  defp handle_input("eval " <> code) do
    try do
      {result, _binding} = Code.eval_string(code)
      IO.inspect(result, label: "🧪 Eval Result")
    rescue
      error -> IO.puts("❌ Eval Error: #{Exception.message(error)}")
    end
  end

  defp handle_input(input) do
case Core.resolve_and_classify(input) do
  {:ok, %SemanticInput{} = semantic} ->
    IO.puts("🧠 Intent Classification:")
    IO.puts(" → Intent: #{semantic.intent}")
    IO.puts(" → Keyword: #{semantic.keyword}")
    IO.puts(" → Confidence: #{Float.round(semantic.confidence, 2)}")

    IO.puts("🧠 Tokens:")
    Enum.each(semantic.token_structs || semantic.tokens, &print_token/1)

      {:error, :dictionary_missing} ->
        IO.puts("❌ Could not resolve unknown words. Try enriching the lexicon.")

      {:error, reason} ->
        IO.puts("❌ Failed to classify input: #{inspect(reason)}")

      other ->
        IO.puts("⚠️ Unexpected classifier output: #{inspect(other)}")
    end
  end

  # -- Output Helpers --

  defp print_token(%{word: word, pos: pos, keyword: kw, intent: i, confidence: c})
       when is_binary(word) and is_binary(pos) do
    IO.puts(" • #{word} [#{pos}] → intent: #{i}, keyword: #{kw}, conf: #{Float.round(c, 2)}")
  end

  defp print_token(%BrainCell{word: word, pos: pos} = cell) do
    IO.puts(" • #{word} [#{pos}] → BrainCell (ID: #{cell.id})")
  end

  defp print_token(other) do
    IO.puts(" • #{inspect(other)}")
  end

  defp print_enriched(%BrainCell{pos: pos, definition: defn}) do
    IO.puts(" • [#{pos}] #{defn}")
  end

  defp print_enriched(other) do
    IO.puts("⚠️ Unexpected DB entry: #{inspect(other)}")
  end

  # -- Lexicon Enrichment --

  defp enrich_word(word) do
    case LexiconEnricher.enrich(word) do
      {:ok, cells} when is_list(cells) ->
        IO.puts("📚 Enriched entries for '#{word}':")
        Enum.each(cells, &print_enriched/1)

      {:error, reason} ->
        IO.puts("❌ Failed to enrich: #{inspect(reason)}")
    end
  end
end

