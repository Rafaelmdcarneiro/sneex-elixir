defmodule Sneex.Address.Indirect do
  @moduledoc "
  This module defines the implementation for indirect addressing
  "
  defstruct [:base_mode, :type]
  alias Sneex.Address.Mode
  alias Sneex.Cpu
  use Bitwise

  @type t :: %__MODULE__{base_mode: any(), type: type()}
  @type type :: :data | :program | :long

  @spec new_data(any()) :: __MODULE__.t()
  def new_data(base), do: %__MODULE__{base_mode: base, type: :data}

  @spec new_program(any()) :: __MODULE__.t()
  def new_program(base), do: %__MODULE__{base_mode: base, type: :program}

  @spec new_long(any()) :: __MODULE__.t()
  def new_long(base), do: %__MODULE__{base_mode: base, type: :long}

  defimpl Sneex.Address.Mode do
    def address(%{base_mode: base, type: :data}, cpu) do
      cpu |> Cpu.data_bank() |> calc_addr(base, cpu)
    end

    def address(%{base_mode: base, type: :program}, cpu) do
      cpu |> Cpu.program_bank() |> calc_addr(base, cpu)
    end

    def address(%{base_mode: base, type: :long}, cpu) do
      indirect_addr = base |> Mode.address(cpu)
      cpu |> Cpu.read_data(indirect_addr, 3)
    end

    def byte_size(%{base_mode: mode}, cpu), do: Mode.byte_size(mode, cpu)

    def fetch(mode, cpu) do
      addr = address(mode, cpu)
      cpu |> Cpu.read_data(addr)
    end

    def store(mode, cpu, data) do
      addr = address(mode, cpu)
      cpu |> Cpu.write_data(addr, data)
    end

    def disasm(%{base_mode: mode, type: :long}, cpu), do: "[#{Mode.disasm(mode, cpu)}]"
    def disasm(%{base_mode: mode}, cpu), do: "(#{Mode.disasm(mode, cpu)})"

    defp calc_addr(bank, base, cpu) do
      indirect_addr = base |> Mode.address(cpu)
      offset = cpu |> Cpu.read_data(indirect_addr, 2)
      bank |> bsl(16) |> bor(offset) |> band(0xFFFFFF)
    end
  end
end
