;
; YModem implementation.
; File format: The filename MAY indicate the load address in memory for the file. If so, the format is:
;       filename_yHHHH.suffix
;
; Where:  _yHHHH indicates a preferred destination address of HHHH - four digits hexadecimal value (uppercase).
;

                    .MODULE ymodem

_FLASH_PREFIX       .EQU    'f'
_DEST_PREFIX        .EQU    'y'

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

_dest_set_by_file   .EQU    0FEh            ; File destination set from filename

ymodem_data_length  .EQU    12              ; Size of data block before buffer
file_mode           .EQU    -12             ; FFh : Normal transfer,  FEh : Destination set by file, 0-7Fh : Flash write 
file_count          .EQU    -11
length_low          .EQU    -10
length_high         .EQU    -9
dest_low            .EQU    -8
dest_high           .EQU    -7
current_packet      .EQU    -6
packet_type         .EQU    -5
recieved_packet     .EQU    -4
recieved_packet_cpl .EQU    -3
crc_low             .EQU    -2
crc_high            .EQU    -1

YMODEM_BUFFER       .EQU    _SOH_PACKET_SIZE + ymodem_data_length

;
; ymodem - Main entry point. Call with:
;     HL = Address of YMODEM_BUFFER (=128 + ymodem_data_length) byte buffer for receiving data
;     DE = (Optional) address to write data. 0xFFFF to accept destination from filename otherwise
;
; Returns status code in A:
;     YMODEM_SUCCESS : (=0) If the file was successfully received
;     YMODEM_xxxx    : (Non zero) If the receiver timed out waiting for a byte
;
;

ymodem              LD      BC, ymodem_data_length      ; Skip data block at start of buffer
                    ADD     HL, BC
                    PUSH    HL
                    POP     IX
                    XOR     A                           
                    LD      (IX+file_count), A
                    DEC     A
                    LD      (IX+file_mode), A
                    LD      (IX+dest_low), E
                    LD      (IX+dest_high), D

_ymodem_start       XOR     A                           ; Set initial packet number
                    LD      (IX+current_packet), A
                    LD      IY, 0FFFFh                  ; IY - bytes to load. Default - load all bytes

_packet_loop        CALL    _recieve_safe
                    JR      NZ, _packet_byte
_send_crc_and_loop  LD      A, _C
                    CALL    _send_byte
                    JR      _packet_loop

_packet_byte        CP      _SOH
                    JP      NZ, _check_stx

; SOH - May be zero'th or last packet
                    PUSH    IX
                    POP     HL
                    LD      BC, _SOH_PACKET_SIZE
                    JR      _receive_packet

_check_stx          CP      _STX
                    JR      NZ, _check_eot
                                                        ; STX packets go straight to DE
                    LD      H, D
                    LD      L, E
                    LD      BC, _STX_PACKET_SIZE    
                    JR      _receive_packet

_check_eot          CP      _EOT
                    JR      NZ, _check_can
                                                        ; End of transmission
                    LD      A, _ACK 
                    CALL    _send_byte

                    INC     (IX+file_count)      
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
; At this point HL is destination, and BC is a byte count
_receive_packet     LD      (IX+packet_type), A         
                    XOR     A
                    CP      (IX+current_packet)         ; If this is the zeroth packet, it must be SOH
                    JR      NZ, _not_zeroth_packet
                    LD      A, _SOH
                    SUB     (IX+packet_type)            ; Leave A as zero if this is OK
                    JR      NZ, _zero_error

_not_zeroth_packet  LD      (IX+crc_high), A
                    LD      (IX+crc_low), A

                    CALL    _receive_byte   
                    LD      (IX+recieved_packet), A
                    CALL    _receive_byte   
                    LD      (IX+recieved_packet_cpl), A

_data_loop          CALL    _receive_byte
                    LD      (HL), A

                    CALL    _calc_checksum  

                    PUSH    BC                          ; Count down the bytes remaining, and stop increasing HL once we reach 0
                    LD      BC, -1
                    ADD     IY, BC                      ; Carry set if IY not zero
                    POP     BC
                    JR      C, _in_range
                    INC     IY
                    DEC     HL

_in_range           INC     HL
                    DEC     BC

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

                    LD      A, (IX+recieved_packet)
                    CPL
                    CP      (IX+recieved_packet_cpl)
                    LD      A, _ERR_PACKET_COUNT
                    JR      NZ, _packet_error
                    LD      A, (IX+crc_high)
                    CP      B
                    LD      A, _ERR_CHECK_HIGH
                    JR      NZ, _packet_error
                    LD      A, (IX+crc_low)
                    CP      C
                    LD      A, _ERR_CHECK_LOW
                    JR      NZ, _packet_error

; CRC and packet number check out... 
                    LD      A, (IX+recieved_packet)
                    CP      (IX+current_packet)
                    JR      NZ, _send_nak
                    INC     (IX+current_packet)
                    AND     A
                    JR      Z, _header_packet

                    LD      A, (IX+packet_type)
                    CP      _SOH
                    JR      NZ, _not_soh

; SOH packets must be copied to DE -> 
                    PUSH    IY                      ; Calculate how many bytes left..
                    POP     BC
                    LD      HL, _SOH_PACKET_SIZE
                    AND     A
                    SBC     HL, BC
                    
                    PUSH    IY
                    POP     BC
                    LD      IY, 0                   ; Set IY to zero in case there is:

                    JR      NC, _copy_soh           ; Less than a full packet remaining..

                    PUSH    IY                      ; Otherwise, calculate remaining bytes..
                    POP     HL
                    LD      BC, _SOH_PACKET_SIZE
                    AND     A
                    SBC     HL, BC
                    PUSH    HL
                    POP     IY
                    LD      BC, _SOH_PACKET_SIZE    ;..given we're transferring the whole packet..

_copy_soh           PUSH    IX
                    POP     HL     
                    LDIR
                    LD      H, D
                    LD      L, E

_not_soh            LD      D, H
                    LD      E, L
_send_ack           LD      A, _ACK 
_send_and_loop      CALL    _send_byte
                    JP      _send_crc_and_loop      

_send_nak           CALL   _recieve_safe                ; Drain the incoming stream before sending nak
                    JR      NZ, _send_nak

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

_check_filecount    LD      A, (IX+file_count)
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

_check_flash        CP      _FLASH_PREFIX
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

_digit_checked      PUSH    HL
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

                    LD      A, 0FFh                     ; Only set the dest from the filename if 
                    CP      (IX+dest_low)               ; the routine was called with a destination of 0FFFFh
                    JR      NZ, _next_filechar
                    CP      (IX+dest_high)
                    JR      NZ, _next_filechar
                    
                    LD      (IX+file_mode), _dest_set_by_file
                    LD      A, C                        ; Which char did we start with?
                    CP      _FLASH_PREFIX
                    JR      NZ, _set_dest

                    LD      (IX+file_mode), E
                    LD      DE,04000h

_set_dest           LD      (IX+dest_low), E
                    LD      (IX+dest_high), D

                    JR      _next_filechar

_invalid_dest       LD      E, (IX+dest_low)            ; We silently skip invalid destination values
                    LD      D, (IX+dest_high)
                    JR      _next_filechar

_read_length        LD      A, 0FFh                     ; At this point we should have a valid destination
                    CP      (IX+dest_low)               
                    JR      NZ, _dest_ok
                    CP      (IX+dest_high)
                    JR      NZ, _dest_ok

                    LD      A, YMODEM_NO_DEST
                    AND     A
                    RET

_dest_ok            LD      B, H
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
                    PUSH    DE
                    LD      D, H
                    LD      E, L
                    ADD     HL, HL
                    ADD     HL, HL
                    ADD     HL, DE
                    ADD     HL, HL
                    LD      E, A
                    LD      D, 0
                    ADD     HL, DE
                    POP     DE
                    JR      _parse_length
_length_end         PUSH    HL
                    POP     IY
                    LD      (IX+length_low), L
                    LD      (IX+length_high), H
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
                    LD      H, (IX+crc_high)
                    LD      L, (IX+crc_low)

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

                    LD      (IX+crc_high), H
                    LD      (IX+crc_low), L
                    POP     BC
                    POP     HL
                    RET

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
