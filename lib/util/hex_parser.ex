defmodule Util.HexParser do
  @moduledoc """
  This module defines some helper functions for playing around with raw memory from a ROM.
  """

  use Bitwise

  @block_size 16

  def convert_file(input_file, output_file) do
    output_file
    |> File.open!([:write], handle_file(input_file))
  end

  def calculate_checksum(input_file) do
    checksum =
      input_file
      |> File.open!([:read, :binary], &read_and_sum(&1, 0))

    inverse_checksum = bxor(checksum, 0xFFFF)
    {format_byte(checksum, 4), format_byte(inverse_checksum, 4)}
  end

  defp read_and_sum(file_pid, curr_total) do
    case IO.binread(file_pid, 1) do
      :eof ->
        curr_total &&& 0xFFFF

      <<byte::size(8)>> ->
        read_and_sum(file_pid, curr_total + byte)
    end
  end

  defp handle_file(input_file) do
    fn output_pid ->
      input_file
      |> File.open!([:read, :binary], &read_file(&1, output_pid, 0))
    end
  end

  defp read_file(input_pid, output_pid, block_number) do
    case IO.binread(input_pid, @block_size) do
      :eof ->
        :ok

      block ->
        formatted_block = (block_number * @block_size) |> format_result(block)
        IO.write(output_pid, formatted_block)
        read_file(input_pid, output_pid, block_number + 1)
    end
  end

  defp format_result(index, block) do
    [[format_index(index), ": "], format_block(block), ["\r\n"]]
  end

  defp format_block(<<
         b0::size(8),
         b1::size(8),
         b2::size(8),
         b3::size(8),
         b4::size(8),
         b5::size(8),
         b6::size(8),
         b7::size(8),
         b8::size(8),
         b9::size(8),
         bA::size(8),
         bB::size(8),
         bC::size(8),
         bD::size(8),
         bE::size(8),
         bF::size(8)
       >>) do
    fhex = &format_byte(&1, 2)
    fbin = &format_printable_byte(&1)

    hex = [
      fhex.(b0),
      " ",
      fhex.(b1),
      " ",
      fhex.(b2),
      " ",
      fhex.(b3),
      " ",
      fhex.(b4),
      " ",
      fhex.(b5),
      " ",
      fhex.(b6),
      " ",
      fhex.(b7),
      " ",
      fhex.(b8),
      " ",
      fhex.(b9),
      " ",
      fhex.(bA),
      " ",
      fhex.(bB),
      " ",
      fhex.(bC),
      " ",
      fhex.(bD),
      " ",
      fhex.(bE),
      " ",
      fhex.(bF)
    ]

    ascii = [
      "|",
      fbin.(b0),
      fbin.(b1),
      fbin.(b2),
      fbin.(b3),
      fbin.(b4),
      fbin.(b5),
      fbin.(b6),
      fbin.(b7),
      fbin.(b8),
      fbin.(b9),
      fbin.(bA),
      fbin.(bB),
      fbin.(bC),
      fbin.(bD),
      fbin.(bE),
      fbin.(bF),
      "|"
    ]

    [hex, ["  "], ascii]
  end

  defp format_byte(byte, length) do
    byte
    |> Integer.to_string(16)
    |> String.pad_leading(length, "0")
  end

  defp format_printable_byte(byte) when byte >= 32 and byte <= 127 do
    case String.valid?(to_string([byte])) do
      true -> [byte]
      _ -> "."
    end
  end

  defp format_printable_byte(_byte) do
    "."
  end

  defp format_index(index) do
    <<bank::binary-size(2), remainder::binary>> =
      index
      |> Integer.to_string(16)
      |> String.pad_leading(6, "0")

    bank <> " " <> remainder
  end
end
