defmodule Sneex.Address.DirectPage do
  @moduledoc """
  This module defines the behavior for accessing direct page memory.
  """
  alias Sneex.{BasicTypes, Cpu}
  use Bitwise

  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: __MODULE__.t()
  def new do
    %__MODULE__{}
  end

  defimpl Sneex.Address.Mode do
    def address(_mode, cpu), do: cpu |> calc_addr()

    def byte_size(_mode, _cpu), do: 1

    def fetch(mode, cpu) do
      addr = mode |> address(cpu)
      cpu |> Cpu.read_data(addr)
    end

    def store(mode, cpu, data) do
      addr = mode |> address(cpu)
      cpu |> Cpu.write_data(addr, data)
    end

    def disasm(_mode, cpu) do
      cpu |> Cpu.read_operand(1) |> BasicTypes.format_byte()
    end

    defp calc_addr(cpu) do
      dp = cpu |> Cpu.direct_page()
      op = cpu |> Cpu.read_operand(1)

      (op + dp) |> band(0xFFFF)
    end
  end
end
