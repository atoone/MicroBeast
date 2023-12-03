; snes.asm - A simple demonstration to read a SNES controller through the MicroBeast GPIO
;
; Uses the base BIOS to write the buttons being pressed to the display.
;
; Build with:
;  tasm -t80 -b mandel.asm mandel_m8000.bin
;
;
; Assumes the following connections on the GPIO header:
;
;      GPIO                      SNES
;                               _______
;    (A) (A) +5v --------- +5v  | (1) |
;    (B) (C) PB0 -------> Clock | (2) |
;    (D) (E) PB1 -------> Latch | (3) |
;    (F) (G) PB2 <------- Data  | (4) |
;    (H) (I) PB3                |-----|
;    (J) (K) BRDY               | (5) |
;    (L) (M) ARDY               | (6) |
;    (N) (O) ~BSTB      +-- GND | (7) |
;    (P) (Q) ~ASTB      |       \_____/
;    (R) (R) GND -------+ 
;

                    .MODULE  main

                    .ORG   08000h

                    CALL    setup_snes

_snes_loop          LD      BC,0FD00h      ; A9 is low -> Read Row 1
                    IN      A, (C)         ; A contains keys G, F, D, S, A, CTRL
                    AND     03Fh
                    CP      03Fh
                    RET     NZ             ; Return if a key is pressed

                    CALL    read_snes
                    LD      A, (_last_value)
                    CP      L
                    JR      NZ, _changed
                    LD      A, (_last_value+1)
                    CP      H
                    JR      Z, _delay

_changed            LD      (_last_value), HL

                    LD      DE, _message
                    CALL    _write_string

                    LD      HL, (_last_value)
                    LD      DE, _snes_btns
                    LD      B, 12

_output_loop        PUSH    DE
                    PUSH    BC
                    SLA     L
                    RL      H
                    PUSH    HL

                    LD      C, 9
                    CALL    NC, _write_string

                    POP     HL
                    POP     BC
                    POP     DE
_next               LD      A, (DE)
                    INC     DE
                    CP      '$'
                    JR      NZ, _next
                    DJNZ    _output_loop

_delay
                    LD      BC, 0
_delay_loop         DEC     BC
                    LD      A, B
                    OR      C
                    JR      NZ, _delay_loop
                    JR      _snes_loop

_message            .DB     CARRIAGE_RETURN, ESCAPE_CHAR, 'K', "Pressed $"

_snes_btns          .DB     "B $"
                    .DB     "Y $"
                    .DB     "Select $"
                    .DB     "Start $"
                    .DB     "Up $"
                    .DB     "Down $"
                    .DB     "Left $"
                    .DB     "Right $"
                    .DB     "A $"
                    .DB     "X $"
                    .DB     "L $"
                    .DB     "R $$$"

_write_string       LD      A, (DE)
                    CP      '$'
                    RET     Z
                    LD      C, A
                    PUSH    DE
                    CALL    BIOS_CONOUT
                    POP     DE
                    INC     DE
                    JR      _write_string

_last_value         .DW     0

;
; Setup the PIO to read the SNES controller. 
;
setup_snes          DI
                    LD      A, PIO_MODE_3           ; Port B mode 3
                    OUT     (PIO_B_CTRL), A
                    LD      A, PORT_B_IOMASK        ; All inputs, apart from bits 1 (Latch) and 0 (Clock)
                    LD      (port_b_dir), A             ; Stop BIOS from messing it up
                    OUT     (PIO_B_CTRL), A

                    LD      A, SNES_IDLE
                    LD      (port_b_data), A
                    OUT     (PIO_B_DATA), A
                    EI 
                    RET

;
; Read the SNES controller, returning the bitmask in HL
;
;

read_snes           DI
                    LD      HL, 01
                    LD      C, PIO_B_DATA

                    LD      E, SNES_IDLE | SNES_LATCH
                    OUT     (C), E

                    LD      B, 10
                    DJNZ    $
                    LD      E, SNES_IDLE
                    OUT     (C), E

_read_loop          LD      B, 8
                    DJNZ    $

                    IN      A, (C)
                    RRA 
                    RRA
                    AND     01

                    SLA     L
                    RL      H
                    JR      C, _read_done

                    OR      L
                    LD      L, A

                    LD      E, 0
                    OUT     (C), E

                    LD      B, 10
                    DJNZ    $

                    LD      E, SNES_IDLE
                    OUT     (C), E
                   
                    JR      _read_loop

_read_done          EI
                    RET

; Used by BIOS to manage I2C connection on high bits of Port B
;
port_b_dir          .EQU  0FF01h
port_b_data         .EQU  0FF02h


; Location of BIOS conout routine
; 
BIOS_CONOUT         .EQU  0EE0Ch


;
; General constants
;

CARRIAGE_RETURN     .EQU  0Dh
NEWLINE             .EQU  0Ah
ESCAPE_CHAR         .EQU  1Bh

SNES_CLOCK          .EQU  001h
SNES_LATCH          .EQU  002h

SNES_IDLE           .EQU  SNES_CLOCK


PIO_B_DATA          .EQU  011h
PIO_B_CTRL          .EQU  013h

PIO_MODE_0          .EQU  00Fh      ; Mode 0: All outputs
PIO_MODE_1          .EQU  04fh      ; Mode 1: All inputs
PIO_MODE_2          .EQU  080h      ; Mode 2 (Port A only): Bi-directional
PIO_MODE_3          .EQU  0CFh      ; Mode 3: Per-pin I/O on the given port - write an additional word with bits set (1) for input, reset (0) for output on the matching pin.

PORT_B_IOMASK       .EQU  0FCh      ; All inputs, apart from bits 1 (Latch) and 0 (Clock)


                    .END
