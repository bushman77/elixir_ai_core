
defmodule Core.Contractions do
  @moduledoc "Canonicalize and expand common English contractions (with/without apostrophes)."

  # Map raw (often apostrophe-less) -> canonical with apostrophe
  @canon %{
    "im" => "i'm", "ive" => "i've", "id" => "i'd", "ill" => "i'll",
    "dont" => "don't", "cant" => "can't", "wont" => "won't",
    "isnt" => "isn't", "arent" => "aren't", "wasnt" => "wasn't", "werent" => "weren't",
    "youre" => "you're", "youve" => "you've", "youll" => "you'll",
    "hes" => "he's", "shes" => "she's", "its" => "it's", "thats" => "that's",
    "theyre" => "they're", "theres" => "there's", "lets" => "let's"
  }

  # Canonical (with apostrophe) -> expanded words
  @expand %{
    "i'm" => ["i", "am"], "i've" => ["i", "have"], "i'd" => ["i", "would"],
    "i'll" => ["i", "will"], "don't" => ["do", "not"], "can't" => ["can", "not"],
    "won't" => ["will", "not"], "isn't" => ["is", "not"], "aren't" => ["are", "not"],
    "wasn't" => ["was", "not"], "weren't" => ["were", "not"], "you're" => ["you", "are"],
    "you've" => ["you", "have"], "you'll" => ["you", "will"], "he's" => ["he", "is"],
    "she's" => ["she", "is"], "it's" => ["it", "is"], "that's" => ["that", "is"],
    "they're" => ["they", "are"], "there's" => ["there", "is"], "let's" => ["let", "us"]
  }

  def canonicalize(token) when is_binary(token) do
    Map.get(@canon, token, token)
  end

  def expand(token) when is_binary(token) do
    Map.get(@expand, token, [token])
  end
end

