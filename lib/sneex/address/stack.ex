defmodule Sneex.Address.Stack do
  @moduledoc "This module defines the implementation for stack addressing"
  defstruct []

  alias Sneex.{BasicTypes, Cpu}
  use Bitwise

  @type t :: %__MODULE__{}

  @spec new() :: __MODULE__.t()
  def new, do: %__MODULE__{}

  defimpl Sneex.Address.Mode do
    def address(%{}, cpu) do
      operand = cpu |> Cpu.read_operand(1)
      stack = cpu |> Cpu.stack_ptr()
      (stack + operand) |> band(0xFFFF)
    end

    def byte_size(_mode, _cpu), do: 1

    def fetch(mode, cpu) do
      addr = address(mode, cpu)
      cpu |> Cpu.read_data(addr)
    end

    def store(mode, cpu, data) do
      addr = address(mode, cpu)
      cpu |> Cpu.write_data(addr, data)
    end

    def disasm(_mode, cpu) do
      operand = cpu |> Cpu.read_operand(1)
      "#{BasicTypes.format_byte(operand)},S"
    end
  end
end
