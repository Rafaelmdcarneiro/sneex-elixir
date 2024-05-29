defmodule Sneex.Address.Helper do
  @moduledoc """
  This module defines common functions that are used by various addressing modes
  Maybe this ends up going away?
  """
  alias Sneex.Cpu
  use Bitwise

  def indexed(addr, cpu = %Cpu{}, :x), do: (addr + Cpu.x(cpu)) |> band(0xFFFFFF)
  def indexed(addr, cpu = %Cpu{}, :y), do: (addr + Cpu.y(cpu)) |> band(0xFFFFFF)

  def calc_offset(part1, part2), do: (part1 + part2) |> band(0xFFFF)

  def absolute_offset(upper_byte, addr), do: upper_byte |> bsl(16) |> bor(addr) |> band(0xFFFFFF)

  def read_indirect(addr, cpu = %Cpu{}, size), do: cpu |> Cpu.read_data(addr, size)

  def extra_cycle_for_16_bit(:bit16), do: 1
  def extra_cycle_for_16_bit(_), do: 0
end
