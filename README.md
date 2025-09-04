# elixir\_ai\_core
## Project Status
Actively evolving neuro-symbolic Elixir AI: OTP/GenServers + Postgres BrainCells + Axon/Nx.
Current focus: intent fusion, phrase generation, mood-modulated responses.
See: CHANGELOG 0.0.1 “Spark” for what’s shipped and what’s next.

A neuro-symbolic AI framework in **Elixir** that blends classic NLP (tokenization, POS tagging, intent rules), lightweight ML, and process-based “brain cell” actors. The system models cognition as flows of tokens → semantics → activated brain cells → mood-modulated response generation.

> **Status:** Active development. Expect breaking changes as modules converge around `SemanticInput` and process supervision patterns.

---

## ✨ Why this project?

* **Traceable cognition:** symbolic structures (tokens, POS, intents) give you debuggable reasoning steps.
* **Process-native intelligence:** each **BrainCell** is a supervised Elixir process, enabling dynamic activation and recovery.
* **Mood & neuromodulators:** responses are shaped by **MoodCore**, **EmotionModulator**, and simulated neurotransmitters.
* **Hybrid intent stack:** rules (IntentMatrix), heuristics (Resolver), and ML (IntentModel / FRP) cooperate.

---

## 🔭 System overview


flowchart TD
    A[User Input] --> B[Core.Tokenizer]
    B --> C[Core.POS → POSDisambiguator → ViterbiLite]
    C --> D[IntentClassifier / IntentMatrix / IntentModel]
    D --> E[IntentResolver]
    E --> F[SemanticInput]
    F --> G[Brain & BrainCell Supervisor]
    G --> H[MoodCore • EmotionModulator • SubstanceEffect]
    H --> I[ResponsePlanner]
    I --> J[PhraseGenerator → BrainOutput]
    J --> K[Console • local_llm_client • openai_client]

    subgraph Knowledge & Memory
      L[MemoryCore] --- M[KnowledgeDistiller]
      N[Lexicon • Vocab • Profanity • MultiwordMatcher]
    end

    F -. context .-> L
    M -. enrich .-> N
    N -. expands .-> B


**Data Flow (high-level):**

1. **Tokenizer** splits text; **MultiwordMatcher** catches phrase-level units.
2. **POS/POSDisambiguator/ViterbiLite** assign part-of-speech with lightweight sequence reasoning.
3. **Intent layer** (Classifier/Matrix/Model) proposes intents + confidence.
4. **IntentResolver** fuses signals into a single intent profile.
5. **SemanticInput** packages the rich state for downstream modules.
6. **Brain** activates **BrainCells**; **Attention** & **Curiosity** modulate which cells fire.
7. **MoodCore / EmotionModulator** apply stateful tone and neurotransmitter effects.
8. **ResponsePlanner** chooses an approach; **PhraseGenerator** realizes it; **BrainOutput** renders.

---

## 🧱 Key modules & directories

* **`lib/core/`** – language pipeline & cognition

  * `tokenizer.ex`, `multiword_matcher.ex`, `pos*.ex`, `viterbi_lite.ex`
  * `intent_classifier.ex`, `intent_matrix.ex`, `intent_model.ex`, `intent_resolver.ex`
  * `semantic_input.ex`, `semantic_pos_tagger.ex`, `response_planner.ex`, `phrase_generator.ex`
  * `memory_core.ex`, `knowledge_distiller.ex`, `goal_planner.ex`, `emotion_modulator.ex`, `profantity.ex`
* **`lib/brain/`** – process-based cognition

  * `neuron.ex`, `attention.ex`, `curiosity_thread.ex`
  * Supervisor lives in `lib/braincell/supervisor.ex` with `braincell.ex`
* **`lib/ml/`** – ML components

  * `grump_model.ex` and FRP stack in `lib/frp/` (features, labels, pipeline, train)
* **Interfaces**

  * `console.ex`, `local_llm_client.ex`, `openai_client.ex`, `model_server.ex`
* **Persistence**

  * `core/db.ex`, `elixir_ai_core/postgrex_types.ex`

> Tip: The project is converging on `SemanticInput` as the canonical container between pipeline stages—prefer extending this struct over adding new ad‑hoc fields elsewhere.

---

## 🛠️ Getting started

### Prereqs

* Elixir ≥ **1.15** (works on 1.16–1.18)
* Erlang/OTP compatible with your Elixir version
* PostgreSQL (if you’re persisting BrainCells / logs)

### Setup

```bash
mix deps.get
mix compile
# If using DB
mix ecto.create && mix ecto.migrate
```

### Run the console

```bash
iex -S mix
# inside IEx
Console.start()
```

### Sample interaction

```text
> hello there
🧠 Intent: greeting (0.70)
🎭 Mood: neutral
💬 Planned: "Hi there! How’s it going?"
```

---

## 🧪 Testing

```bash
mix test
```

* Prefer unit tests around `SemanticInput`, tokenization/POS, and intent resolution.
* For ML, seed small snapshots of datasets and test feature extraction determinism.

---

## ⚙️ Configuration highlights

* **Mood & neuromodulators:** tune in `moodcore.ex`, `emotion_modulator.ex`, `substanceeffect.ex`.
* **FRP/ML:** feature toggles in `frp/pipeline.ex`; training entry in `frp/train.ex`.
* **LLM connectors:** set environment vars consumed by `openai_client.ex` / `local_llm_client.ex`.
* **DB:** configure `config/*.exs` for Ecto + Postgres types.

---

## 🧩 Extending the system

* Add a new **phrase template** → `phrase_generator.ex`
* Add a **rule** to intent scoring → `intent_matrix.ex`
* Add a **feature** to ML stack → `frp/features.ex`
* Add a **BrainCell type** → `braincell.ex` + register under the supervisor
* Add a **lexicon source** → `lexicon_client/` & wire into `knowledge_distiller.ex`

Design principle: prefer **composability** via small modules that exchange a richer `SemanticInput` rather than pushing complex logic into a single stage.

---

## 🔬 Roadmap

* [ ] Unify POS/intent features with FRP pipeline for joint training
* [ ] Expand `SemanticInput` tracing hooks for end-to-end introspection
* [ ] Curiosity-driven retrieval loops (query MemoryCore when confidence is low)
* [ ] Mood feedback loop from user reactions (positive/negative signals)
* [ ] Exportable thought traces for evaluation (privacy‑safe)

---

## 🤝 Contributing

1. Fork and create a feature branch: `feat/<short-name>`
2. Add tests for new behavior
3. Keep modules small; prefer protocol/behaviour boundaries for new families
4. Open a PR with a brief rationale and a runnable example

---

## 📜 License

MIT (proposed). See `LICENSE`.

---

## Acknowledgements

* Axon/Nx for Elixir ML
* The Elixir community for OTP-first design inspiration

---

### Appendix: Developer map

```text
User → Tokenizer → POS/Disambig/Viterbi → Intent(three ways) → Resolver → SemanticInput
      → Brain/Cells (Attention/Curiosity)
      → MoodCore → ResponsePlanner → PhraseGenerator → BrainOutput → Console/Clients
      ↘ MemoryCore ↔ KnowledgeDistiller ↔ Lexicon/Vocab/Profanity/Multiword
```
