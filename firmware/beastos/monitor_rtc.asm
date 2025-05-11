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
                        .MODULE monitor_rtc

_offset_sec             .EQU    0
_offset_min             .EQU    1
_offset_hour            .EQU    2
_offset_wkday           .EQU    3
_offset_date            .EQU    4
_offset_month           .EQU    5
_offset_year            .EQU    6


rtc_display_time        LD      HL, time_scratch
                        CALL    rtc_get_time_hl
                        JP      NC, _get_error

                        LD      C, CARRIAGE_RETURN
                        CALL    bios_conout
                        
                        LD      A, (time_scratch+_offset_wkday)
                        LD      HL, weekdays
                        LD      C, A

                        CALL    _search_word
                        
_get_date               CALL    _space
                        LD      A, (time_scratch+_offset_date)
                        CALL    _two_chars_space

                        LD      A, (time_scratch+_offset_month)
                        LD      HL, _months
                        BIT     4, A
                        JR      Z, _month_ok
                        SUB     6
_month_ok               LD      C,A

                        CALL    _search_word
                        CALL    _space
                        LD      A, 20h
                        CALL    _two_chars

                        LD      A, (time_scratch+_offset_year)
                        CALL    _two_chars_space

                        LD      A, (time_scratch+_offset_hour)
                        CALL    _two_chars_space

                        LD      A, (time_scratch+_offset_min)
                        CALL    _two_chars_space

                        LD      A, (time_scratch+_offset_sec)
                        CALL    _two_chars
                        RET

_two_chars_space       CALL    _two_chars
_space                  LD      C, ' '
                        JP      bios_conout

_two_chars              LD      C,A
                        SRL     A
                        SRL     A
                        SRL     A
                        SRL     A
                        ADD     A, '0'
                        PUSH    BC
                        LD      C, A
                        CALL    bios_conout
                        POP     BC
                        LD      A,C
                        AND     0fh
                        ADD     A, '0'
                        LD      C, A
                        JP      bios_conout
;
; Search table pointed to by HL for the C'th word (1-based)
; Prints the chosen word to conout
;
_search_word            DEC     C
                        JR      NZ, _next_char
                        
_print_word             LD      A, (HL)
                        INC     HL
                        AND     A
                        RET     Z
                        LD      C, A
                        PUSH    HL
                        CALL    bios_conout
                        POP     HL
                        JR      _print_word

_next_char              LD      A, (HL)
                        INC     HL
                        AND     A
                        JR      NZ, _next_char
                        JR      _search_word


weekdays                .DB "Mon",0
                        .DB "Tue",0
                        .DB "Wed",0
                        .DB "Thu",0
                        .DB "Fri",0
                        .DB "Sat",0
                        .DB "Sun",0

_months                 .DB "Jan",0
                        .DB "Feb",0
                        .DB "Mar",0
                        .DB "Apr",0
                        .DB "May",0
                        .DB "Jun",0
                        .DB "Jul",0
                        .DB "Aug",0
                        .DB "Sep",0
                        .DB "Oct",0
                        .DB "Nov",0
                        .DB "Dec",0


_get_error              CALL    i2c_stop
                        CALL    m_print_inline 
                        .DB     "Error getting time\r\n", 0
                        XOR     A
                        RET

                        .MODULE main