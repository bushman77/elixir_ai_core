defmodule SelfCoder do
  def write_function(idea) do
    prompt = "Write an Elixir function that " <> idea
    {:ok, code} = LLM.generate_code(prompt)
    File.write!("lib/brain/self_learned/#{UUID.uuid4()}.ex", code)
    compile(code)
  end

  def compile(code) do
    Code.eval_string(code)
  end
end

