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

  defp handle_input(".enrich") do
    IO.puts("Usage: .enrich <word>")
  end

  defp handle_input(".enrich " <> word) do
    word = String.trim(word)

    case LexiconEnricher.update(word) do
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

    :ok
  end

  defp handle_input(input) do
    tokens = Tokenizer.resolve_phrases(input)
    Core.set_attention tokens
    IO.inspect(tokens, label: "🧠 Tokens")
  end

  # -- Optional mood mapping for intents --

  defp mood_for_intent(:greeting), do: :happy
  defp mood_for_intent(:farewell), do: :sad
  defp mood_for_intent(:reflect), do: :reflective
  defp mood_for_intent(:recall), do: :nostalgic
  defp mood_for_intent(:define), do: :neutral
  defp mood_for_intent(:unknown), do: :curious
  defp mood_for_intent(_), do: :neutral
end

