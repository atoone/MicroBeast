# ManicMiner Port for MicroBeast + VideoBeast

Based on the Skoolkit disassembly (here: https://gitlab.com/z80-source-code-software/other-systems/manic-miner-disassembly---zx-spectrum/-/blob/master/mm.asm)

Build with Pasmo:

`pasmo mm.asm mm1_m4000.bin`

## Running

Start MicroBeast BIOS, then use YModem file transfer to load to address `4000h` (Use `Address from file` option to 
load `mm1_m4000.bin` to the right location automatically). Or in BeastEm emulator, load the file directly to address
`4000h` once the BIOS is running.

When the file is loaded, execute from address 5400h.

## Explanation

The original disassembly has been lightly altered to account for the different keyboard ports and higher processor speed 
of MicroBeast, and to provide a font (the original Spectrum version uses the Sinclair BASIC ROM font). The changes are 
made with equates, which allow the alterations to be switched off to generate code that would run normally on a 
Spectrum.

In addition, setup routines are needed to configure MicroBeast and VideoBeast to have a similar memory map
to a 48K Spectrum. Luckily, the original code for ManicMiner has a gap around address `9400h` which is large enough to 
include both the font and setup routines.

Normally Manic Miner loads from address 32768 to 65535 (the top 32K of memory). To make it easier to load on MicroBeast, 
which executes its BIOS from the upper ~8K of RAM (where Manic Miner would normally store map data), the setup routines 
assume the 32kB file is loaded to a lower location (from address `4000h`), and then re-adjust the page layout to
run the game from the normal address.
