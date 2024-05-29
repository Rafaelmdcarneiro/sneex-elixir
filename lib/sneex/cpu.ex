defmodule Sneex.Cpu do
  @moduledoc """
  This module defines a structure that represents the CPU's current state, and defines functions for
  interacting with that state (getting it, updating it, etc.).

  Design thoughts:
  - CPU should have 2 functions:
      - tick: this will act as a clock tick
      - step: this will immediately execute the current command (regardless of remaining ticks)
  - Have a module that will load the next command
  - Have a module/struct that represents current command

  23                    15                       7                         0
                        Accumulator (B)      (A) or (C)      Accumulator (A)
  Data Bank Register
                        X Index                  Register X
                        Y Index                  Register Y
    0 0 0 0 0 0 0 0     Direct                   Page Register (D)
    0 0 0 0 0 0 0 0     Stack                    Pointer (S)
  Program Bank Register Program                  Counter (PC)
  """
  defstruct [
    :acc,
    :acc_size,
    :x,
    :y,
    :index_size,
    :data_bank,
    :direct_page,
    :program_bank,
    :stack_ptr,
    :pc,
    :emu_mode,
    :neg_flag,
    :overflow_flag,
    :carry_flag,
    :zero_flag,
    :irq_disable,
    :decimal_mode,
    :memory
  ]

  use Bitwise

  @type t :: %__MODULE__{
          acc: word(),
          acc_size: bit_size(),
          x: word(),
          y: word(),
          index_size: bit_size(),
          data_bank: byte(),
          direct_page: word(),
          program_bank: byte(),
          stack_ptr: word(),
          pc: word(),
          emu_mode: emulation_mode(),
          neg_flag: boolean(),
          overflow_flag: boolean(),
          carry_flag: boolean(),
          zero_flag: boolean(),
          irq_disable: boolean(),
          decimal_mode: boolean(),
          memory: Sneex.Memory.t()
        }
  @typep word :: Sneex.BasicTypes.word()
  @typep long :: Sneex.BasicTypes.long()
  @type emulation_mode :: :native | :emulation
  @type bit_size :: :bit8 | :bit16

  @doc "This is a simple constructor that will initialize all of the defaults for the CPU."
  @spec new(Sneex.Memory.t()) :: __MODULE__.t()
  def new(memory) do
    %__MODULE__{
      acc: 0,
      acc_size: :bit8,
      x: 0,
      y: 0,
      index_size: :bit8,
      data_bank: 0,
      direct_page: 0,
      program_bank: 0,
      stack_ptr: 0,
      pc: 0,
      emu_mode: :emulation,
      neg_flag: false,
      overflow_flag: false,
      carry_flag: false,
      zero_flag: false,
      irq_disable: false,
      decimal_mode: false,
      memory: memory
    }
  end

  @doc "
  Gets the accumulator from the CPU.

  It will take into account the bit size of the accumulator and only return 8 or 16 bits.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xFF) |> Sneex.Cpu.acc()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xFFFF) |> Sneex.Cpu.acc()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:emulation) |> Sneex.Cpu.acc(0xFFFF) |> Sneex.Cpu.acc_size(:bit16) |> Sneex.Cpu.acc()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.acc(0xFFFF) |> Sneex.Cpu.acc_size(:bit16) |> Sneex.Cpu.acc()
  0xFFFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.acc(0xFFFFFF) |> Sneex.Cpu.acc_size(:bit16) |> Sneex.Cpu.acc()
  0xFFFF
  "
  @spec acc(__MODULE__.t()) :: word()
  def acc(%__MODULE__{acc: a, acc_size: :bit8}), do: a &&& 0xFF
  def acc(%__MODULE__{acc: a, emu_mode: :emulation}), do: a &&& 0xFF
  def acc(%__MODULE__{acc: a}), do: a &&& 0xFFFF

  @doc "Sets the accumulator value for the CPU."
  @spec acc(__MODULE__.t(), word()) :: __MODULE__.t()
  def acc(cpu = %__MODULE__{}, acc), do: %__MODULE__{cpu | acc: acc}

  @doc "
  Gets the lower 8 bits of the accumulator (referred to as A).

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xDEAD) |> Sneex.Cpu.a()
  0xAD

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xBEEF) |> Sneex.Cpu.a()
  0xEF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0x42) |> Sneex.Cpu.a()
  0x42
  "
  @spec a(__MODULE__.t()) :: byte()
  def a(%__MODULE__{acc: c}), do: c |> band(0x00FF)

  @doc "
  Gets the top 8 bits of the accumulator (referred to as B).

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xDEAD) |> Sneex.Cpu.b()
  0xDE

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xBEEF) |> Sneex.Cpu.b()
  0xBE

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0x42) |> Sneex.Cpu.b()
  0x00
  "
  @spec b(__MODULE__.t()) :: byte()
  def b(%__MODULE__{acc: c}), do: c |> band(0xFF00) |> bsr(8)

  @doc "
  Gets the full 16 bits of the accumulator (referred to as C), regardless of the current memory mode.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xDEAD) |> Sneex.Cpu.c()
  0xDEAD

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc(0xBEEF) |> Sneex.Cpu.c()
  0xBEEF
  "
  @spec c(__MODULE__.t()) :: byte()
  def c(%__MODULE__{acc: c}), do: c |> band(0xFFFF)

  @doc "Gets the size of the accumulator, either :bit8 or :bit16."
  @spec acc_size(__MODULE__.t()) :: bit_size()
  def acc_size(%__MODULE__{emu_mode: :emulation}), do: :bit8
  def acc_size(%__MODULE__{acc_size: acc_size}), do: acc_size

  @doc "Sets the size of the accumulator, either :bit8 or :bit16."
  @spec acc_size(__MODULE__.t(), bit_size()) :: __MODULE__.t()
  def acc_size(cpu = %__MODULE__{}, size), do: %__MODULE__{cpu | acc_size: size}

  @doc "
  Gets the x index from the CPU.

  It will take into account the bit size of the index registers and only return 8 or 16 bits.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.x(0xFF) |> Sneex.Cpu.x()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.x(0xFFFF) |> Sneex.Cpu.x()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.x(0xFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.emu_mode(:emulation) |> Sneex.Cpu.x()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.x(0xFFFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.x()
  0xFFFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.x(0xFFFFFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.x()
  0xFFFF
  "
  @spec x(__MODULE__.t()) :: word()
  def x(%__MODULE__{x: x, index_size: :bit8}), do: x &&& 0xFF
  def x(%__MODULE__{x: x, emu_mode: :emulation}), do: x &&& 0xFF
  def x(%__MODULE__{x: x}), do: x &&& 0xFFFF

  @doc "Sets the x index for the CPU."
  @spec x(__MODULE__.t(), word()) :: __MODULE__.t()
  def x(cpu = %__MODULE__{}, x), do: %__MODULE__{cpu | x: x}

  @doc "
  Gets the y index from the CPU.

  It will take into account the bit size of the index registers and only return 8 or 16 bits.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.y(0xFF) |> Sneex.Cpu.y()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.y(0xFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.emu_mode(:emulation) |> Sneex.Cpu.y()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.y(0xFFFF) |> Sneex.Cpu.y()
  0xFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.y(0xFFFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.y()
  0xFFFF

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.y(0xFFFFFF) |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.y()
  0xFFFF
  "
  @spec y(__MODULE__.t()) :: word()
  def y(%__MODULE__{y: y, index_size: :bit8}), do: y &&& 0xFF
  def y(%__MODULE__{y: y, emu_mode: :emulation}), do: y &&& 0xFF
  def y(%__MODULE__{y: y}), do: y &&& 0xFFFF

  @doc "Sets the y index for the CPU."
  @spec y(__MODULE__.t(), word()) :: __MODULE__.t()
  def y(cpu = %__MODULE__{}, y), do: %__MODULE__{cpu | y: y}

  @doc "Gets the size of the index registers, either :bit8 or :bit16"
  @spec index_size(__MODULE__.t()) :: bit_size()
  def index_size(%__MODULE__{emu_mode: :emulation}), do: :bit8
  def index_size(%__MODULE__{index_size: size}), do: size

  @doc "Sets the size of the index registers, either :bit8 or :bit16"
  @spec index_size(__MODULE__.t(), bit_size()) :: __MODULE__.t()
  def index_size(cpu = %__MODULE__{}, size), do: %__MODULE__{cpu | index_size: size}

  @doc "
  This allows reading the break (b) flag while the CPU is in emulation mode.
  It converts the index size (x) flag into the break flag while the CPU is in emulation mode.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.break_flag()
  true

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.index_size(:bit16) |> Sneex.Cpu.break_flag()
  false

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.break_flag(false) |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.index_size()
  :bit16
  "
  @spec break_flag(__MODULE__.t()) :: boolean
  def break_flag(%__MODULE__{emu_mode: :emulation, index_size: :bit8}), do: true
  def break_flag(%__MODULE__{emu_mode: :emulation, index_size: :bit16}), do: false

  @doc "This allows setting the break (b) flag while the CPU is in emulation mode."
  @spec break_flag(__MODULE__.t(), any) :: __MODULE__.t()
  def break_flag(cpu = %__MODULE__{emu_mode: :emulation}, true),
    do: %__MODULE__{cpu | index_size: :bit8}

  def break_flag(cpu = %__MODULE__{emu_mode: :emulation}, false),
    do: %__MODULE__{cpu | index_size: :bit16}

  @doc "
  Get the current value for the data bank register

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.data_bank(0xAA) |> Sneex.Cpu.data_bank()
  0xAA
  "
  @spec data_bank(__MODULE__.t()) :: byte()
  def data_bank(%__MODULE__{data_bank: dbr}), do: dbr &&& 0xFF

  @doc "Sets the current value for the data bank register"
  @spec data_bank(__MODULE__.t(), byte()) :: __MODULE__.t()
  def data_bank(cpu = %__MODULE__{}, dbr), do: %__MODULE__{cpu | data_bank: dbr}

  @doc "
  Get the current value for the direct page register

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.direct_page(0xBB) |> Sneex.Cpu.direct_page()
  0xBB
  "
  @spec direct_page(__MODULE__.t()) :: word()
  def direct_page(%__MODULE__{direct_page: dpr}), do: dpr &&& 0xFFFF

  @doc "Sets the value for the direct page register"
  @spec direct_page(__MODULE__.t(), word()) :: __MODULE__.t()
  def direct_page(cpu = %__MODULE__{}, dpr), do: %__MODULE__{cpu | direct_page: dpr}

  @doc "
  Get the current value for the program bank register

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.program_bank(0xBB) |> Sneex.Cpu.program_bank()
  0xBB
  "
  @spec program_bank(__MODULE__.t()) :: byte()
  def program_bank(%__MODULE__{program_bank: pbr}), do: pbr &&& 0xFF

  @doc "Set the value of the program bank register"
  @spec program_bank(__MODULE__.t(), byte()) :: __MODULE__.t()
  def program_bank(cpu = %__MODULE__{}, pbr), do: %__MODULE__{cpu | program_bank: pbr}

  @doc "
  Get the current value for the stack pointer

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.stack_ptr(0xABCD) |> Sneex.Cpu.stack_ptr()
  0xABCD
  "
  @spec stack_ptr(__MODULE__.t()) :: word()
  def stack_ptr(%__MODULE__{stack_ptr: sp}), do: sp &&& 0xFFFF

  @doc "Set the value of the stack pointer"
  @spec stack_ptr(__MODULE__.t(), word()) :: __MODULE__.t()
  def stack_ptr(cpu = %__MODULE__{}, sp), do: %__MODULE__{cpu | stack_ptr: sp}

  @doc "
  Get the current value for the program counter.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.pc(0x1234) |> Sneex.Cpu.pc()
  0x1234
  "
  @spec pc(__MODULE__.t()) :: word()
  def pc(%__MODULE__{pc: pc}), do: pc &&& 0xFFFF

  @doc "Set the value of the program counter"
  @spec pc(__MODULE__.t(), word()) :: __MODULE__.t()
  def pc(cpu = %__MODULE__{}, pc), do: %__MODULE__{cpu | pc: pc}

  @doc "
  Gets the effective program counter

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.pc(0x1234) |> Sneex.Cpu.program_bank(0xAB) |> Sneex.Cpu.effective_pc()
  0xAB1234
  "
  def effective_pc(%__MODULE__{program_bank: pbr, pc: pc}), do: pbr |> bsl(16) |> bor(pc)

  @doc "
  Get the current value for the emulation mode, either :native or :emulation.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:native) |> Sneex.Cpu.emu_mode()
  :native

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.emu_mode(:emulation) |> Sneex.Cpu.emu_mode()
  :emulation
  "
  @spec emu_mode(__MODULE__.t()) :: emulation_mode()
  def emu_mode(%__MODULE__{emu_mode: em}), do: em

  @doc "Set the current value for the emulation mode"
  @spec emu_mode(__MODULE__.t(), emulation_mode()) :: __MODULE__.t()
  def emu_mode(cpu = %__MODULE__{}, em), do: %__MODULE__{cpu | emu_mode: em}

  @doc "
  Get the current value for the negative flag.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.negative_flag(true) |> Sneex.Cpu.negative_flag()
  true
  "
  @spec negative_flag(__MODULE__.t()) :: boolean()
  def negative_flag(%__MODULE__{neg_flag: n}), do: n

  @doc "Set the value of the negative flag"
  @spec negative_flag(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def negative_flag(cpu = %__MODULE__{}, n), do: %__MODULE__{cpu | neg_flag: n}

  @doc "
  Get the current value for the overflow flag.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.overflow_flag(true) |> Sneex.Cpu.overflow_flag()
  true
  "
  @spec overflow_flag(__MODULE__.t()) :: boolean()
  def overflow_flag(%__MODULE__{overflow_flag: o}), do: o

  @doc "Set the value of the overflow flag"
  @spec overflow_flag(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def overflow_flag(cpu = %__MODULE__{}, o), do: %__MODULE__{cpu | overflow_flag: o}

  @doc "
  Get the current value for the decimal mode (true = decimal, false = binary).

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.decimal_mode(true) |> Sneex.Cpu.decimal_mode()
  true
  "
  @spec decimal_mode(__MODULE__.t()) :: boolean()
  def decimal_mode(%__MODULE__{decimal_mode: d}), do: d

  @doc "Set the decimal mode: true = decimal, false = binary"
  @spec decimal_mode(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def decimal_mode(cpu = %__MODULE__{}, d), do: %__MODULE__{cpu | decimal_mode: d}

  @doc "
  Get the current value for the interrupt disable.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.irq_disable(true) |> Sneex.Cpu.irq_disable()
  true
  "
  @spec irq_disable(__MODULE__.t()) :: boolean()
  def irq_disable(%__MODULE__{irq_disable: i}), do: i

  @doc "Set the value of the interrupt disable (IRQ disable)"
  @spec irq_disable(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def irq_disable(cpu = %__MODULE__{}, i), do: %__MODULE__{cpu | irq_disable: i}

  @doc "
  Get the current value for the zero flag.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.zero_flag(true) |> Sneex.Cpu.zero_flag()
  true
  "
  @spec zero_flag(__MODULE__.t()) :: boolean()
  def zero_flag(%__MODULE__{zero_flag: z}), do: z

  @doc "Set the value of the zero flag"
  @spec zero_flag(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def zero_flag(cpu = %__MODULE__{}, z), do: %__MODULE__{cpu | zero_flag: z}

  @doc "
  Get the current value for the carry flag.

  ## Examples

  iex> <<>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.carry_flag(true) |> Sneex.Cpu.carry_flag()
  true
  "
  @spec carry_flag(__MODULE__.t()) :: boolean()
  def carry_flag(%__MODULE__{carry_flag: c}), do: c

  @doc "Set the value of the carry flag"
  @spec carry_flag(__MODULE__.t(), boolean()) :: __MODULE__.t()
  def carry_flag(cpu = %__MODULE__{}, c), do: %__MODULE__{cpu | carry_flag: c}

  @doc "Get the Sneex.Memory that is held by the CPU."
  @spec memory(__MODULE__.t()) :: Sneex.Memory.t()
  def memory(%__MODULE__{memory: m}), do: m

  @doc "Read the next opcode (where the program counter currently points)."
  @spec read_opcode(__MODULE__.t()) :: byte()
  def read_opcode(cpu = %__MODULE__{memory: m}) do
    eff_pc = cpu |> effective_pc()
    Sneex.Memory.read_byte(m, eff_pc)
  end

  @doc "Read the 1, 2, or 3 byte operand that is 1 address past the program counter."
  @spec read_operand(__MODULE__.t(), 1 | 2 | 3) :: byte() | word() | long()
  def read_operand(cpu = %__MODULE__{memory: m}, 1) do
    eff_pc = cpu |> effective_pc()
    Sneex.Memory.read_byte(m, eff_pc + 1)
  end

  def read_operand(cpu = %__MODULE__{memory: m}, 2) do
    eff_pc = cpu |> effective_pc()
    Sneex.Memory.read_word(m, eff_pc + 1)
  end

  def read_operand(cpu = %__MODULE__{memory: m}, 3) do
    eff_pc = cpu |> effective_pc()
    Sneex.Memory.read_long(m, eff_pc + 1)
  end

  @doc "
  Reads data from the memory. The address is the memory location where the read starts.
  The amount of data read (1 or 2 bytes) is based off of the accumulator size.

  ## Examples

  iex> <<1, 2>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc_size(:bit8) |> Sneex.Cpu.read_data(0x000000)
  0x01

  iex> <<1, 2>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc_size(:bit8) |> Sneex.Cpu.read_data(0x000001)
  0x02

  iex> <<1, 2>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc_size(:bit8) |> Sneex.Cpu.read_data(0x000000, 2)
  0x0201

  iex> <<1, 2>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc_size(:bit16) |> Sneex.Cpu.read_data(0x000000)
  0x0201

  iex> <<1, 2>> |> Sneex.Memory.new() |> Sneex.Cpu.new() |> Sneex.Cpu.acc_size(:bit16) |> Sneex.Cpu.read_data(0x000000, 1)
  0x01
  "
  @spec read_data(__MODULE__.t(), long()) :: byte() | word()
  def read_data(%__MODULE__{memory: m, acc_size: :bit8}, address) do
    Sneex.Memory.read_byte(m, address)
  end

  def read_data(%__MODULE__{memory: m, acc_size: :bit16}, address) do
    Sneex.Memory.read_word(m, address)
  end

  @spec read_data(__MODULE__.t(), long(), 1 | 2 | 3) :: byte() | word()
  def read_data(%__MODULE__{memory: m}, address, 1) do
    Sneex.Memory.read_byte(m, address)
  end

  def read_data(%__MODULE__{memory: m}, address, 2) do
    Sneex.Memory.read_word(m, address)
  end

  def read_data(%__MODULE__{memory: m}, address, 3) do
    Sneex.Memory.read_long(m, address)
  end

  @doc "
  Writes data to the memory. The address is the memory location where the write starts.
  The amount of data written (1 or 2 bytes) is based off of the accumulator size.
  "
  @spec write_data(__MODULE__.t(), long(), byte() | word()) :: __MODULE__.t()
  def write_data(cpu = %__MODULE__{memory: m, acc_size: :bit8}, address, value) do
    new_memory = Sneex.Memory.write_byte(m, address, value)
    %__MODULE__{cpu | memory: new_memory}
  end

  def write_data(cpu = %__MODULE__{memory: m, acc_size: :bit16}, address, value) do
    new_memory = Sneex.Memory.write_word(m, address, value)
    %__MODULE__{cpu | memory: new_memory}
  end
end
