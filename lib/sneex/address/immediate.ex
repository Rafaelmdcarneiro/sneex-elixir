defmodule Sneex.Address.Immediate do
  @moduledoc "
  This module defines the implementation for immediate addressing
  "
  alias Sneex.{BasicTypes, Cpu}
  use Bitwise
  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: __MODULE__.t()
  def new, do: %__MODULE__{}

  defimpl Sneex.Address.Mode do
    def address(_mode, _cpu), do: 0

    def byte_size(_mode, cpu), do: cpu |> Cpu.acc_size() |> calc_byte_size()

    def fetch(mode, cpu) do
      size = byte_size(mode, cpu)
      cpu |> Cpu.read_operand(size)
    end

    def store(_mode, cpu, _data), do: cpu

    def disasm(mode, cpu) do
      size = byte_size(mode, cpu)
      cpu |> Cpu.read_operand(size) |> format_data(size)
    end

    defp format_data(data, 1), do: data |> BasicTypes.format_byte() |> format_data()
    defp format_data(data, 2), do: data |> BasicTypes.format_word() |> format_data()

    defp format_data(data), do: "##{data}"

    defp calc_byte_size(:bit8), do: 1
    defp calc_byte_size(:bit16), do: 2
  end
end
