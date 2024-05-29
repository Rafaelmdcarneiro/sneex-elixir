defmodule Sneex.Address.Register do
  @moduledoc """
  This module handles data from one of the registers (accumulator, X, or Y).
  """
  alias Sneex.Cpu

  defstruct [:read, :write, :register]

  @type t :: %__MODULE__{read: function(), write: function(), register: String.t()}
  @type registers :: :acc | :x | :y

  @spec new(registers()) :: __MODULE__.t()
  def new(:x), do: %__MODULE__{read: &Cpu.x/1, write: &Cpu.x/2, register: "X"}
  def new(:y), do: %__MODULE__{read: &Cpu.y/1, write: &Cpu.y/2, register: "Y"}
  def new(:acc), do: %__MODULE__{read: &Cpu.acc/1, write: &Cpu.acc/2, register: "A"}

  defimpl Sneex.Address.Mode do
    def address(_mode, _cpu), do: 0x0000

    def byte_size(_mode, _cpu), do: 0

    def fetch(%{read: read}, cpu), do: cpu |> read.()

    def store(%{write: write}, cpu, data), do: cpu |> write.(data)

    def disasm(%{register: r}, _cpu), do: r
  end
end
