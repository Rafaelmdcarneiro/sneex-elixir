defmodule Sneex.Ops.And do
  @moduledoc "This module represents the AND operation."
  defstruct [:cycle_mods, :address_mode, :preindex_mode, :index_reg]

  use Bitwise

  alias Sneex.Address.{
    Absolute,
    CycleCalculator,
    DirectPage,
    Immediate,
    Indexed,
    Indirect,
    Mode,
    Stack
  }

  alias Sneex.{Cpu, CpuHelper}

  @type t :: %__MODULE__{
          cycle_mods: list(CycleCalculator.t()),
          address_mode: any(),
          preindex_mode: nil | any(),
          index_reg: nil | :x | :y
        }

  @immediate 0x29
  @absolute 0x2D
  @absolute_long 0x2F
  @direct_page 0x25
  @direct_page_indirect 0x32
  @direct_page_indirect_long 0x27
  @absolute_indexed_x 0x3D
  @absolute_long_indexed_x 0x3F
  @absolute_indexed_y 0x39
  @direct_page_indexed_x 0x35
  @direct_page_indexed_x_indirect 0x21
  @direct_page_indirect_indexed_y 0x31
  @direct_page_indirect_long_indexed_y 0x37
  @stack_relative 0x23
  @stack_relative_indirect_indexed_y 0x33

  @spec new(Cpu.t() | byte()) :: nil | __MODULE__.t()
  def new(cpu = %Cpu{}) do
    cpu |> Cpu.read_opcode() |> new()
  end

  def new(@immediate) do
    %__MODULE__{
      address_mode: Immediate.new(),
      cycle_mods: [CycleCalculator.constant(2), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@absolute) do
    %__MODULE__{
      address_mode: Absolute.new(true),
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@absolute_long) do
    %__MODULE__{
      address_mode: Absolute.new_long(),
      cycle_mods: [CycleCalculator.constant(5), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@direct_page) do
    %__MODULE__{
      address_mode: DirectPage.new(),
      cycle_mods: [
        CycleCalculator.constant(3),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@direct_page_indirect) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indirect.new_data(),
      cycle_mods: [
        CycleCalculator.constant(5),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@direct_page_indirect_long) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indirect.new_long(),
      cycle_mods: [
        CycleCalculator.constant(6),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@absolute_indexed_x) do
    premode = true |> Absolute.new()

    %__MODULE__{
      address_mode: premode |> Indexed.new(:x),
      preindex_mode: premode,
      index_reg: :x,
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@absolute_long_indexed_x) do
    %__MODULE__{
      address_mode: Absolute.new_long() |> Indexed.new(:x),
      cycle_mods: [CycleCalculator.constant(5), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@absolute_indexed_y) do
    premode = true |> Absolute.new()

    %__MODULE__{
      address_mode: premode |> Indexed.new(:y),
      preindex_mode: premode,
      index_reg: :y,
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@direct_page_indexed_x) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indexed.new(:x),
      cycle_mods: [
        CycleCalculator.constant(4),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@direct_page_indexed_x_indirect) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indexed.new(:x) |> Indirect.new_data(),
      cycle_mods: [
        CycleCalculator.constant(6),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@direct_page_indirect_indexed_y) do
    premode = DirectPage.new() |> Indirect.new_data()

    %__MODULE__{
      address_mode: premode |> Indexed.new(:y),
      preindex_mode: premode,
      index_reg: :y,
      cycle_mods: [
        CycleCalculator.constant(5),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@direct_page_indirect_long_indexed_y) do
    %__MODULE__{
      address_mode: DirectPage.new() |> Indirect.new_long() |> Indexed.new(:y),
      cycle_mods: [
        CycleCalculator.constant(6),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ]
    }
  end

  def new(@stack_relative) do
    %__MODULE__{
      address_mode: Stack.new(),
      cycle_mods: [CycleCalculator.constant(4), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(@stack_relative_indirect_indexed_y) do
    %__MODULE__{
      address_mode: Stack.new() |> Indirect.new_data() |> Indexed.new(:y),
      cycle_mods: [CycleCalculator.constant(7), CycleCalculator.acc_is_16_bit(1)]
    }
  end

  def new(_opcode), do: nil

  defimpl Sneex.Ops.Opcode do
    def byte_size(%{address_mode: mode}, cpu), do: Mode.byte_size(mode, cpu) + 1

    def total_cycles(%{preindex_mode: nil, cycle_mods: mods}, cpu) do
      CycleCalculator.calc_cycles(cpu, mods)
    end

    def total_cycles(%{preindex_mode: premode, index_reg: reg, cycle_mods: mods}, cpu) do
      initial_addr = Mode.address(premode, cpu)
      boundary_mod = CycleCalculator.check_page_boundary(1, initial_addr, reg)
      CycleCalculator.calc_cycles(cpu, [boundary_mod | mods])
    end

    def execute(%{address_mode: mode}, cpu) do
      acc_size = cpu |> Cpu.acc_size()
      data = mode |> Mode.fetch(cpu)

      result = cpu |> Cpu.acc() |> band(data)
      %{negative: nf, zero: zf} = result |> CpuHelper.check_flags_for_value(acc_size)

      cpu |> Cpu.acc(result) |> Cpu.negative_flag(nf) |> Cpu.zero_flag(zf)
    end

    def disasm(%{address_mode: mode}, cpu), do: "AND #{Mode.disasm(mode, cpu)}"
  end
end
