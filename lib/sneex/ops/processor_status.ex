defmodule Sneex.Ops.ProcessorStatus do
  @moduledoc """
  This represents the op codes for interacting with the processor status bits.
  This includes the following commands:
  CLC, SEC, CLD, SED, REP, SEP, SEI, CLI, CLV, NOP, XBA, and XCE

  One thing to note about this opcode is that since it doesn't do a lot of memory addressing,
  it has not (and may never?) be updated to make use of the new addressing mode fuctionality.
  """
  defstruct [:opcode]

  use Bitwise
  alias Sneex.{BasicTypes, Cpu}

  @opaque t :: %__MODULE__{
            opcode:
              0x18 | 0x38 | 0xD8 | 0xF8 | 0xC2 | 0xE2 | 0x78 | 0x58 | 0xB8 | 0xEA | 0xEB | 0xFB
          }

  @spec new(byte()) :: nil | __MODULE__.t()

  def new(oc)
      when oc == 0x18 or oc == 0x38 or oc == 0xD8 or oc == 0xF8 or oc == 0xC2 or oc == 0xEB do
    %__MODULE__{opcode: oc}
  end

  def new(oc)
      when oc == 0xE2 or oc == 0x78 or oc == 0x58 or oc == 0xB8 or oc == 0xEA or oc == 0xFB do
    %__MODULE__{opcode: oc}
  end

  def new(_opcode), do: nil

  defimpl Sneex.Ops.Opcode do
    @clc 0x18
    @sec 0x38
    @cld 0xD8
    @sed 0xF8
    @rep 0xC2
    @sep 0xE2
    @sei 0x78
    @cli 0x58
    @clv 0xB8
    @nop 0xEA
    @xba 0xEB
    @xce 0xFB

    def byte_size(%{opcode: oc}, _cpu)
        when oc == @clc or oc == @sec or oc == @cld or oc == @sed or oc == @sei,
        do: 1

    def byte_size(%{opcode: oc}, _cpu)
        when oc == @cli or oc == @clv or oc == @nop or oc == @xba or oc == @xce,
        do: 1

    def byte_size(%{opcode: oc}, _cpu) when oc == @rep or oc == @sep, do: 2

    def total_cycles(%{opcode: oc}, _cpu)
        when oc == @clc or oc == @sec or oc == @cld or oc == @sed or oc == @sei,
        do: 2

    def total_cycles(%{opcode: oc}, _cpu)
        when oc == @cli or oc == @clv or oc == @nop or oc == @xce,
        do: 2

    def total_cycles(%{opcode: oc}, _cpu) when oc == @rep or oc == @sep or oc == @xba, do: 3

    def execute(%{opcode: @clc}, cpu), do: cpu |> Cpu.carry_flag(false)
    def execute(%{opcode: @sec}, cpu), do: cpu |> Cpu.carry_flag(true)
    def execute(%{opcode: @cld}, cpu), do: cpu |> Cpu.decimal_mode(false)
    def execute(%{opcode: @sed}, cpu), do: cpu |> Cpu.decimal_mode(true)
    def execute(%{opcode: @sei}, cpu), do: cpu |> Cpu.irq_disable(true)
    def execute(%{opcode: @cli}, cpu), do: cpu |> Cpu.irq_disable(false)
    def execute(%{opcode: @clv}, cpu), do: cpu |> Cpu.overflow_flag(false)
    def execute(%{opcode: @nop}, cpu), do: cpu

    def execute(%{opcode: @xba}, cpu) do
      b = cpu |> Cpu.b()
      a = cpu |> Cpu.a() |> bsl(8)
      c = b + a
      cpu |> Cpu.acc(c) |> Cpu.negative_flag(c > 0x7FFF) |> Cpu.zero_flag(c == 0x0000)
    end

    def execute(%{opcode: @xce}, cpu) do
      carry_flag = Cpu.carry_flag(cpu)
      emu_mode = Cpu.emu_mode(cpu)
      cpu |> exchange_carry_and_emu(carry_flag, emu_mode)
    end

    def execute(%{opcode: @rep}, cpu) do
      operand = Cpu.read_operand(cpu, 1)
      emu_mode = Cpu.emu_mode(cpu)

      {cpu, _} = {cpu, operand} |> modify_flags(emu_mode, false)
      cpu
    end

    def execute(%{opcode: @sep}, cpu) do
      operand = Cpu.read_operand(cpu, 1)
      emu_mode = Cpu.emu_mode(cpu)

      {cpu, _} = {cpu, operand} |> modify_flags(emu_mode, true)
      cpu
    end

    defp modify_flags(cpu_mask, _emulation_mode = :emulation, value) do
      cpu_mask
      |> modify_neg_flag(value)
      |> modify_overflow_flag(value)
      |> modify_decimal_mode(value)
      |> modify_irq_disable(value)
      |> modify_zero_flag(value)
      |> modify_carry_flag(value)
    end

    defp modify_flags(cpu_mask, _emulation_mode, false) do
      cpu_mask
      |> modify_neg_flag(false)
      |> modify_overflow_flag(false)
      |> modify_acc_size(:bit16)
      |> modify_index_size(:bit16)
      |> modify_decimal_mode(false)
      |> modify_irq_disable(false)
      |> modify_zero_flag(false)
      |> modify_carry_flag(false)
    end

    defp modify_flags(cpu_mask, _emulation_mode, _value) do
      cpu_mask
      |> modify_neg_flag(true)
      |> modify_overflow_flag(true)
      |> modify_acc_size(:bit8)
      |> modify_index_size(:bit8)
      |> modify_decimal_mode(true)
      |> modify_irq_disable(true)
      |> modify_zero_flag(true)
      |> modify_carry_flag(true)
    end

    defp modify_neg_flag({cpu, mask}, value) when (mask &&& 0x80) == 0x80 do
      {Cpu.negative_flag(cpu, value), mask}
    end

    defp modify_neg_flag(cpu_mask, _), do: cpu_mask

    defp modify_overflow_flag({cpu, mask}, value) when (mask &&& 0x40) == 0x40 do
      {Cpu.overflow_flag(cpu, value), mask}
    end

    defp modify_overflow_flag(cpu_mask, _), do: cpu_mask

    defp modify_acc_size({cpu, mask}, value) when (mask &&& 0x20) == 0x20 do
      {Cpu.acc_size(cpu, value), mask}
    end

    defp modify_acc_size(cpu_mask, _), do: cpu_mask

    defp modify_index_size({cpu, mask}, value) when (mask &&& 0x10) == 0x10 do
      {Cpu.index_size(cpu, value), mask}
    end

    defp modify_index_size(cpu_mask, _), do: cpu_mask

    defp modify_decimal_mode({cpu, mask}, value) when (mask &&& 0x08) == 0x08 do
      {Cpu.decimal_mode(cpu, value), mask}
    end

    defp modify_decimal_mode(cpu_mask, _), do: cpu_mask

    defp modify_irq_disable({cpu, mask}, value) when (mask &&& 0x04) == 0x04 do
      {Cpu.irq_disable(cpu, value), mask}
    end

    defp modify_irq_disable(cpu_mask, _), do: cpu_mask

    defp modify_zero_flag({cpu, mask}, value) when (mask &&& 0x02) == 0x02 do
      {Cpu.zero_flag(cpu, value), mask}
    end

    defp modify_zero_flag(cpu_mask, _), do: cpu_mask

    defp modify_carry_flag({cpu, mask}, value) when (mask &&& 0x01) == 0x01 do
      {Cpu.carry_flag(cpu, value), mask}
    end

    defp modify_carry_flag(cpu_mask, _), do: cpu_mask

    # Not switching modes, so do nothing:
    defp exchange_carry_and_emu(cpu, _carry = true, _emu_mode = :emulation), do: cpu
    defp exchange_carry_and_emu(cpu, _carry = false, _emu_mode = :native), do: cpu

    defp exchange_carry_and_emu(cpu, _carry = true, _emu_mode) do
      cpu |> Cpu.carry_flag(false) |> Cpu.emu_mode(:emulation)
    end

    defp exchange_carry_and_emu(cpu, _carry = false, _emu_mode) do
      cpu
      |> Cpu.carry_flag(true)
      |> Cpu.emu_mode(:native)
      |> Cpu.acc_size(:bit8)
      |> Cpu.index_size(:bit8)
    end

    def disasm(%{opcode: @clc}, _cpu), do: "CLC"
    def disasm(%{opcode: @sec}, _cpu), do: "SEC"
    def disasm(%{opcode: @cld}, _cpu), do: "CLD"
    def disasm(%{opcode: @sed}, _cpu), do: "SED"
    def disasm(%{opcode: @sei}, _cpu), do: "SEI"
    def disasm(%{opcode: @cli}, _cpu), do: "CLI"
    def disasm(%{opcode: @clv}, _cpu), do: "CLV"
    def disasm(%{opcode: @nop}, _cpu), do: "NOP"
    def disasm(%{opcode: @xba}, _cpu), do: "XBA"
    def disasm(%{opcode: @xce}, _cpu), do: "XCE"

    def disasm(%{opcode: @rep}, cpu) do
      status_bits = cpu |> Cpu.read_operand(1) |> BasicTypes.format_byte()
      "REP ##{status_bits}"
    end

    def disasm(%{opcode: @sep}, cpu) do
      status_bits = cpu |> Cpu.read_operand(1) |> BasicTypes.format_byte()
      "SEP ##{status_bits}"
    end
  end
end
