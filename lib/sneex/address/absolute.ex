defmodule Sneex.Address.Absolute do
  @moduledoc """
  This module defines the implementation for absolute addressing
  """
  defstruct [:type]

  alias Sneex.{BasicTypes, Cpu}
  use Bitwise

  @type t :: %__MODULE__{type: type()}
  @type type :: :data | :program | :long

  @spec new(boolean()) :: __MODULE__.t()
  def new(_is_data? = true), do: %__MODULE__{type: :data}
  def new(_is_data? = false), do: %__MODULE__{type: :program}

  @spec new_long() :: __MODULE__.t()
  def new_long, do: %__MODULE__{type: :long}

  defimpl Sneex.Address.Mode do
    def address(%{type: t}, cpu), do: t |> calc_addr(cpu)

    def byte_size(%{type: :long}, _cpu), do: 3
    def byte_size(_mode, _cpu), do: 2

    def fetch(mode, cpu) do
      addr = address(mode, cpu)
      cpu |> Cpu.read_data(addr)
    end

    def store(mode, cpu, data) do
      addr = address(mode, cpu)
      cpu |> Cpu.write_data(addr, data)
    end

    def disasm(mode = %{type: :long}, cpu), do: mode |> address(cpu) |> BasicTypes.format_long()

    def disasm(mode, cpu),
      do: mode |> address(cpu) |> band(0xFFFF) |> BasicTypes.format_word()

    defp calc_addr(:data, cpu), do: cpu |> Cpu.data_bank() |> calc_addr(cpu)
    defp calc_addr(:program, cpu), do: cpu |> Cpu.program_bank() |> calc_addr(cpu)
    defp calc_addr(:long, cpu), do: cpu |> Cpu.read_operand(3)

    defp calc_addr(bank, cpu) do
      operand = cpu |> Cpu.read_operand(2)
      bank |> bsl(16) |> bor(operand) |> band(0xFFFFFF)
    end
  end
end
