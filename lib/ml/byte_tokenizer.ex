defmodule ML.ByteTokenizer do
  @moduledoc """
  Byte-level tokenizer with BOS/EOS.
  Vocabulary: 0..255 = raw bytes, 256 = <bos>, 257 = <eos>.
  """
  @bos 256
  @eos 257
  @vocab 258

  def bos_id, do: @bos
  def eos_id, do: @eos
  def vocab_size, do: @vocab

  @doc """
  Encode a string to integer IDs with optional bos/eos.
  """
  def encode(str, opts \\ [add_bos: true, add_eos: false]) when is_binary(str) do
    bytes = :binary.bin_to_list(str)
    ids = Enum.map(bytes, & &1)
    ids = if Keyword.get(opts, :add_bos, true), do: [@bos | ids], else: ids
    ids = if Keyword.get(opts, :add_eos, false), do: ids ++ [@eos], else: ids
    ids
  end

  def decode(ids) when is_list(ids) do
    ids
    |> Enum.reject(&(&1 in [@bos, @eos]))
    |> :binary.list_to_bin()
  end
end
