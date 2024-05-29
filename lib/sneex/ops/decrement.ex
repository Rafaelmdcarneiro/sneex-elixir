defmodule Sneex.Ops.Decrement do
  @moduledoc """
  This represents the op codes for decrementing a value (DEC, DEX, and DEY).
  """
  defstruct [:disasm_override, :bit_size, :cycle_mods, :address_mode]

  alias Sneex.Address.{Absolute, CycleCalculator, DirectPage, Indexed, Mode, Register}
  alias Sneex.{Cpu, CpuHelper}
  use Bitwise

  @type t :: %__MODULE__{
          disasm_override: nil | String.t(),
          bit_size: :bit8 | :bit16,
          cycle_mods: list(CycleCalculator.t()),
          address_mode: any()
        }

  @spec new(Cpu.t() | byte()) :: nil | __MODULE__.t()
  def new(cpu = %Cpu{}) do
    cpu |> Cpu.read_opcode() |> new(cpu)
  end

  @spec new(byte(), Cpu.t()) :: nil | __MODULE__.t()

  def new(0x3A, cpu) do
    addr_mode = :acc |> Register.new()
    bit_size = cpu |> Cpu.acc_size()
    mods = [CycleCalculator.constant(2)]
    %__MODULE__{bit_size: bit_size, cycle_mods: mods, address_mode: addr_mode}
  end

  def new(0xCE, cpu) do
    addr_mode = true |> Absolute.new()
    bit_size = cpu |> Cpu.acc_size()
    mods = [CycleCalculator.constant(6), CycleCalculator.acc_is_16_bit(2)]
    %__MODULE__{bit_size: bit_size, cycle_mods: mods, address_mode: addr_mode}
  end

  def new(0xC6, cpu) do
    addr_mode = DirectPage.new()
    bit_size = cpu |> Cpu.acc_size()

    mods = [
      CycleCalculator.constant(5),
      CycleCalculator.acc_is_16_bit(2),
      CycleCalculator.low_direct_page_is_not_zero(1)
    ]

    %__MODULE__{bit_size: bit_size, cycle_mods: mods, address_mode: addr_mode}
  end

  def new(0xDE, cpu) do
    addr_mode = true |> Absolute.new() |> Indexed.new(:x)
    bit_size = cpu |> Cpu.acc_size()
    mods = [CycleCalculator.constant(7), CycleCalculator.acc_is_16_bit(2)]
    %__MODULE__{bit_size: bit_size, cycle_mods: mods, address_mode: addr_mode}
  end

  def new(0xD6, cpu) do
    addr_mode = DirectPage.new() |> Indexed.new(:x)
    bit_size = cpu |> Cpu.acc_size()

    mods = [
      CycleCalculator.constant(6),
      CycleCalculator.acc_is_16_bit(2),
      CycleCalculator.low_direct_page_is_not_zero(1)
    ]

    %__MODULE__{bit_size: bit_size, cycle_mods: mods, address_mode: addr_mode}
  end

  def new(0xCA, cpu) do
    addr_mode = :x |> Register.new()
    bit_size = cpu |> Cpu.index_size()
    mods = [CycleCalculator.constant(2)]

    %__MODULE__{
      disasm_override: "DEX",
      bit_size: bit_size,
      cycle_mods: mods,
      address_mode: addr_mode
    }
  end

  def new(0x88, cpu) do
    addr_mode = :y |> Register.new()
    bit_size = cpu |> Cpu.index_size()
    mods = [CycleCalculator.constant(2)]

    %__MODULE__{
      disasm_override: "DEY",
      bit_size: bit_size,
      cycle_mods: mods,
      address_mode: addr_mode
    }
  end

  def new(_opcode, _cpu), do: nil

  defimpl Sneex.Ops.Opcode do
    def byte_size(%{address_mode: mode}, cpu), do: 1 + Mode.byte_size(mode, cpu)

    def total_cycles(%{cycle_mods: mods}, cpu) do
      cpu |> CycleCalculator.calc_cycles(mods)
    end

    def execute(%{address_mode: mode, bit_size: bit_size}, cpu) do
      {data, cpu} = mode |> Mode.fetch(cpu) |> decrement(bit_size, cpu)
      mode |> Mode.store(cpu, data)
    end

    defp decrement(0, bit_size, cpu = %Cpu{}) do
      new_value = bit_size |> determine_mask() |> band(0xFFFF)
      %{negative: nf, zero: zf} = CpuHelper.check_flags_for_value(new_value, bit_size)
      new_cpu = cpu |> Cpu.zero_flag(zf) |> Cpu.negative_flag(nf)
      {new_value, new_cpu}
    end

    defp decrement(value, bit_size, cpu = %Cpu{}) do
      new_value = bit_size |> determine_mask() |> band(value - 1)
      %{negative: nf, zero: zf} = CpuHelper.check_flags_for_value(new_value, bit_size)
      new_cpu = cpu |> Cpu.zero_flag(zf) |> Cpu.negative_flag(nf)
      {new_value, new_cpu}
    end

    defp determine_mask(:bit8), do: 0xFF
    defp determine_mask(:bit16), do: 0xFFFF

    def disasm(%{disasm_override: nil, address_mode: mode}, cpu),
      do: "DEC #{Mode.disasm(mode, cpu)}"

    def disasm(%{disasm_override: override}, _cpu), do: override
  end
end
