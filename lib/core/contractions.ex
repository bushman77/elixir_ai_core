defmodule Core.Contractions do
  @moduledoc """
  Canonicalize and expand common English contractions (with/without apostrophes).

  Provides:
    • `canonicalize/1` – token-level: normalizes casing/apostrophes, returns canonical form
    • `expand/1` – token-level: returns a list of expanded words (defaults to [token])
    • `canonicalize_sentence/1` – sentence-level: expands WH-'s to "X is" and canonicalizes tokens
  """

  # --- helpers ---------------------------------------------------------------

  @spec norm(binary()) :: binary()
  defp norm(s) do
    s
    |> :unicode.characters_to_nfc_binary()
    |> String.downcase()
    |> String.replace("’", "'")
    |> String.trim()
  end

  # keep if you want it elsewhere; NOT used in attributes
  @spec strip_apos(binary()) :: binary()
  defp strip_apos(s), do: String.replace(s, ~r/['’]/u, "")

  # --- canonical forms -------------------------------------------------------

  @canonical_forms ~w(
    i'm i've i'd i'll
    you're you've you'll
    he's she's it's that's
    they're there's let's
    we're we've we'll
    they've they'll
    don't can't won't isn't aren't wasn't weren't
    shouldn't couldn't wouldn't didn't doesn't mustn't shan't ain't
    who's what's where's when's why's how's
    y'all
  )

  # Build a map of variants -> canonical (inline String.replace; no local fn calls)
  @canon_map Enum.reduce(@canonical_forms, %{}, fn c, acc ->
    c1 = c
    c2 = String.replace(c, ~r/['’]/u, "")  # without apostrophe
    acc
    |> Map.put(c1, c1)
    |> Map.put(c2, c1)
  end)
  |> Map.merge(%{
    # extra raw spellings often seen without apostrophes
    "im" => "i'm", "ive" => "i've", "id" => "i'd", "ill" => "i'll",
    "dont" => "don't", "cant" => "can't", "wont" => "won't",
    "isnt" => "isn't", "arent" => "aren't", "wasnt" => "wasn't", "werent" => "weren't",
    "youre" => "you're", "youve" => "you've", "youll" => "you'll",
    "hes" => "he's", "shes" => "she's", "its" => "it's", "thats" => "that's",
    "theyre" => "they're", "theres" => "there's", "lets" => "let's",
    "were" => "we're", "weve" => "we've", "well" => "we'll",
    "whos" => "who's", "whats" => "what's", "wheres" => "where's",
    "whens" => "when's", "whys" => "why's", "hows" => "how's",
    "yall" => "y'all"
  })

  # --- expansions (canonical -> list of words) -------------------------------

  @expand_map %{
    "i'm" => ["i", "am"],       "i've" => ["i", "have"],    "i'd" => ["i", "would"],
    "i'll" => ["i", "will"],    "you're" => ["you", "are"], "you've" => ["you", "have"],
    "you'll" => ["you", "will"],"he's" => ["he", "is"],     "she's" => ["she", "is"],
    "it's" => ["it", "is"],     "that's" => ["that", "is"], "they're" => ["they", "are"],
    "there's" => ["there", "is"],"let's" => ["let", "us"],  "we're" => ["we", "are"],
    "we've" => ["we", "have"],  "we'll" => ["we", "will"],  "they've" => ["they", "have"],
    "they'll" => ["they", "will"], "who's" => ["who", "is"], "what's" => ["what", "is"],
    "where's" => ["where", "is"],"when's" => ["when", "is"],"why's" => ["why", "is"],
    "how's" => ["how", "is"],   "y'all" => ["you", "all"],

    "don't" => ["do", "not"],   "can't" => ["can", "not"],  "won't" => ["will", "not"],
    "isn't" => ["is", "not"],   "aren't" => ["are", "not"], "wasn't" => ["was", "not"],
    "weren't" => ["were", "not"],"shouldn't" => ["should", "not"],
    "couldn't" => ["could", "not"], "wouldn't" => ["would", "not"],
    "didn't" => ["did", "not"], "doesn't" => ["does", "not"],
    "mustn't" => ["must", "not"], "shan't" => ["shall", "not"], "ain't" => ["ain", "not"]
  }

  # --- public API -------------------------------------------------------------

  @spec canonicalize(binary()) :: binary()
  def canonicalize(token) when is_binary(token) do
    t = norm(token)
    Map.get(@canon_map, t, t)
  end

  @spec expand(binary()) :: [binary()]
  def expand(token) when is_binary(token) do
    token
    |> canonicalize()
    |> then(&Map.get(@expand_map, &1, [&1]))
  end

  @spec canonicalize_sentence(binary()) :: binary()
  def canonicalize_sentence(s) when is_binary(s) do
    s1 =
      s
      |> :unicode.characters_to_nfc_binary()
      |> String.replace("’", "'")

    # Expand WH-'s at sentence level so matcher sees "what is ..."
    s2 =
      Regex.replace(~r/\b(what|where|who|how|when|why)['’]?s\b/i, s1, fn _m, wh ->
        wh_down = String.downcase(wh)
        "#{wh_down} is"
      end)

    s2
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&canonicalize/1)
    |> Enum.join(" ")
  end

  @doc false
  def normalize(s), do: canonicalize_sentence(s)
end

