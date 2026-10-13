
; Version - display version information
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
; Command line: VERSION
;
; Displays the version information for CP/M and VideoBeast, if installed
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/beastos.inc"

IO_PAGE_1               .EQU    071h      ; Page 1: 4000h - 7fffh

VB_UNLOCK               .EQU    0F3h           ; Unlock register write

VBASE                   .EQU    04000h

VB_MODE                 .EQU    VBASE + 03FFFh
VB_REGISTERS_LOCKED     .EQU    VBASE + 03FFEh

VB_REGISTERS_MUL_X      .EQU    VBASE + 03FE0h
VB_REGISTERS_MUL_Y      .EQU    VBASE + 03FE2h

                        LD      (old_stack), SP
                        LD      SP, old_stack

                        CALL    version

                        LD      SP, (old_stack)
                        RET

version                 CALL    MBB_PRINT
                        .DB     "BeastOS Version ", 0
                        CALL    MBB_GET_VERSION
                        PUSH    AF

                        SRL     A
                        SRL     A
                        SRL     A
                        SRL     A
                        CALL    decimal_a
                        LD      E, '.'
                        LD      C, BDOS_CONOUT
                        CALL    BDOS
                        POP     AF
                        AND     0Fh
                        CALL    decimal_a

                        CALL    MBB_PRINT
                        .DB     "\r\nROM:\r\n", 0

                        CALL    access_rom
                        LD      HL, 04007h
                        LD      A, (HL)
                        CP      'F'
                        JR      NZ, _firm_done

                        LD      C, BDOS_CONOUT
                        LD      B, 24

_firm_loop              LD      E, A
                        PUSH    BC
                        PUSH    HL
                        CALL    BDOS
                        POP     HL
                        POP     BC
                        INC     HL
                        LD      A, (HL)
                        AND     A
                        JR      Z, _firm_done
                        DJNZ    _firm_loop

_firm_done              CALL    restore_rom
 
                        CALL    MBB_PRINT 
                        .DB     "\r\nVideoBeast ", 0

                        DI
                        CALL    access_videobeast

                        LD      A, 43
                        LD      (VB_REGISTERS_LOCKED), A
                        LD      A, (VB_REGISTERS_LOCKED)
                        AND     A
                        JR      NZ, _no_videobeast

                        LD      A, VB_UNLOCK
                        LD      (VB_REGISTERS_LOCKED), A
                        LD      A, (VB_REGISTERS_LOCKED)
                        CP      VB_UNLOCK
                        JR      NZ, _no_videobeast

                        LD      HL, (VB_REGISTERS_MUL_Y)  ; Major/minor version on reset
                        LD      (major_minor), HL
                        LD      HL, (VB_REGISTERS_MUL_X)  ; Git commit count on reset
                        LD      (build_ver), HL
                        CALL    restore_videobeast
                        EI

                        LD      A, (major_minor+1)
                        CALL    decimal_a
                        CALL    MBB_PRINT
                        .DB     ".", 0
                        LD      A, (major_minor)
                        CALL    decimal_a

                        CALL    MBB_PRINT
                        .DB     " +",0

                        LD     HL, (build_ver)
                        CALL   decimal_hl

                        RET


_no_videobeast          CALL    restore_videobeast
                        EI

                        CALL   MBB_PRINT
                        .DB    "not present",0
                        
                        RET

;
; Display the bottom nibble in A as a decimal
;

decimal_a               LD      L, A
                        LD      H, 0

;Number in hl to decimal ASCII
;Thanks to z80 Bits
;inputs:    hl = number to ASCII
;example: hl=300 outputs '300'
;
decimal_hl              XOR     A
                        LD      (leading_zero),A
                        LD      BC,-10000
                        CALL    digit_out
                        LD      BC,-1000
                        CALL    digit_out
                        LD      BC,-100
                        CALL    digit_out
                        LD      BC,-10
                        CALL    digit_out
                        LD      BC,-1
                        LD      A, 1                    ; Always display last digit
                        LD      (leading_zero), A

digit_out               LD      A,'0'-1
digit_loop              INC     A
                        ADD     HL,BC
                        JR      C,digit_loop
                        SBC     HL,BC
                        LD      E,A
                        LD      C, BDOS_CONOUT
                        CP      '0'
                        JP      Z, check_zero
                        LD      (leading_zero), A
output_digit            PUSH    HL
                        CALL    BDOS
                        POP     HL
                        RET

check_zero              LD      A, (leading_zero)
                        AND     A
                        RET     Z  
                        JR      output_digit

access_rom              LD      C, 1
                        CALL    MBB_GET_PAGE
                        LD      (old_page),A

                        LD      A, 1
                        LD      E, 0
                        CALL    MBB_SET_PAGE
                        RET

restore_rom             LD      A, (old_page)
                        LD      E, A
                        LD      A, 1
                        JP      MBB_SET_PAGE


access_videobeast       LD      C, 1
                        CALL    MBB_GET_PAGE
                        LD      (old_page),A
                        LD      A, 1
                        LD      E, 040h
                        CALL    MBB_SET_PAGE

                        LD      A, (VB_REGISTERS_LOCKED)
                        LD      (lock_status), A
                        RET

restore_videobeast      LD      A, (lock_status)
                        LD      (VB_REGISTERS_LOCKED), A
                        
                        LD      A, (old_page)
                        LD      E, A
                        LD      A, 1
                        JP     MBB_SET_PAGE

old_page                .DB     0
lock_status             .DB     0

leading_zero            .DB     0
major_minor             .DW     0
build_ver               .DW     0

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0


                        .END