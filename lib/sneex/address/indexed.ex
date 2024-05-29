defmodule Sneex.Address.Indexed do
  @moduledoc """
  This is an address modifier that can be used to adjust an address based off of
  one of the index registers (X or Y).
  """
  alias Sneex.Address.Mode
  alias Sneex.Cpu

  defstruct [:base_mode, :register]

  @type t :: %__MODULE__{base_mode: any(), register: index_registers()}
  @type index_registers :: :x | :y

  @spec new(any(), index_registers()) :: __MODULE__.t()
  def new(base, register) do
    %__MODULE__{base_mode: base, register: register}
  end

  defimpl Sneex.Address.Mode do
    def address(%{base_mode: base, register: r}, cpu) do
      base |> Mode.address(cpu) |> adjust_address(cpu, r)
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

    def disasm(%{base_mode: mode, register: :x}, cpu), do: "#{Mode.disasm(mode, cpu)},X"
    def disasm(%{base_mode: mode, register: :y}, cpu), do: "#{Mode.disasm(mode, cpu)},Y"

    defp adjust_address(address, cpu, :x), do: address + Cpu.x(cpu)
    defp adjust_address(address, cpu, :y), do: address + Cpu.y(cpu)
  end
end
