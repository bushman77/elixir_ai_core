defmodule Console do
  @moduledoc """
  Simple interactive console for AI Brain.
  Commands:
    - learn <word>  # fetches word info, memorizes it in the brain
    - anything else # interprets input and shows token/POS tagging
  """

  def start do
    IO.puts("🧠 AI Brain Console started. Type 'learn <word>' to teach me something.")
    loop()
  end

  defp loop do
    input = IO.gets("> ")

    case input do
      nil ->
        IO.puts("\nGoodbye!")
        :ok

      _ ->
        input = String.trim(input)
        handle_input(input)
        loop()
    end
  end

  defp handle_input("learn " <> word) when byte_size(word) > 0 do
    case LexiconEnricher.enrich(word) do
      {:ok, lexicon_map} ->
        case Core.memorize(lexicon_map) do
          {:ok, ids} ->
            IO.puts("✅ Learned #{word} with IDs: #{Enum.join(ids, ", ")}")

          {:error, reason} ->
            IO.puts("❌ Failed to memorize #{word}: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to enrich #{word}: #{inspect(reason)}")
    end
  end

  defp handle_input(input) when input != "" do
    tokens = Tokenizer.tokenize(input)
    {:answer, analysis} = Core.POS.classify_input(tokens)

    IO.inspect(analysis, label: "🤖")
  end

  defp handle_input(""), do: :ok
end

