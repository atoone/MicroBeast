;
; Get RTC Boot options. 
; Options are 4 bytes stored at RTC SRAM addresses 0x20..0x23
; First three bytes are the characters 'OPT', in order. 
; If these are not set, assume no options have been stored and return zero.
; Otherwise, return option byte at 0x23 in A
;
; Note interrupts should be disabled before calling
;
rtc_get_opts            LD      H, RTC_ADDRESS
                        LD      L, RTC_SRAM_OPT                 ; We're reading from the options RAM address
                        LD      E, 0                            ; Default return result
                        CALL    i2c_read_from
                        JR      NC, _rtc_no_opt

                        LD      HL, rtc_opt_bytes               ; We're comparing against these bytes, until we reach 0.
_rtc_opt_check          CP      (HL)
                        JR      NZ, _rtc_no_opt
                        INC     HL
                        LD      A, (HL)
                        AND     A
                        JR      Z, _rtc_check_done
                        CALL    i2c_ack
                        CALL    i2c_read
                        JR      _rtc_opt_check
                        
_rtc_check_done         CALL    i2c_ack                         
                        CALL    i2c_read
                        LD      E, A

_rtc_no_opt             CALL    i2c_stop
                        LD      A, E
                        RET

rtc_opt_bytes           .DB     "OPT", 0

;
; Set RTC Boot Options.
; Enter with A = Option flags
; Returns with Carry SET if options were written OK
;
; Note interrupts should be disabled before calling
;
rtc_set_opts            LD      (rtc_opt_value),A
                        LD      H, RTC_ADDRESS      
                        LD      L, RTC_SRAM_OPT
                        CALL    i2c_write_to
                        JP      NC, _write_error

                        LD      HL, rtc_opt_scratch
_write_loop             LD      A, (HL)
                        INC     HL
                        CP      0ffh
                        JP      Z, _rtc_opts_written
                        CALL    i2c_write
                        JP      NC, _write_error
                        JR      _write_loop

_rtc_opts_written       CALL    i2c_stop
                        SCF
                        RET

_write_error            CALL    i2c_stop
                        AND     A
                        RET

rtc_opt_scratch         .DB     "OPT"
rtc_opt_value           .DB     0, 0ffh
