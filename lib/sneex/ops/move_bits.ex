defmodule Sneex.Ops.MoveBits do
  @moduledoc "
  This represents the op codes for moving the bits of a value
  This can either be a shift (where 0's fill in the bit, and the
  moved bit goes to the carry flag) or a rotation (where the
  carry flag is filled in and the moved bit goes to the carry flag).
  "
  defstruct [:cycle_mods, :address_mode, :operation, :disasm]

  use Bitwise

  alias Sneex.Address.{Absolute, CycleCalculator, DirectPage, Indexed, Mode, Register}
  alias Sneex.{Cpu, CpuHelper}

  @type t :: %__MODULE__{
          cycle_mods: list(CycleCalculator.t()),
          address_mode: any(),
          operation: function(),
          disasm: String.t()
        }

  @spec new(Cpu.t() | byte()) :: nil | __MODULE__.t()
  def new(cpu = %Cpu{}) do
    cpu |> Cpu.read_opcode() |> new()
  end

  def new(opcode), do: opcode |> determine_base_data() |> set_function_and_disasm(opcode)

  defp determine_base_data(op) when 0x1E == band(op, 0x1E) do
    %__MODULE__{
      cycle_mods: [CycleCalculator.constant(7), CycleCalculator.acc_is_16_bit(2)],
      address_mode: true |> Absolute.new() |> Indexed.new(:x)
    }
  end

  defp determine_base_data(op) when 0x0E == band(op, 0x0E) do
    %__MODULE__{
      cycle_mods: [CycleCalculator.constant(6), CycleCalculator.acc_is_16_bit(2)],
      address_mode: true |> Absolute.new()
    }
  end

  defp determine_base_data(op) when 0x0A == band(op, 0x0A) do
    %__MODULE__{
      cycle_mods: [CycleCalculator.constant(2)],
      address_mode: Register.new(:acc)
    }
  end

  defp determine_base_data(op) when 0x16 == band(op, 0x16) do
    %__MODULE__{
      cycle_mods: [
        CycleCalculator.constant(6),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      address_mode: DirectPage.new() |> Indexed.new(:x)
    }
  end

  defp determine_base_data(op) when 0x06 == band(op, 0x06) do
    %__MODULE__{
      cycle_mods: [
        CycleCalculator.constant(5),
        CycleCalculator.acc_is_16_bit(1),
        CycleCalculator.low_direct_page_is_not_zero(1)
      ],
      address_mode: DirectPage.new()
    }
  end

  defp determine_base_data(_op), do: nil

  defp set_function_and_disasm(data = %__MODULE__{}, op)
       when 0x00 == band(op, 0xF0) or 0x10 == band(op, 0xF0) do
    %__MODULE__{data | disasm: "ASL", operation: build_shift_function(:left)}
  end

  defp set_function_and_disasm(data = %__MODULE__{}, op)
       when 0x40 == band(op, 0xF0) or 0x50 == band(op, 0xF0) do
    %__MODULE__{data | disasm: "LSR", operation: build_shift_function(:right)}
  end

  defp set_function_and_disasm(data = %__MODULE__{}, op)
       when 0x20 == band(op, 0xF0) or 0x30 == band(op, 0xF0) do
    %__MODULE__{data | disasm: "ROL", operation: build_rotate_function(:left)}
  end

  defp set_function_and_disasm(data = %__MODULE__{}, op)
       when 0x60 == band(op, 0xF0) or 0x70 == band(op, 0xF0) do
    %__MODULE__{data | disasm: "ROR", operation: build_rotate_function(:right)}
  end

  defp set_function_and_disasm(_data, _op), do: nil

  defp build_shift_function(direction) do
    fn value, bitness, _carry_flag ->
      CpuHelper.rotate(value, bitness, direction)
    end
  end

  defp build_rotate_function(direction) do
    fn value, bitness, carry_flag ->
      mask = adjust_rotation_mask(bitness, direction, carry_flag)

      {new_value, new_carry_flag} = CpuHelper.rotate(value, bitness, direction)
      adjusted_value = bor(new_value, mask)

      {adjusted_value, new_carry_flag}
    end
  end

  defp adjust_rotation_mask(_bitness, :left, true), do: 0x0001
  defp adjust_rotation_mask(:bit8, :right, true), do: 0x80
  defp adjust_rotation_mask(:bit16, :right, true), do: 0x8000
  defp adjust_rotation_mask(_bitness, _direction, false), do: 0x0000

  defimpl Sneex.Ops.Opcode do
    def byte_size(%{address_mode: mode}, cpu), do: Mode.byte_size(mode, cpu) + 1

    def total_cycles(%{cycle_mods: mods}, cpu) do
      CycleCalculator.calc_cycles(cpu, mods)
    end

    def execute(%{address_mode: mode, operation: op}, cpu) do
      acc_size = cpu |> Cpu.acc_size()
      carry_flag = cpu |> Cpu.carry_flag()
      {result, new_carry_flag} = mode |> Mode.fetch(cpu) |> op.(acc_size, carry_flag)
      %{negative: nf, zero: zf} = result |> CpuHelper.check_flags_for_value(acc_size)
      cpu = mode |> Mode.store(cpu, result)

      cpu |> Cpu.negative_flag(nf) |> Cpu.zero_flag(zf) |> Cpu.carry_flag(new_carry_flag)
    end

    def disasm(%{address_mode: mode, disasm: disasm}, cpu),
      do: "#{disasm} #{Mode.disasm(mode, cpu)}"
  end
end
