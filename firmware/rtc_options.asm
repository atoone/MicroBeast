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
                        CALL    MBB_I2C_RD_ADDRESS
                        JR      NC, _rtc_no_opt

                        LD      HL, rtc_opt_bytes               ; We're comparing against these bytes, until we reach 0.
_rtc_opt_check          CP      (HL)
                        JR      NZ, _rtc_no_opt
                        INC     HL
                        LD      A, (HL)
                        AND     A
                        JR      Z, _rtc_check_done
                        CALL    MBB_I2C_ACK
                        CALL    MBB_I2C_READ
                        JR      _rtc_opt_check
                        
_rtc_check_done         CALL    MBB_I2C_ACK                         
                        CALL    MBB_I2C_READ
                        LD      E, A

_rtc_no_opt             CALL    MBB_I2C_STOP
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
                        CALL    MBB_I2C_WR_ADDRESS
                        JP      NC, _write_error

                        LD      HL, rtc_opt_scratch
_write_loop             LD      A, (HL)
                        INC     HL
                        CP      0ffh
                        JP      Z, _rtc_opts_written
                        CALL    MBB_I2C_WRITE
                        JP      NC, _write_error
                        JR      _write_loop

_rtc_opts_written       CALL    MBB_I2C_STOP
                        SCF
                        RET

_write_error            CALL    MBB_I2C_STOP
                        AND     A
                        RET

rtc_opt_scratch         .DB     "OPT"
rtc_opt_value           .DB     0, 0ffh
