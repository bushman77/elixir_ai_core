defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizes text into words and resolves part-of-speech (POS) tags
  using the Brain DB and online enrichment as fallback.
  """
  import Ecto.Query

  alias Core.DB
  alias BrainCell
  alias LexiconEnricher
  @base 128

  @doc """
  Convert a word to a unique numeric ID based on char positions.
  """
  def word_to_id(word) when is_binary(word) do
    word
    |> String.downcase()
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.map(fn {char, idx} ->
      (char - 96) * :math.pow(@base, idx)
    end)
    |> Enum.sum()
    |> round()
  end

  @doc """
  Normalize numeric ID to float between 0 and 1.
  """
  def embed(word, max \\ 1_000_000_000.0) do
    word_to_id(word) / max
  end

  @doc """
  Tokenizes a sentence into a list of maps with word and possible POS tags.
  """
  @spec tokenize(String.t()) :: [%{word: String.t(), pos: [atom()]}]
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.map(&resolve_word/1)
  end

  defp resolve_word(word) do
    case DB.all(from(b in BrainCell, where: b.word == ^word)) do
      [] ->
        case LexiconEnricher.enrich(word) do
          {:ok, _} ->
            case DB.all(from(b in BrainCell, where: b.word == ^word)) do
              [] -> 
                IO.puts("🚫 Word '#{word}' not found in brain. Assigning [:unknown].")
                %{word: word, pos: [:unknown]}
              results -> 
                IO.puts("🧠 Found '#{word}' with POS: #{inspect(Enum.map(results, & &1.pos))}")
                %{word: word, pos: Enum.map(results, & &1.pos)}
            end

          _ ->
            %{word: word, pos: [:unknown]}
        end

      results ->
        %{word: word, pos: Enum.map(results, & &1.pos)}
    end
  end
end
