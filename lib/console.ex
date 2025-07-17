defmodule Console do
  use GenServer
  @moduledoc """
  Interactive console for AI Brain.
  Type any sentence and the system will tokenize it, enrich unknown words,
  register brain cells, and show analysis.
  """
import Ecto.Query

  alias Core.Tokenizer
  alias Core
  alias LexiconEnricher
  alias Core.DB
  alias Brain

  # -- Public API --

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start do
    GenServer.cast(__MODULE__, :prompt)
  end

  # -- GenServer Callbacks --

  def init(:ok) do
    IO.puts("🧠 AI Brain Console started. Type anything to begin.")
    GenServer.cast(self(), :prompt)
    {:ok, %{}}
  end

  def handle_cast(:prompt, state) do
    try do
      input = IO.gets("> ")

      case input do
        nil ->
          IO.puts("\nGoodbye!")
          {:stop, :normal, state}

        _ ->
          input
          |> String.trim()
          |> handle_input()

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
  end

  # -- Input Handling --

  defp handle_input(""), do: :ok

  defp handle_input(".enrich"), do: IO.puts("Usage: .enrich <word>")

  defp handle_input(".enrich " <> word) do
    word = String.trim(word)

    case LexiconEnricher.enrich(word) do
      :ok ->
        entries = DB.all(from b in BrainCell, where: b.word == ^word)

        case entries do
          [] ->
            IO.puts("⚠️  No brain cells found for '#{word}' after enrichment.")

          _ ->
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
        IO.puts("⚠️  Enrichment failed: #{inspect(reason)}")
    end
  end

defp handle_input("eval " <> code) do
  try do
    result = Code.eval_string(code)
    IO.inspect(result, label: "🧪 Eval Result")
  rescue
    error -> IO.puts("❌ Eval Error: #{inspect(error)}")
  end

  :ok
end



defp handle_input(input) do
  tokens = Tokenizer.tokenize(input)
  IO.inspect(tokens, label: "🧠 Tokens")

  Enum.each(tokens, fn token ->
    if token.pos == [:unknown] do
      case DB.all(from b in BrainCell, where: b.word == ^token.word) do
        [] -> IO.puts("⚠️ No brain cells found for #{token.word}")
        _ -> :ok
      end
    end
  end)

  # 🔁 RECALL: Check last memory
  case Core.MemoryCore.recent(1) do
    [%{intent: :question, text: last}] ->
      IO.puts("🤔 You previously asked: #{last}. Want to follow up?")

    _ ->
      :ok
  end

  # 🧠 Reason and respond
  case Core.resolve_and_classify(input) do
    {:answer, analysis} ->
      IO.inspect(analysis, label: "🤖")
      response = Core.ResponsePlanner.plan(analysis)

      case response do
        {:reply, message} -> IO.puts("😄 [🧠 AI] #{message}")
        message when is_binary(message) -> IO.puts("😄 [🧠 AI] #{message}")
        _ -> IO.inspect(response, label: "⚠️ Unexpected response format")
      end

    {:error, :dictionary_missing} ->
      IO.puts("🤖: I believe I have misplaced my dictionary.")
  end
end

defp mood_for_intent(:greeting), do: :happy
  defp mood_for_intent(:farewell), do: :sad
  defp mood_for_intent(:reflect), do: :reflective
  defp mood_for_intent(:recall), do: :nostalgic
  defp mood_for_intent(:define), do: :neutral
  defp mood_for_intent(:unknown), do: :curious
  defp mood_for_intent(_), do: :neutral
end
