defmodule Sneex.Address.CycleCalculator do
  @moduledoc """
  This module provides the mechanism to run through all of the modifiers for calculating the total cycles.
  It also provides various constructors for building modifiers.
  """
  alias Sneex.Cpu
  use Bitwise

  defstruct [:cycles, :check_func]

  @type t :: %__MODULE__{cycles: integer(), check_func: function()}

  # Cycle calculator
  @spec calc_cycles(Cpu.t(), list(__MODULE__.t())) :: integer()
  def calc_cycles(cpu, mods) do
    Enum.reduce(mods, 0, check_mod_builder(cpu))
  end

  defp check_mod_builder(cpu = %Cpu{}) do
    fn %__MODULE__{cycles: c, check_func: f}, count ->
      adj = cpu |> f.() |> check_mod(c)
      count + adj
    end
  end

  defp check_mod(true, c), do: c
  defp check_mod(_, _), do: 0

  # Constructors
  @spec constant(integer()) :: __MODULE__.t()
  def constant(cycles), do: %__MODULE__{cycles: cycles, check_func: fn _cpu -> true end}

  @spec acc_is_16_bit(integer()) :: __MODULE__.t()
  def acc_is_16_bit(cycles),
    do: %__MODULE__{cycles: cycles, check_func: build_check_cpu_func(&Cpu.acc_size/1, :bit16)}

  @spec index_is_16_bit(integer()) :: __MODULE__.t()
  def index_is_16_bit(cycles),
    do: %__MODULE__{cycles: cycles, check_func: build_check_cpu_func(&Cpu.index_size/1, :bit16)}

  @spec native_mode(integer()) :: __MODULE__.t()
  def native_mode(cycles),
    do: %__MODULE__{cycles: cycles, check_func: build_check_cpu_func(&Cpu.emu_mode/1, :native)}

  @spec low_direct_page_is_not_zero(integer()) :: __MODULE__.t()
  def low_direct_page_is_not_zero(cycles),
    do: %__MODULE__{cycles: cycles, check_func: &check_lower_byte_of_direct_page/1}

  @spec check_page_boundary(integer(), Sneex.BasicTypes.long(), :x | :y) :: __MODULE__.t()

  def check_page_boundary(cycles, initial_addr, :x) do
    func = build_page_boundary_func(initial_addr, &Cpu.x/1)
    %__MODULE__{cycles: cycles, check_func: func}
  end

  def check_page_boundary(cycles, initial_addr, :y) do
    func = build_page_boundary_func(initial_addr, &Cpu.y/1)
    %__MODULE__{cycles: cycles, check_func: func}
  end

  @spec check_page_boundary_and_emulation_mode(
          integer(),
          Sneex.BasicTypes.long(),
          Sneex.BasicTypes.long()
        ) ::
          __MODULE__.t()
  def check_page_boundary_and_emulation_mode(cycles, initial_addr, new_addr) do
    func = fn cpu ->
      is_emu? = :emulation == Cpu.emu_mode(cpu)
      cross_page? = check_page_boundary(initial_addr, new_addr)

      is_emu? and cross_page?
    end

    %__MODULE__{cycles: cycles, check_func: func}
  end

  defp build_page_boundary_func(initial_addr, accessor) do
    fn cpu ->
      index = cpu |> accessor.()
      indexed_addr = initial_addr + index
      check_page_boundary(initial_addr, indexed_addr)
    end
  end

  defp build_check_cpu_func(accessor, value) do
    get_data = &(&1 |> accessor.())
    &(value == get_data.(&1))
  end

  defp check_lower_byte_of_direct_page(cpu) do
    lower_byte = cpu |> Cpu.direct_page() |> band(0x00FF)
    0 != lower_byte
  end

  defp check_page_boundary(addr1, addr2) when band(addr1, 0xFFFF00) == band(addr2, 0xFFFF00),
    do: false

  defp check_page_boundary(_addr1, _addr2), do: true
end
