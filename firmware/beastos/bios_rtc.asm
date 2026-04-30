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
rtc_init                CALL    MBB_PRINT
                        .DB     "\n\rCheck RTC",0

                        CALL    _read_seconds
                        CALL    _pause
                        BIT     7, E                ; Check to see if the clock is running
                        RET     NZ                  ; Return if it is..

_do_reset               CALL    MBB_PRINT
                        .DB     "\n\rReset RTC",0

                        LD      H, RTC_ADDRESS      ; Clock isn't running, reset to default time
                        LD      L, RTC_REG_SEC
                        CALL    MBB_I2C_WR_ADDRESS
                        JP      NC, rtc_ack_error

                        LD      HL, time_scratch
_reset_loop             LD      A, (HL)
                        INC     HL
                        CP      0ffh
                        JP      Z, _start_clock
                        CALL    MBB_I2C_WRITE
                        JP      NC, rtc_ack_error
                        JR      _reset_loop

_start_clock            CALL    MBB_I2C_STOP            ; Enable VBAT and start the clock

                        LD      H, RTC_ADDRESS      ; Enable VBAT
                        LD      L, RTC_REG_WKDAY
                        CALL    MBB_I2C_RD_ADDRESS
                        JP      NC, rtc_ack_error
                        LD      E, A
                        CALL    MBB_I2C_STOP
                        SET     3, E
                        CALL    _pause

                        CALL    MBB_I2C_WR_ADDRESS
                        JP      NC, rtc_ack_error
                        LD      A, E
                        CALL    MBB_I2C_WRITE
                        JP      NC, rtc_ack_error
                        CALL    MBB_I2C_STOP

                        CALL    _read_seconds
                        SET     7, E                ; Set bit 7 to enable clock
                        
                        CALL    MBB_I2C_WR_ADDRESS
                        JP      NC, rtc_ack_error
                        LD      A, E
                        CALL    MBB_I2C_WRITE
                        JP      NC, rtc_ack_error
                        CALL    MBB_I2C_STOP
                        RET

_pause                  LD      B, 0
                        DJNZ    $
                        RET

;
; Read seconds register in E
;
_read_seconds           LD      H, RTC_ADDRESS      
                        LD      L, RTC_REG_SEC      
                        CALL    MBB_I2C_RD_ADDRESS
                        JP      NC, rtc_ack_error
                        LD      E, A
                        JP      MBB_I2C_STOP

rtc_ack_error           CALL    MBB_I2C_STOP
                        
                        CALL    MBB_PRINT
                        .DB     "\n\rRTC Panic",0
                        RET

;
; Read the time to the 7 bytes starting at HL
; Returns with Carry SET if successful, else Carry CLEAR
;
rtc_get_time_hl         PUSH    HL
                        LD      H, RTC_ADDRESS
                        LD      L, RTC_REG_SEC
                        CALL    MBB_I2C_RD_ADDRESS
                        POP     BC
                        RET     NC
                        LD      HL, _masktable
                        JR      _store_time
_get_loop               PUSH    BC 
                        CALL    MBB_I2C_ACK
                        CALL    MBB_I2C_READ
                        POP     BC
_store_time             AND     (HL)
                        LD      (BC), A
                        INC     HL
                        INC     BC
                        LD      A, (HL)
                        AND     A
                        JR      NZ, _get_loop
                        CALL    MBB_I2C_STOP
                        SCF
                        RET

rtc_64Hz                LD      B, 4                ; Set RTC Coarse mode and Output Pin to Square wave - gives 64 Hz pulse
_set_ctrl_loop          PUSH    BC
                        LD      H, RTC_ADDRESS      
                        LD      L, RTC_REG_CTRL
                        CALL    MBB_I2C_WR_ADDRESS
                        JR      NC, _rtc_ack_error
                        LD      A, RTC_64HZ_ENABLED
                        CALL    MBB_I2C_WRITE
                        JR      NC, _rtc_ack_error
                        XOR     A
                        CALL    MBB_I2C_WRITE
_rtc_ack_error          CALL    MBB_I2C_STOP

                        LD      B, 0
                        DJNZ    $

                        CALL    _check_ctrl
                        POP     BC
                        RET     Z
                        DJNZ    _set_ctrl_loop
                        RET


; Check that the control is set to coarse trim and 0 offset
; Returns with Zero flag set if settings are good.
;
_check_ctrl             LD      H, RTC_ADDRESS      
                        LD      L, RTC_REG_CTRL
                        CALL    MBB_I2C_RD_ADDRESS
                        LD      D, 2
                        JR      NC, _ctrl_error
                        LD      E, A
                        CALL    MBB_I2C_ACK
                        CALL    MBB_I2C_READ
                        LD      D, A
                        CALL    MBB_I2C_STOP
                        LD      A, E
                        LD      B, 4
                        CP      RTC_64HZ_ENABLED
                        RET     NZ
_ctrl_error             LD      A, D
                        AND     A
                        RET 


_masktable              .db     07fh        ; Seconds
                        .db     07fh        ; Minutes
                        .db     03fh        ; Hours
                        .db     007h        ; Weekday
                        .db     03Fh        ; Date
                        .db     01fh        ; Month
                        .db     0ffh        ; Year
                        .db     000h        ; End of mask marker


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
