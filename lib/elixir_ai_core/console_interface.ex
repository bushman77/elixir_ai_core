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

    case input do
      "" ->
        IO.puts("💤 Nothing said.")
        loop()

      ":quit" ->
        IO.puts("👋 Goodbye.")
        :init.stop()

      _ ->
        # STEP 1: Tag the input
        tagged = ElixirAiCore.POSTagger.tag_sentence(input)

        # STEP 2: Parse sentence structure
        case ElixirAiCore.SentenceStructureParser.parse_tagged_sentence(tagged) do
          {:ok, structure_info} ->
            IO.inspect(structure_info, label: "🧠 Parsed Structure")

          {:unknown, reason} ->
            IO.puts("🤔 Couldn’t recognize structure: #{inspect(reason[:tokens])}")
        end

        # STEP 3: Continue brain training with raw words
        words = Enum.map(tagged, fn {w, _tag} -> w end)
        BrainTrainer.teach_chain(words)

        # STEP 4: Fire first word
        first_word = hd(words)
        BrainCell.fire(first_word, 1.0)

        # STEP 5: Wait and respond
        Process.sleep(300)

        case BrainOutput.top_fired_cell_id() do
          nil ->
            IO.puts("🤖 ...hmm, I’ve got nothing.")

          top_word ->
            response = PhraseGenerator.generate_phrase(top_word)
            IO.puts("🤖 #{response}")
            BrainOutput.reset_activations()
        end

        loop()
    end
  end
end
