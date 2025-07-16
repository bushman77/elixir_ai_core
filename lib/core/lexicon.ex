defmodule Core.Lexicon do
  @moduledoc """
  Provides internal lexical entries for base verb and modal word recognition.

  This is used as a fallback or bootstrap layer when enriching from the Brain,
  especially before any external API calls.

  Use `get/1` to retrieve a word’s meaning(s), or `all/0` to inspect the lexicon.
  """

  @type word_entry :: %{
          partOfSpeech: String.t(),
          definitions: [
            %{
              definition: String.t(),
              example: String.t(),
              synonyms: [String.t()],
              antonyms: [String.t()]
            }
          ]
        }

  @spec get(String.t()) :: [word_entry()] | nil
  def get(word) when is_binary(word) do
    Map.get(@internal_lexicon, String.downcase(word))
  end

  @spec all :: map()
  def all, do: @internal_lexicon

 @internal_lexicon %{
    # Be verbs
    "be" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "exist", "example" => "To be or not to be", "synonyms" => ["exist", "occur"], "antonyms" => []}]}],
    "am" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "first person singular present of be", "example" => "I am happy", "synonyms" => ["exist"], "antonyms" => []}]}],
    "is" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of be", "example" => "She is here", "synonyms" => ["exists"], "antonyms" => []}]}],
    "are" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "second person singular and plural present of be", "example" => "You are welcome", "synonyms" => ["exist"], "antonyms" => []}]}],
    "was" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "first and third person singular past of be", "example" => "He was late", "synonyms" => [], "antonyms" => []}]}],
    "were" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "second person singular and plural past of be", "example" => "They were here", "synonyms" => [], "antonyms" => []}]}],

    # Have verbs
    "have" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "possess, own, or hold", "example" => "I have a book", "synonyms" => ["own", "possess"], "antonyms" => []}]}],
    "has" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of have", "example" => "She has a car", "synonyms" => ["owns"], "antonyms" => []}]}],
    "had" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "past tense of have", "example" => "He had a dog", "synonyms" => ["owned"], "antonyms" => []}]}],

    # Do verbs
    "do" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "perform an action", "example" => "I do my homework", "synonyms" => ["perform", "execute"], "antonyms" => []}]}],
    "does" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of do", "example" => "She does the dishes", "synonyms" => ["performs"], "antonyms" => []}]}],
    "did" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "past tense of do", "example" => "They did the work", "synonyms" => ["performed"], "antonyms" => []}]}],

    # Modal verbs
    "can" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express ability or possibility", "example" => "I can swim", "synonyms" => ["be able to"], "antonyms" => []}]}],
    "could" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "past of can, express possibility or ability", "example" => "She could come", "synonyms" => [], "antonyms" => []}]}],
    "may" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express possibility or permission", "example" => "You may leave", "synonyms" => [], "antonyms" => []}]}],
    "might" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express possibility", "example" => "It might rain", "synonyms" => [], "antonyms" => []}]}],
    "must" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express necessity or obligation", "example" => "You must stop", "synonyms" => [], "antonyms" => []}]}],
    "shall" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express future intent or obligation", "example" => "I shall return", "synonyms" => [], "antonyms" => []}]}],
    "should" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express advice or expectation", "example" => "You should eat", "synonyms" => [], "antonyms" => []}]}],
    "will" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express future intent or willingness", "example" => "I will go", "synonyms" => [], "antonyms" => []}]}],
    "would" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express conditional intent", "example" => "I would help", "synonyms" => [], "antonyms" => []}]}]
  }

end

