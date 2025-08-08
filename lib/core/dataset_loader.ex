defmodule Core.DatasetLoader do
  @clinc_path "priv/data_full.json"

  def load_clinc150_split(split) do
    with {:ok, body} <- File.read(@clinc_path),
         {:ok, %{"train" => train, "val" => val, "test" => test}} <- Jason.decode(body) do
      split_data = case split do
        :train -> train
        :val -> val
        :test -> test
      end

      Enum.map(split_data, fn [sentence, intent] ->
        %Core.SemanticInput{
          sentence: sentence,
          intent: intent,
          source: :clinc150,
          confidence: 1.0, # override later
          keyword: extract_keyword(sentence),
          tokens: Core.Tokenizer.tokenize(sentence)
        }
      end)
    end
  end

  defp extract_keyword(sentence) do
    # Placeholder: Add your own keyword logic later
    sentence
    |> String.split()
    |> Enum.at(0)
  end
end

