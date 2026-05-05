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


LCD_COMMAND         .EQU    40h
LCD_DATA            .EQU    41h


LCD_DO_RESET        .EQU    0E2h
LCD_DO_NOP          .EQU    0E3h

LCD_DO_MODE_SET     .EQU    0F1h
LCD_DO_QTR_DUTY     .EQU    0ACh
LCD_DO_MODE_END     .EQU    0F0h

LCD_DO_POWER        .EQU    028h
LCD_POWER_BOOSTER   .EQU    004h
LCD_POWER_REG       .EQU    002h
LCD_POWER_FOLLOW    .EQU    001h

LCD_DO_POWER_ALL    .EQU    LCD_DO_POWER | LCD_POWER_BOOSTER | LCD_POWER_REG | LCD_POWER_FOLLOW

LCD_DO_PAGE_SET     .EQU    0B0h
LCD_DO_COLUMN_HI    .EQU    010h        ; D2-D0 = Upper three bits
LCD_DO_COLUMN_LO    .EQU    000h        ; D3-D0 = Lower four bits

LCD_DO_MODE_NORMAL  .EQU    0A4h        ; Normal mode
LCD_DO_MODE_ALL     .EQU    0A5h        ; Show all pixels

LCD_DO_MODE_POS     .EQU    0A6h        ; 
LCD_DO_MODE_NEG     .EQU    0A7h        ; Reverse

LCD_DO_DISPLAY_ON   .EQU    0AFh        ; Display on
LCD_DO_DISPLAY_OFF  .EQU    0AEh        ; Display off

LCD_DO_SEG_DIR      .EQU    0A0h        ; Segment direction
LCD_DO_COMMON_DIR   .EQU    0C0h        ; Common direction     

LCD_NO_COMMAND      .EQU    0FFh

display_init        LD      A, (display_detect)
                    AND     DISPLAY_LCD
                    CALL    NZ, lcd_reset

                    CALL    disp_clear
                    LD      E, DISP_DEFAULT_BRIGHTNESS
                    CALL    disp_brightness

                    LD      A, (display_detect)
                    AND     DISPLAY_LED
                    RET     Z

                    CALL    _disp_select_l
                    CALL    _disp_config

                    CALL    _disp_select_r
                    CALL    _disp_config

_disp_select_l      LD      A, DL_ADDRESS
                    LD      (display_address), A
                    RET

_disp_select_r      LD      A, DR_ADDRESS
                    LD      (display_address), A
                    RET

_disp_config        LD      L, CONFIG_PAGE
                    CALL    disp_page
                    LD      A, (display_address)
                    LD      H, A
                    LD      L, 0
                    CALL    MBB_I2C_WR_ADDRESS
                    LD      A, 011h         ; Turn display on *Change to higher frequency switching to reduce board noise
                    CALL    MBB_I2C_WRITE
                    LD      A, 078h         ; 0.020mA
                    CALL    MBB_I2C_WRITE
                    JP      MBB_I2C_STOP

lcd_reset           LD      B, 4
_reset_loop         LD      A, LCD_DO_RESET
                    OUT     (LCD_COMMAND), A       
                    CALL    _pause
                    CALL    _pause
                    CALL    _pause

lcd_init            LD      HL, _reset_list
_init_loop          LD      A,(HL)
                    INC     HL
                    CP      LCD_NO_COMMAND
                    JR      Z, _lcd_done

                    OUT     (LCD_COMMAND), A
                    CALL    _pause
                    JR      _init_loop

_lcd_done           IN      A, (LCD_DATA)
                    AND     A
                    RET     Z
                    DJNZ    _reset_loop
                    RET

_pause              PUSH    BC
                    LD      BC, 0

_pause_loop         DJNZ    _pause_loop   
                    DEC     C
                    JR      NZ, _pause_loop

                    POP     BC
                    RET        

_reset_list         .DB LCD_DO_POWER_ALL
                    .DB LCD_DO_PAGE_SET          ; Set page address
                    .DB LCD_DO_COLUMN_HI
                    .DB LCD_DO_COLUMN_LO
                    .DB LCD_DO_MODE_SET          ; Set quarter duty
                    .DB LCD_DO_QTR_DUTY
                    .DB LCD_DO_MODE_END
                    .DB LCD_DO_MODE_NORMAL
                    .DB LCD_DO_DISPLAY_ON
                    .DB LCD_DO_SEG_DIR
                    .DB LCD_DO_COMMON_DIR
                    .DB LCD_NO_COMMAND
;
; Sets the brightness for the display
; Enter with E set to the desired brightness for all segments
;
disp_brightness     LD      A, (display_detect)
                    AND     DISPLAY_LED
                    RET     Z

                    CALL    _disp_select_l
                    CALL    _set_bright
                    CALL    _disp_select_r
_set_bright         LD      L, BRIGHT_PAGE
                    CALL    disp_page
                    LD      L, 12
_bright_loop        PUSH    HL
                    LD      A, (display_address)
                    LD      H, A
                    DEC     L
                    SLA     L
                    SLA     L
                    SLA     L
                    SLA     L
                    CALL    MBB_I2C_WR_ADDRESS
                    POP     HL
                    LD      H, 010h
_bright_byte        LD      A, E
                    CALL    MBB_I2C_WRITE
                    DEC     H
                    JR      NZ, _bright_byte
                    CALL    MBB_I2C_STOP
                    DEC     L
                    JR      NZ, _bright_loop
                    LD      L, LED_PAGE
                    CALL    disp_page
                    RET

; Set the Page number
; Call with page number in L
;
; Uses A, B, C, D
disp_page           PUSH    HL
                    CALL    disp_unlock 
                    LD      A, (display_address)
                    LD      H, A
                    LD      L, 0FDh
                    CALL    MBB_I2C_WR_ADDRESS
                    POP     HL
                    LD      A, L
                    CALL    MBB_I2C_WRITE
                    JP      MBB_I2C_STOP

disp_unlock         LD      A, (display_address)
                    LD      H, A
                    LD      L, DISP_REG_CRWL
                    CALL    MBB_I2C_WR_ADDRESS
                    LD      A, DISP_UNLOCK
                    CALL    MBB_I2C_WRITE
                    JP      MBB_I2C_STOP

; Set the character at column A to brightness C
;
;
disp_char_bright    PUSH    BC
                    LD      B, A

                    LD      A, (display_detect)
                    AND     DISPLAY_LED
                    JR      NZ, _set_bright_ok
                    POP     BC
                    RET

_set_bright_ok      LD      A, B
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

                    LD      A, (display_address)
                    LD      H, A
                    LD      L, E
                    SLA     L
                    SLA     L
                    SLA     L
                    SLA     L
                    CALL    MBB_I2C_WR_ADDRESS
                    POP     HL
                    LD      H, 010h
_bright_char_loop   LD      A, L
                    CALL    MBB_I2C_WRITE
                    DEC     H
                    JR      NZ, _bright_char_loop
                    CALL    MBB_I2C_STOP

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
                    LD      B, A

                    LD      A, (display_detect)
                    AND     DISPLAY_LCD
                    CALL    NZ, lcd_bitmask
                    LD      A, (display_detect)
                    AND     DISPLAY_LED
                    JR      Z, _no_led

                    LD      A, B
                    PUSH    HL
                    LD      H, DL_ADDRESS
                    CP      12
                    JP      C, _disp_left
                    LD      H, DR_ADDRESS
                    SUB     12
_disp_left          LD      L, A
                    SLA     L
                    CALL    MBB_I2C_WR_ADDRESS
                    POP     HL
                    LD      A, L
                    CALL    MBB_I2C_WRITE
                    LD      A, H
                    CALL    MBB_I2C_WRITE
                    CALL    MBB_I2C_STOP
_no_led             POP     AF
                    INC     A
                    RET

; Display a bitmask in HL at column A (0 - 23)
;
; Returns with A pointing to next column, preserves HL
;
; Uses C
lcd_bitmask         LD      C, A
                    LD      A, LCD_DO_PAGE_SET          ; Set page address

                    OUT     (LCD_COMMAND), A

                    LD      A, C
                    SRL     A
                    SRL     A
                    AND     07h
                    OR      LCD_DO_COLUMN_HI

                    OUT     (LCD_COMMAND), A

                    LD      A, C
                    SLA     A
                    SLA     A
                    AND     0Ch
                    OR      LCD_DO_COLUMN_LO

                    OUT     (LCD_COMMAND), A

                    INC     C

                    LD      A, L
                    OUT     (NIO_LCD_LOWER), A
                    LD      A, H
                    OUT     (NIO_LCD_UPPER), A

                    IN      A, (NIO_LCD_LOWER)
                    CALL    _do_byte
                    IN      A, (NIO_LCD_UPPER)

_do_byte            OUT     (LCD_DATA), A

                    SRL     A
                    SRL     A
                    SRL     A
                    SRL     A
                    OUT     (LCD_DATA), A
                    LD      A, C
                    RET

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