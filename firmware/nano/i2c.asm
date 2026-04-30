; ============================================ I2C Routines =================================================
; Software driven I2C for Nanobeast IO
;
; Uses NIO Port B
;
; Port B (A0 = 1) - Port B supports I2C
;
;                      D7     D6     D5     D4     D3     D2     D1     D0
;
; CTRL (A1 = 1) RD     SDA   EXT   RTC_EN UART_EN INTR_EN   0     0     SCL
;               WR     SDA    -      -      -      -        0     0     SCL    - On write, if D2,1 = 00, writes I2C data
;
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
                    .MODULE ni2c_nio

init_ni2c           LD      A, NI2C_DATA_MASK | NI2C_CLK_MASK | NI2C_REGISTER  ; Clock and data both high/floating
                    OUT     (NIO_B_CTRL), A         ; 
                    LD      (nio_i2c_data), A
                    ; Fall through into Bus reset

; Reset the bus
;
; Uses A, B, D
ni2c_bus_reset      LD      B, 0ah          ; ten cycles
_loop_b             CALL    ni2c_scl_cycle
                    DJNZ    _loop_b
                    CALL    ni2c_scl_high
                    LD      B, 0F0h
                    DJNZ    $
                    RET

;
; Uses A
ni2c_start          CALL    ni2c_sda_high
                    CALL    ni2c_scl_high
                    CALL    ni2c_sda_low     ; Drive data low
                    JP      ni2c_scl_low     ; Drive clock low


;
; Read a byte from Device address H, Register L into A
; Calls nni2c_start, sets address, reads byte and then calls nni2c_stop
; Returns With Carry SET and A containing the register value, or Carry CLEAR if no acknowledge
; Uses A, B, C, D, H, L
; Preserves H, L
ni2c_read_byte      CALL    ni2c_read_from
                    ; Fall through into stop
                
;
; Uses A
ni2c_stop           CALL    ni2c_sda_low     ; Drive data low
                    CALL    ni2c_scl_high
                    JP      ni2c_sda_high

; Write a byte in C to Device address H, register L
; Returns with Carry SET if OK, CLEAR if no acknowledgement
; Calls ni2c_stop when done..
;
; Preserves H, L
ni2c_write_byte     PUSH    BC
                    CALL    ni2c_write_to
                    POP     BC
                    JP      NC, ni2c_stop
                    LD      A, C
                    CALL    ni2c_write
                    JR      ni2c_stop
                    
;
; Read a byte from Device address H, Register L
; Calls ni2c_start, but does NOT call ni2c_stop
; Returns With Carry SET and A containing the register value, or Carry CLEAR if no acknowledge
; Uses A, B, C, D, H, L
; Preserves H, L
ni2c_read_from      CALL    ni2c_start
                    LD      A, H
                    CALL    ni2c_address_w
                    JR      NC, _read_end
                    LD      A, L
                    CALL    ni2c_write
                    JR      NC, _read_end
                    LD      B, 50
_read_pause         DJNZ    _read_pause
                    CALL    ni2c_start
                    LD      A, H
                    CALL    ni2c_address_r
                    JR      NC, _read_end
                    CALL    ni2c_read
                    SCF
_read_end           RET


;
; Prepare to write to Device address H, Register L
; Calls ni2c_start, but does NOT call ni2c_stop
; Returns with Carry SET if OK, CLEAR if no acknowledgement
;
; Preserves H, L
ni2c_write_to       CALL    ni2c_start
                    LD      A, H
                    CALL    ni2c_address_w
                    RET     NC
                    LD      A, L
                    JR      ni2c_write

; Start reading from device address held in A
;
; Uses A, B, C, D
ni2c_address_r      SLA     A
                    OR      1
                    JR      ni2c_write

; Start writing to device address held in A
;
; Uses A, B, C, D
ni2c_address_w       SLA     A

; Write A as a byte to i2c bus
; Returns Carry CLEAR if no acknowledge
;
; Uses A, B, C, D
ni2c_write          CALL    ni2c_send_byte
                    BIT     NI2C_DATA_BIT, D     ; D contains acknowledge bit
                    SCF
                    RET     Z               ; Return with carry set if acknowledge bit is low

                    CALL    ni2c_stop        ; Stop bus if error
                    SCF
                    CCF
                    RET                     ; Clear carry if acknowledge is high

; Read byte from i2C into A, without ACK
;
; Uses A, B, C, D
ni2c_read           LD      B, 8h
_loop_r             IN      A, (NIO_B_CTRL)
                    RL      A
_data_high          RL      C
                    CALL    ni2c_scl_cycle
                    DJNZ    _loop_r

                    LD      A, C
                    RET

;
; Send a byte in A, returning the ACK state in D
; Uses A, B, C,
;
ni2c_send_byte      PUSH    HL
                    PUSH    DE
                    LD      D, A
                            
                    LD      H, NI2C_REGISTER << 1            ; Start with SDA and SCL LOW
                    LD      B, 8
                    LD      E, NI2C_CLK_MASK

_fast_loop          LD      A, H
                    SLA     D
                    RR      A
                    OUT     (NIO_B_CTRL), A

                    OR      E
                    OUT     (NIO_B_CTRL), A                 ; Clock high

                    XOR     E
                    OUT     (NIO_B_CTRL), A                 ; Clock low
                    DJNZ    _fast_loop

                    LD      A, H
                    SCF
                    RR      A                               ; Release SDA
                    OUT     (NIO_B_CTRL), A

                    OR      E
                    OUT     (NIO_B_CTRL), A                 ; Clock high


                    IN      A, (NIO_B_CTRL)                 ; Read ACK
                    POP     DE
                    POP     HL
                    LD      D, A

                    LD      A, NI2C_DATA_MASK | NI2C_REGISTER
                    OUT     (NIO_B_CTRL), A                 ; Clock low, SDA released
                    LD      (nio_i2c_data), A

                    RET

;
; Send an ACK..
;
ni2c_ack            CALL    ni2c_sda_low
                    CALL    ni2c_scl_cycle
                    ; Fall through to ni2c_sda_high

; SCL/SDA toggle routines
;
; All use A

ni2c_sda_high       LD      A, (nio_i2c_data)
                    SET     NI2C_DATA_BIT, A
                    OUT     (NIO_B_CTRL), A
                    LD      (nio_i2c_data), A
                    RET

ni2c_sda_low        LD      A, (nio_i2c_data)
                    RES     NI2C_DATA_BIT, A
                    OUT     (NIO_B_CTRL), A
                    LD      (nio_i2c_data), A
                    RET

ni2c_scl_low        LD      A, (nio_i2c_data)
                    RES     NI2C_CLK_BIT, A
                    OUT     (NIO_B_CTRL), A
                    LD      (nio_i2c_data), A
                    RET

ni2c_scl_high       LD      A, (nio_i2c_data)
                    SET     NI2C_CLK_BIT, A
                    OUT     (NIO_B_CTRL), A
                    LD      (nio_i2c_data), A
                    RET

ni2c_scl_cycle      LD     A, (nio_i2c_data)        ; SCL low then high, return SDA in D, bit 7
                    RES    NI2C_CLK_BIT, A
                    LD     (nio_i2c_data), A
                    OUT    (NIO_B_CTRL), A
                    
                    SET    NI2C_CLK_BIT, A
                    OUT    (NIO_B_CTRL), A
                    
                    IN     A, (NIO_B_CTRL)
                    LD     D, A
                    LD     A, (nio_i2c_data)
                    OUT    (NIO_B_CTRL), A
                    RET

                    .MODULE main
