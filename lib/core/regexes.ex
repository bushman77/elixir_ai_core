# lib/core/regexes.ex
defmodule Core.Regexes do
  @moduledoc false

  # Accepts: sorry, sry, my bad, apologies, apology,
  # apologize/apologise/apologizing/apologising,
  # and common misspellings: appologize/appologies/appology
  @apology ~r/
    \b(
      sry|
      so*rry|
      my\W*bad|
      apolog(?:y|ies|i[sz]e|i[sz]ing)|
      appolog(?:y|ies|i[sz]e|i[sz]ing)     # common double-p misspells
    )\b
  /ix

  def apology_regex, do: @apology
end

