defmodule Console do
  use GenServer

  @moduledoc """
  Interactive console for AI Brain.
  Type any sentence and the system will tokenize it, enrich unknown words, register brain cells, and show analysis.
  """

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Call this to start console prompt loop asynchronously
  def start do
    GenServer.cast(__MODULE__, :prompt)
  end

  # GenServer callbacks

def init(:ok) do
  IO.puts("🧠 AI Brain Console started. Type anything to begin.")
  # Kick off prompt loop immediately
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
      IO.puts("⚠️ Console error: #{Exception.message(exception)}")
      GenServer.cast(self(), :prompt)
      {:noreply, state}
  end
end

  # Internal input handler (same as your original)
  defp handle_input(""), do: :ok

  defp handle_input(input) do
    tokens = Tokenizer.tokenize(input)

    Enum.each(tokens, fn token ->
      if token.pos == [:unknown] do
        case Brain.get(token.word) do
          {:error, reason} ->
            IO.puts("⚠️ Failed to enrich #{token.word}: #{inspect(reason)}")

          [] ->
            IO.puts("⚠️ No brain cells found for #{token.word}")

          _ ->
            :ok
        end
      end
    end)

    case Core.resolve_and_classify(input) do
      {:answer, analysis} -> IO.inspect(analysis, label: "🤖")
      {:error, :dictionary_missing} -> IO.puts("🤖: I believe I have misplaced my dictionary.")
    end
  end
end
  
