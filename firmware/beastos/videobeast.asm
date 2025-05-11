;
; VideoBeast includes for CP/M BIOS
;
;
; Copyright (c) 2023 Andy Toone for Feersum Technology Ltd.
;
; Part of the MicroBeast Z80 kit computer project. Support hobby electronics.
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;

VBASE               .EQU   04000h

VB_MODE             .EQU   VBASE + 03FFFh
VB_REGISTERS_LOCKED .EQU   VBASE + 03FFEh

VB_PAGE_0           .EQU   VBASE + 03FF9h
VB_PAGE_1           .EQU   VBASE + 03FF8h
VB_PAGE_2           .EQU   VBASE + 03FF7h
VB_PAGE_3           .EQU   VBASE + 03FF6h

VB_LOWER_REGS       .EQU   VBASE + 03FF5h


VB_LAYER_0          .EQU   VBASE + 03F80h
VB_LAYER_1          .EQU   VBASE + 03F90h
VB_LAYER_2          .EQU   VBASE + 03FA0h
VB_LAYER_3          .EQU   VBASE + 03FB0h
VB_LAYER_4          .EQU   VBASE + 03FC0h
VB_LAYER_5          .EQU   VBASE + 03FD0h

MODE_640            .EQU   0
MODE_848            .EQU   1
MODE_DOUBLE         .EQU   8
MODE_TESTCARD       .EQU   010h

MODE_MAP_16K        .EQU   0
MODE_MAP_SINCLAIR   .EQU   080h

LAYER_TYPE          .EQU   0
LAYER_TOP           .EQU   1
LAYER_BOTTOM        .EQU   2
LAYER_LEFT          .EQU   3
LAYER_RIGHT         .EQU   4
LAYER_SCROLL_X      .EQU   5
LAYER_SCROLL_XY     .EQU   6
LAYER_SCROLL_Y      .EQU   7

TYPE_NONE           .EQU   0
TYPE_TEXT           .EQU   1
TYPE_SPRITE         .EQU   2
TYPE_TILE           .EQU   3
TYPE_BITMAP_8       .EQU   4

TEXT_MAP_BASE       .EQU   8       ; 16Kb character map
TEXT_FONT_BASE      .EQU   9       ;  2Kb font offset
TEXT_PALETTE        .EQU   10      ; Bits 0-3: Palette number   Bit 4: Use Sinclair bit pattern
TEXT_BITMAP         .EQU   11      ; 16Kb 1bpp bitmap..

VB_UNLOCK           .EQU   0F3h           ; Unlock register write

VIDEOBEAST_PAGE     .EQU   40h 