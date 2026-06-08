;
; LED - LED control utility. Controls Zorkulator backlight and LEDs
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
; Command line: LED <a|b|d> <NN>
;
; Controls LED output, where
;   <a|b|d> is an optional parameter to select LED  A (green), B (red) or D (backlight)
;           If not supplied, the backlight is controlled
; 
;   <NN> is an optional percentage brightness, where 0 is off and 100 is full brightness.
;
; If no percentage is given, allows the backlight to be set with 'u' and 'd'
;
;

                    .ORG    0100h

                    .INCLUDE "beastos/beastos.inc"

CMD_LEN             .EQU    00080h
CMD_START           .EQU    00081h

                    LD      (old_stack), SP
                    LD      SP, old_stack

                    LD      A, (CMD_LEN)
                    OR      A
                    JR      Z, start_control

                    LD      D, 0

                    LD      B, A
                    LD      HL, CMD_START

_strip_spaces       LD      A, (HL)
                    CP      ' '
                    JR      NZ, _param_ready

                    INC     HL                    
                    DJNZ    _strip_spaces
                    JR      start_control

_param_ready        CP      'a'
                    JR      C, _param_in_range
                    CP      'e'
                    JR      NC, _param_error

                    XOR     020h
_param_in_range     CP      'A'
                    JR      C, _param_loop
                    CP      'E'
                    JR      NC, _param_error

                    SUB     'A'
                    LD      (led_index), A

                    INC     HL
                    DJNZ    _strip_spaces
                    JR      start_control

_param_loop         LD      A, D
                    CP      11
                    JR      NC, _param_error

                    ADD     A, A
                    ADD     A, A
                    ADD     A, D
                    ADD     A, A
                    LD      D, A

                    LD      A, (HL)
                    INC     HL
                    SUB     '0'
                    JR      C, _param_error

                    CP      10
                    JR      NC, _param_error
                    ADD     A, D
                    LD      D, A
                    DJNZ    _param_loop

                    CP      101
                    JR      NC, _param_error

                    LD      (brightness), A
                    LD      (user_set), A
                    JR      start_control

_param_error        CALL    MBB_PRINT
                    .DB     "\r\nUse LED <A|B|C|D> <pct>",0
                    JP      _restore

start_control       CALL    read_led_state

                    LD      H, BL_ADDRESS      
                    LD      L, BL_REG_MODE1
                    LD      E, BL_SET_WAKE

                    CALL    write_backlight

write_brightness    LD      A, (brightness)
                    AND     A
                    JR      NZ, _set_bright

                    LD      H, BL_ADDRESS      
                    LD      L, BL_REG_LEDOUT
                    LD      E, BL_SET_LED0_FULL
                    LD      A, (led_index)
                    CP      03
                    JR      Z, _full_ok

                    LD      E, BL_SET_LED0_OFF

_full_ok            CALL    adjust_e

                    CALL    write_backlight
                    JR      _display_setting

_set_bright         LD      H, BL_ADDRESS      
                    LD      L, BL_REG_LEDOUT
                    LD      E, BL_SET_LED0_PWM

                    CALL    adjust_e

                    CALL    write_backlight
                    
                    LD      H, BL_ADDRESS      
                    LD      A, (led_index)
                    ADD     A, BL_REG_LED0
                    LD      L, A
                    CP      BL_REG_LED3

                    LD      A, (brightness)
                    LD      E, A

                    JR      NZ, _bright_dbl
                    NEG
                    LD      E, A
                    JR      _bright_ok

_bright_dbl         SLA     E

_bright_ok          CALL    write_backlight

_display_setting    LD     A, (led_index)
                    CP     3
                    JR     NZ, _show_letter
                    
                    CALL    MBB_PRINT
                    .DB     "\rLCD  : ", 0
                    JR      _show_percent

_show_letter        ADD     A, 'A'
                    LD      (_letter), A

                    CALL    MBB_PRINT
                    .DB     "\rLED "
_letter             .DB     "-: ", 0

_show_percent       LD      A, (brightness)

                    LD      HL, _percent
                    CALL    byte_to_dec

                    CALL    MBB_PRINT
_percent            .DB     "   %",0

                    LD      A, (brightness)
                    LD      B, A
                    CALL    div_five
                    LD      C, A
                    CALL    show_bar

                    LD      A, (user_set)
                    INC     A
                    JR      NZ, _finish

                    XOR     A
                    LD      (escape), A

_wait_key           LD      E, 0FFh
                    LD      C, BDOS_CONIO
                    CALL    BDOS
                    AND     A
                    JR      Z, _wait_key

                    CP      1Bh                 ; Escape
                    JR      NZ, _not_escape

                    LD      (escape), A         ; Set escape flag and read next character
                    JR      _wait_key

_not_escape         LD      C, A
                    LD      A, (escape)
                    AND     A
                    LD      A, C
                    JR      Z, _normal_key

                    CP      'A'                 ; Cursor up
                    JR      Z, _increase
                    CP      'C'                 ; Cursor right
                    JR      Z, _increase

                    CP      'B'
                    JR      Z, _decrease
                    CP      'D'
                    JR      Z, _decrease
                    JR      _finish

_normal_key         CP      'u'
                    JR      Z, _increase
                    CP      129
                    JR      NZ, _not_up

_increase           LD      A, (brightness)
                    CP      100
                    JR      Z, _wait_key

                    INC     A
_write_loop         LD      (brightness), A
                    JP      write_brightness

_not_up             CP      'd'
                    JR      Z, _decrease
                    CP      130
                    JR      NZ, _finish

_decrease           LD      A, (brightness)
                    AND     A
                    JR      Z, _wait_key

                    DEC     A
                    JR      _write_loop

_finish             CALL    MBB_PRINT
                    .DB     "\r\n-------------------------"
                    .DB     "\r                         ",0

_restore            LD      SP, (old_stack)
                    RET

write_backlight     CALL    MBB_I2C_WR_ADDRESS
                    JR      NC, _bl_ack_error
                    LD      A, E
                    CALL    MBB_I2C_WRITE
                    JP      NC, _bl_ack_error
                    JP      MBB_I2C_STOP

_bl_ack_error       CALL    MBB_PRINT
                    .DB     "\r\nNo LED found", 0
                    JR      _restore

adjust_e            LD      A, (led_index)
                    LD      D, 0FCh             ; Our bitmask
                    JR      _start_shift

_shift_loop         RLC     D
                    RLC     D

                    SLA     E
                    SLA     E
_start_shift        DEC     A
                    JP      P, _shift_loop

                    LD      A, (led_state)
                    AND     D
                    OR      E
                    LD      E, A
                    RET


read_led_state      LD      H, BL_ADDRESS
                    LD      L, BL_REG_LEDOUT
                    CALL    MBB_I2C_RD_ADDRESS
                    JR      NC, _bl_ack_error
                    LD      (led_state), A
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

brightness          .DB     50          ; 0 (off) to 100
escape              .DB     0           ; Escape flag for reading input. Zero for no escape
user_set            .DB     0FFh        ; Set to ffh if no parameter was supplied
led_index           .DB     3           ; Default is LCD backlight
led_state           .DB     0

stack_space         .BLOCK  32          ; 16 deep stack..
old_stack           .DW     0

;
; Backlight module
;
BL_ADDRESS              .EQU    062h
BL_REG_MODE1            .EQU    000h

BL_SET_WAKE             .EQU    001h    ; Mode 1 value to wake the oscillator (default on startup is off)

BL_REG_MODE2            .EQU    001h

BL_SET_OPEN_DRAIN       .EQU    000h    ; Mode 2 value for open drain outputs

BL_REG_LED0             .EQU    002h
BL_REG_LED1             .EQU    003h
BL_REG_LED2             .EQU    004h
BL_REG_LED3             .EQU    005h

BL_REG_LEDOUT           .EQU    008h

BL_SET_LED0_OFF         .EQU    000h
BL_SET_LED0_FULL        .EQU    001h
BL_SET_LED0_PWM         .EQU    002h
BL_SET_LED0_GROUP       .EQU    003h

BL_SET_LED1_OFF         .EQU    000h
BL_SET_LED1_FULL        .EQU    004h
BL_SET_LED1_PWM         .EQU    008h
BL_SET_LED1_GROUP       .EQU    00Ch

BL_SET_LED2_OFF         .EQU    000h
BL_SET_LED2_FULL        .EQU    010h
BL_SET_LED2_PWM         .EQU    020h
BL_SET_LED2_GROUP       .EQU    030h

BL_SET_LED3_OFF         .EQU    000h
BL_SET_LED3_FULL        .EQU    040h
BL_SET_LED3_PWM         .EQU    080h
BL_SET_LED3_GROUP       .EQU    0C0h

                    .END

