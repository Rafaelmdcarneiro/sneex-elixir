defmodule Util.Header do
  @moduledoc """
  This module defines a structure for interpretting some of the ROM's metadata
  """

  use Bitwise

  @base_size 0x400

  defstruct [
    :title,
    :rom_makeup,
    :rom_type,
    :rom_size,
    :sram_size,
    :license_id,
    :version_number,
    :checksum,
    :checksum_complement,
    :native_mode_interrupts,
    :emulation_mode_interrupts
  ]

  @type rom_makeup :: :lorom | :hirom | :sa1rom | :lofastrom | :hifastrom | :exlorom | :exhirom
  @type rom_type :: :rom | :ram | :sram | :dsp1 | :fx

  @type t :: %Util.Header{
          title: String.t(),
          rom_makeup: rom_makeup(),
          rom_type: rom_type(),
          rom_size: non_neg_integer(),
          sram_size: non_neg_integer(),
          license_id: integer(),
          version_number: integer(),
          checksum: integer(),
          checksum_complement: integer(),
          native_mode_interrupts: Util.InterruptVector.t(),
          emulation_mode_interrupts: Util.InterruptVector.t()
        }

  @spec new(binary()) :: Util.Header.t() | :invalid
  def new(<<
        raw_title::binary-size(21),
        raw_rom_makeup::size(8),
        raw_rom_type::size(8),
        raw_rom_size::size(8),
        raw_sram_size::size(8),
        license_id::size(8),
        version::size(8),
        checksum_complement::size(16),
        checksum::size(16),
        _unknown::size(8),
        native_vectors::binary-size(16),
        emulation_vectors::binary-size(16)
      >>) do
    with {:ok, title} <- determine_title(raw_title),
         {:ok, rom_makeup} <- determine_rom_makeup(raw_rom_makeup),
         {:ok, rom_type} <- determine_rom_type(raw_rom_type),
         rom_size <- determine_size(raw_rom_size),
         sram_size <- determine_size(raw_sram_size) do
      %Util.Header{
        title: title,
        rom_makeup: rom_makeup,
        rom_type: rom_type,
        rom_size: rom_size,
        sram_size: sram_size,
        license_id: license_id,
        version_number: version,
        checksum: checksum,
        checksum_complement: checksum_complement,
        native_mode_interrupts: parse_native_interrupts(native_vectors),
        emulation_mode_interrupts: parse_emulation_interrupts(emulation_vectors)
      }
    else
      _ -> :invalid
    end
  end

  defp determine_title(raw_title) do
    case String.valid?(raw_title) do
      true ->
        title = raw_title |> String.codepoints() |> List.to_string() |> String.trim()
        {:ok, title}

      _ ->
        :invalid
    end
  end

  defp determine_rom_makeup(0x20), do: {:ok, :lorom}
  defp determine_rom_makeup(0x21), do: {:ok, :hirom}
  defp determine_rom_makeup(0x23), do: {:ok, :sa1rom}
  defp determine_rom_makeup(0x30), do: {:ok, :lofastrom}
  defp determine_rom_makeup(0x31), do: {:ok, :hifastrom}
  defp determine_rom_makeup(0x32), do: {:ok, :exlorom}
  defp determine_rom_makeup(0x35), do: {:ok, :exhirom}
  defp determine_rom_makeup(_), do: :invalid

  # eventually figure this out...
  defp determine_rom_type(_), do: {:ok, :rom}

  defp determine_size(raw_size) do
    @base_size <<< raw_size
  end

  defp parse_native_interrupts(<<
         _unknown1::binary-size(2),
         _unknown2::binary-size(2),
         cop_bytes::binary-size(2),
         break_bytes::binary-size(2),
         abort_bytes::binary-size(2),
         nmi_bytes::binary-size(2),
         reset_bytes::binary-size(2),
         irq_bytes::binary-size(2)
       >>) do
    %Util.InterruptVector{
      coprocessor: correct_interrupt_address(cop_bytes),
      break: correct_interrupt_address(break_bytes),
      abort: correct_interrupt_address(abort_bytes),
      non_maskable: correct_interrupt_address(nmi_bytes),
      reset: correct_interrupt_address(reset_bytes),
      irq: correct_interrupt_address(irq_bytes)
    }
  end

  defp parse_emulation_interrupts(<<
         _unknown1::binary-size(2),
         _unknown2::binary-size(2),
         cop_bytes::binary-size(2),
         _unknown3::binary-size(2),
         abort_bytes::binary-size(2),
         nmi_bytes::binary-size(2),
         reset_bytes::binary-size(2),
         break_and_irq_bytes::binary-size(2)
       >>) do
    break_and_irq_address = correct_interrupt_address(break_and_irq_bytes)

    %Util.InterruptVector{
      coprocessor: correct_interrupt_address(cop_bytes),
      abort: correct_interrupt_address(abort_bytes),
      non_maskable: correct_interrupt_address(nmi_bytes),
      reset: correct_interrupt_address(reset_bytes),
      break: break_and_irq_address,
      irq: break_and_irq_address
    }
  end

  defp correct_interrupt_address(<<lower::size(8), upper::size(8)>>) do
    upper <<< 8 ||| lower
  end
end
