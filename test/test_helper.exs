ExUnit.start()

Code.ensure_compiled!(LexiconClient.Behavior)
Mox.defmock(LexiconClientMock, for: LexiconClient.Behavior)

Application.put_env(:elixir_ai_core, :lexicon_client, LexiconClientMock)

