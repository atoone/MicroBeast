; ============================================ I2C Routines =================================================
; Software driven I2C for Z80 PIO
;
; Assume I2C clock is on Port B bit 6
;            data is on Port B bit 7
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
                    .MODULE i2c

init_portb          LD      A, PIO_MODE_3           ; Port B mode 3
                    LD      (port_b_mode), A
                    OUT     (PIO_B_CTRL), A

                    LD      A, PORT_B_IOMASK        ;
                    LD      (port_b_dir), A
                    OUT     (PIO_B_CTRL), A

                    LD      A, 03Fh                 ; All bits high apart from D7, D6
                    LD      (port_b_data),A
                    OUT     (PIO_B_DATA), A         ; Changing D7 or D6 to an output will drive the lines low
                    RET

; Reset the bus
;
; Uses A, B, D
i2c_bus_reset       LD      B, 0ah          ; ten cycles
_loop_b             CALL    i2c_scl_cycle
                    DJNZ    _loop_b
                    CALL    i2c_scl_high
                    LD      B, 0F0h
                    DJNZ    $
                    RET

;
; Uses A
i2c_start           CALL    i2c_sda_high
                    CALL    i2c_scl_high
                    CALL    i2c_sda_low     ; Drive data low
                    JP      i2c_scl_low     ; Drive clock low


;
; Read a byte from Device address H, Register L into A
; Calls i2c_start, sets address, reads byte and then calls i2c_stop
; Returns With Carry SET and A containing the register value, or Carry CLEAR if no acknowledge
; Uses A, B, C, D, H, L
; Preserves H, L
i2c_read_byte       CALL    i2c_read_from
                    ; Fall through into stop
                
;
; Uses A
i2c_stop            CALL    i2c_sda_low     ; Drive data low
                    CALL    i2c_scl_high
                    JP      i2c_sda_high

; Write a byte in C to Device address H, register L
; Returns with Carry SET if OK, CLEAR if no acknowledgement
; Calls i2c_stop when done..
;
; Preserves H, L
i2c_write_byte      PUSH    BC
                    CALL    i2c_write_to
                    POP     BC
                    JP      NC, i2c_stop
                    LD      A, C
                    CALL    i2c_write
                    JR      i2c_stop
                    
;
; Read a byte from Device address H, Register L
; Calls i2c_start, but does NOT call i2c_stop
; Returns With Carry SET and A containing the register value, or Carry CLEAR if no acknowledge
; Uses A, B, C, D, H, L
; Preserves H, L
i2c_read_from       CALL    i2c_start
                    LD      A, H
                    CALL    i2c_address_w
                    JR      NC, _read_end
                    LD      A, L
                    CALL    i2c_write
                    JR      NC, _read_end
                    LD      B, 50
_read_pause         DJNZ    _read_pause
                    CALL    i2c_start
                    LD      A, H
                    CALL    i2c_address_r
                    JR      NC, _read_end
                    CALL    i2c_read
                    SCF
_read_end           RET


;
; Prepare to write to Device address H, Register L
; Calls i2c_start, but does NOT call i2c_stop
; Returns with Carry SET if OK, CLEAR if no acknowledgement
;
; Preserves H, L
i2c_write_to        CALL    i2c_start
                    LD      A, H
                    CALL    i2c_address_w
                    RET     NC
                    LD      A, L
                    JP      i2c_write

; Start reading from device address held in A
;
; Uses A, B, C, D
i2c_address_r       SLA     A
                    OR      1
                    JR      i2c_write

; Start writing to device address held in A
;
; Uses A, B, C, D
i2c_address_w       SLA     A

; Write A as a byte to i2c bus
; Returns Carry CLEAR if no acknowledge
;
; Uses A, B, C, D
i2c_write           PUSH    HL
                    LD      HL, (port_b_mode)           ; L = port_b_mode, H = port_b_dir
                    LD      D, A
                    
                    LD      A, ~(I2C_DATA_MASK|I2C_CLK_MASK)           ; Set SDA and SCL (port_b_dir bit) LOW
                    AND     H
                    SLA     A
                    LD      H, A

                    LD      C, PIO_B_CTRL
                    LD      B, 8

_fast_loop          LD      A, H
                    SLA     D
                    RR      A
                    OUT     (C),L
                    OUT     (PIO_B_CTRL), A

                    OR      I2C_CLK_MASK
                    OUT     (C), L
                    OUT     (PIO_B_CTRL), A                 ; Clock high

                    XOR     I2C_CLK_MASK
                    OUT     (C), L
                    OUT     (PIO_B_CTRL),A                  ; Clock low
                    DJNZ    _fast_loop

                    LD      A, H
                    SCF
                    RR      A
                    OUT     (C),L                           ; Release SDA
                    OUT     (PIO_B_CTRL), A

                    OR      I2C_CLK_MASK
                    OUT     (C), L
                    OUT     (PIO_B_CTRL), A                 ; Clock high

                    OUT     (C), L
                    XOR     I2C_CLK_MASK
                    LD      L, A
                    LD      (port_b_dir), A

                    IN      A, (PIO_B_DATA)                 ; Read ACK
                    OUT     (C),L                           ; Clock low

                    POP     HL

                    BIT     I2C_DATA_BIT, D     ; D contains acknowledge bit
                    SCF
                    RET     Z               ; Return with carry set if acknowledge bit is low

                    CALL    i2c_stop        ; Stop bus if error
                    SCF
                    CCF
                    RET                     ; Clear carry if acknowledge is high

; Read byte from i2C into A, without ACK
;
; Uses A, B, C, D
i2c_read            LD      B, 8h
_loop_r             IN      A, (PIO_B_DATA)
                    SCF
                    BIT     I2C_DATA_BIT, A
                    JR      NZ, _data_high
                    CCF
_data_high          RL      C
                    CALL    i2c_scl_cycle
                    DJNZ    _loop_r
                    ; CALL    i2c_scl_cycle

                    LD      A, C
                    RET

;
; Send an ACK..
;
i2c_ack             CALL    i2c_sda_low
                    CALL    i2c_scl_cycle
                    JR      i2c_sda_high

; SCL/SDA toggle routines
;
; All use A
i2c_scl_low         LD      A, (port_b_mode)
                    OUT     (PIO_B_CTRL), A

                    LD      A, (port_b_dir)
                    RES     I2C_CLK_BIT, A
                    OUT     (PIO_B_CTRL), A
                    LD      (port_b_dir), A
                    RET

i2c_sda_high        LD      A, (port_b_mode)
                    OUT     (PIO_B_CTRL), A

                    LD      A, (port_b_dir)
                    SET     I2C_DATA_BIT, A
                    OUT     (PIO_B_CTRL), A
                    LD      (port_b_dir), A
                    RET

i2c_sda_low         LD      A, (port_b_mode)
                    OUT     (PIO_B_CTRL), A

                    LD      A, (port_b_dir)
                    RES     I2C_DATA_BIT, A
                    OUT     (PIO_B_CTRL), A
                    LD      (port_b_dir), A
                    RET

i2c_scl_high        LD      A, (port_b_mode)
                    OUT     (PIO_B_CTRL), A

                    LD      A, (port_b_dir)
                    SET     I2C_CLK_BIT, A
                    OUT     (PIO_B_CTRL), A
                    LD      (port_b_dir), A
                    RET

i2c_scl_cycle       PUSH   BC
                    LD     BC, PIO_B_CTRL
                    LD     A, (port_b_mode)
                    LD     D, A
                    LD     A, (port_b_dir)

                    RES    I2C_CLK_BIT, A
                    LD     (port_b_dir), A
                    OUT    (C), D
                    OUT    (PIO_B_CTRL), A
                    
                    SET    I2C_CLK_BIT, A
                    OUT    (C), D
                    OUT    (PIO_B_CTRL), A
                    
                    IN     A, (PIO_B_DATA)
                    OUT    (C), D
                    LD     D, A
                    LD     A, (port_b_dir)
                    OUT    (PIO_B_CTRL), A
                    POP    BC
                    RET

                    .MODULE main
