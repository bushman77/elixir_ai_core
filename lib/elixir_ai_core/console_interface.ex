defmodule ElixirAiCore.ConsoleInterface do
  @moduledoc """
  A simple text-based interface to talk to the brain from the terminal.
  Type a sentence, and the brain will learn and respond using braincells.
  """

  alias ElixirAiCore.BrainTrainer
  alias BrainCell
  alias BrainOutput
  alias PhraseGenerator

  def start do
    spawn(fn -> loop() end)
  end

  defp loop do
    input =
      IO.gets("> ")
      |> to_string()
      |> String.trim()
      |> String.downcase()

    case input do
      "" ->
        IO.puts("💤 Nothing said.")
        loop()

      ":quit" ->
        IO.puts("👋 Goodbye.")
        :init.stop()

      _ ->
        words = String.split(input)

        # Teach the brain with input
        BrainTrainer.teach_chain(words)

        # Fire the first word in the sentence
        first_word = hd(words)
        BrainCell.fire(first_word, 1.0)

        # Allow some time for propagation
        Process.sleep(300)

        # Get the top-activated cell and generate a phrase from it
        case BrainOutput.top_fired_cell_id() do
          nil ->
            IO.puts("🤖 ...hmm, I’ve got nothing.")

          top_word ->
            response =
              PhraseGenerator.generate_phrase(top_word)

            IO.puts("🤖 #{response}")
            BrainOutput.reset_activations()
        end

        loop()
    end
  end
end
