alias Core.{IntentResolver, ResponsePlanner, SemanticInput}

sem =
  %SemanticInput{
    sentence: "fuck you",
    token_structs: [],
    intent: :unknown,
    keyword: nil,
    confidence: 0.0,
    mood: :grumpy # or whatever MoodCore would set
  }
  |> IntentResolver.resolve_intent()
  |> ResponsePlanner.analyze()

IO.inspect(sem.intent, label: "Intent")
IO.inspect(sem.response, label: "Response")  # or :planned_response if that's what Console prints

