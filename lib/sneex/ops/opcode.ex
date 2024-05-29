defprotocol Sneex.Ops.Opcode do
  @spec byte_size(any(), Sneex.Cpu.t()) :: 1 | 2 | 3 | 4
  def byte_size(opcode, cpu)

  @spec total_cycles(any(), Sneex.Cpu.t()) :: pos_integer()
  def total_cycles(opcode, cpu)

  @spec execute(any(), Sneex.Cpu.t()) :: Sneex.Cpu.t()
  def execute(opcode, cpu)

  @spec disasm(any(), Sneex.Cpu.t()) :: String.t()
  def disasm(opcode, cpu)
end
