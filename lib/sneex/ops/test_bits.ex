defmodule Sneex.Ops.TestBits do
  @moduledoc "This represents the op codes for testing memory against the accumulator (BIT, TRB, TSB)."
  defstruct [:cycle_mods, :address_mode, :operation, :disasm, :preindex_mode]

  use Bitwise

  alias Sneex.Address.{Absolute, CycleCalculator, DirectPage, Immediate, Indexed, Mode}
  alias Sneex.{Cpu, CpuHelper}

  @type t :: %__MODULE__{
          cycle_mods: list(CycleCalculator.t()),
          address_mode: any(),
          operation: function(),
          disasm: String.t(),
          preindex_mode: any()
        }

  @bit_immediate 0x89
  @bit_absolute 0x2C
  @bit_direct_page 0x24
  @bit_absolute_indexed_x 0x3C
  @bit_direct_page_indexed_x 0x34

  @trb_absolute 0x1C
  @trb_direct_page 0x14

  @tsb_absolute 0x0C
  @tsb_direct_page 0x04

  @spec new(Cpu.t() | byte()) :: nil | __MODULE__.t()
  def new(cpu = %Cpu{}) do
    cpu |> Cpu.read_opcode() |> new()
  end

  def new(@bit_immediate) do
    %__MODULE__{
      address_mode: Immediate.new(),
      cycle_mods: [CycleCalculator.constant(2), CycleCalculator.acc_is_16_bit(1)],
      operation: &perform_bit/2,
      disasm: "BIT"
    }
  end

  def new(@bit_absolute) do
    %__MODULE__{
      address_mode: Absolute.new(true),
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)],
      operation: &perform_bit/2,
      disasm: "BIT"
    }
  end

  def new(@bit_direct_page) do
    %__MODULE__{
      address_mode: DirectPage.new(),
      cycle_mods: [
        CycleCalculator.constant(3),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      operation: &perform_bit/2,
      disasm: "BIT"
    }
  end

  def new(@bit_absolute_indexed_x) do
    premode = true |> Absolute.new()

    %__MODULE__{
      address_mode: premode |> Indexed.new(:x),
      preindex_mode: premode,
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)],
      operation: &perform_bit/2,
      disasm: "BIT"
    }
  end

  def new(@bit_direct_page_indexed_x) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indexed.new(:x),
      cycle_mods: [
        CycleCalculator.constant(4),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      operation: &perform_bit/2,
      disasm: "BIT"
    }
  end

  def new(@trb_absolute) do
    %__MODULE__{
      address_mode: Absolute.new(true),
      cycle_mods: [CycleCalculator.constant(6), CycleCalculator.acc_is_16_bit(2)],
      operation: &perform_trb/2,
      disasm: "TRB"
    }
  end

  def new(@trb_direct_page) do
    %__MODULE__{
      address_mode: DirectPage.new(),
      cycle_mods: [
        CycleCalculator.constant(5),
        CycleCalculator.acc_is_16_bit(2),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      operation: &perform_trb/2,
      disasm: "TRB"
    }
  end

  def new(@tsb_absolute) do
    %__MODULE__{
      address_mode: Absolute.new(true),
      cycle_mods: [CycleCalculator.constant(6), CycleCalculator.acc_is_16_bit(2)],
      operation: &perform_tsb/2,
      disasm: "TSB"
    }
  end

  def new(@tsb_direct_page) do
    %__MODULE__{
      address_mode: DirectPage.new(),
      cycle_mods: [
        CycleCalculator.constant(5),
        CycleCalculator.acc_is_16_bit(2),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      operation: &perform_tsb/2,
      disasm: "TSB"
    }
  end

  def new(_opcode), do: nil

  @spec perform_bit(Sneex.Cpu.t(), any) :: Sneex.Cpu.t()
  def perform_bit(cpu, address_mode) do
    data = Mode.fetch(address_mode, cpu)
    bitness = Cpu.acc_size(cpu)
    %{negative: nf, overflow: vf} = CpuHelper.check_flags_for_value(data, bitness)

    %{zero: zf} = cpu |> Cpu.acc() |> band(data) |> CpuHelper.check_flags_for_value(bitness)

    cpu |> Cpu.negative_flag(nf) |> Cpu.overflow_flag(vf) |> Cpu.zero_flag(zf)
  end

  @spec perform_trb(Sneex.Cpu.t(), any) :: Sneex.Cpu.t()
  def perform_trb(cpu, address_mode) do
    data = Mode.fetch(address_mode, cpu)
    bitness = Cpu.acc_size(cpu)
    data_complement = complement(data, bitness)
    acc = cpu |> Cpu.acc()

    result = band(acc, data_complement)
    %{zero: zf} = acc |> band(data) |> CpuHelper.check_flags_for_value(bitness)

    address_mode |> Mode.store(cpu, result) |> Cpu.zero_flag(zf)
  end

  @spec perform_tsb(Sneex.Cpu.t(), any) :: Sneex.Cpu.t()
  def perform_tsb(cpu, address_mode) do
    data = Mode.fetch(address_mode, cpu)
    bitness = Cpu.acc_size(cpu)
    acc = cpu |> Cpu.acc()

    result = bor(acc, data)
    %{zero: zf} = acc |> band(data) |> CpuHelper.check_flags_for_value(bitness)

    address_mode |> Mode.store(cpu, result) |> Cpu.zero_flag(zf)
  end

  defp complement(data, :bit8), do: data |> bnot() |> band(0xFF)
  defp complement(data, :bit16), do: data |> bnot() |> band(0xFFFF)

  defimpl Sneex.Ops.Opcode do
    def byte_size(%{address_mode: mode}, cpu), do: Mode.byte_size(mode, cpu) + 1

    def total_cycles(%{preindex_mode: nil, cycle_mods: mods}, cpu) do
      CycleCalculator.calc_cycles(cpu, mods)
    end

    def total_cycles(%{preindex_mode: premode, cycle_mods: mods}, cpu) do
      initial_addr = Mode.address(premode, cpu)
      boundary_mod = CycleCalculator.check_page_boundary(1, initial_addr, :x)
      CycleCalculator.calc_cycles(cpu, [boundary_mod | mods])
    end

    def execute(%{address_mode: mode, operation: op}, cpu), do: op.(cpu, mode)

    def disasm(%{address_mode: mode, disasm: disasm}, cpu),
      do: "#{disasm} #{Mode.disasm(mode, cpu)}"
  end
end
