defmodule Sneex.Memory do
  @moduledoc """
  This module wraps memory access.
  """
  defstruct [:data]

  use Bitwise

  @opaque t :: %__MODULE__{
            data: binary()
          }

  @spec new(binary()) :: __MODULE__.t()
  def new(data) when is_binary(data) do
    %__MODULE__{data: data}
  end

  @spec raw_data(__MODULE__.t()) :: binary()
  def raw_data(%__MODULE__{data: data}) do
    data
  end

  @spec read_byte(__MODULE__.t(), Sneex.BasicTypes.address()) :: byte()
  def read_byte(%__MODULE__{data: data}, address) do
    {_, result, _} = split_data(data, address, 1)
    result
  end

  @spec write_byte(__MODULE__.t(), Sneex.BasicTypes.address(), byte()) :: __MODULE__.t()
  def write_byte(%__MODULE__{data: data}, address, byte) do
    {pre, _, post} = split_data(data, address, 1)
    new_data = pre <> <<byte>> <> post
    %__MODULE__{data: new_data}
  end

  @spec read_word(__MODULE__.t(), Sneex.BasicTypes.address()) :: Sneex.BasicTypes.word()
  def read_word(%__MODULE__{data: data}, address) do
    {_, result, _} = split_data(data, address, 2)
    result
  end

  @spec write_word(__MODULE__.t(), Sneex.BasicTypes.address(), Sneex.BasicTypes.word()) ::
          __MODULE__.t()
  def write_word(%__MODULE__{data: data}, address, word) do
    {pre, _, post} = split_data(data, address, 2)
    new_data = pre <> unformat_data(word, 2) <> post
    %__MODULE__{data: new_data}
  end

  @spec read_long(__MODULE__.t(), Sneex.BasicTypes.address()) :: Sneex.BasicTypes.long()
  def read_long(%__MODULE__{data: data}, address) do
    {_, result, _} = split_data(data, address, 3)
    result
  end

  @spec write_long(__MODULE__.t(), Sneex.BasicTypes.address(), Sneex.BasicTypes.long()) ::
          __MODULE__.t()
  def write_long(%__MODULE__{data: data}, address, long) do
    {pre, _, post} = split_data(data, address, 3)
    new_data = pre <> unformat_data(long, 3) <> post
    %__MODULE__{data: new_data}
  end

  defp split_data(memory, 0, length) when is_binary(memory) and length <= byte_size(memory) do
    <<data::binary-size(length), rest::binary>> = memory
    {<<>>, format_data(data), rest}
  end

  defp split_data(memory, address, length)
       when is_binary(memory) and address + length <= byte_size(memory) do
    <<before::binary-size(address), data::binary-size(length), rest::binary>> = memory
    {before, format_data(data), rest}
  end

  defp format_data(<<b::size(8)>>), do: b

  defp format_data(<<b0::size(8), b1::size(8)>>) do
    b1 <<< 8 ||| b0
  end

  defp format_data(<<b0::size(8), b1::size(8), b2::size(8)>>) do
    b2 <<< 16 ||| b1 <<< 8 ||| b0
  end

  defp unformat_data(data, 2) do
    hi = data |> band(0xFF00) |> bsr(8)
    lo = data &&& 0x00FF
    <<lo, hi>>
  end

  defp unformat_data(data, 3) do
    hi = data |> band(0xFF0000) |> bsr(16)
    med = data |> band(0x00FF00) |> bsr(8)
    lo = data &&& 0x0000FF
    <<lo, med, hi>>
  end
end
