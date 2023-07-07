; RTC Routines
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
                        .MODULE rtc
                        ;  Initial time on power up..
timestamp               .db  23h            ; Seconds
                        .db  59h            ; Minutes
                        .db  08h            ; Hours    (24 hr clock)
                        .db  06h            ; Weekday  (1-7. Monday=1)
                        .db  05h            ; Date
                        .db  11h            ; Month
                        .db  22h            ; Year 
                        .db  0ffh           ; 0ffh end marker

; Set the initial time and start the clock
;
;
rtc_reset               CALL    uart_inline
                        .DB     "Checking RTC\n\r",0

                        LD      H, RTC_ADDRESS
                        LD      L, RTC_REG_SEC      ; Read the seconds register
                        CALL    i2c_read_from
                        LD      E, A
                        JP      NC, rtc_ack_error
                        CALL    i2c_stop
                        CALL    _pause
                        BIT     7, E                ; Check to see if the clock is running
                        JR      Z, _do_reset        ; If not, reset the time

                        CALL    _check_ctrl         ; If it is, check that ctrl is set correctly
                        JP      NZ, _set_ctrl
                        RET

_do_reset               CALL    uart_inline
                        .DB     "Reset time\n\r",0

                        LD      H, RTC_ADDRESS      ; Clock isn't running, reset to default time
                        LD      L, RTC_REG_SEC
                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error

                        LD      HL, timestamp
_reset_loop             LD      A, (HL)
                        INC     HL
                        CP      0ffh
                        JP      Z, _start_clock
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        JR      _reset_loop

_start_clock            CALL    i2c_stop            ; Enable VBAT and start the clock

                        CALL    uart_inline
                        .DB     "Starting clock\n\r",0

                        LD      H, RTC_ADDRESS      ; Enable VBAT
                        LD      L, RTC_REG_WKDAY
                        CALL    i2c_read_from
                        JP      NC, rtc_ack_error
                        LD      E, A
                        CALL    i2c_stop
                        SET     3, E
                        CALL    _pause

                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error
                        LD      A, E
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        CALL    i2c_stop

                        LD      H, RTC_ADDRESS      ; Enable clock
                        LD      L, RTC_REG_SEC      ; Read the seconds register
                        CALL    i2c_read_from
                        JP      NC, rtc_ack_error
                        LD      E, A
                        CALL    i2c_stop
                        SET     7, E                ; Set bit 7 to enable clock
                        
                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error
                        LD      A, E
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        CALL    i2c_stop

_set_ctrl               LD      B, 4
_set_ctrl_loop          PUSH    BC
                        LD      H, RTC_ADDRESS      ; Set Coarse mode and Output Pin to Square wave - gives 64 Hz pulse
                        LD      L, RTC_REG_CTRL
                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error
                        LD      A, 044h
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        XOR     A
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        CALL    i2c_stop

                        CALL    _pause

                        CALL    _check_ctrl
                        POP     BC
                        RET     Z

                        CALL    uart_inline
                        .DB     "Reset trim\r\n",0
                        DJNZ    _set_ctrl_loop
                        RET

_pause                  LD      B, 0
                        DJNZ    $
                        RET

rtc_ack_error           CALL    i2c_stop
                        
                        CALL    uart_inline
                        .DB     "RTC Panic\n\r",0
                        LD      A, H
                        CALL    uart_hex
                        LD      A, L
                        CALL    uart_hex
                        JP      $

; Check that the control is set to coarse trim and 0 offset
; Returns with Zero flag set if settings are good.
;
_check_ctrl             LD      H, RTC_ADDRESS      
                        LD      L, RTC_REG_CTRL
                        CALL    i2c_read_from
                        JP      NC, rtc_ack_error
                        LD      E, A
                        CALL    i2c_ack
                        CALL    i2c_read
                        LD      D, A
                        CALL    i2c_stop
                        LD      A, E
                        LD      B, 4
                        CP      044h
                        RET     NZ
                        LD      A, D
                        AND     A
                        RET 

ack_error               .DB "RTC Ack error 0",0

;
;
; 00 - Second
; 01 - Minute
; 02 - Hour
; 03 - Wkday
; 04 - Date
; 05 - Month
; 06 - Year
;
_offset_sec             .EQU    0
_offset_min             .EQU    1
_offset_hour            .EQU    2
_offset_wkday           .EQU    3
_offset_date            .EQU    4
_offset_month           .EQU    5
_offset_year            .EQU    6

;
; Read the time into the temp_data area
; Returns with Carry SET if successful, else Carry CLEAR
;
rtc_get_time2           LD      H, RTC_ADDRESS
                        LD      L, RTC_REG_SEC
                        CALL    i2c_read_from
                        JR      NC, _get_error
                        LD      HL, temp_data
                        LD      B, 7
                        JR      _store_time2
_get_loop2              PUSH    BC
                        CALL    i2c_start
                        LD      A, RTC_ADDRESS  
                        CALL    i2c_address_r   
                        CALL    i2c_read
                        POP     BC
_store_time2            LD      (HL), A
                        CALL    i2c_stop
                        INC     HL
                        DJNZ    _get_loop2
                        SCF
                        RET

rtc_get_time            LD      H, RTC_ADDRESS
                        LD      L, RTC_REG_SEC
                        CALL    i2c_read_from
                        JR      NC, _get_error
                        LD      HL, temp_data
                        LD      B, 7
                        JR      _store_time
_get_loop               PUSH    BC 
                        CALL    i2c_ack
                        CALL    i2c_read
                        POP     BC
_store_time             LD      (HL), A
                        INC     HL
                        DJNZ    _get_loop
                        CALL    i2c_stop
                        SCF
                        RET

_get_error              CALL    i2c_stop
                        CALL    uart_inline 
                        .DB     "Error getting time\r\n", 0
                        XOR     A
                        RET

rtc_display_time        CALL    rtc_get_time
                        LD      DE, scratch_pad
                        LD      A, (temp_data+_offset_wkday)
                        LD      HL, _weekdays
                        AND     7
                        LD      C, A

                        CALL    _search_word
                        CALL    _copy_word
                        
_get_date               CALL    _space
                        LD      A, (temp_data+_offset_date)
                        AND     03Fh
                        CALL    _two_chars
                        CALL    _space

                        LD      A, (temp_data+_offset_month)
                        LD      HL, _months
                        AND     01fh
                        BIT     4, A
                        JR      Z, _month_ok
                        SUB     6
_month_ok               LD      C,A

                        CALL    _search_word
                        CALL    _copy_word
                        CALL    _space
                        LD      A, 20h
                        CALL    _two_chars

                        LD      A, (temp_data+_offset_year)
                        CALL    _two_chars
                        CALL    _space

                        LD      A, (temp_data+_offset_hour)
                        AND     03fh
                        CALL    _two_chars
                        CALL    _space

                        LD      A, (temp_data+_offset_min)
                        AND     07fh
                        CALL    _two_chars
                        CALL    _space

                        LD      A, (temp_data+_offset_sec)
                        AND     07fh
                        CALL    _two_chars
                        XOR     A
                        LD      (DE),A

                        LD      HL, scratch_pad
                        CALL    disp_string
                        RET

_space                  LD      A, ' '
                        LD      (DE), A
                        INC     DE
                        RET

_two_chars              LD      C,A
                        SRL     A
                        SRL     A
                        SRL     A
                        SRL     A
                        ADD     A, '0'
                        LD      (DE), A
                        INC     DE
                        LD      A,C
                        AND     0fh
                        ADD     A, '0'
                        LD      (DE), A
                        INC     DE
                        RET
;
; Search table pointed to by HL for the C'th word (1-based)
; Returns with HL pointing to the word indexed by C, where the first word has index 1
;
_search_word            DEC     C
                        RET     Z
_next_char              LD      A, (HL)
                        INC     HL
                        AND     A
                        JR      NZ, _next_char
                        JR      _search_word

;
; Copy from (DE) to (HL) until we encounter a 0
; Return with DE pointing to the next location, and HL pointing to the zero byte
;
_copy_word              LD      A, (HL)              ; HL -> Day of week string..
                        AND     A
                        RET     Z             
                        LD      (DE), A
                        INC     HL
                        INC     DE
                        JR      _copy_word

_weekdays               .DB "Mon",0
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

                        .MODULE main