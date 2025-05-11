;
; VLOAD - Videobeast file load utility
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
; Command line: VLOAD filename address
;
;
;

                        .ORG    0100h

                        .INCLUDE "beastos/bios.inc"

CMD_LEN                 .EQU    00080h
CMD_START               .EQU    00081h

FCB                     .EQU    05Ch            ; File control block address
DISK_BUFFER             .EQU    080h            ; Input disk buffer address

;
;   FILE CONTROL BLOCK DEFINITIONS
FCB_DISK_NAME           .EQU    FCB+0           ; Disk name
FCB_FILE_NAME           .EQU    FCB+1           ; File name
FCB_FILE_TYPE           .EQU    FCB+9           ; Disk file type (3 characters)
FCB_EXTENT              .EQU    FCB+12          ; File's current extent number
FCB_RECORD_COUNT        .EQU    FCB+15          ; File's record count (0 to 128)
FCB_CURRENT_RECORD      .EQU    FCB+32          ; Current (next) record number (0 to 127)

FCB_LEN                 .EQU    FCB+33          ; FCB length

IO_PAGE_1               .EQU    071h            ; Page 1: 4000h - 7fffh
VIDEOBEAST_PAGE         .EQU    040h

VB_UNLOCK               .EQU    0F3h            ; Unlock register write

VBASE                   .EQU    04000h

VB_MODE                 .EQU    VBASE + 03FFFh
VB_REGISTERS_LOCKED     .EQU    VBASE + 03FFEh
VB_PAGE_0               .EQU    VBASE + 03FF9h

VB_REGISTERS_H          .EQU    (VBASE >> 8) + 03Fh

                        LD      (old_stack), SP
                        LD      SP, old_stack
                        LD      A, (CMD_LEN)
                        CP      4                   ; Need at least four characters
                        JR      NC, _has_params

_show_help              LD      DE, help_message
_exit_message           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
_finish                 LD      SP, (old_stack)
                        RET

_has_params             LD      B, A                 ; Now set up parameters for parsing the address
                        LD      DE, 0                ; CDE will be address
                        LD      C, E
                        LD      A, E

                        LD      HL, CMD_START
_find_filename          LD      A, (HL)              ; Look for the start of the filename
                        INC     HL
                        CP      ' '
                        JR      NZ, _space_start
                        DJNZ    _find_filename
                        JR      _show_help

_find_space             LD      A, (HL)             ; Now look for the space after the filename
                        INC     HL
                        CP      ' '
                        JR      Z, _address_start
_space_start            DJNZ    _find_space
                        JR      _show_help

_invalid_address        LD      DE, error_address
                        JR      _exit_message

_find_address           LD      A, (HL)
                        INC     HL
                        CP      ' '
                        JR      Z, _address_start

                        CP      'X'
                        JR      NZ, _decimal_loop

                        DEC     B
                        JR      Z, _show_help
                        LD      A, (HL)
                        INC     HL
                        JR      _hex_loop

_address_start          DJNZ    _find_address
                        JR      _show_help

                        ; Parse a decimal address into CDE
                        ;
_decimal_loop           PUSH    HL               ; Get here with A holding the first/next digit of the address
                        PUSH    AF               ; Multiply CDE by 10

                        EX      DE, HL
                        ADD     HL, HL
                        RL      C
                        LD      A,  C
                        PUSH    HL           ; ADE = 2 * CDE             
                        POP     DE

                        ADD     HL, HL
                        RL      C
                        ADD     HL, HL
                        RL      C

                        ADD     HL, DE
                        JR      NC, _no_carry
                        INC     C

_no_carry               ADD     A, C
                        LD      C, A
                        EX      DE, HL

                        POP     AF
                        POP     HL

                        ; Now add the digit in A to CDE
                        SUB     '9'+1
                        ADD     A, 10
                        JR      C, _digit_ok
                        JP      _kilobytes

_digit_ok               PUSH    HL

                        LD      H, 0
                        LD      L, A
                        ADD     HL, DE
                        EX      DE, HL
                        JR      NC, _digit_no_carry
                        INC     C

_digit_no_carry         POP     HL

                        LD      A, (HL)
                        INC     HL  
                        DJNZ    _decimal_loop
                        JR      _open_and_load

_kilobytes              CP      'K'
                        JR      NZ, _show_help

                        LD      C, D
                        LD      D, E
                        LD      E, 0

                        SLA     D
                        RL      C
                        SLA     D
                        RL      C

                        DEC     B
                        JP      NZ, _show_help
                        JR      _open_and_load

                        ;
                        ; Parse a hex address into CDE
                        ;
_hex_loop               EX      DE, HL
                        ADD     HL, HL
                        RL      C
                        ADD     HL, HL
                        RL      C
                        ADD     HL, HL
                        RL      C
                        ADD     HL, HL
                        RL      C
                        EX      DE, HL

                        SUB     '9'+1
                        ADD     A, 10
                        JR      C, _hex_digit_ok  

                        SUB     7
                        JR      C, _kilobytes
                        CP      16
                        JR      NC, _kilobytes

_hex_digit_ok           PUSH    HL

                        LD      H, 0
                        LD      L, A
                        ADD     HL, DE
                        EX      DE, HL
                        
                        POP     HL

                        LD      A, (HL)
                        INC     HL
                        DJNZ    _hex_loop

                        ; Get here with CDE holding address - adjust it for VideoBeast and prepare to load

_open_and_load          LD      A, D

                        RL      D
                        RL      C
                        RL      D
                        RL      C
                        RL      D
                        RL      C
                        RL      D
                        RL      C

                        AND     00Fh
                        OR      040h
                        LD      D, A

                        ; Now DE has the target location in page 1 amd C has the VideoBeast page number

                        PUSH    DE
                        PUSH    BC

                        LD      C, 1                        ; Remember what the current page mappings are so we can restore them later
                        CALL    MBB_GET_PAGE
                        LD      (old_page_1), A

                        CALL    open_file
                        POP     BC
                        POP     DE

                        LD      HL, 0                       ; Count records loaded in HL

                        CP      0FFh
                        JR      NZ, _load_loop

                        LD      DE, error_file_open
                        JP      _exit_message

_load_loop              CALL    read_record
                        AND     A
                        JR      NZ, _load_complete

                        ; Now copy it into VideoBeast
                        DI
                        LD      A, VIDEOBEAST_PAGE
                        OUT     (IO_PAGE_1), A

                        LD      A, (VB_REGISTERS_LOCKED)
                        LD      (lock_status), A

                        LD      A, VB_UNLOCK
                        LD      (VB_REGISTERS_LOCKED), A

                        LD      A, (VB_MODE)
                        LD      (old_vb_mode), A

                        AND     00Fh
                        LD      (VB_MODE), A                        ; Make sure we have 16K page mapping

                        LD      A, (VB_PAGE_0)
                        LD      (old_vb_page0), A

                        LD      A, C
                        LD      (VB_PAGE_0), A

                        PUSH    HL
                        PUSH    BC
                        LD      HL, DISK_BUFFER

                        LD      BC, 128
                        LDIR
                        POP     BC
                        POP     HL

                        BIT     4, D                                ; Wrapped into next page
                        JR      Z, _no_overflow

                        RES     4, D
                        INC     C

_no_overflow
                        LD      A, (old_vb_page0)
                        LD      (VB_PAGE_0), A

                        LD      A, (old_vb_mode)
                        LD      (VB_MODE), A

                        LD      A, (lock_status)
                        LD      (VB_REGISTERS_LOCKED), A

                        LD      A, (old_page_1)
                        OUT     (IO_PAGE_1), A
                        EI

                        INC     HL
                        JR      _load_loop


_load_complete          ; HL has number of sectors loaded...
                        LD      DE, digit_store
                        CALL    Num2Dec

                        LD      HL, digit_store
                        CALL    adjust_digits
  
                        LD      DE, success_count
                        LD      C, B
                        LD      B, 0
                        LDIR

                        LD      HL, success_end
                        LD      BC, success_end_len
                        LDIR

                        LD      DE, success_message
                        JP      _exit_message

; Convert number in HL to 5 digit decimal string stored at DE
;
;   Code from https://map.grauw.nl/sources/external/z80bits.html#5.1
;
Num2Dec                 LD      BC,-10000
                        CALL    _digit
                        LD      BC,-1000
                        CALL    _digit
                        LD      BC,-100
                        CALL    _digit
                        LD      C,-10
                        CALL    _digit
                        LD      C,B

_digit                  LD      A,'0'-1
_digit_loop             INC     A
                        ADD     HL,BC
                        JR      C,_digit_loop
                        SBC     HL,BC

                        LD      (DE),A
                        INC     DE
                        RET

;
; Given HL points to a 5 digit decimal string created by num2dec above, return the 
; address of the first non-zero digit in HL, and the remaining digit count in B
;
adjust_digits           LD      B, 5
_find_start             LD      A, (HL)
                        CP      '0'
                        RET     NZ
                        INC     HL
                        DJNZ    _find_start
                        RET


; Open the file in the FCB. Returns A = 255 if there is an error
;
open_file               XOR     A        
                        LD      (FCB_CURRENT_RECORD), A     ;CLEAR CURRENT RECORD
;
                        LD      DE, FCB
                        LD      C, BDOS_OPENFILE
                        CALL    BDOS
                        RET

;Read disk file record. Returns A = 0 if the record is read OK (otherwise file end)
;
read_record   
                        PUSH    HL
                        PUSH    DE 
                        PUSH    BC
                        LD      DE, FCB
                        LD      C, BDOS_READSEQ
                        CALL    BDOS
                        POP     BC
                        POP     DE
                        POP     HL
                        RET

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0

old_page_1              .DB     0
lock_status             .DB     0
old_vb_mode             .DB     0
old_vb_page0            .DB     0

digit_store             .BLOCK  6

success_message           .DB     "Loaded "
success_count             .BLOCK 5
success_end               .DB     " sectors OK.$"
success_end_len           .EQU   $-success_end

error_file_open         .DB     "ERROR: Cannot read file$"
error_address           .DB     "ERROR: Invalid address$"

help_message            .DB     "VLOAD: VideoBeast RAM Loader\n\r"
                        .DB     " Usage:\n\r"
                        .DB     "   VLOAD <filename> [x]<address>[K]\n\r\n"
                        .DB     " Loads file into Video RAM starting at the given address.\n\r"
                        .DB     " Address is decimal bytes unless prefixed with 'x'.\n\r"
                        .DB     " End with K to specficy Kb offset\n\n$"

                        .END