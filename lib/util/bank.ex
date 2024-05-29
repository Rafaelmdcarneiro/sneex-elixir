defmodule Util.Bank do
  @moduledoc """
  This module defines a structure for dealing with a bank of data within the ROM.

  It provides methods for extracting a bank of memory out of a ROM and accessing data within that bank.
  """

  defstruct [:pages]

  @opaque t :: %Util.Bank{pages: %{integer() => Util.Page.t()}}

  @bank_size 0x10000
  @header_address 0xFC0

  @spec new(binary()) :: {Util.Bank.t(), binary()} | Util.Bank.t()

  def new(data) when is_binary(data) and byte_size(data) == @bank_size do
    %Util.Bank{pages: extract_pages(%{}, 0, data)}
  end

  def new(data = <<bank::binary-size(@bank_size), rest::binary>>)
      when is_binary(data) and byte_size(data) >= @bank_size do
    {new(bank), rest}
  end

  defp extract_pages(pages, page_index, data) do
    case Util.Page.new(data) do
      {page, more_data} ->
        pages = Map.put(pages, page_index, page)
        extract_pages(pages, page_index + 1, more_data)

      last_page ->
        Map.put(pages, page_index, last_page)
    end
  end

  @spec bank_size :: non_neg_integer()
  def bank_size do
    @bank_size
  end

  @spec extract_header(Util.Bank.t()) :: Util.Header.t() | nil

  def extract_header(%Util.Bank{pages: %{0x7 => page7, 0xF => pageF}}) do
    [page7, pageF]
    |> Enum.map(&try_extract_header/1)
    |> Enum.find(&(&1 != nil))
  end

  defp try_extract_header(page) do
    case Util.Page.get_block(page, @header_address) |> Util.Header.new() do
      :invalid ->
        nil

      header ->
        header
    end
  end
end
