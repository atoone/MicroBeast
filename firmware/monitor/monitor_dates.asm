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

set_date            LD      A, (cursor_row)
                    ADD     A, 31
                    LD      (_set_date_row), A
                    LD      (_set_week_row), A
                    CALL    MBB_PRINT
                    .DB     CARRIAGE_RETURN, "Date YY/MM/DD", ESCAPE_CHAR, "K", ESCAPE_CHAR, "Y",
_set_date_row       .DB     0
                    .DB     31+6, 0
                    LD      HL, date_limits
                    CALL    get_date_time

                    LD      A, 1
_select_loop        LD      (day_of_week), A

                    CALL    MBB_PRINT
                    .DB     ESCAPE_CHAR, "Y", 
_set_week_row       .DB     0
                    .DB     31+16, 0

                    LD      A, (day_of_week)
                    LD      C, A
                    LD      HL, weekdays
                    CALL    print_word_c

_select_week        CALL    BIOS_CONIST
                    AND     A
                    JR      Z, _select_week
                    CALL    BIOS_CONIN
                    CALL    translate_cursors
                    
                    CP      KEY_UP
                    JR      NZ, _test_down
                    LD      A, (day_of_week)
                    CP      7
                    JR      Z, _select_week
                    INC     A
                    JR      _select_loop
_test_down          CP      KEY_DOWN
                    JR      NZ, _test_enter 
                    LD      A, (day_of_week)
                    CP      1
                    JR      Z, _select_week
                    DEC     A
                    JR      _select_loop
_test_enter         CP      KEY_ENTER
                    JR      NZ, _select_week

                    DI
                    LD      H, RTC_ADDRESS      
                    LD      L, RTC_REG_WKDAY
                    CALL    MBB_I2C_WR_ADDRESS
                    JP      NC, _clock_error

                    LD      HL, day_of_week
                    LD      A, (HL)
                    INC     HL

                    OR      RTC_WEEKDAY_RUNNING
                    CALL    MBB_I2C_WRITE
                    JP      NC, _clock_error

_write_date_loop    LD      B, (HL)
                    INC     HL

                    LD      A, (HL)
                    INC     HL
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A

                    OR      B
                    CP      0ffh
                    JP      Z, _start_clock
                    CALL    MBB_I2C_WRITE
                    JP      NC, _clock_error
                    JR      _write_date_loop

_start_clock        CALL    MBB_I2C_STOP
                    EI
                    RET

_clock_error        CALL    MBB_I2C_STOP
                    EI
                    CALL    MBB_PRINT
                    .DB     CARRIAGE_RETURN, "RTC Error", ESCAPE_CHAR, "K", 0
                    JP      BIOS_CONIN

set_time            LD      A, (cursor_row)
                    ADD     A, 31
                    LD      (_set_time_row), A
                    CALL    MBB_PRINT
                    .DB     CARRIAGE_RETURN, "Time HH/mm/ss", ESCAPE_CHAR, "K", ESCAPE_CHAR, "Y",
_set_time_row       .DB     0
                    .DB     31+6, 0
                    LD      HL, time_limits
                    CALL    get_date_time

                    LD      A, (digit_values+1)
                    OR      08h
                    LD      (digit_values+1), A
                    CALL    BIOS_CONIN

                    DI
                    LD      H, RTC_ADDRESS      
                    LD      L, RTC_REG_SEC
                    CALL    MBB_I2C_WR_ADDRESS
                    JP      NC, _clock_error

                    LD      HL, digit_values
                    JR      _write_date_loop
                    
time_limits         .DB     9,5,9,5,3,2

date_limits         .DB     1,3,2,1,9,9

day_of_week         .DB     1
digit_values        .DB     0,0,0,0,0,0
                    .DB     0FFh

get_date_time       LD      DE, digit_values
                    LD      BC, 6
                    LDIR
                    DEC     HL
                    DEC     DE
                    LD      B, 6

_get_digit          PUSH    HL
                    PUSH    DE
                    PUSH    BC
                    CALL    BIOS_CONIN
                    POP     BC
                    POP     DE
                    POP     HL
                    SUB     '0'
                    JR      C, _get_digit
                    LD      C, A
                    LD      A, (DE)
                    LD      (_digit_compare+1),A
                    CP      C
                    JR      C, _get_digit

                    LD      A, C
                    LD      (DE), A
                    ADD     A,'0'
                    PUSH    DE
                    PUSH    HL
                    PUSH    BC
                    LD      C, A
                    CALL    BIOS_CONOUT
                    POP     BC
                    POP     HL
                    POP     DE

                    LD      A,(DE)
                    DEC     HL
                    DEC     DE
                    BIT     0, B
                    JR      NZ, _next_tuple
_digit_compare      CP      0
                    JR      Z, _next_digit
                    LD      A, 9
                    LD      (DE), A
_next_digit         DJNZ    _get_digit
                    RET
_next_tuple         CALL    MBB_PRINT
                    .DB     ESCAPE_CHAR, 'C', 0
                    JR      _next_digit