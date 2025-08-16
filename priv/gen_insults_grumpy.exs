defmodule GrumpGen do
  @moduledoc """
  Generates playful, non-hateful 'grump' roasts for training an insult detector or reply model.
  Content avoids protected-attribute targets, slurs, body-shaming, or violence.
  """

  @openers [
    "Look,", "Buddy,", "Hey, genius,", "Fun fact,", "Bold move,", "Hot take,",
    "Neat idea,", "Heads up,", "Real talk,", "Tough love time,"
  ]

  @adverbs ~w(barely mildly extremely wildly suspiciously impressively heroically accidentally mercilessly stylishly)
  @adjs [
    "half-baked", "laggy", "wobbly", "noisy", "fragile", "sleep-deprived", "spicy",
    "overcaffeinated", "untested", "outdated", "chaotic", "glitchy", "improvised",
    "optimistic", "guess-driven", "duct-taped", "vibes-based", "ambitious", "confused"
  ]

  # keep nouns abstract/technical so we roast ideas/work, not identity
  @nouns [
    "logic", "plan", "approach", "hot take", "syntax", "argument", "workflow",
    "strategy", "timeline", "UI", "commit", "branch", "refactor", "algorithm",
    "guesstimate", "assumption", "draft", "prototype", "pitch", "theory"
  ]

  @things [
    "todo", "merge conflict", "stack trace", "race condition", "404",
    "rubber duck", "debug print", "broken shortcut", "beta feature",
    "unit test you forgot to write", "README from 2014"
  ]

  @comparisons [
    "a summer porch light", "a beta weekend", "a spaghetti factory",
    "a group project at 2 am", "Windows 98 on a toaster",
    "a tutorial speedrun", "a coffee-fueled hackathon", "Monday morning standup",
    "a Jenga tower in a wind tunnel", "an infinite loop"
  ]

  @buttons [
    "patience", "linting", "spellcheck", "common sense", "error handling",
    "version control", "rate limits", "sanity checks", "reality"
  ]

  @templates [
    "{opener} your {noun} has more bugs than {comparison}.",
    "{opener} that {noun} is held together with duct tape and {noun2}.",
    "{opener} your {noun} just blue-screened my {button}.",
    "{opener} bold move. That {noun} is {adj} even by {thing} standards.",
    "{opener} this {noun} is a {thing} with extra steps.",
    "{opener} your {noun} is running on vibes and missing semicolons.",
    "{opener} spicy {noun}. Sadly, it’s still undercooked.",
    "{opener} your {noun} tripped over its own recursion.",
    "{opener} that {noun} is the emoji equivalent of a 404.",
    "{opener} neat {noun}. Did you lint it with glitter?",
    "{opener} your {noun} just filed a bug against itself.",
    "{opener} that {noun} is a speed bump on the information superhighway.",
    "{opener} your {noun} is a {adj} {thing} in production.",
    "{opener} optimistic {noun}. Reality disagrees.",
    "{opener} your {noun} is a TODO comment with confidence.",
    "{opener} that {noun} reads like a stack trace written in crayon.",
    "{opener} your {noun} is a merge conflict with opinions.",
    "{opener} courageous {noun}. QA will love this.",
    "{opener} your {noun} leaks edge cases like a sieve.",
    "{opener} cute {noun}. Shame it’s allergic to logic."
  ]

  @doc "Generate N unique, safe roasts"
def generate(n) when is_integer(n) and n > 0 do
  uniq_left(n, MapSet.new(), [])
end

defp uniq_left(0, _set, acc), do: Enum.reverse(acc)

defp uniq_left(k, set, acc) when k > 0 do
  line = build() |> tidy()

  if MapSet.member?(set, line) do
    # duplicate → don't decrement
    uniq_left(k, set, acc)
  else
    uniq_left(k - 1, MapSet.put(set, line), [line | acc])
  end
end

  defp build do
    template = pick(@templates)

    replace(template, %{
      "opener" => pick(@openers),
      "adj" => pick(@adjs),
      "adverb" => pick(@adverbs),
      "noun" => pick(@nouns),
      "noun2" => pick(@nouns),
      "thing" => pick(@things),
      "comparison" => pick(@comparisons),
      "button" => pick(@buttons)
    })
  end

  defp pick(list), do: Enum.random(list)

  defp replace(str, map) do
    Enum.reduce(map, str, fn {k, v}, acc ->
      String.replace(acc, "{#{k}}", v)
    end)
  end

  defp tidy(s) do
    s
    |> String.replace(~r/\s+/, " ")
    |> String.replace(" ,", ",")
    |> String.trim()
  end

def write_jsonl!(path, lines, label \\ "insult") do
  File.mkdir_p!(Path.dirname(path))

  File.open!(path, [:write, :utf8], fn io ->
    Enum.each(lines, fn text ->
      IO.binwrite(io, Jason.encode!(%{text: text, label: label}))
      IO.binwrite(io, "\n")
    end)
  end)

  path
end


end

# --- Run it ---
n = 5_000
lines = GrumpGen.generate(n)
path = GrumpGen.write_jsonl!("priv/datasets/grump_insults_5k.jsonl", lines)
IO.puts("Wrote #{n} lines to #{path}")

# Show a few samples
Enum.take(lines, 10) |> Enum.each(&IO.puts("• " <> &1))
