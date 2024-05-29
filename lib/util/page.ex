defmodule Util.Page do
  @moduledoc """
  This module defines a structure for dealing with a page of data within the ROM.

  It provides methods for extracting a page of memory out of a ROM and accessing data within that page.
  """

  defstruct [:data]

  @opaque t :: %Util.Page{data: binary()}

  @page_size 0x1000

  @spec new(binary()) :: {Util.Page.t(), binary()} | Util.Page.t()

  def new(data) when is_binary(data) and byte_size(data) == @page_size do
    %Util.Page{data: data}
  end

  def new(data = <<page::binary-size(@page_size), rest::binary>>)
      when is_binary(data) and byte_size(data) >= @page_size do
    {%Util.Page{data: page}, rest}
  end

  @spec get_byte(Util.Page.t(), char()) :: byte()

  def get_byte(%Util.Page{data: <<byte::size(8), _rest::binary>>}, 0), do: byte

  def get_byte(%Util.Page{data: data}, address)
      when is_integer(address) and address > 0 and address < @page_size do
    <<_before::binary-size(address), byte::size(8), _rest::binary>> = data
    byte
  end

  @spec get_block(Util.Page.t(), char()) :: binary()

  def get_block(%Util.Page{data: data}, 0), do: data

  def get_block(%Util.Page{data: data}, address)
      when is_integer(address) and address > 0 and address < @page_size do
    <<_before::binary-size(address), block::binary>> = data
    block
  end

  @spec get_block(Util.Page.t(), non_neg_integer(), non_neg_integer()) :: any()

  def get_block(%Util.Page{data: data}, 0, @page_size), do: data

  def get_block(%Util.Page{data: data}, 0, size) when is_integer(size) and size < @page_size do
    <<block::binary-size(size), _rest::binary>> = data
    block
  end

  def get_block(%Util.Page{data: data}, address, size)
      when is_integer(address) and is_integer(size) and address >= 0 and size > 0 and
             address + size <= @page_size do
    <<_before::binary-size(address), block::binary-size(size), _rest::binary>> = data
    block
  end

  @spec page_size :: 4096
  def page_size do
    @page_size
  end
end
