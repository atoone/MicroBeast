;
; BATT - Battery monitor utility
;
; Copyright (c) 2026 Andy Toone for Feersum Technology Ltd.
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

;
; Command line: BATT
;
; Displays current battery status, then waits for a keypress.
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/beastos.inc"


FXL_ADDRESS                 .EQU 043h

CHARGE_DONE_MASK            .EQU 001h
FAST_CHARGE_MASK            .EQU 008h
JACK_POWER_MASK             .EQU 002h
USB_POWER_MASK              .EQU 010h

FXL_CTRL_REG                .EQU 001h           ; Write FXL_CTRL_RESET to soft reset the device
FXL_CTRL_RESET              .EQU 001h

FXL_IO_DIR_REG              .EQU 002h           ; Reset value: 000h - All inputs

FXL_PULL_ENABLE_REG         .EQU 00Bh           ; Reset value: 0FFh - All enabled
FXL_PULL_ALL_MASK           .EQU 0FFh

FXL_PULL_UPDWN_REG          .EQU 00Dh           ; Reset value: 000h - All pull down
FXL_PULL_UP_MASK            .EQU 0FFh

FXL_INPUT_REG               .EQU 00Fh


FUEL_ADDRESS                .EQU 036h

FUEL_VOLT_REG               .EQU 002h           ; Cell voltage / 78.125uV
FUEL_SOC_REG                .EQU 004h           ; State of charge 1%/256 (ie high byte = percentage charge)
FUEL_CRATE_REG              .EQU 016h           ; Charge rate 0.208%/hr


                        LD      (old_stack), SP
                        LD      SP, old_stack

_reset                  CALL    MBB_PRINT
                        .DB     "\n\rBattery status\n\r", 0

                        LD      H, FXL_ADDRESS
                        LD      L, FXL_CTRL_REG
                        CALL    MBB_I2C_WR_ADDRESS

                        JR      NC, _reset_error

                        LD      A, FXL_CTRL_RESET
                        CALL    MBB_I2C_WRITE

                        JR      NC, _reset_error
                        CALL    MBB_I2C_STOP

                        JR      _set_pullup

_reset_error            CALL    MBB_PRINT
                        .DB     "No Battery connected", 0

                        JP      _finish

_read_error             CALL    MBB_PRINT
                        .DB     "Read error", 0
                        JP      _finish

_set_pullup             LD      H, FXL_ADDRESS
                        LD      L, FXL_PULL_UPDWN_REG
                        CALL    MBB_I2C_WR_ADDRESS

                        JR      NC, _reset_error

                        LD      A, FXL_PULL_UP_MASK
                        CALL    MBB_I2C_WRITE

                        JR      NC, _reset_error
                        CALL    MBB_I2C_STOP

                        ; Now see where we're getting power
_get_power              CALL    MBB_PRINT
                        .DB     "\r", 0

                        XOR     A
                        LD      (is_battery), A

                        LD      H, FXL_ADDRESS
                        LD      L, FXL_INPUT_REG
                        CALL    MBB_I2C_RD_ADDRESS

                        JR      NC, _read_error

                        LD      E, A
                        CALL    MBB_I2C_STOP

                        LD      A, E
                        AND     USB_POWER_MASK
                        JR      NZ, _no_usb_power

                        CALL    MBB_PRINT
                        .DB     "USB ",0

_no_usb_power           LD      A, E
                        AND     JACK_POWER_MASK
                        JR      NZ, _no_jack_power

                        CALL    MBB_PRINT
                        .DB     "Ext ", 0

_no_jack_power          LD      A, E
                        AND     USB_POWER_MASK | JACK_POWER_MASK
                        CP      USB_POWER_MASK | JACK_POWER_MASK
                        JR      NZ, do_fuel

                        LD      A, 0FFh
                        LD      (is_battery), A

                        CALL    MBB_PRINT
                        .DB     "Battery ", 0

do_fuel                 LD      L, FUEL_SOC_REG
                        CALL    read_fuel
                        JP      NC, _fuel_error

                        ; HL is word value
                        LD      B, H                ; - Percentage
                        PUSH    BC

                        LD      HL, _percent
                        LD      A, B
                        CALL    byte_to_dec

                        CALL    MBB_PRINT
_percent                .DB     "   %    ",0

                        POP     BC
                        CALL    div_five
                        LD      C, A

                        ; C is now charge from 0-20
                        LD      B, 0

                        LD      A, (is_battery)
                        AND     A
                        JR      Z, _animate
                        LD      B, C

_animate                PUSH    BC
                        LD      C, B
                        CALL    show_bar

                        LD      BC, 16384
_delay                  DEC     BC
                        LD      A, B
                        OR      C
                        JR      NZ, _delay

                        POP     BC
                        LD      A, B
                        INC     B
                        CP      C
                        JR      NZ, _animate

                        LD      B, 128
                        CALL    MBB_GET_TIMER
                        
_wait_second            LD      C, L
                        PUSH    BC
                        
                        LD      E, 0FFh
                        LD      C, BDOS_CONIO
                        CALL    BDOS
                        
                        POP     BC

                        AND     A
                        JR      NZ, _finish

                        CALL    MBB_GET_TIMER
                        LD      A, C
                        CP      L
                        JR      Z, _wait_second

                        DJNZ    _wait_second

                        JP      _get_power
                        
_finish                 CALL    MBB_PRINT
                        .DB     "\r\n-------------------------"
                        .DB     "\r                         ",0

                        LD      SP, (old_stack)
                        RET

_fuel_error             CALL    MBB_PRINT
                        .DB     "Error checking level", 0
                        JR      _finish

BAR_LEFT                .EQU    0039h
BAR_MIDDLE              .EQU    0009h
BAR_RIGHT               .EQU    000fh

SOLID_LEFT              .EQU    3370h
SOLID_RIGHT             .EQU    0c86h


show_bar                XOR     A
                        LD      B, A                ; B is our counter 0-20

                        LD      HL, BAR_LEFT
_bar_loop               LD      DE, SOLID_LEFT
                        CP      C
                        JR      NC, _skip_left
                        LD      A, H
                        OR      D
                        LD      H, A
                        LD      A, L
                        OR      E
                        LD      L, A
                        LD      A, B

_skip_left              INC     A
                        LD      DE, SOLID_RIGHT
                        CP      C
                        JR      NC, _skip_right

                        LD      A, H
                        OR      D
                        LD      H, A
                        LD      A, L
                        OR      E
                        LD      L, A
                        LD      A, B

_skip_right             SRL     A
                        ADD     A, 14
                        PUSH    BC
                        CALL    MBB_WRITE_LED
                        POP     BC

                        INC     B
                        INC     B
                        LD      HL, BAR_MIDDLE
                        LD      A, B
                        CP      18
                        JR      C, _bar_loop
                        LD      HL, BAR_RIGHT
                        JR      Z, _bar_loop
                        RET

; Return A = B/5 (uses C)
div_five                LD      C,B
                        SRL     C
                        SRL     C
                        LD      A,B
                        SUB     C
                        RRA
                        SRL     A
                        LD      C,A
                        LD      A,B
                        SUB     C
                        RRA
                        SRL     A
                        LD      C,A
                        LD      A,B
                        SUB     C
                        RRA
                        SRL     A
                        RET

;
; Read a word from the fuel gauge register L into HL
; Carry flag is set if read was successful
;
read_fuel               LD      H, FUEL_ADDRESS 
                        CALL    MBB_I2C_RD_ADDRESS
                        RET     NC
                
                        LD      H, A
                        CALL    MBB_I2C_ACK
                        CALL    MBB_I2C_READ

                        LD      L, A
                        CALL    MBB_I2C_STOP
                        SCF
                        RET

;
; Writes a three digit decimal number in A to (HL)
;
byte_to_dec             LD      D, '0'
                        LD      C,-100
                        CALL    _digit
                        LD      C,-10
                        CALL    _digit
                        LD      C,-1
                        LD      D, C
_digit                  LD      B,'0'-1
_digit_loop             INC     B
                        ADD     A,C
                        JR      C,_digit_loop
                        SUB     C               ;works as add 100/10/1
                        LD      C, A            
                        LD      A, B            ;char is in b
                        CP      D
                        LD      A, ' '
                        JR      Z, _store
                        LD      A, B
                        LD      D, 0FFh
_store                  LD      (HL), A         
                        INC     HL
                        LD      A, C             
                        RET

is_battery              .DB     0           ; Non zero if there is a power source

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0


                        .END