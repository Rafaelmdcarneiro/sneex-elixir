defmodule Sneex.BasicTypes do
  @moduledoc """
  This module defines some basic data types that are used across the application.
  """
  use Bitwise

  @type word :: 0x00..0xFFFF
  @type long :: 0x00..0xFFFFFF
  @type address :: 0x00..0xFFFFFF

  @spec format_byte(byte()) :: String.t()
  def format_byte(byte) when is_integer(byte) and byte >= 0x00 and byte <= 0xFF do
    "$" <> format_data(byte, 2)
  end

  @spec format_word(word()) :: String.t()
  def format_word(word) when is_integer(word) and word >= 0x0000 and word <= 0xFFFF do
    "$" <> format_data(word, 4)
  end

  @spec format_long(long()) :: String.t()
  def format_long(long) when is_integer(long) and long >= 0x000000 and long <= 0xFFFFFF do
    "$" <> format_data(long, 6)
  end

  defp format_data(data, length) do
    data
    |> Integer.to_string(16)
    |> String.pad_leading(length, "0")
  end

  @doc "
  Converts an 8-bit value into a 2's complement signed value

  ## Examples

  iex> Sneex.BasicTypes.signed_byte(0x01)
  1

  iex> Sneex.BasicTypes.signed_byte(0x11)
  17

  iex> Sneex.BasicTypes.signed_byte(0xAA)
  -86

  iex> Sneex.BasicTypes.signed_byte(0xFF)
  -1
  "
  @spec signed_byte(byte()) :: integer()
  def signed_byte(val) when val < 0x80, do: val

  def signed_byte(val) when val >= 0x80 and val <= 0xFF do
    temp = val |> band(0xFF) |> bxor(0xFF)
    (temp + 1) * -1
  end

  @doc "
  Converts an 16-bit value into a 2's complement signed value

  ## Examples

  iex> Sneex.BasicTypes.signed_word(0x01)
  1

  iex> Sneex.BasicTypes.signed_word(0x1111)
  4369

  iex> Sneex.BasicTypes.signed_word(0xAABB)
  -21829

  iex> Sneex.BasicTypes.signed_word(0xFFFF)
  -1
  "
  @spec signed_word(word()) :: integer()
  def signed_word(val) when val < 0x8000, do: val

  def signed_word(val) when val >= 0x8000 and val <= 0xFFFF do
    temp = val |> band(0xFFFF) |> bxor(0xFFFF)
    (temp + 1) * -1
  end
end
