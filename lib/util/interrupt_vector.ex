defmodule Util.InterruptVector do
  @moduledoc """
  This is a structure that holds the addresses for various interrupts.

  The interrupts are:
  * _Coprocessor_: Co-processor enable. Shouldn't be used for the SNES.
  * _Break_: {purpose TBD}
  * _Abort_: {purpose TBD}
  * _NMI (Non-maskable interrupt)_: Called when vertical refresh (vblank) begins.
  * _Reset_: Execution begins via this vector.
  * _IRQ_: Interrupt request. Can be called at a certain point in the horizontal refresh cycle.

  There are also spots for 2-3 more addresses. It's unknown what those interrupts are used for.

  More information can be found here:
  * https://en.wikibooks.org/wiki/Super_NES_Programming/SNES_memory_map#Interrupt_vectors
  """
  defstruct [:coprocessor, :break, :abort, :non_maskable, :reset, :irq]

  @type t :: %Util.InterruptVector{
          coprocessor: non_neg_integer(),
          break: non_neg_integer(),
          non_maskable: non_neg_integer(),
          abort: non_neg_integer(),
          reset: non_neg_integer(),
          irq: non_neg_integer()
        }
end
