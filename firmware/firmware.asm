;
; MicroBeast Firmware - boot MicroBeast and launch embedded monitor, bios and other systems
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
                    .MODULE  main
                    .INCLUDE "ports.asm"
                    .INCLUDE "shared_data.asm"


                    .org 0h
                    DI                              ; Disable Z80 interrupts
                    JR      _start

                    .DB     "Firmware 1.7 30/12/25",0,0

_start              LD      SP, 0h                  ; Set SP

                    .INCLUDE    "boot_seq.asm"

_main               CALL    init_portb
                    CALL    i2c_bus_reset
                    
                    CALL    display_init
         
                    LD      E, 0                    ; Set brightness to zero
                    CALL    disp_brightness

                    LD      A,  0
                    LD      HL, welcome
                    CALL    disp_string

                    ;; Animate it
                    LD      A, DL_ADDRESS           ; Put both controllers in brightness mode
                    LD      (display_address), A
                    LD      L, BRIGHT_PAGE
                    CALL    disp_page

                    LD      A, DR_ADDRESS
                    LD      (display_address), A
                    LD      L, BRIGHT_PAGE
                    CALL    disp_page

                    LD      A, 0                    ; Current animation from 0-24
                    LD      (temp_byte), A
                    
                    ; Update display
_frame_loop         CALL    i2c_start
                    LD      A, DL_ADDRESS
                    CALL    i2c_address_w
                    XOR     A                       ; First digit in display
                    CALL    i2c_write

                    LD      B, 12
                    LD      A, (temp_byte)
                    LD      C, A

_l_char_loop        PUSH    BC
                    LD      B, 0
                    LD      HL, little_sin
                    ADD     HL, BC 
                    
                    LD      E, 16
_write_l_char       LD      A, (HL)
                    CALL    i2c_write
                    DEC     E
                    JR      NZ, _write_l_char

                    POP     BC
                    INC     C
                    INC     C
                    LD      A, C
                    CP      24
                    JR      C, _no_loop_l
                    SBC     A, 24
                    LD      C, A
_no_loop_l          DJNZ    _l_char_loop
                    CALL    i2c_stop

                    PUSH    BC
                    CALL    i2c_start
                    LD      A, DR_ADDRESS
                    CALL    i2c_address_w
                    XOR     A
                    CALL    i2c_write

                    POP     BC
                    LD      B, 12

_r_char_loop        PUSH    BC
                    LD      B, 0
                    LD      HL, little_sin
                    ADD     HL, BC 

                    LD      E, 16
_write_r_char       LD      A, (HL)
                    CALL    i2c_write
                    DEC     E
                    JR      NZ, _write_r_char

                    POP     BC
                    INC     C
                    INC     C
                    LD      A, C
                    CP      24
                    JR      C, _no_loop_r
                    SBC     A, 24
                    LD      C, A
_no_loop_r          DJNZ    _r_char_loop
                    CALL    i2c_stop

_next_frame         LD      A, (temp_byte)
                    INC     A
                    LD      (temp_byte), A
                    CP      24
                    JP      NZ, _frame_loop

                    LD      E, DISP_DEFAULT_BRIGHTNESS      ; Reset brightness
                    CALL    disp_brightness

                    LD      A, 0
                    LD      HL, welcome2
                    CALL    disp_string

                    CALL    wait_key

;======================================== SETUP BIOS ========================================

                    LD      HL, bios_seg+4
                    LD      DE, (bios_seg)
                    PUSH    DE
                    LD      BC, (bios_seg+2)
                    LDIR
                    RET
                    
little_sin          .DB     0, 3, 9, 19, 32, 48, 64, 81, 96, 110, 120, 126, 128, 126, 120, 110, 96, 81, 65, 48, 33, 19, 9, 3  ; 24 values

halt                JR      halt

wait_key            LD      BC, 0000h   ; Keyboard all rows
_wait_key           IN      A, (C)
                    AND     3fh
                    CP      3fh
                    JP      Z, _wait_key

_wait_up            LD      D, 100
_wait_loop          IN      A, (C)
                    AND     3fh
                    CP      3fh
                    JP      NZ, _wait_up
                    DEC     D
                    JP      NZ, _wait_loop
                    RET

welcome             .db "************************", 0
welcome2            .db "* MICRO BEAST  Ver 1_7 *", 0

;
; Write A as a hex byte
; Overwrites A...
;
uart_hex            PUSH    AF
                    SRA     A
                    SRA     A
                    SRA     A
                    SRA     A
                    CALL    to_hex
                    CALL    uart_send
                    POP     AF
                    CALL    to_hex
                    JP      uart_send
;
; Returns the low nibble of A as a hex digit
;
to_hex              AND $0F      ;LOW NIBBLE ONLY
                    ADD A,$90
                    DAA 
                    ADC A,$40
                    DAA 
                    RET 
;
; Inline send. Sends the zero terminated string immediately following the call to this function to the UART.
;  e.g.             CALL    uart_inline
;                   .DB     "My text to send", 0
;                   <code continues after message...>
; Returns with Carry set if the string was successfully sent, otherwise, carry is clear.
;
; Uses A 
;
uart_inline         EX      (SP), HL
                    CALL    uart_string
                    JP      C, _inline_end      
_find_end           LD      A, (HL)             ; Get the current character  (Carry preserved)
                    INC     HL                  ; Point to next character    (Carry preserved)
                    AND     A                   ; Test if the current character was zero (Clears carry)
                    JP      NZ, _find_end       ; If it was, we're done, otherwise repeat
_inline_end         EX      (SP), HL
                    RET
;
; Send a zero terminated string pointed to by HL to the UART
;
; Returns with Carry Set if the string was sent sucessfully, clear otherwise
;                    
uart_string         LD      A,(HL)
                    INC     HL
                    AND     A
                    JP      Z, _string_end
                    CALL    uart_send
                    JP      C, uart_string
                    RET
_string_end         SCF
                    RET

; =============================================== Font =====================================================
;
                    .INCLUDE disp.asm
                    .INCLUDE font.asm
                    .INCLUDE  i2c.asm
                    .INCLUDE  io.asm
                    .INCLUDE  uart.asm
                    .include  memory_test.asm

bios_seg            .INCLUDE  build/monitor.inc
.END
