defmodule Console do
  use GenServer
  import Ecto.Query

  alias Core.{Tokenizer, DB}
  alias LexiconEnricher
  alias Core
  alias Brain

  @moduledoc """
  Interactive console for AI Brain.

  Type any sentence and the system will tokenize it,
  enrich unknown words, register brain cells, and show analysis.
  """

  # -- Public API --

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def start, do: GenServer.cast(__MODULE__, :prompt)

  # -- GenServer Callbacks --

  def init(:ok) do
    IO.puts("🧠 AI Brain Console started. Type anything to begin.")
    GenServer.cast(self(), :prompt)
    {:ok, %{}}
  end

  def handle_cast(:prompt, state) do
    case IO.gets("> ") do
      nil ->
        IO.puts("\nGoodbye!")
        {:stop, :normal, state}

      input ->
        handle_input(String.trim(input))
        GenServer.cast(self(), :prompt)
        {:noreply, state}
    end
  rescue
    exception ->
      IO.puts("↳ #{Exception.message(exception)}")
      IO.inspect(__STACKTRACE__)
      GenServer.cast(self(), :prompt)
      {:noreply, state}
  end

  # -- Input Handling --

  defp handle_input(""), do: :ok

  defp handle_input(".enrich"), do: IO.puts("Usage: .enrich <word>")

  defp handle_input(".enrich " <> word) do
    case LexiconEnricher.update(String.trim(word)) do
      {:ok, _cells} ->
        entries = DB.all(from b in BrainCell, where: b.word == ^word)

        if entries == [] do
          IO.puts("⚠️ No brain cells found for '#{word}' after enrichment.")
        else
          IO.puts("✅ Enriched '#{word}' with:")
          Enum.each(entries, fn
            %BrainCell{pos: pos, definition: defn} ->
              IO.puts(" • [#{pos}] #{defn}")
            other ->
              IO.puts("⚠️ Unexpected DB entry: #{inspect(other)}")
          end)
        end

      {:error, :not_found} ->
        IO.puts("❌ Word '#{word}' not found in online dictionary.")

      {:error, reason} ->
        IO.puts("⚠️ Enrichment failed: #{inspect(reason)}")
    end
  end

  defp handle_input("eval " <> code) do
    try do
      {result, _binding} = Code.eval_string(code)
      IO.inspect(result, label: "🧪 Eval Result")
    rescue
      error -> IO.puts("❌ Eval Error: #{inspect(error)}")
    end
  end

defp handle_input(input) do
  case Core.resolve_and_classify(input) do
    {:answer, %{intent: intent, keyword: keyword, confidence: confidence, tokens: tokens}} ->
      IO.puts("🧠 Intent Classification:")
      IO.puts(" → Intent: #{intent}")
      IO.puts(" → Keyword: #{keyword}")
      IO.puts(" → Confidence: #{Float.round(confidence, 2)}")
      IO.puts("🧠 Tokens:")
      Enum.each(tokens, &print_token/1)

    {:error, :dictionary_missing} ->
      IO.puts("❌ Could not resolve unknown words. Try enriching the lexicon.")

    {:error, reason} ->
      IO.puts("❌ Failed to classify input: #{inspect(reason)}")
  end
end

  # -- Helpers --

  defp print_token(%{word: word, pos: pos, keyword: keyword, intent: intent, confidence: conf}) do
    IO.puts(" • #{word} [#{pos}]  → intent: #{intent}, keyword: #{keyword}, conf: #{conf}")
  end

  defp print_token(token) do
    IO.puts(" • #{inspect(token)}")
  end
end

