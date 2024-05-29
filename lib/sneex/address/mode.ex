defprotocol Sneex.Address.Mode do
  @spec address(any(), Sneex.Cpu.t()) :: Sneex.BasicTypes.long()
  def address(mode, cpu)

  @spec byte_size(any(), Sneex.Cpu.t()) :: 0 | 1 | 2 | 3
  def byte_size(mode, cpu)

  @spec fetch(any(), Sneex.Cpu.t()) :: byte() | Sneex.BasicTypes.word() | Sneex.BasicTypes.long()
  def fetch(mode, cpu)

  @spec store(any(), Sneex.Cpu.t(), byte() | Sneex.BasicTypes.word() | Sneex.BasicTypes.long()) ::
          Sneex.Cpu.t()
  def store(mode, cpu, data)

  @spec disasm(any(), Sneex.Cpu.t()) :: String.t()
  def disasm(mode, cpu)
end
