defmodule Console do
  use GenServer

  import Ecto.Query
  alias Core.{DB, Brain, SemanticInput}
  alias LexiconEnricher

  @moduledoc """
  Interactive console for AI Brain.

  Type a sentence to tokenize, enrich, activate brain cells, and analyze intent.
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
    case Core.resolve_input(input) do
      {:ok, %SemanticInput{} = semantic} ->
        IO.puts("""
        🧠 Intent Classification:
         → Intent: #{semantic.intent}
         → Keyword: #{semantic.keyword}
         → Confidence: #{Float.round(semantic.confidence, 2)}
         → Source: #{semantic.source}
        """)

        #IO.puts("🧠 Tokens:")
        #Enum.each(semantic.token_structs || semantic.tokens, &IO.inspect(&1))

        if semantic.mood, do: IO.puts("🎭 Mood: #{semantic.mood}")
        if semantic.response, do: IO.puts("💬 Planned Response: #{semantic.response}")

      {:error, :not_found} ->
        IO.puts("❌ No BrainCells or usable tokens found.")

      {:error, reason} ->
        IO.puts("❌ Failed to classify input: #{inspect(reason)}")

      other ->
        IO.puts("⚠️ Unexpected output: #{inspect(other)}")
    end
  end

  # -- Lexicon Enrichment --

  defp enrich_word(word) do
    case LexiconEnricher.enrich(word) do
      {:ok, cells} when is_list(cells) ->
        IO.puts("📚 Enriched entries for '#{word}':")
        Enum.each(cells, &IO.inspect(&1))

      {:error, reason} ->
        IO.puts("❌ Failed to enrich: #{inspect(reason)}")
    end
  end
end

