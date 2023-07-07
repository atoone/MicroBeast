;
; UART routines..
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
                    .MODULE     uart

;
; Baud rates, assuming 1.8432Mhz crystal
;
UART_9600           .EQU    12
UART_19200          .EQU    6
UART_38400          .EQU    3

UART_MODE_AUTO      .EQU    022h   ; Auto flow mode
UART_MODE_NO_FLOW   .EQU    000h   ; Auto RTS and CTS disabled
UART_MODE_DIAG      .EQU    030h   ; Loopback mode

;
; Various constants
;
UART_8N1            .EQU    003h
UART_TIMEOUT        .EQU    50000

_CTS_STATUS_MASK    .EQU    010h

;
; Set up the UART. Assume it has had time to settle after reset...
;
;
uart_init           LD      BC, UART_19200              ; B is flow control, 0 -> No auto flow control

                    IN      A,(UART_MODEM_STATUS)       ; If CTS is enabled, assume we can use flow control
                    AND     _CTS_STATUS_MASK
                    JR      Z, _no_listener

                    LD      B, UART_MODE_AUTO
                        
_no_listener        LD      A, 80h                      ; Divisor Latch Setting Mode
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
                    RET

;
; Send character in A to UART
; Preserves all registers
;
; Carry flag is set on return if the UART send succeeded, clear if it timed out
;
uart_send           PUSH    BC
                    PUSH    AF
                    LD      BC, UART_TIMEOUT
_check_ready        IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JP      NZ, _uart_ready             ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _check_ready

                    POP     AF
                    POP     BC
                    SCF
                    CCF
                    RET

_uart_ready         POP     AF
                    POP     BC
                    OUT     (UART_TX_RX), A
                    SCF
                    RET

;
; Check to see if there are any characters to receive
; Preserves all registers
;
; Returns with carry set if there are characters ready, clear if not
;
uart_ready          PUSH    AF
                    IN      A, (UART_LINE_STATUS)
                    BIT     0, A
                    JP      Z, _not_ready
                    POP     AF
                    SCF
                    RET

_not_ready          POP     AF
                    SCF
                    CCF
                    RET

;
; Receive a character from the UART in A
; 
; Returns with a character in A and the carry flag set. If no characters
; are available, returns with the carry flag clear.
;
uart_receive        IN      A, (UART_LINE_STATUS)
                    BIT     0, A
                    JP      Z, _no_character
                    IN      A, (UART_TX_RX)
                    SCF
                    RET

_no_character       SCF
                    CCF
                    RET

;
; Write A as a hex byte
; Overwrites A...
;
uart_hex            PUSH    AF
                    SRA     A
                    SRA     A
                    SRA     A
                    SRA     A
                    CALL    to_hex
                    CALL    uart_send
                    POP     AF
                    CALL    to_hex
                    JP      uart_send
;
; Returns the low nibble of A as a hex digit
;
to_hex              AND $0F      ;LOW NIBBLE ONLY
                    ADD A,$90
                    DAA 
                    ADC A,$40
                    DAA 
                    RET 
;
; Inline send. Sends the zero terminated string immediately following the call to this function to the UART.
;  e.g.             CALL    uart_inline
;                   .DB     "My text to send", 0
;                   <code continues after message...>
; Returns with Carry set if the string was successfully sent, otherwise, carry is clear.
;
; Uses A 
;
uart_inline         EX      (SP), HL
                    CALL    uart_string
                    JP      C, _inline_end      
_find_end           LD      A, (HL)             ; Get the current character  (Carry preserved)
                    INC     HL                  ; Point to next character    (Carry preserved)
                    AND     A                   ; Test if the current character was zero (Clears carry)
                    JP      NZ, _find_end       ; If it was, we're done, otherwise repeat
_inline_end         EX      (SP), HL
                    RET
;
; Send a zero terminated string pointed to by HL to the UART
;
; Returns with Carry Set if the string was sent sucessfully, clear otherwise
;                    
uart_string         LD      A,(HL)
                    INC     HL
                    AND     A
                    JP      Z, _string_end
                    CALL    uart_send
                    JP      C, uart_string
                    RET
_string_end         SCF
                    RET

                    .MODULE main