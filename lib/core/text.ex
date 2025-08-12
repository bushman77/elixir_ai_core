defmodule Core.Text do
  @moduledoc "Safe text normalization for tokenization."
  @type opts :: [lowercase: boolean(), keep_emojis: boolean()]

  @default_opts [lowercase: true, keep_emojis: true]

  def normalize(s, opts \\ []) when is_binary(s) do
    opts = Keyword.merge(@default_opts, opts)

    s
    |> :unicode.characters_to_nfc_binary()
    |> strip_control_chars()
    |> normalize_whitespace()
    |> (fn s -> if opts[:lowercase], do: String.downcase(s), else: s end).()
    |> strip_punct_but_keep_word_internals(opts)
    |> String.trim()
  end

  defp strip_control_chars(s),
    do: String.replace(s, ~r/[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}]/u, "")

  defp normalize_whitespace(s),
    do: String.replace(s, ~r/\s+/u, " ")

  # Keep letters/digits, spaces, apostrophes/hyphens inside words, and dots in numbers.
  defp strip_punct_but_keep_word_internals(s, opts) do
    # Remove punctuation at word boundaries but allow ' and - between alphanumerics
    s = String.replace(s, ~r/(?<!\p{L}|\p{N})['-]|['-](?!\p{L}|\p{N})/u, "")
    # Remove stray periods not between digits
    s = String.replace(s, ~r/(?<!\p{N})\.(?!\p{N})/u, "")
    # Optionally strip (most) emojis; keep if keep_emojis true
    if opts[:keep_emojis], do: s, else: String.replace(s, ~r/[\p{So}\p{Sk}]/u, "")
  end
end

