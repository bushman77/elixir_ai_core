Nx.default_backend(Nx.BinaryBackend)

alias ML.{Generator, ByteTokenizer}

base = :erlang.binary_to_term(File.read!("/tmp/weights/base_lm.npz"))
# For now we just reuse base; if you trained the mood file, you can merge or swap it in.
params = base

decode = [top_p: 0.9, temperature: 0.65, max_new_tokens: 120, stops: ["<eos>", "\nuser:"]]

prompt = """
<bos> [INT=general] [MOOD=grumpy]
[CTX]
- Prefer bullet steps.
- Start with the fastest check first.
- End with a caution or next step.
[/CTX]
user: I need quick steps to reset my router safely.
assistant:
"""

out = Generator.generate(prompt, params, decode)
IO.puts("\n---\n" <> ByteTokenizer.decode(ByteTokenizer.encode(out, add_bos: false, add_eos: false)))
