;
; VPEEK - Videobeast peek and poke utility
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

;
; Command line: VPEEK  <r> <x> hex_address <value> <value...>
;
; With just hex_addres specified, VPEEK will list the values at the given hex address in the current VideoBeast page.
;   Use <r> to read registers (unlocks and re-locks register access). Enter for more values, any other key to exit.
;   Add one or more values (space or comma separated) to set values from the given address
;   Use <x> to exit immediately without prompting
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/bios.inc"

CMD_LEN                 .EQU    00080h
CMD_START               .EQU    00081h

IO_PAGE_1               .EQU    071h      ; Page 1: 4000h - 7fffh

VB_UNLOCK               .EQU    0F3h           ; Unlock register write

VBASE                   .EQU    04000h

VB_MODE                 .EQU    VBASE + 03FFFh
VB_REGISTERS_LOCKED     .EQU    VBASE + 03FFEh

VB_REGISTERS_H          .EQU    (VBASE >> 8) + 03Fh

                        LD      (old_stack), SP
                        LD      SP, old_stack

                        XOR     A
                        LD      (cmd_mode), A
                        LD      A, (CMD_LEN)
                        OR      A
                        JR      NZ, _has_params

_show_help              LD      DE, help_message
_exit_message           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
_finish                 LD      SP, (old_stack)
                        RET

_has_params             LD     B, A
                        LD     HL, CMD_START
_param_loop             LD     A, (HL)
                        INC    HL
                        CP     64
                        JR     C, _not_alpha
                        OR     020h             ; To lowercase
_not_alpha              CP     'r'
                        JR     NZ, _not_register
                        LD     A, (cmd_mode)
                        AND    A
                        LD     DE, r_error_message
                        JR     NZ, _exit_message
                        LD     A, (cmd_options)
                        OR     OPT_REGISTER
_set_param              LD     (cmd_options), A
                        JR     _next_param

_not_register           CP     'x'
                        JR     NZ, _not_exit
                        LD     A, (cmd_mode)
                        AND    A
                        LD     DE, x_error_message
                        JR     NZ, _exit_message
                        LD     A, (cmd_options)
                        OR     OPT_EXIT
                        JR     _set_param

_not_exit               CP    ' '
                        JR    Z, _next_param
                        CP    ','
                        JR    Z, _next_param
                        JR    _param_value

_next_param             DJNZ  _param_loop
                        LD    A, (cmd_mode)
                        AND   A

                        JR    Z, _show_help

                        RET

_show_value_error       LD      DE, value_error_message
                        JR      _exit_message

_show_long_error        LD      DE, long_error_message
                        JR      _exit_message

_param_value            LD      DE, 0
                        EX      DE, HL
                        LD      C, 5
                        JR      _value_go

_value_loop             LD      A, (DE)

                        CP      ' '
                        JR      Z, _use_value
                        CP      ','
                        JR      Z, _use_value
                        INC     DE

_value_go               DEC     C
                        JR      Z, _show_long_error

                        CP      '0'
                        JR      C, _show_value_error

                        CP      ':'
                        JR      C, _param_digit

                        OR      020h                    ; Lower cases
                        CP      'a'
                        JR      C, _show_value_error

                        CP      'g'
                        JR      NC, _show_value_error

                        SUB     'a'-10
                        JR      _use_digit
_param_digit            SUB     '0'
_use_digit              AND     0Fh
                        ADD     HL, HL
                        ADD     HL, HL
                        ADD     HL, HL
                        ADD     HL, HL
                        OR      L
                        LD      L, A
                        
                        DJNZ    _value_loop

_use_value              LD      A, (cmd_mode)
                        AND     A
                        JR      NZ, _write_value
                        INC     A
                        LD      (cmd_mode), A
                        LD      (cmd_address), HL
                        LD      (cmd_write_address), HL
                        LD      A, B
                        AND     A
                        JR      Z, _display_values
                        EX      DE, HL
                        JP      _param_loop

_write_value            LD      A, H
                        AND     A
                        JR      NZ, _show_long_error
                        LD      C, L
                        LD      HL, (cmd_write_address)

                        CALL    access_videobeast

                        LD      A, (cmd_options)
                        AND     OPT_REGISTER
                        JR      Z, _full_address
                        LD      H, VB_REGISTERS_H

                        LD      A, VB_UNLOCK
                        LD      (VB_REGISTERS_LOCKED), A

_full_address           LD      A, C
                        LD      (HL), A
                        INC     HL
                        LD      (cmd_write_address), HL

                        CALL    restore_videobeast
                        EX      DE, HL

                        LD      A, B
                        AND     A
                        JP      NZ, _param_loop
                        
;
; -------------------------   Display the values from the selected address -------------------------
;
_display_values         LD      A, (cmd_options)            ; TODO: Always start at 0/8 offset?
                        AND     OPT_REGISTER
                        JR      Z, _disp_address

                        LD      DE, disp_r_message
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
                        JR      _disp_address_low

_disp_address           LD      A, (cmd_address+1)
                        CALL    display_hex
_disp_address_low       LD      A, (cmd_address)            ; Fix address to 8 byte steps
                        AND     0F8h                    
                        LD      (cmd_address), A
                        CALL    display_hex

                        LD      E, ' '
                        LD      C, BDOS_CONOUT
                        CALL    BDOS
                        
                        CALL    access_videobeast

                        LD      B, 8
                        LD      HL, (cmd_address)

                        LD      A, (cmd_options)
                        AND     OPT_REGISTER
                        JR      Z, _disp_loop
                        LD      H, VB_REGISTERS_H

                        LD      A, VB_UNLOCK
                        LD      (VB_REGISTERS_LOCKED), A

_disp_loop              LD      A, (HL)                     
                        CALL    display_hex

                        INC     HL
                        DJNZ    _disp_loop
                        CALL    restore_videobeast

                        LD      A, (cmd_options)
                        AND     OPT_EXIT
                        JP      NZ, _finish

_wait_key               LD      E, 0FFh
                        LD      C, BDOS_CONIO
                        CALL    BDOS
                        AND     A
                        JR      Z, _wait_key
                        CP      13
                        JP      NZ, _finish

                        LD      BC, 8
                        LD      HL, (cmd_address)
                        ADD     HL, BC
                        LD      (cmd_address), HL

                        LD      DE, disp_newline
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

                        JR      _display_values

display_hex             PUSH    HL
                        PUSH    BC
                                                    
                        PUSH    AF
                        SRA     A
                        SRA     A
                        SRA     A
                        SRA     A
                        CALL    to_hex

                        LD      E, A
                        LD      C, BDOS_CONOUT
                        CALL    BDOS
                        POP     AF
                        CALL    to_hex

                        LD      E, A
                        LD      C, BDOS_CONOUT
                        CALL    BDOS

                        POP     BC
                        POP     HL
                        RET

; Returns the low nibble of A as a hex digit
;
to_hex                  AND     00Fh      ;LOW NIBBLE ONLY
                        ADD     A,090h
                        DAA 
                        ADC     A,040h
                        DAA 
                        RET 

access_videobeast       DI
                        PUSH    HL
                        PUSH    BC
                        PUSH    DE
                        LD      C, 1
                        CALL    MBB_GET_PAGE
                        LD      (old_page),A
                        LD      A, 1
                        LD      E, 040h
                        CALL    MBB_SET_PAGE

                        LD      A, (VB_REGISTERS_LOCKED)
                        LD      (lock_status), A
                        POP     DE
                        POP     BC
                        POP     HL
                        RET

restore_videobeast      LD      A, (lock_status)
                        LD      (VB_REGISTERS_LOCKED), A

                        PUSH    DE
                        PUSH    BC
                        
                        LD      A, (old_page)
                        LD      E, A
                        LD      A, 1
                        CALL    MBB_SET_PAGE
                        POP     BC
                        POP     DE
                        EI
                        RET

cmd_mode                .DB     0
cmd_options             .DB     0
cmd_address             .DW     0
cmd_write_address       .DW     0

lock_status             .DB     0
old_page                .DB     0

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0

OPT_REGISTER            .EQU    01h
OPT_EXIT                .EQU    02h

disp_r_message          .DB     "R $"

disp_newline            .DB     "\n\r$"

r_error_message         .DB     "ERROR: Unexpected 'r' parameter.$"

x_error_message         .DB     "ERROR: Unexpected 'x' parameter.$"

value_error_message     .DB     "ERROR: Invalid hex value. Use 0-9, A-F.$"

long_error_message      .DB     "ERROR: Have value too long$"

help_message            .DB     "VPEEK: VideoBeast RAM Read/Write\n\r"
                        .DB     " Usage:\n\r"
                        .DB     "   VPEEK [r|x] HEX [value] [value..]\n\r\n"
                        .DB     " Options:\n\r"
                        .DB     "   r : Access VideoBeast registers 00-FF\n\r"
                        .DB     "   x : Exit without prompting\n\r\n"
                        .DB     " Add values (space or comma separated) to write.\n\r"
                        .DB     "$"


                        .END