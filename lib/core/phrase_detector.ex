defmodule Core.PhraseDetector do
  @moduledoc """
  Detects known multiword phrases in a sentence using the Brain database.
  Learns and enriches new ones automatically.
  Provides helpers to mark phrases in text to preserve phrase boundaries.
  """

  alias Core.Tokenizer
  alias Brain
  alias BrainCell
  alias LexiconEnricher

  @min_window 2
  @max_window 4

  @doc """
  Finds all known multiword phrases stored in the brain that appear in the given sentence.
  """
  def detect(sentence) when is_binary(sentence) do
    tokens = Tokenizer.tokenize(sentence)

    stored_phrases =
      Brain.get_all(tokens)
      |> Enum.map(& &1.word)
      |> MapSet.new()

    phrase_candidates(tokens)
    |> Enum.filter(&MapSet.member?(stored_phrases, &1))
    |> Enum.uniq()
  end

  @doc """
  Detects phrases in the sentence, learns and enriches any new ones.
  Returns all candidate phrases detected.
  """
  def detect_and_learn(sentence) when is_binary(sentence) do
    tokens = Tokenizer.tokenize(sentence)

    known_phrases =
      Brain.get_all(tokens)
      |> Enum.map(& &1.word)
      |> MapSet.new()

    phrase_candidates(tokens)
    |> Enum.map(fn phrase ->
      if MapSet.member?(known_phrases, phrase) do
        phrase
      else
        learn_and_enrich_phrase(phrase)
        phrase
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Replaces detected phrases in the sentence with tagged placeholders.

  Example:
      iex> Core.PhraseDetector.replace_with_tags("I want to say hello to my friend")
      "I want to [PHRASE:say hello] to [PHRASE:my friend]"
  """
  def replace_with_tags(sentence) when is_binary(sentence) do
    detect(sentence)
    |> Enum.reduce(sentence, fn phrase, acc ->
      String.replace(acc, phrase, "[PHRASE:#{phrase}]")
    end)
  end

  # Internal helper to generate all sliding phrase windows
  defp phrase_candidates(tokens) do
    for size <- @min_window..@max_window,
        chunk <- Enum.chunk_every(tokens, size, 1, :discard),
        do: Enum.join(chunk, " ")
  end

  # Internal helper to create and enrich a new phrase in Brain
  defp learn_and_enrich_phrase(phrase) do
    {:ok, cell} = Brain.create(%BrainCell{
      word: phrase,
      pos: [:phrase],
      type: :phrase,
      definition: nil,
      activation: 0.0,
      dopamine: 0.0,
      serotonin: 0.0
    })

    # Enrich POS, definition, synonyms, etc. for the new phrase
    LexiconEnricher.enrich(cell.word)
  end
end

