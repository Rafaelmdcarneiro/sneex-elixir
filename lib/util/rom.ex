defmodule Util.Rom do
  @moduledoc """
  This module represents a SNES ROM. You can create a new instance by calling parse with a path
  to a ROM. It will load the data from the file and parse it into a digestible format.

  The module also provides helper methods for addressing into the ROM's data along with some
  helper functions for quickly accessing some metadata about the ROM.
  """

  defstruct [:banks, :header]

  @opaque t :: %Util.Rom{banks: %{integer() => Util.Bank.t()}, header: Util.Header.t() | nil}

  @spec new(%{integer() => Util.Bank.t()}) :: Util.Rom.t()
  def new(banks = %{0x00 => first_bank}) do
    %Util.Rom{banks: banks, header: Util.Bank.extract_header(first_bank)}
  end

  @spec parse(Path.t()) :: Util.Rom.t()
  def parse(path) do
    banks = File.open!(path, [:read, :binary], &load_bank(&1, %{}, 0))
    new(banks)
  end

  defp load_bank(file_pid, banks, bank_id) do
    case read_bank(file_pid) do
      {:ok, new_bank} ->
        banks = Map.put(banks, bank_id, new_bank)
        load_bank(file_pid, banks, bank_id + 1)

      _ ->
        banks
    end
  end

  defp read_bank(file_pid) do
    case IO.binread(file_pid, Util.Bank.bank_size()) do
      :eof ->
        :eof

      block ->
        {:ok, Util.Bank.new(block)}
    end
  end
end
