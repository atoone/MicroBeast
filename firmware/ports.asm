;
; Port definintions
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

BACKSPACE_CHAR      .EQU  08h
CARRIAGE_RETURN     .EQU  0Dh
NEWLINE             .EQU  0Ah
ESCAPE_CHAR         .EQU  1Bh
CPM_NUM             .EQU  1Fh

;=================================== UART ============================================
UART_TX_RX          .EQU    020h    ; Read: receiver buffer, Write: transmitter buffer
UART_INT_ENABLE     .EQU    021h    ; Interrupt enable register
UART_INT_ID         .EQU    022h    ; Read: Interrupt identification register
UART_FIFO_CTRL      .EQU    022h    ; Write: FIFO Control register
UART_LINE_CTRL      .EQU    023h    ; Line control register
UART_MODEM_CTRL     .EQU    024h    ; Modem control
UART_LINE_STATUS    .EQU    025h    ; Line status
UART_MODEM_STATUS   .EQU    026h    ; Modem status
UART_SCRATCH        .EQU    027h    ; Scratch register

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


;=================================== MEMORY PAGING ===================================
IO_MEM_0            .EQU    070h      ; Page 0: 0000h - 3fffh
IO_MEM_1            .EQU    071h      ; Page 1: 4000h - 7fffh
IO_MEM_2            .EQU    072h      ; Page 2: 8000h - bfffh
IO_MEM_3            .EQU    073h      ; Page 3: c000h - ffffh

IO_MEM_CTRL         .EQU    074h      ; Paging enable register
IO_MEM_ENABLE       .EQU    1
IO_MEM_DISABLE      .EQU    0 

RAM_PAGE_0          .EQU    020h
RAM_PAGE_1          .EQU    021h
RAM_PAGE_2          .EQU    022h
RAM_PAGE_3          .EQU    023h

RAM_PAGE_16         .EQU    030h
RAM_PAGE_31         .EQU    03Fh

ROM_PAGE_0          .EQU    000h
ROM_PAGE_16         .EQU    010h

PAGE_1_START        .EQU    4000h

;====================================== I2C DEVICES ===================================
I2C_DATA_BIT            .equ    7
I2C_CLK_BIT             .equ    6

I2C_DATA_MASK           .equ    1 << I2C_DATA_BIT
I2C_CLK_MASK            .equ    1 << I2C_CLK_BIT

; Display
;==========
DL_ADDRESS              .EQU    050h     ; Left  Matrix controller I2C address
DR_ADDRESS              .EQU    053h     ; Right Matrix controller I2C address

DISP_REG_CRWL           .EQU    0FEh     ; Command Register write lock
DISP_UNLOCK             .EQU    0C5h     ; Unlock command

DISP_DEFAULT_BRIGHTNESS .EQU    080h     ; Default brightness
DISP_DIMMED             .EQU    018h     ; Dimmed

DISPLAY_WIDTH           .EQU    24       ; 24 characters

; RTC
;==========
RTC_ADDRESS             .EQU    06fh

RTC_REG_SEC             .EQU    000h    ; Also has oscillator enable bit in B7, 1 = run
RTC_REG_MIN             .EQU    001h
RTC_REG_HOUR            .EQU    002h    ; B6: 1 = 12hr/ 0 = 24hr clock (r/w) 
                                        ;        If 12 hr clock, B5: 1 = PM/ 0 = AM. B4: hour tens. Otherwise B5-4: hour tens, B3-0: hour units
RTC_REG_WKDAY           .EQU    003h    ; Oscillator status bit in B5, 1 = enabled and running. 
                                        ;   B4: 1 = power was lost, write 0 to clear (timestamp registers are set)
                                        ;   B3: 1 = enable external battery supply (VBAT)
                                        ;   B2-0: Weekday, from 1 to 7 
RTC_REG_DATE            .EQU    004h    ; BCD Date (1 to 31)
RTC_REG_MTH             .EQU    005h    ; B5: 1 = Leap year (read only). B4: month tens, B3-0: month units  (Month is 1 to 12)
RTC_REG_YEAR            .EQU    006h    ; BCD Year

RTC_REG_CTRL            .EQU    007h    ; B7: If Square wave and Alarm 0 and Alarm 1 are disabled, sets Output Pin level
                                        ;   B6: SQWEN, 1 = Enable square wave on Output Pin, Alarms disabled
                                        ;   B5, B4: Alarm 1, 0 Enable. 1 = Alarm is enabled
                                        ;   B3: 1 = Use external oscillator
                                        ;   B2: CRSTRIM, 1 = Coarse trim mode, Output pin is 64Hz
                                        ;   B1-0: If SQWEN = 1 & CRSTRIM = 0, sets Output pin freq. 00 -> 1Hz, 01 -> 4.096kHz, 10 -> 8.192kHz, 11 -> 32.768kHz
RTC_REG_TRIM            .EQU    008h    ; Trim, initially 0. B7: Sign, 1=Add, 0=Subtract clock cycles.  
                                        ;   B6-0: Trim amount/2. Applied 1 every minute in fine trim, 128 times a second in coarse trim mode. 0 = disable trim

RTC_64HZ_ENABLED        .EQU    044h    ; Value for RTC_REG_CTRL to enable 64Hz interrupt output

RTC_WEEKDAY_RUNNING     .EQU    008h    ; Value for RTC_REG_WKDAY for normall running of clock