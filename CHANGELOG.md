# Changelog

## [0.0.1] - Spark
### Added
- Tokenizer: head-matched multiword phrase detection prior to tokenization.
- Brain/BrainCell: Postgres/Ecto-backed cells + GenServer processes; clean %BrainCell{} API.
- Brain: tracks active_cells and activation_log; hooks to MoodCore.register_activation/1.
- SemanticInput: unified container (tokens, pos_list, intent, mood, phrase_matches, roles, activation_summary).
- Intent stack: IntentMatrix + Classifier with low-confidence fallback; IntentResolver fuse step.
- BrainOutput: mood-aware phrasing and connection-walk thought traces.
- Axon/Nx: baseline training loop and dataset wiring (CLINC150 groundwork).
- OllamaClient: Tesla-based local LLM connector with context handling.

### Changed
- Core cleanup for clarity/safety; removed DETS in favor of Postgres.

### Next
- ResponsePlanner matrix tuned by intent/keyword/confidence.
- Dynamic PhraseGenerator (POS + intent + mood).
- MoodCore feedback loops and sweeteners (:why intent; expanded keyword boosts).

