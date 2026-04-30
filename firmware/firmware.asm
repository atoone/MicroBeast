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
                    .INCLUDE "common_data.asm"
                    .INCLUDE "firmware_vars.asm"
                    .INCLUDE "beastos/beastos.inc"

                    .org 0h
                    DI                              ; Disable Z80 interrupts
                    JR      _start

                    .DB     "Firmware 1.8 28/04/26",0,0

_start              LD      SP, 0h                  ; Set SP

                    .INCLUDE    "boot_seq.asm"

                    LD      A, (device_id)
                    CP      DEVICE_MICRO
                    JR      Z, _do_micro_intro

                    CALL    nanobeast_intro
                    JR      _finish_boot

_do_micro_intro     CALL    microbeast_intro

_finish_boot        LD      A, (boot_mode)                  ; If boot mode is zero, skip reading the RTC options byte
                    AND     A
                    JR      Z, _skip_opts

                    CALL    rtc_get_opts                    ; Fetch the boot options byte
_skip_opts          LD      C, A
                    LD      A, (display_detect)             ; If no display is detected, disable output and just use UART
                    AND     A
                    LD      A, C
                    JR      NZ, _has_display
                    OR      BOOT_NO_LED

_has_display        LD      (boot_mode), A                  ; Store our boot mode...  

                    AND     A
                    CALL    Z, wait_key                     ; Only wait for a key if the boot options are unset/default

                    ;
                    ; TODO - if input is from the UART, use that as primary input?
                    ;

;======================================== SETUP BIOS ========================================

                    LD      HL, monitor_img
                    CALL    get_img_header
                    PUSH    DE
                    LDIR

                    LD      HL, bios_img
                    CALL    get_img_header
                    LDIR
                    RET
                    
get_img_header      LD      E, (HL)
                    INC     HL
                    LD      D, (HL)
                    INC     HL
                    LD      C, (HL)
                    INC     HL
                    LD      B, (HL)
                    INC     HL
                    RET

microbeast_intro    CALL    init_portb
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

                    XOR     A
                    LD      HL, welcome2
                    JP      disp_string

little_sin          .DB     0, 3, 9, 19, 32, 48, 64, 81, 96, 110, 120, 126, 128, 126, 120, 110, 96, 81, 65, 48, 33, 19, 9, 3  ; 24 values

nanobeast_intro     XOR     A
                    LD      HL, welcome3
                    JP      disp_string

nano_jump_table     .INCLUDE "nano/jump_table.asm"

micro_jump_table    .INCLUDE "micro/jump_table.asm"

;
; Dummy labels for routines in jump table that we don't support

m_print_inline      JP      uart_inline

load_ccp
configure_hardware
set_usr_interrupt
bios_flash_write
get_disk_page
rtc_get_time_hl
get_page_mapping
set_page_mapping
get_version 
wait_for_key
                    CALL    uart_inline
                    .DB     "BIOS Call not supported\n\r", 0
                    JR      $

;
; Waits for a key or input from the UART
; On return 
;       Carry is SET if input was received from the UART
;       Carry is CLEAR if input was received from the keyboard
;
wait_key            CALL    uart_receive
                    RET     C

                    LD      BC, 0000h           ; Keyboard all rows
                    IN      A, (C)
                    AND     3fh
                    CP      3fh
                    JP      Z, wait_key

_wait_up            LD      D, 100
_wait_loop          IN      A, (C)
                    AND     3fh
                    CP      3fh                 ; Carry flag is clear if keys are all released
                    JP      NZ, _wait_up
                    DEC     D
                    JP      NZ, _wait_loop
                    RET

welcome             .db "************************", 0
welcome2            .db "* MICRO BEAST  Ver 1_8 *", 0
welcome3            .db "* NANO BEAST   Ver 1_8 *", 0

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
                    .INCLUDE  beastos/display.asm
                    .INCLUDE  beastos/font.asm
                    .INCLUDE  micro/i2c.asm
                    .INCLUDE  micro/io.asm
                    .INCLUDE  nano/i2c.asm
                    .INCLUDE  nano/io.asm
                    .INCLUDE  keyboard.inc
                    .INCLUDE  uart.asm
                    .INCLUDE  memory_test.asm
                    .INCLUDE  rtc_options.asm
monitor_img         .INCLUDE  build/monitor.inc
bios_img            .INCLUDE  build/bios.inc
.END
