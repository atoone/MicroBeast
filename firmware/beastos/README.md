# MicroBeast Simple Operating System

This project provides a boot Monitor utility and Basic CP/M 2.2 implementation for MicroBeast.

## Overview

Key files:

* cpm22.asm   - Standard CP/M 2.2 CCP and BDOS source code (single combined executable)
* bios.asm    - MicroBeast specific BIOS routines
* monitor.asm - Boot Monitor (combines Monitor and BIOS)

In a standard CP/M installation, the machine-specific BIOS is installed at the top of system memory to provide access to display, I/O and other hardware. The BIOS then
loads the CCP (Command control processor) and BDOS (Basic Disc Operating System) just below itself from a suitable source (e.g. boot sectors of a floppy drive).

MicroBeast provides a boot Monitor that, combined with the CP/M compatible BIOS, is installed by the ROM-resident firmware on startup. The monitor resides just below the 
BIOS, and accesses its functions directly for display, I/O and keyboard. The user can easily select between booting to the monitor, or starting CP/M normally - at which
point the BIOS will overwrite the Monitor with the CP/M CCP and BDOS.

The BIOS has the standard CP/M 2.2 entry jump table, but may provide additional routines that can be called directly by the monitor.

```

                      Monitor                                  CP/M

     0xFFFF  +--------------------------+              +--------------------------+
             | BIOS Stack               |              | BIOS Stack               |
             |                          |              |                          |
     0xFF00  | BIOS Work area           |              | BIOS Work area           |
             +--------------------------+              +--------------------------+
             |                          |              |                          |
     0xFE00  | Interrupt 2 Vector table |              | Interrupt 2 Vector table |
             +--------------------------+              +--------------------------+
     0xFDFD  | Interrupt Jump           |              | Interrupt Jump           |
             |                          |              |                          |
             |                          |              |                          |
     0xEE00  | BIOS                     |     0xEE00   | BIOS                     |  
             +--------------------------+              +--------------------------+
             |                          |              |                          |
             |                          |              |                          |
             |                          |     0xE000   | BDOS                     |
     0xDF00  | Monitor                  |              +--------------------------+
             +--------------------------+              |                          |
             |                          |              |                          |
             |                          |     0xD800   | CCP                      |
             |                          |              +--------------------------+
             |                          |              |                          |
             |                          |              |                          |
             .                          .              .                          .
             .                          .              .                          .
             |                          |              |                          |
             |                          |              |                          |
             |                          |     0x0100   | Transient Program Area   |
             |                          |              +--------------------------+
             |                          |              | Low Storage              | 
     0x0000  +--------------------------+     0x0000   +--------------------------+

```

As standard with CP/M 2.2, the BIOS is expected to be `0x1600` (5632 decimal) bytes above the base of the CCP. At present, the BIOS takes up `0x1200` (4608 decimal) bytes. The interrupt jump and vector table with the BIOS work area above them take up just over 512 bytes, leaving 4093 bytes available for BIOS routines. These handle Flash I/O, the 14 segment display, I2C and RTC communications.

## Console handling

The console is a virtual VT-52 terminal, with 40 x 24 characters by default (columns x rows). This is stored in a page in memory that itself represents 
a virtual screen text display 128 x 64, with two bytes being stored for each character (ASCII code and colour attribute). The virtual screen occupies exactly
one page of memory (16K), as each of the 64 rows occupies 256 bytes. It is treated as wrapping at row 64. Whilst this appears inefficient, it means that
addressing is simple (row is high byte of address, column x 2 is low byte), and scrolling of the virtual console can be achieved by adjusting the offset of
the virtual console within the screen buffer.

The console is controlled by the IOByte, allowing input and output to be selected using the standard CP/M `STAT` command. Note that the `TTY` and `CRT` options
for the console device only control the input source - any output will be directed to *both* the built in display *and* the UART serial device. To send output
to a single destination, use the `BAT` option, which specifies that the input is determined by the `RDR` Reader device, and ouput by the `LST` list device.


  +-----+-----+-----+-----+-----+-----+-----+-----+
  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
  +-----+-----+-----+-----+-----+-----+-----+-----+
  |    LST    |    PUN    |    RDR    |    CON    |
  +-----+-----+-----+-----+-----+-----+-----+-----+
  

  
    Con:
        00 TTY - Input on TTY, output to display + tty
        01 CRT - Input on Keyboard, output to display + tty
        10 BAT - Use Reader for console input, and the current List (printer) device as the console output.
        11 UC1 - Reserved for Phase 2
    Rdr:
        00 TTY - Input on TTY
        01 PTR - Input on keyboard
        10 UR1 - Unused
        11 UR2 - Unused
    PUN: 
        00 TTY - Output to TTY
        01 PTP - Unused
        10 UP1 - Unused
        11 UP2 - Unused
    LST: 
        00 TTY - Output to TTY
        01 CRT - Output to display
        10 LPT - Unused
        11 UL1 - Reserved for Phase 2

To view the current IOByte configuration use `STAT DEV:` which will display something like:

```
CON: is CRT:
RDR: is TTY:
PUN: is TTY:
LST: is TTY:
```

The `STAT` command can also be used to change the IOByte configuration. For instance, to switch input to be from Serial (TTY) and output to be display + serial, us `STAT CON:=TTY:`.

## Escape Codes

The console supports the following escape character sequences:

| Characters   | Description                                         |
|--------------|-----------------------------------------------------|
|  `ESC` `K`   | Clear to end of line                                |


## Disk Handling

### Rom Disk

Disks are 248K in size, 79 tracks of 26 sectors, with the first 2 tracks containing the CP/M operating system

The ROM disk takes up 16 pages, from page 4

The RAM disk takes up 16 pages, from page 0x24 (36 decimal)

When MicroBeast starts up, the Monitor formats a blank RAM disk

## Building

cd beastos
tasm -t80 monitor.asm
python ..\hex2inc.py monitor.obj
cd ..
tasm -t80 -b firmware.asm


## Running

beast -f 0 \projects\fortan\mpf\software\firmware.obj -l 0 \projects\fortan\mpf\software\firmware.lst -l 23 \projects\fortan\mpf\software\beastos\monitor.lst -f 10000 \projects\fortan\cpm\systemDisk\microbeast.img
beast -f 0 \projects\fortan\mpf\software\firmware.obj -l 0 \projects\fortan\mpf\software\firmware.lst -l 23 \projects\fortan\mpf\software\beastos\monitor.lst -f 10000 \projects\fortan\cpm\systemDisk\microbeast.img


## CP/M Disk Image

Using CPM Tools, Create a blank disk with the CP/M CCP in the first sectors:

`mkfs.cpm.exe -f memotech-type50 -b cpm22.bin microbeast.img`

Add files to the image:

`cpmcp.exe -f memotech-type50 microbeast.img mbasic.com 0:mbasic.com`

List files on the image

`cpmls.exe -f memotech-type50 microbeast.img`