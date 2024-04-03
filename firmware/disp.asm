; ========================================== Display Routines ===============================================
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
                    .MODULE disp

CONFIG_PAGE         .EQU    3
BRIGHT_PAGE         .EQU    1
LED_PAGE            .EQU    0 

display_init        CALL    disp_clear
                    LD      E, DISP_DEFAULT_BRIGHTNESS
                    CALL    disp_brightness

                    CALL    disp_select_l
                    CALL    disp_config

                    CALL    disp_select_r
                    CALL    disp_config

disp_select_l       LD      A, DL_ADDRESS
                    LD      (display_address), A
                    RET

disp_select_r       LD      A, DR_ADDRESS
                    LD      (display_address), A
                    RET

disp_config         LD      L, CONFIG_PAGE
                    CALL    disp_page
                    CALL    i2c_start
                    LD      A, (display_address)
                    CALL    i2c_address_w
                    LD      A, 000h
                    CALL    i2c_write
                    LD      A, 001h         ; Turn display on
                    CALL    i2c_write
                    LD      A, 078h         ; 0.020mA
                    CALL    i2c_write
                    JP      i2c_stop

;
; Sets the brightness for the display
; Enter with E set to the desired brightness for all segments
;
disp_brightness     CALL    disp_select_l
                    CALL    _set_bright
                    CALL    disp_select_r
_set_bright         LD      L, BRIGHT_PAGE
                    CALL    disp_page
                    LD      L, 12
_bright_loop        CALL    i2c_start
                    LD      A, (display_address)
                    CALL    i2c_address_w
                    LD      A, L
                    DEC     A
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A
                    CALL    i2c_write
                    LD      H, 010h
_bright_byte        LD      A, E
                    CALL    i2c_write
                    DEC     H
                    JR      NZ, _bright_byte
                    CALL    i2c_stop
                    DEC     L
                    JR      NZ, _bright_loop
                    LD      L, LED_PAGE
                    CALL    disp_page
                    RET

; Set the Page number
; Call with page number in L
;
; Uses A, B, C, D
disp_page           CALL    disp_unlock
                    CALL    i2c_start
                    LD      A, (display_address)
                    CALL    i2c_address_w
                    LD      A, 0FDh
                    CALL    i2c_write
                    LD      A, L
                    CALL    i2c_write
                    JP      i2c_stop

disp_unlock         CALL    i2c_start           ; Must be called before switching pages
                    LD      A, (display_address)
                    CALL    i2c_address_w
                    LD      A, DISP_REG_CRWL
                    CALL    i2c_write
                    LD      A, DISP_UNLOCK
                    CALL    i2c_write
                    JP      i2c_stop

; Set the character at column A to brightness C
;
;
disp_char_bright    PUSH    BC
                    LD      B, DL_ADDRESS
                    CP      12
                    JP      C, _bright_left
                    LD      B, DR_ADDRESS
                    SUB     12
_bright_left        LD      E, A
                    LD      A, B
                    LD      (display_address), A
                    LD      L, BRIGHT_PAGE
                    CALL    disp_page

                    CALL    i2c_start
                    LD      A, (display_address)
                    CALL    i2c_address_w
                    LD      A, E
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A
                    CALL    i2c_write
                    POP     HL
                    LD      H, 010h
_bright_char_loop   LD      A, L
                    CALL    i2c_write
                    DEC     H
                    JR      NZ, _bright_char_loop
                    CALL    i2c_stop

                    LD      L, LED_PAGE
                    CALL    disp_page
                    RET
                    
; Display a single character A at column C
;
; Returns with A pointing to next column
;
disp_character      CP      32
                    JP      P, _not_control

_invalid_char       LD      HL, INVALID_CHAR_BITMASK
                    LD      A, C
                    JP      disp_bitmask

_not_control        BIT     7, A
                    JP      NZ, _invalid_char
                    SUB     32

                    LD      D, 0
                    LD      E, A
                    SLA     E                   ; Don't need to shift into D, since bit 7 is zero
                    LD      HL, font  
                    ADD     HL, DE
                    LD      D, (HL)
                    INC     HL
                    LD      H, (HL)
                    LD      L, D
                    LD      A, C
                    ; Fall into disp_bitmask

; Display a bitmask in HL at column A (0 - 23)
;
; Returns with A pointing to next column
;
; Uses A, B, C, D, E
disp_bitmask        PUSH    AF
                    LD      B, DL_ADDRESS
                    CP      12
                    JP      C, _disp_left
                    LD      B, DR_ADDRESS
                    SUB     12
_disp_left          LD      E, A
                    CALL    i2c_start
                    LD      A, B
                    CALL    i2c_address_w
                    LD      A, E
                    SLA     A
                    CALL    i2c_write
                    LD      A, L
                    CALL    i2c_write
                    LD      A, H
                    CALL    i2c_write
                    CALL    i2c_stop
                    POP     AF
                    INC     A
                    RET


                    JP      disp_bitmask
;
; Clear the display and show an inline string from column 0
;
disp_clear_inline   CALL    disp_clear
                    XOR     A
;
; Display an inline string to column A->
;
disp_inline         EX      (SP), HL
                    CALL    disp_string
                    INC     HL
                    EX      (SP), HL
                    RET

; Display a string pointed to by HL to column A->
; Note string should be zero terminated...
; Returns with HL pointing to the 0 terminator
;
disp_string         LD      C, A
                    LD      A, (HL)
                    OR      A
                    JP      NZ, _char_ok
                    RET

_char_ok            PUSH    HL
                    CALL    disp_character
                    POP     HL
                    INC     HL
                    JR      disp_string

; Clear the display
;
disp_clear          LD      A, 0
                    LD      HL, 0
_clear_loop         CALL    disp_bitmask
                    CP      24
                    JP      NZ, _clear_loop
                    RET

                    .MODULE main