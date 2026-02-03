;
; SETOPTS - Set MicroBeast Boot Options
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
; Command line: SETOPTS
;
; Prompts user to change current Boot options. Press enter to accept current value, Y or N to change
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/bios.inc"

;
; RTC Opts include uses system labels for i2c routines, so EQUate these to the matching BIOS jump table entries
;
i2c_read_from           .EQU    MBB_I2C_RD_ADDRESS
i2c_read                .EQU    MBB_I2C_READ
i2c_write_to            .EQU    MBB_I2C_WR_ADDRESS
i2c_write               .EQU    MBB_I2C_WRITE
i2c_ack                 .EQU    MBB_I2C_ACK
i2c_stop                .EQU    MBB_I2C_STOP

; Boot options
BOOT_TO_CPM             .EQU    001h
BOOT_NO_LED             .EQU    002h
BOOT_RESTORE_B          .EQU    004h
BOOT_TTY_INPUT          .EQU    008h

                        LD      (old_stack), SP
                        LD      SP, old_stack

                        LD      DE, welcome_message
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

                        CALL    _wait_key

                        DI
                        CALL    rtc_get_opts
                        EI
                        LD      (current_opts), A


                        LD      DE, boot_cpm
                        LD      A, BOOT_TO_CPM
                        CALL    update_opt

                        LD      DE, disable_led
                        LD      A, BOOT_NO_LED
                        CALL    update_opt

                        LD      DE, restore_b
                        LD      A, BOOT_RESTORE_B
                        CALL    update_opt

                        LD      DE, tty_input
                        LD      A, BOOT_TTY_INPUT
                        CALL    update_opt

                        LD      A, (current_opts)
                        DI
                        CALL    rtc_set_opts
                        EI

                        LD      DE, updated_message
                        JR      C,  _exit_message
                        LD      DE, failed_message

_exit_message           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

_finish                 LD      SP, (old_stack)
                        RET

; Update a single option. 
; Enter with DE = Message to display
;             A = Mask for option bit
; Returns with (current_opts) updated as required
;                        
update_opt              LD      (opt_mask), A
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
                        LD      A, (opt_mask)
                        LD      L, A
                        LD      A, (current_opts)
                        AND     L
                        LD      DE, default_no
                        JR      Z, _show_default
                        LD      DE, default_yes
_show_default           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

_get_update             CALL    _wait_key
                        CP      13
                        RET     Z

                        CP      'y'
                        JR      Z, _set_opt
                        CP      'n'
                        JR      Z, _clear_opt
                        JR      _get_update

_set_opt                LD      A, (opt_mask)
                        LD      L, A
                        LD      A, (current_opts)
                        OR      L
                        LD      (current_opts), A
                        LD      DE, select_yes
_print_and_return       LD      C, BDOS_PRINTSTRING
                        JP      BDOS

_clear_opt              LD      A, (opt_mask)
                        CPL
                        LD      L, A
                        LD      A, (current_opts)
                        AND     L
                        LD      (current_opts), A
                        LD      DE, select_no
                        JR      _print_and_return

_wait_key               LD      E, 0FFh             ; Wait for a key without echoing it
                        LD      C, BDOS_CONIO
                        CALL    BDOS
                        AND     A
                        JR      Z, _wait_key
                        RET  

                        .INCLUDE  "ports.asm"
                        .INCLUDE  "rtc_options.asm"

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0

current_opts            .DB     0
opt_mask                .DB     0

welcome_message         .DB     "SETOPTS: Boot Options$"

boot_cpm                .DB     "\n\r\n\rBoot to CP/M?     $"
disable_led             .DB         "\n\rLED Off?          $"
restore_b               .DB         "\n\rRestore Drive B?  $"
tty_input               .DB         "\n\rSerial/TTY input? $"

updated_message         .DB     "\n\r\n\rBoot options updated$"
failed_message          .DB     "\n\r\n\rError writing options$"

default_yes             .DB     "(Y) $"
default_no              .DB     "(N) $"

select_yes              .DB     "Y$"
select_no               .DB     "N$"

                        .END
