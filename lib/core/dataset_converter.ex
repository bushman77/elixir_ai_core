defmodule Core.DatasetConverter do
  alias Core
  alias Core.SemanticInput

  @spec clinc_entry_to_semantic_input(map()) :: SemanticInput.t()
  def clinc_entry_to_semantic_input(%{"text" => text, "intent" => intent}) do
    # Step 1: run through Core resolution pipeline
    semantic = Core.resolve_and_classify(text)

    # Step 2: override intent with CLINC label (for supervised alignment)
    %SemanticInput{semantic | intent: intent, source: :clinc_label}
  end
end

