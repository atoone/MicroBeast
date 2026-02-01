;
; Boot sequence
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
                    .MODULE  boot_sequence
;
; TODO: PIO setup should happen after the initial beep. Do it here for now, until new boards are available.
;
                    LD      A, PIO_SET_INTERRUPT    ; Ports A/B Interrupt control - no interrupts
                    OUT     (PIO_A_CTRL), A         ; Set control twice in case a reset interrupted a control sequence
                    OUT     (PIO_A_CTRL), A
                    OUT     (PIO_B_CTRL), A
                    OUT     (PIO_B_CTRL), A

                    LD      A, PIO_MODE_3           ; Port A Mode 3 
                    OUT     (PIO_A_CTRL), A
                    LD      A, 0FFh                 ; All inputs
                    OUT     (PIO_A_CTRL), A


                    LD      A, PIO_MODE_3           ; Port B mode 3
                    OUT     (PIO_B_CTRL), A
                    LD      A, PORT_B_IOMASK        ; All inputs, apart from bit 4 (audio out)
                    OUT     (PIO_B_CTRL), A

                    LD     HL, 0E80h                ; Approx middle C
;
; Beep to show we've booted
;
_boot_beep          IN      A, (AUDIO_PORT)         ; Check the state of the audio port,,
                    LD      D, A                 
                    LD      E, 100                  ; 100 cycles = 1/3 of a sec
_beep_loop          LD      A, D
                    XOR     AUDIO_MASK
                    OUT     (AUDIO_PORT), A

                    LD      C, L
_beep_delay0        LD      B, H
_beep_delay1        DJNZ    _beep_delay1            ; 13 * (count-2) + 8
                    DEC     C
                    JR      NZ, _beep_delay0

                    LD      A, D
                    OUT     (AUDIO_PORT), A

                    LD      C, L
_beep_delay2        LD      B, H
_beep_delay3        DJNZ    _beep_delay3            ; 13 * (count-2) + 8
                    DEC     C
                    JR      NZ, _beep_delay2      

                    DEC     E
                    JR      NZ, _beep_loop

;
; Now initialise the UART
;
;
                    LD      BC, UART_19200 | (UART_MODE_NO_FLOW << 8)  ;;; TODO This is sooooo wrong - sets C (divisor) to 38 
                    LD      A, 80h                      ; Divisor Latch Setting Mode
                    OUT     (UART_LINE_CTRL), A         ;  - entered by writing 1 to bit 7 of LCR
                    NOP
                    NOP
                    LD      A, C
                    OUT     (UART_TX_RX), A
                    NOP
                    NOP
                    XOR     A
                    OUT     (UART_INT_ENABLE), A
                    NOP
                    NOP

                    LD      A, UART_8N1                 ; Set 8N1 and exit divisor latch setting mode
                    OUT     (UART_LINE_CTRL), A

                    LD      A, 07h                      ; Enable and clear FIFO registers
                    OUT     (UART_FIFO_CTRL), A

                    LD      A, B
                    AND     A
                    JR      Z, _no_flowcontrol

                    OUT     (UART_MODEM_CTRL), A

_no_flowcontrol     NOP
                    NOP

;
; Send 'OK' to UART
;
;
                    LD      BC, UART_TIMEOUT
_check_ready1       IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JR      NZ, _uart_ready1            ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready1

                    LD      HL, 07C0h                   ; #C1
                    JP      _boot_beep                  ; Beep again if we can't get ready on the UART

_uart_ready1        LD      A, 'O'
                    OUT     (UART_TX_RX), A
                    

                    LD      BC, UART_TIMEOUT
_check_ready2       IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JR      NZ, _uart_ready2             ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready2

                    LD      HL, 07C0h                   ; #C1
                    JP      _boot_beep                  ; Beep again if we can't get ready on the UART

_uart_ready2        LD      A, 'K'
                    OUT     (UART_TX_RX), A


                    LD      BC, UART_TIMEOUT
_check_ready3       IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JR      NZ, _uart_ready3             ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready3

                    LD      HL, 07C0h                   ; #C1
                    JP      _boot_beep                  ; Beep again if we can't get ready on the UART


_uart_ready3        LD      A, CARRIAGE_RETURN
                    OUT     (UART_TX_RX), A


                    LD      BC, UART_TIMEOUT
_check_ready4       IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JR      NZ, _uart_ready4             ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready4

                    LD      HL, 07C0h                   ; #C1
                    JP      _boot_beep                  ; Beep again if we can't get ready on the UART


_uart_ready4        LD      A, NEWLINE
                    OUT     (UART_TX_RX), A

                    NOP
                    NOP

                    LD      BC, UART_TIMEOUT            ; Make sure the character is sent before we re-initialise the UART later
_check_ready5       IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JR      NZ, _uart_ready5            ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready5

_uart_ready5
;
; Now enable RAM in page 3 and test
;
;
                    LD      A, ROM_PAGE_0
                    OUT     (IO_MEM_0), A           ; Page 0 is Flash 0
                    LD      A, RAM_PAGE_3
                    OUT     (IO_MEM_3), A           ; Page 3 is RAM 0

                    LD      A, IO_MEM_ENABLE
                    OUT     (IO_MEM_CTRL), A

                    LD      A, 37h                  ; Can we write and read a value from Page 3?
                    LD      (0FF02h), A

                    LD      A, (0FF02h)
                    LD      HL, 03E0h               ; #C2
                    CP      37h

                    JP      NZ, _boot_beep          ; Beep again if we don't see the value we've written
                    INC     A
                    LD      (0FF02h), A
                    LD      A, (0FF02h)
                    CP      38h

                    JP      NZ, _boot_beep

                    CALL    uart_init               ; Reinitialise the UART to make sure we've not missed anything
;
; Now check keys all read as un-pressed, apart from DELETE
;
                    LD      A, NORMAL_BOOT     ; Reset boot mode
                    LD      (boot_mode), A

                    LD      BC, 0F700h
_key_loop           IN      A, (C)
                    AND     03Fh
                    CP      03Fh
                    JP      Z, _key_ok

                    LD      L, A
                    LD      A, B
                    CP      0EFh
                    JP      Z, _delete_row

                    LD      H,B                 ; If it's not the delete row, the panic code is the row and key mask
                    JP      panic

_delete_row         LD      A, L
                    CP      02Fh                ; If it's the zero key, we need to skip boot opts.
                    JR      NZ, _not_zero_key

                    LD      A, SKIP_OPTS
                    LD      (boot_mode), A
                    JR      _key_ok

_not_zero_key       CP      01Fh                ; If it is the delete row and not the delete key, panic 0004
                    LD      HL, PANIC_0004
                    JP      NZ, panic

                    CALL    uart_inline
                    .DB     "Memory test\r\n", 0

                    CALL    mem_test_start

_key_ok             RRC     B
                    LD      A, B
                    CP      0F7h
                    JP      NZ, _key_loop

                    CALL    uart_inline
                    .DB     "Keyboard OK\r\n", 0

;
; At this stage we should have a working UART and memory.. we can start calling routines..
;
                    CALL    uart_inline
                    .DB     "MicroBeast starting...\n\r",0

                    JR      _continue

panic               CALL    uart_inline
                    .DB     "Panic\n\r",0
                    LD      A, H
                    CALL    uart_hex
                    LD      A, L
                    CALL    uart_hex
_beep               LD      DE, 0400h
                    LD      C, 5
                    CALL    play_note
                    LD      DE, 0506h
                    LD      C, 5
                    CALL    play_note
                    JR      _beep

_continue           CALL    init_portb
                    CALL    i2c_bus_reset
;
; Now: Port B should be all inputs, so D7 (i2c data) should be high
;                   
                    LD      B, 0ffh
                    DJNZ    $

                    IN      A, (PIO_B_DATA)
                    AND     I2C_DATA_MASK           ; TODO - No panic code
                    JR      Z, panic

                    CALL    i2c_sda_low             ; Set data low
                    IN      A, (PIO_B_DATA)
                    AND     I2C_DATA_MASK           ; TODO - No panic code
                    JR      NZ, panic

                    CALL    uart_inline
                    .DB     "Detected PIO\r\n",0

;
; All good, let's see what's on the bus...
;
                    CALL    i2c_bus_reset

                    CALL    i2c_start
                    LD      A, DL_ADDRESS
                    CALL    i2c_address_w
                    LD      HL, PANIC_0001
                    JR      NC, panic
                    CALL    i2c_stop

                    CALL    uart_inline
                    .DB     "Detected Display 1/2\r\n", 0

                    CALL    i2c_start
                    LD      A, DR_ADDRESS
                    CALL    i2c_address_w
                    LD      HL, PANIC_0002
                    JP      NC, panic
                    CALL    i2c_stop

                    CALL    uart_inline
                    .DB     "Detected Display 2/2\r\n", 0

                    CALL    i2c_start
                    LD      A, RTC_ADDRESS
                    CALL    i2c_address_w
                    LD      HL, PANIC_0003
                    JP      NC, panic
                    CALL    i2c_stop

                    CALL    uart_inline
                    .DB     "Detected RTC\r\n", 0

                    .MODULE main