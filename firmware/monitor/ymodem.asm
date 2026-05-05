;
; YModem implementation.
; File format: The filename MAY indicate the load address in memory for the file. If so, the format is:
;       filename_mHHHH.suffix
;    or filename_pHH.suffix
;
; Where:  _mHHHH indicates a preferred destination address of HHHH (in memory) - four digits hexadecimal value (uppercase).
;   or    _pHH   indicates the page in memory that the file is intended for (assumes start at offset 0 in page..)
;
; When _p is used, the file is always written to bank 1 - address 4000h. It is expected that the calling program will
; then copy the data to the target page, which can be retrieved from the ym_file_mode return value.
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

                    .MODULE ymodem

_PAGE_PREFIX        .EQU    'p'
_DEST_PREFIX        .EQU    'm'

; Return values
YMODEM_SUCCESS      .EQU    000h
YMODEM_TIMEOUT      .EQU    001h
YMODEM_UNKNOWN      .EQU    002h            ; Unknown packet type (Packet byte in C)
YMODEM_CANCEL       .EQU    003h            ; Cancelled by sender
YMODEM_PACKET_ERROR .EQU    004h            ; Packet data error (Error code in C)
YMODEM_LENGTH_ERROR .EQU    005h            ; Length data in zeroth packet is invalid
YMODEM_NO_DEST      .EQU    006h            ; No destination provided
YMODEM_SEND_TIMEOUT .EQU    007h
YMODEM_MULTI_FILES  .EQU    008h            ; Cannot receive more than one file 

_SOH                .EQU    001h            ; 128 byte data packet header
_STX                .EQU    002h            ; 1024 byte data packet header
_EOT                .EQU    004h            ; End transfer
_ACK                .EQU    006h            ; Respond
_NAK                .EQU    015h            ; No response
_CAN                .EQU    018h            ; Transmission aborted
_C                  .EQU    043h            ; Request packet

_SOH_PACKET_SIZE    .EQU    128
_STX_PACKET_SIZE    .EQU    1024
_FRAME_OVERHEAD     .EQU    5               ; Three byte header + two byte CRC (high byte first)

_TIMEOUT_COUNT      .EQU    50000

_ERR_PACKET_COUNT   .EQU    1               ; Wrong packet index
_ERR_CHECK_HIGH     .EQU    2               ; High byte of CRC failed
_ERR_CHECK_LOW      .EQU    3               ; Low byte of CRC failed
_ERR_CANCEL         .EQU    4               ; Got a cancel request without second cancel
_ERR_ZERO_PACKET    .EQU    5               ; Zeroth packet must be SOH

YM_DEST_FROM_FILE   .EQU    0FEh            ; File destination set from filename

ymodem_data_length  .EQU    17              ; Size of data block before buffer

ym_file_mode        .EQU    -17             ; FFh : Normal transfer,  FEh : Destination set by file, 0-7Fh : Page write 
ym_file_count       .EQU    -16
ym_length_low       .EQU    -15             ; Length specified in header packet
ym_length_mid       .EQU    -14
ym_length_high      .EQU    -13
ym_loaded_high      .EQU    -12             ; Tracks high byte of length during load.
ym_soh_saved_len    .EQU    -11             ; We have to copy part of a final SOH packet from the buffer - track actual length needed
ym_soh_saved_len_h  .EQU    -10 
ym_current_page     .EQU    -9              ; FFh if no paging, otherwise page to send data to
ym_dest_low         .EQU    -8              ; If specified in file header - the destination address of the file
ym_dest_high        .EQU    -7
ym_current_packet   .EQU    -6              ; Expected packet number
ym_packet_type      .EQU    -5              ; Packet type - SOH/STX
ym_packet_num       .EQU    -4              ; Packet number we're currently receiving
ym_packet_num_cpl   .EQU    -3              ; Complement..
ym_crc_low          .EQU    -2              ; CRC Low byte
ym_crc_high         .EQU    -1              ; CRC High byte

YMODEM_BUFFER       .EQU    _SOH_PACKET_SIZE + ymodem_data_length
YMODEM_INFO         .EQU    _SOH_PACKET_SIZE

;
; ymodem - Main entry point. Call with:
;     HL = Address of YMODEM_BUFFER (=128 + ymodem_data_length) byte buffer for receiving data
;     DE = (Optional) address to write data. 0xFFFF to accept destination from filename otherwise
;      A = Page to write data. 0xFF to disable paging/accept page from filename otherwise
;
; If using A to set a Page destination, DE should be an offset within Bank 1 (ie 4000h - 7FFFh)
; If the file specifies a page destination, DE is initialised to 4000h - the start of the page
;
; Returns status code in A:
;     YMODEM_SUCCESS : (=0) If the file was successfully received
;     YMODEM_xxxx    : (Non zero) If the receiver timed out waiting for a byte
;
; Note Bank 1 may have been set to a new page destination if one was specified.

ymodem              LD      BC, ymodem_data_length      ; Skip data block at start of buffer
                    ADD     HL, BC
                    PUSH    HL
                    POP     IX
                    LD      (IX+ym_current_page), A
                    LD      (IX+ym_file_mode), A           ; Default normal transfer, 0FFh, else page 
                    XOR     A                           
                    LD      (IX+ym_file_count), A
                    DEC     A
                    LD      (IX+ym_dest_low), E
                    LD      (IX+ym_dest_high), D

_ymodem_start       XOR     A                           ; Set initial packet number
                    LD      (IX+ym_current_packet), A
                    LD      IY, 0FFFFh                  ; IY - bytes to load. Default - load all bytes

                    ; Now we can load.
                    ; DE = destination
                    ; IY = low 16 bits of length
                    ; IX = load buffer

_packet_loop        CALL    _recieve_safe
                    JR      NZ, _packet_byte
_send_crc_and_loop  LD      A, _C
                    CALL    _send_byte
                    JR      _packet_loop

_packet_byte        CP      _SOH
                    JP      NZ, _check_stx

                    PUSH    IX                          ; SOH - May be zero'th or last packet
                    POP     HL
                    LD      BC, _SOH_PACKET_SIZE
                    JR      _receive_packet

_check_stx          CP      _STX
                    JR      NZ, _check_eot
                                                        
                    LD      H, D                        ; STX packets go straight to DE
                    LD      L, E
                    LD      BC, _STX_PACKET_SIZE    
                    JR      _receive_packet

_check_eot          CP      _EOT
                    JR      NZ, _check_can
                                                        ; End of transmission
                    LD      A, _ACK 
                    CALL    _send_byte

                    INC     (IX+ym_file_count)      
                    JR      _ymodem_start  

_check_can          CP      _CAN
                    JR      NZ, _unknown_packet
                                                        ; Single cancel request. Check for another
                    CALL    _receive_byte
                    CP      _CAN
                    LD      A, _ERR_CANCEL
                    JR      NZ, _packet_error

                    LD      A, _ACK 
                    CALL    _send_byte
_purge              CALL    _recieve_safe               ; Purge remains of any cancel request
                    JR      NZ, _purge

                    LD      A, YMODEM_CANCEL
                    AND     A
                    RET

_zero_error         LD      A, _ERR_ZERO_PACKET
_packet_error       LD      C, A                        ; Packet data error - return error code in C
                    LD      A, YMODEM_PACKET_ERROR
                    AND     A
                    RET

_unknown_packet     LD      C, A                        ; Unknown packet type - return header byte in C
                    LD      A, YMODEM_UNKNOWN
                    AND     A
                    RET     

; Receive data for both SOH and STX packets..
; At this point HL is destination (either DE or IX-buffer), and BC is a byte count
;
_receive_packet     LD      (IX+ym_packet_type), A   

                    LD      A, (IX+ym_current_page)
                    CP      0FFh
                    JR      Z, _no_page_specified
                    OUT     (IO_MEM_1), A

_no_page_specified  XOR     A
                    LD      (IX+ym_soh_saved_len), A     ; Reset how many bytes of an SOH packet we actually loaded..
                    LD      (IX+ym_soh_saved_len_h), A

                    CP      (IX+ym_current_packet)         ; If this is the zeroth packet, it must be SOH
                    JR      NZ, _not_zeroth_packet
                    LD      A, _SOH
                    SUB     (IX+ym_packet_type)            ; Leave A as zero if this is OK
                    JR      NZ, _zero_error

_not_zeroth_packet  LD      (IX+ym_crc_high), A
                    LD      (IX+ym_crc_low), A

                    CALL    _receive_byte   
                    LD      (IX+ym_packet_num), A
                    CALL    _receive_byte   
                    LD      (IX+ym_packet_num_cpl), A

_data_loop          LD      A, L                        ; Handle paging if we're loading into paged memory..
                    AND     A
                    JR      NZ, _data_receive
                    LD      A, H
                    CP      80h
                    JR      NZ, _data_receive
                    LD      A, (IX+ym_current_page)
                    INC     A
                    JR      Z, _data_receive           ; Paging disabled

                    LD      (IX+ym_current_page), A        ; Move to next page
                    OUT     (IO_MEM_1), A
                    LD      H, 40h
                    
_data_receive       CALL    _receive_byte

                    LD      (HL), A

                    CALL    _calc_checksum  

                    PUSH    BC                          ; Count down the bytes remaining, and once we get to zero, send bytes to _dev_null
                    LD      BC, -1
                    ADD     IY, BC                      ; Carry set if IY not zero
                    POP     BC
                    JR      C, _in_range

                    DEC     (IX+ym_loaded_high)
                    JP      P, _in_range
     
                    INC     (IX+ym_loaded_high)      ; Keep resetting counter...
                    INC     IY
                    LD      HL, _dev_null
                    JR      _do_next

_in_range           INC     (IX+ym_soh_saved_len)
                    JR      NZ, _packet_part_ok
                    INC     (IX+ym_soh_saved_len_h)
_packet_part_ok     INC     HL

_do_next            DEC     BC

                    LD      A, B
                    OR      C
                    JR      NZ, _data_loop

                    XOR     A
                    CALL    _calc_checksum  
                    XOR     A
                    CALL    _calc_checksum  

                    CALL    _receive_byte
                    LD      B, A
                    CALL    _receive_byte   
                    LD      C, A
;
; Now do checks...

                    LD      A, (IX+ym_packet_num)
                    CPL
                    CP      (IX+ym_packet_num_cpl)
                    LD      A, _ERR_PACKET_COUNT
                    JP      NZ, _packet_error
                    LD      A, (IX+ym_crc_high)
                    CP      B
                    LD      A, _ERR_CHECK_HIGH
                    JP      NZ, _packet_error
                    LD      A, (IX+ym_crc_low)
                    CP      C
                    LD      A, _ERR_CHECK_LOW
                    JP      NZ, _packet_error

; CRC and packet number check out... 
                    LD      A, (IX+ym_packet_num)
                    CP      (IX+ym_current_packet)
                    JR      NZ, _retry_packet               ; We need to restore IY (length) if we wish to survive.. DE is not updated until later, so OK
                    INC     (IX+ym_current_packet)
                    AND     A
                    JR      Z, _header_packet

                    LD      A, (IX+ym_packet_type)
                    CP      _SOH
                    JR      NZ, _not_soh

; SOH packets must be copied to DE -> 
                    LD      C, (IX+ym_soh_saved_len)
                    LD      B, 0
                    PUSH    IX
                    POP     HL
                    LDIR
                    JR      _send_ack

_not_soh            LD      D, H
                    LD      E, L
_send_ack           LD      A, _ACK 
_send_and_loop      CALL    _send_byte
                    JP      _send_crc_and_loop      

_retry_packet       XOR     A                           ; Clear carry
                    SBC     HL, DE
                    JR      NC, _retry_page_ok          

                    LD      A,(IX+ym_current_page)         ; If HL (latest write dest) is less than DE (write dest at start of packet) assume we've changed pages..
                    CP      0FFH
                    JR      Z, _retry_page_ok           ; We're not paging anyway...
                    DEC     A 
                    LD      (IX+ym_current_page), A
                    OUT     (IO_MEM_1),A

_retry_page_ok      LD      C, (IX+ym_soh_saved_len)     ; Restore IY (length)
                    LD      B, (IX+ym_soh_saved_len_h)
                    PUSH    IY
                    POP     HL
                    ADD     HL, BC
                    JR      NC, _retry_iy_ok
                    INC     (IX+ym_loaded_high)
_retry_iy_ok        PUSH    HL
                    POP     IY
                                                        ; TODO: If we've changed the page, that needs to be restored as well


_retry_drain        CALL   _recieve_safe                ; Drain the incoming stream before sending nak
                    JR      NZ, _retry_drain

                    LD      A, _NAK
                    JR      _send_and_loop


_header_packet      PUSH    IX
                    POP     HL
                    LD      A, (HL)                     ; Empty zeroth packet means end of batch send
                    AND     A
                    JR      NZ, _check_filecount

                    LD      A, _ACK 
                    CALL    _send_byte
                    LD      A, YMODEM_SUCCESS   
                    AND     A
                    RET

_check_filecount    LD      A, (IX+ym_file_count)
                    AND     A
                    JR      Z, _next_filechar

                    LD      A, YMODEM_MULTI_FILES
                    AND     A
                    RET

_next_filechar      LD      A, (HL)
                    INC     HL
_check_char         AND     A
                    JR      Z, _read_length
                    CP      '_'                     ; Check for special transfer modes
                    JR      NZ, _next_filechar
                    LD      A, (HL)
                    LD      C, A                    ; Remember the prefix char in C
                    INC     HL
                    CP      _DEST_PREFIX
                    JR      NZ, _check_flash
                    LD      B, 4
                    LD      DE, 0
                    JR      _parse_dest

_check_flash        CP      _PAGE_PREFIX
                    JR      NZ, _check_char
                    LD      B, 2
                    LD      DE, 0

_parse_dest         LD      A, (HL)
                    INC     HL
                    SUB     '0'
                    JR      C, _invalid_dest
                    CP      10
                    JR      C, _digit_checked
                    SUB     7
                    JR      C, _invalid_dest
                    CP      16
                    JR      NC, _invalid_dest

_digit_checked      PUSH    HL                          ; Shift existing dest left 4 bits and merge new hex digit
                    LD      H, D
                    LD      L, E
                    ADD     HL, HL
                    ADD     HL, HL
                    ADD     HL, HL
                    ADD     HL, HL
                    OR      L
                    LD      D, H
                    LD      E, A
                    POP     HL
                    DJNZ    _parse_dest

                    LD      A, C                        ; Which char did we start with?
                    CP      _PAGE_PREFIX
                    JR      NZ, _memory_dest

                    LD      A, (IX+ym_current_page)        ; Page prefix. Use original value if set when ymodem was called
                    CP      0FFh
                    JR      NZ, _next_filechar

                    LD      (IX+ym_file_mode), E           ; Otherwise use the file specified value and load from 4000h
                    LD      (IX+ym_current_page), E
                    LD      DE,04000h    
                    JR      _store_dest

_memory_dest        LD      A, 0FFh                     ; Only set the dest from the filename if 
                    CP      (IX+ym_dest_low)               ; the routine was called with a destination of 0FFFFh
                    JR      NZ, _next_filechar
                    CP      (IX+ym_dest_high)
                    JR      NZ, _next_filechar

                    LD      (IX+ym_file_mode), YM_DEST_FROM_FILE

_store_dest         LD      (IX+ym_dest_low), E
                    LD      (IX+ym_dest_high), D

                    JR      _next_filechar

_invalid_dest       LD      E, (IX+ym_dest_low)            ; We silently skip invalid destination values
                    LD      D, (IX+ym_dest_high)
                    JR      _next_filechar

_read_length        LD      A, 0FFh                     ; At this point we should have a valid destination
                    CP      (IX+ym_dest_low)               
                    JR      NZ, _dest_ok
                    CP      (IX+ym_dest_high)
                    JR      NZ, _dest_ok

                    LD      A, YMODEM_NO_DEST
                    AND     A
                    RET

_dest_ok            LD      A, 0FFh
                    LD      (IX+ym_length_low), A       ; Reset the length counter///
                    LD      (IX+ym_length_mid), A
                    LD      (IX+ym_length_high), A         
                    LD      (IX+ym_loaded_high), A
                    LD      IY, 0FFFFh 
                    LD      B, H
                    LD      C, L               
                    LD      HL, 0
                    LD      A, (BC)                     ; Length is optional
                    AND     A
                    JP      Z, _send_ack

_parse_length       LD      A, (BC)
                    INC     BC
                    AND     A
                    JR      Z, _length_end
                    CP      ' '
                    JR      Z, _length_end
                    SUB     '0'
                    JR      C, _invalid_length
                    CP      10
                    JR      NC, _invalid_length

                    PUSH    BC
                    PUSH    DE
                    PUSH    AF

                    EX      DE, HL              ; HL into DE 
                    LD      A, 10

                    ; DE x A  -> AHL  (from http://z80-heaven.wikidot.com/advanced-math#toc12)
                    ; preserves DE
                    LD      BC, 0800h
                    LD      H, C
                    LD      L, C
_pl_loop            ADD     HL, HL
                    RLA
                    JR      NC, _pl_skip
                    ADD     HL, DE
                    ADC     A, C
_pl_skip            DJNZ    _pl_loop

                    LD      (IX+ym_length_high), A     ; Note we only handle overflow for one digit.. max value 655,359?
                    POP     AF
                    LD      E, A
                    LD      D, C
                    ADD     HL, DE
                    JR      NC, _pl_length_ok
                    INC     (IX+ym_length_high)

_pl_length_ok       POP     DE
                    POP     BC
                    JR      _parse_length

_length_end         PUSH    HL
                    POP     IY
                    LD      (IX+ym_length_low), L
                    LD      (IX+ym_length_mid), H
                    LD      A, (IX+ym_length_high)
                    LD      (IX+ym_loaded_high), A
                    JP      _send_ack

_invalid_length     LD      A, YMODEM_LENGTH_ERROR      ; Hard fail on invalid length data
                    AND     A
                    RET

;-----
; Calculate the checksum from A
_calc_checksum      PUSH    HL
                    PUSH    BC

                    LD      B, 1
                    LD      C, A
                    LD      H, (IX+ym_crc_high)
                    LD      L, (IX+ym_crc_low)

_crc_loop           ADD     HL, HL
                    PUSH    AF

                    SLA     C
                    RL      B
                    JR      NC, _no_in_overflow
                    SET     0, C
_no_in_overflow
                    BIT     0, B
                    JR      Z, _no_in_bit
                    INC     HL
_no_in_bit                    
                    POP     AF
                    JR      NC, _no_crc_overflow
                    LD      A, 021h
                    XOR     L 
                    LD      L,A
                    LD      A, 010h
                    XOR     H 
                    LD      H, A
_no_crc_overflow
                    BIT     0, C
                    JR      Z, _crc_loop    

                    LD      (IX+ym_crc_high), H
                    LD      (IX+ym_crc_low), L
                    POP     BC
                    POP     HL
                    RET

_dev_null           .DB     0

;
; Recieve a byte with timeout, without exiting ymodem
; If success, A contains byte, non-zero flag set
; Otherwise A is zero, Zero flag is set
;
_recieve_safe       LD      HL, _back_safe
                    PUSH    HL
                    CALL    _receive_byte
                    POP     HL
                    RET
_back_safe          XOR     A
                    RET     

;
; Receive a byte with timeout
; If success: A contains byte, non-zero flag set
; Otherwise : Pops the return address off the stack and returns to the original caller with A containing YMODEM_TIMEOUT
;
_receive_byte       PUSH    BC
                    LD      BC, _TIMEOUT_COUNT
_receive_loop       IN      A, (UART_LINE_STATUS)
                    BIT     0, A
                    JR      NZ, _receive_ready
                    LD      A, B
                    LD      B, 10
_rx_delay           AND     A
                    DJNZ    _rx_delay
                    LD      B, A
                    DEC     BC
                    LD      A, B
                    OR      C
                    JR      NZ, _receive_loop
                    POP     BC
                    POP     BC
                    LD      A, YMODEM_TIMEOUT
                    AND     A
                    RET

_receive_ready      IN      A, (UART_TX_RX)
                    POP     BC
                    RET

;
; Send a byte with timeout
; If success: returns normally, no registers affected
; Otherwise : Pops the return address off the stack and returns to the original caller with A containing YMODEM_SEND_TIMEOUT
;
_send_byte          PUSH    BC
                    PUSH    AF
                    LD      BC, _TIMEOUT_COUNT
_send_loop          IN      A, (UART_LINE_STATUS)
                    BIT     5, A
                    JP      NZ, _send_ready             ; Bit 5 is set when the UART is ready
                    DEC     BC
                    LD      A, B
                    OR      C
                    JP      NZ, _send_loop

                    POP     AF
                    POP     BC
                    POP     BC

                    LD      A, YMODEM_SEND_TIMEOUT
                    AND     A
                    RET

_send_ready         POP     AF
                    POP     BC
                    OUT     (UART_TX_RX), A
                    RET

                    .MODULE main