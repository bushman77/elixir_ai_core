defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizes text into words and resolves part-of-speech (POS) tags
  using the Brain DB and online enrichment as fallback.
  Prioritizes head-matched multiword expressions before tokenization.
  """

  import Ecto.Query
  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  @base 128

  # -- Public API --

  def word_to_id(word) when is_binary(word) do
    word
    |> String.downcase()
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.map(fn {char, idx} -> (char - 96) * :math.pow(@base, idx) end)
    |> Enum.sum()
    |> round()
  end

  def embed(word, max \\ 1_000_000_000.0), do: word_to_id(word) / max

  @spec tokenize(String.t()) :: [%{word: String.t(), pos: [atom()]}]
  def tokenize(text) when is_binary(text) do
    cleaned =
      text
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, "")
      |> String.trim()

    multiword_phrases =
      DB.all(from b in BrainCell, where: fragment("word LIKE '% %'"))
      |> Enum.map(& &1.word)
      |> Enum.sort_by(&String.length/1, :desc)

    case find_head_phrase(cleaned, multiword_phrases) do
      {:ok, phrase, tail} ->
        # Check DB first for phrase token
        tokens =
          case DB.all(from(b in BrainCell, where: b.word == ^phrase)) do
            [] ->
              # Phrase not found in DB — enrich dynamically
              case LexiconEnricher.enrich(phrase) do
                {:ok, cells} ->
                  # Memorize enriched phrase cells to DB
                  case Core.memorize(cells) do
                    {:ok, _} -> :ok
                    {:error, _} -> :error
                  end

                  [%{word: phrase, pos: Enum.flat_map(cells, & &1.pos)}]

                _ ->
                  [%{word: phrase, pos: [:unknown]}]
              end

            results ->
              [%{word: phrase, pos: Enum.map(results, & &1.pos)}]
          end

        # Tokenize tail words individually
        tail_tokens =
          tail
          |> String.trim()
          |> String.split()
          |> Enum.map(&resolve_word/1)

        tokens ++ tail_tokens

      :no_match ->
        # No multiword phrase found; tokenize single words normally
        cleaned
        |> String.split()
        |> Enum.map(&resolve_word/1)
    end
  end

  # -- Internal Helpers --

  defp find_head_phrase(_text, []), do: :no_match

  defp find_head_phrase(text, [phrase | rest]) do
    if String.starts_with?(text, phrase) do
      tail = String.replace_prefix(text, phrase, "")
      {:ok, phrase, tail}
    else
      find_head_phrase(text, rest)
    end
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
                IO.puts("🧠 Enriched '#{word}' with POS: #{inspect(Enum.map(results, & &1.pos))}")
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

