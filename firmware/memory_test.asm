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
                    .MODULE     memory_test
mem_test_start      DI 
                    LD          BC, 0E9E1h         ; POP HL, JP (HL)
                    LD          (0C000h), BC
                    LD          A, (0C000h)
                    CP          0E1h
                    JR          Z, _locate_ok

                    LD          A, 'L'
                    OUT         (UART_TX_RX), A
                    JR          $

_locate_ok          CALL        0C000h
                    LD          A, H
                    AND         0C0h
                    LD          D, A            ; D = our page, to avoid

                    LD          E, 0            ; E = Which page we're testing

_test_loop          LD          A, E            ; Don't test the page we're in
                    ADD         A, '0'
                    OUT         (UART_TX_RX), A
                    AND         03h
                    RRCA
                    RRCA

                    CP          D

                    LD          C, A
                    LD          A, CARRIAGE_RETURN
                    OUT         (UART_TX_RX), A
                    LD          A, NEWLINE
                    OUT         (UART_TX_RX), A
                    LD          A, C
                    
                    JR          Z, _test_next

                    LD          H, A            ; HL = start of page
                    LD          L, 0

                    LD          A, IO_MEM_0     ; C = the IO port controlling it..
                    ADD         A, E
                    LD          C, A

                    LD          B, 32           ; B = the physical page we're paging in..

_test_page_loop     DEC         B
                    LD          A, B
                    ADD         A, RAM_PAGE_0
                    OUT         (C), A

                    ; Now we have a page in place.. report it and check it can be written and read..
_wait_uart          IN          A, (UART_LINE_STATUS)
                    BIT         5, A
                    JR          Z, _wait_uart           ; Bit 5 is set when the UART is ready

                    LD          A, 'o'
                    OUT         (UART_TX_RX), A
                    LD          A, B
                    SRL         A
                    SRL         A
                    SRL         A
                    ADD         A, '0'
                    OUT         (UART_TX_RX), A
                    LD          A, B
                    AND         07h
                    ADD         A, '0'
                    OUT         (UART_TX_RX), A
                    CP          '0'
                    JR          NZ, _no_cr
                    LD          A, CARRIAGE_RETURN
                    OUT         (UART_TX_RX), A
                    LD          A, NEWLINE
                    OUT         (UART_TX_RX), A

_no_cr              XOR         A
_test_write         DEC         A
                    LD          (HL), A
                    CP          (HL)
                    JR          NZ, _test_fail
                    CP          B
                    JR          NZ, _test_write

                    AND         A
                    JR          NZ, _test_page_loop

_test_next          INC         E
                    LD          A, 4
                    CP          E
                    JR          NZ, _test_loop

                    JR          _test_read_page

_test_fail          LD          A, 'x'
                    OUT         (UART_TX_RX), A
                    JR          $

_test_read_page     LD          A, 'y'
                    OUT         (UART_TX_RX), A
                    LD          A, CARRIAGE_RETURN
                    OUT         (UART_TX_RX), A
                    LD          A, NEWLINE
                    OUT         (UART_TX_RX), A

                    LD          B, 0           ; B = the physical page we're paging in..

_read_page_loop     LD          A, B
                    ADD         A, RAM_PAGE_0
                    OUT         (C), A          ; C still points to the last valid page we wrote

                    LD          A, (HL)
                    CP          B
                    JR          NZ, _read_fail

_wait_uart2         IN          A, (UART_LINE_STATUS)
                    BIT         5, A
                    JR          Z, _wait_uart2           ; Bit 5 is set when the UART is ready

                    LD          A, B
                    AND         07h
                    ADD         A, '0'
                    OUT         (UART_TX_RX), A
                    CP          '7'
                    JR          NZ, _no_space
                    LD          A, ' '
                    OUT         (UART_TX_RX), A

_no_space           INC         B
                    LD          A, 32
                    CP          B
                    JR          NZ, _read_page_loop

                    LD          A, 'y'
_test_complete      OUT         (UART_TX_RX), A
                    JR          $

_read_fail          LD          A, '!'
                    JR          _test_complete

                    .END