;
; Shared data - common state data for routines
;
; [] show default/initial values stored at the location
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

                    .ORG    0FF00h

; I2C/Port B routines
port_b_mode         .BLOCK  1
port_b_dir          .BLOCK  1
port_b_data         .BLOCK  1

; Display functions
display_address     .BLOCK  1              ; byte - I/O address of the display driver (right or left) being written to

;
; Stuff
timer               .BLOCK  4              ; 2 Words - counts up by 1 every 64th of a second. Rollover ~2 years.
                        
; General I/O
;
; This MUST start with keyboard_state, and will all be reset to zero when io_init is called
;
_key_state_size     .EQU    8               ; 8 key rollover

keyboard_state      .BLOCK  _key_state_size ; state buffer - 8 bytes containing raw key codes for keys currently pressed
keyboard_pos        .BLOCK  2               ; Internal state
key_shift_state     .BLOCK  1               ; Holds state of shift and control keys in bits 0 and 1 respectively
control_key_pressed .BLOCK  1               ; If special control keys are pressed, they are stored here..

_input_buffer_size  .EQU    16
input_buffer        .BLOCK _input_buffer_size          ; 16 byte input buffer. Note wraparound is handled by bitmasks, so don't change this length
input_pos           .BLOCK  1               ; Next read position in input buffer
input_free          .BLOCK  1               ; Next write position in input buffer
input_size          .BLOCK  1               ; Bytes occupied in the input buffer

io_data_end         .EQU  input_size        ; Byte after IO data block, used to reset values to zero

;------------------------------- Console output and screen data ------------------------------------------------
screen_page         .BLOCK  1               ; [30?]  1 Byte, screen buffer page address
screen_offset       .BLOCK  1               ; [0]    1 Byte, row offset (0-63) of virtual screen in screen buffer (high byte of screen address).

; *** ROW AND COL MUST BE IN THIS ORDER - READ BY bios_conout ***
display_row         .BLOCK  1               ; [0]    1 Byte, current row being shown by the LED display
display_col         .BLOCK  1               ; [0]    1 Byte, current column being shown by the LED display - Note, 0 based

; *** ROW AND COL MUST BE IN THIS ORDER - READ BY bios_conout ***
cursor_row          .BLOCK  1               ; [1]    1 Byte, cursor row on virtual console. Top of page is row 1.   
cursor_col          .BLOCK  1               ; [1]    1 Byte, cursor column on virtual console. Left of page is column 1.

console_height      .BLOCK  1               ; [24]   1 Byte, virtual console height (rows)
console_width       .BLOCK  1               ; [40]   1 byte, virtual console width (columns)

console_colour      .BLOCK  1               ; [0x0F] 1 Byte, current colour. Top 4 bits [7:4] are background, bottom 4 [3:0] are foreground
console_flags       .BLOCK  1               ;        1 Byte, bit flags for console

console_timer       .BLOCK  1               ;        1 Byte, used to blink cursor, clear movement indicator etc.
console_escape      .BLOCK  1               ;        1 Byte, escape value (0 if not received yet)
console_param1      .BLOCK  1               ;        1 Byte, first character after escape (0 if not recieved yet)

console_identify    .BLOCK  1               ; [0]    1 Byte, indicates console identifier sequence to be returned..

CFLAGS_SHOW_CURSOR  .EQU    1               ; Awaiting input - show (blink) the cursor
CFLAGS_TRACK_CURSOR .EQU    2               ; LED display is tracking cursor position
CFLAGS_SHOW_MOVED   .EQU    4               ; Show display as being moved by user
CFLAGS_ESCAPE       .EQU    8               ; Escape sequence started
CFLAGS_CURSOR_ON    .EQU    16              ; Cursor is currently displayed

SHOW_MOVE_DELAY     .EQU    60              ; How long to show the display has been moved

;------------------------------- BIOS customisation  ------------------------------------------------

drive_a_mem_page    .BLOCK  1
drive_b_mem_page    .BLOCK  1

;------------------------------- BDOS variables ------------------------------------------------
; *** TRACK AND SECTOR MUST BE IN THIS ORDER - READ BY _get_memdisc_addr ***
sys_track           .BLOCK  1               ; 1 Byte, Current disk track 
sys_sector          .BLOCK  2               ; Word, current disk sector
sys_dmaaddr         .BLOCK  2               ; Word, DMA address - Disc will read data to this address, or write from this address
sys_disk_dph        .BLOCK  2               ; Word, points to current disk parameter header (DPH) 
sys_seldsk          .BLOCK  1               ; Byte, current selected disk drive (A=0, B=1..)

sys_alv0            .BLOCK  32              ; 32 bytes, allocation vector 0 (max 255 blocks)
sys_alv1            .BLOCK  32              ; 32 bytes, allocation vector 1 (max 255 blocks)

display_buffer      .BLOCK  24*2            ; 26 byte scratch area used for composing display output (eg. rtc time display etc.)

intr_stackarea      .BLOCK  32              ; Interrupt handler stack
intr_stack          .BLOCK  2

; Panic codes
;
PANIC_0001          .EQU    0F001h
PANIC_0002          .EQU    0F002h
PANIC_0003          .EQU    0F003h
PANIC_0004          .EQU    0F004h

