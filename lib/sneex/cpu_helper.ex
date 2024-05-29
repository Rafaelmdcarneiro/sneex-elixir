defmodule Sneex.CpuHelper do
  @moduledoc "This module defines helper functions for checking CPU flags."

  use Bitwise

  @doc "
  This function will determine new values for several of the CPU flags.

  ## Examples

  iex> 0 |> Sneex.CpuHelper.check_flags_for_value(:bit8)
  %{carry: false, negative: false, overflow: false, zero: true}

  iex> 0 |> Sneex.CpuHelper.check_flags_for_value(:bit16)
  %{carry: false, negative: false, overflow: false, zero: true}

  iex> 0x80 |> Sneex.CpuHelper.check_flags_for_value(:bit8)
  %{carry: false, negative: true, overflow: false, zero: false}

  iex> 0x80 |> Sneex.CpuHelper.check_flags_for_value(:bit16)
  %{carry: false, negative: false, overflow: false, zero: false}

  iex> 0x7FFF |> Sneex.CpuHelper.check_flags_for_value(:bit16)
  %{carry: false, negative: false, overflow: true, zero: false}

  iex> 0x8000 |> Sneex.CpuHelper.check_flags_for_value(:bit16)
  %{carry: false, negative: true, overflow: false, zero: false}
  "
  @spec check_flags_for_value(integer(), Sneex.Cpu.bit_size()) :: %{
          carry: boolean(),
          negative: boolean(),
          overflow: boolean(),
          zero: boolean()
        }
  def check_flags_for_value(value, bitness) do
    %{
      negative: check_negative_flag(value, bitness),
      overflow: check_overflow_flag(value, bitness),
      zero: check_zero_flag(value),
      carry: check_carry_flag(value)
    }
  end

  defp check_negative_flag(value, :bit8) when 0x80 == band(value, 0x80), do: true
  defp check_negative_flag(value, :bit16) when 0x8000 == band(value, 0x8000), do: true
  defp check_negative_flag(_value, _bitness), do: false

  # Still need to figure this out
  defp check_overflow_flag(value, :bit8) when 0x40 == band(value, 0x40), do: true
  defp check_overflow_flag(value, :bit16) when 0x4000 == band(value, 0x4000), do: true
  defp check_overflow_flag(_value, _bitness), do: false

  defp check_zero_flag(0), do: true
  defp check_zero_flag(_), do: false

  # Still need to figure this out
  defp check_carry_flag(_value), do: false

  @doc "
  This function will rotate a value 1 step to the left or right, filling in 0's.
  It returns a tuple containing the updated value and the bit that was rotated off the value.

  ## Examples - Rotating Left

  iex> 0 |> Sneex.CpuHelper.rotate(:bit8, :left)
  {0, false}

  iex> 0 |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0, false}

  iex> 0x80 |> Sneex.CpuHelper.rotate(:bit8, :left)
  {0, true}

  iex> 0x80 |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0x0100, false}

  iex> 0xFF |> Sneex.CpuHelper.rotate(:bit8, :left)
  {0xFE, true}

  iex> 0xFF |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0x01FE, false}

  iex> 0x7FFF |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0xFFFE, false}

  iex> 0x8000 |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0, true}

  iex> 0xFFFF |> Sneex.CpuHelper.rotate(:bit16, :left)
  {0xFFFE, true}

  ## Examples - Rotating Right

  iex> 0 |> Sneex.CpuHelper.rotate(:bit8, :right)
  {0, false}

  iex> 0 |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0, false}

  iex> 0x80 |> Sneex.CpuHelper.rotate(:bit8, :right)
  {0x40, false}

  iex> 0x80 |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0x40, false}

  iex> 0xFF |> Sneex.CpuHelper.rotate(:bit8, :right)
  {0x7F, true}

  iex> 0xFF |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0x7F, true}

  iex> 0x7FFF |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0x3FFF, true}

  iex> 0x8000 |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0x4000, false}

  iex> 0xFFFF |> Sneex.CpuHelper.rotate(:bit16, :right)
  {0x7FFF, true}
  "
  @spec rotate(integer(), Sneex.Cpu.bit_size(), :left | :right) :: {integer(), boolean()}
  def rotate(value, bitness, :left) do
    mask = bitness |> rotate_left_mask()
    negative? = value |> check_negative_flag(bitness)
    new_value = value |> bsl(1) |> band(mask)
    {new_value, negative?}
  end

  def rotate(value, _bitness, :right) do
    mask = 0x0001
    is_zero? = value |> band(mask) |> check_zero_flag()
    new_value = value |> bsr(1)
    {new_value, not is_zero?}
  end

  defp rotate_left_mask(:bit8), do: 0xFF
  defp rotate_left_mask(:bit16), do: 0xFFFF
end
