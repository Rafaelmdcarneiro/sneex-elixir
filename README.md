# SNEEX
SNEEX: Super Nintendo Emulator in Elixir

# Notes
* Add a Bootloader
    * Read in the whole ROM file and wrap it in the ROM class (TODO: Figure out how to handle the SRAM)
    * Initialize the CPU: it should start in emulation mode and have it's interrupt vectors set from the ROM
    * Reset the CPU (i.e., have it run the emulation-mode reset vector) to start processing

# Useful links
## Memory Maps
https://en.wikibooks.org/wiki/Super_NES_Programming/SNES_memory_map

## CPU/Instructions
http://softpixel.com/~cwright/sianse/docs/65816NFO.HTM
https://wiki.superfamicom.org/uploads/assembly-programming-manual-for-w65c816.pdf
https://wiki.superfamicom.org/65816-reference

## Misc
https://familab.org/2012/12/snes-super-nintendo-emulated-system/5/
