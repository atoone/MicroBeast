;==================================== PIO ============================================
PIO_A_DATA          .EQU  010h
PIO_A_CTRL          .EQU  012h

PIO_B_DATA          .EQU  011h
PIO_B_CTRL          .EQU  013h

PIO_MODE_0          .EQU  00Fh      ; Mode 0: All outputs
PIO_MODE_1          .EQU  04fh      ; Mode 1: All inputs
PIO_MODE_2          .EQU  080h      ; Mode 2 (Port A only): Bi-directional
PIO_MODE_3          .EQU  0CFh      ; Mode 3: Per-pin I/O on the given port - write an additional word with bits set (1) for input, reset (0) for output on the matching pin.

PIO_SET_INTERRUPT   .EQU  007h      ; Set interrupt control world. By itself, this wil disable interrupts on the given port. OR with the following constants to change this
PIO_ENABLE_INT      .EQU  080h      ; Enable interrupts on the given port, when OR'd with the PIO_SET_INTERRUPT control word.
PIO_INT_MASK        .EQU  010h      ; When OR'd with the PIO_SET_INTERRUPT control word, the following word will enable interrupts for pins where the matching bit is zero

;================================== AUDIO ============================================
; Constants for Audio output
AUDIO_PIO           .EQU  1         ; Audio on PIO (rev. 0.1 boards)
AUDIO_UART          .EQU  2         ; Audio on UART (rev. 0.2 boards)

AUDIO_VERSION       .EQU  AUDIO_UART

#IF AUDIO_VERSION = AUDIO_PIO
PORT_B_IOMASK       .EQU  0EFh      ; All inputs, apart from bit 4 (audio out)
AUDIO_MASK          .EQU  010h      ; Bitmask for audio output on Port B. The bit is set for the output pin.
AUDIO_PORT          .EQU  PIO_B_DATA

#ELSE
PORT_B_IOMASK       .EQU  0FFh      ; All inputs
AUDIO_MASK          .EQU  008h      ; Bitmask for audio output on UART Out 2. The bit is set for the output pin
AUDIO_PORT          .EQU  UART_MODEM_CTRL

#ENDIF

;====================================== I2C DEVICES ===================================
I2C_DATA_BIT            .equ    7
I2C_CLK_BIT             .equ    6

I2C_DATA_MASK           .equ    1 << I2C_DATA_BIT
I2C_CLK_MASK            .equ    1 << I2C_CLK_BIT