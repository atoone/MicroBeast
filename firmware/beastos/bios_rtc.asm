; RTC Routines
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
;
                        .MODULE rtc

; Set the initial time and start the clock
;
;
rtc_init                CALL    m_print_inline
                        .DB     "\n\rCheck RTC",0

                        CALL    _read_seconds
                        CALL    _pause
                        BIT     7, E                ; Check to see if the clock is running
                        RET     NZ                  ; Return if it is..

_do_reset               CALL    m_print_inline
                        .DB     "\n\rReset RTC",0

                        LD      H, RTC_ADDRESS      ; Clock isn't running, reset to default time
                        LD      L, RTC_REG_SEC
                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error

                        LD      HL, time_scratch
_reset_loop             LD      A, (HL)
                        INC     HL
                        CP      0ffh
                        JP      Z, _start_clock
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        JR      _reset_loop

_start_clock            CALL    i2c_stop            ; Enable VBAT and start the clock

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

                        CALL    _read_seconds
                        SET     7, E                ; Set bit 7 to enable clock
                        
                        CALL    i2c_write_to
                        JP      NC, rtc_ack_error
                        LD      A, E
                        CALL    i2c_write
                        JP      NC, rtc_ack_error
                        CALL    i2c_stop
                        RET

_pause                  LD      B, 0
                        DJNZ    $
                        RET

;
; Read seconds register in E
;
_read_seconds           LD      H, RTC_ADDRESS      
                        LD      L, RTC_REG_SEC      
                        CALL    i2c_read_from
                        JP      NC, rtc_ack_error
                        LD      E, A
                        JP     i2c_stop

rtc_ack_error           CALL    i2c_stop
                        
                        CALL    m_print_inline
                        .DB     "\n\rRTC Panic",0
                        RET

                        ;  Initial time on power up..
time_scratch            .db  23h            ; Seconds
                        .db  59h            ; Minutes
                        .db  08h            ; Hours    (24 hr clock)
                        .db  06h            ; Weekday  (1-7. Monday=1)
                        .db  05h            ; Date
                        .db  11h            ; Month
                        .db  22h            ; Year 
                        .db  0ffh           ; 0ffh end marker

                        .MODULE main