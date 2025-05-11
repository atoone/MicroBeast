;
; Monitor using CP/M BIOS
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
                    .MODULE  main

MONITOR_START       .EQU   0DB00h

                    .ORG   MONITOR_START
                    CALL   configure_hardware

                    LD      A, 1
                    LD      (iobyte), A

                    LD      A, DRIVE_B_PAGE
                    LD      (drive_b_mem_page), A

_clock_check        LD      HL, timer_int
                    LD      (0FDFEh), HL

                    LD      A, 1
                    LD      (timer), A
                    LD      A, 3
                    CALL    detect_int

                    LD      A, C
                    OR      B
                    JR      NZ, _clock_detected

_no_clock           CALL    m_print_inline
                    .DB     ".", 0

                    CALL    _do_reti
                    JR      _clock_check

_clock_detected     LD      A, 7
                    CALL    detect_int
                    LD      A, C
                    OR      B 
                    JR      Z, _no_clock

                    ; At this point BC ~= 13 * (clock * 100)
                    ; Divide by 13, round lowest digit up/down

                    PUSH    BC
                    POP     HL
                    LD      C, 13
                    CALL    divide_hl_c

                    PUSH    HL
                    POP     DE
                    CALL    de_to_bcd

                    LD      A, (bcd_scratch)         ; Units
                    CP      6
                    JR      C, _display_speed

                    LD      HL, (bcd_scratch+1)
                    LD      B,  4

_increment_bcd      LD      A, (HL)
                    INC     A
                    LD      (HL), A
                    CP      10
                    JR      C, _display_speed        ; No carry here
                    XOR     A
                    LD      (HL), A
                    INC     HL
                    DJNZ    _increment_bcd

_display_speed      LD      A, (bcd_scratch+3)
                    AND     A
                    JR      Z, _skip_leading
                    ADD     A, '0'
                    LD      (_speed_value),A
_skip_leading       LD       A, (bcd_scratch+2)
                    ADD     A, '0'
                    LD      (_speed_value+1), A
                    LD      A, (bcd_scratch+1)
                    ADD     A, '0'
                    LD      (_speed_value+3), A

                    LD      BC, 60h
                    CALL    pause_for_ticks

                    CALL    m_print_inline
                    .DB     NEWLINE, CARRIAGE_RETURN, "Clock speed "
_speed_value        .DB     " 0,0Mhz", 0

                    LD      HL, interrupt_handler
                    LD      (0FDFEh), HL

                    LD      BC, 60h
                    CALL    pause_for_ticks

                    CALL    m_print_inline
                    .DB     NEWLINE, CARRIAGE_RETURN, "MicroBeast Monitor 1.6", 0

                    LD      BC, 60h
                    CALL    pause_for_ticks

                    LD      C, NEWLINE
                    CALL    bios_conout

_monitor_menu       CALL    rtc_display_time

                    LD      BC, 040h
                    CALL    pause_for_ticks

_monitor_read       CALL    bios_conist
                    AND     A
                    JR      Z, _monitor_menu

                    CALL    bios_conin

                    LD      HL, main_menu
                    CALL    start_menu
                    JR      _monitor_menu


boot_cpm            CALL    m_print_inline
                    .DB     NEWLINE, CARRIAGE_RETURN, "Format RAM disk", 0

                    CALL    format_memdisk

boot_without_format LD      HL, bios_boot
                    PUSH    HL
                    JP      load_ccp


main_menu           .DB     "Select action", 0

                    .DW     boot_cpm
                    .DB     "Launch CP/M", 0

                    .DW     memory_view
                    .DB     "Memory Editor", 0

                    .DW     ymodem_loader
                    .DB     "Y-Modem Transfer", 0

                    .DW     set_date
                    .DB     "Set Date", 0

                    .DW     set_time
                    .DB     "Set Time", 0
                    .DW     0


                    .INCLUDE monitor_dates.asm


ymodem_loader       XOR     A
                    LD      (_ymodem_set), A
                    LD      HL, ymodem_menu
                    CALL    start_menu
                    
                    LD      A, (_ymodem_set)
                    AND     A
                    RET     Z

                    LD      DE, (_ymodem_address)
                    LD      A, (_ymodem_page)
                    LD      HL, MONITOR_START-YMODEM_BUFFER
                    DI
                    CALL    ymodem
                    EI
                    AND     A
                    JP      Z, _ymodem_success

                    DEC     A
                    LD      E, A
                    LD      D, 0
                    LD      HL, _ymodem_errors
                    ADD     HL, DE
                    ADD     HL, DE

                    LD      A, (HL)
                    INC     HL
                    LD      H, (HL)
                    LD      L, A

                    LD      A, C
                    ADD     A, '0'
                    LD      (_packet_err_code), A

                    PUSH    HL
                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "ERROR: ", 0

                    POP     HL

_ymodem_err_loop    LD      A, (HL)
                    INC     HL
                    AND     A
                    JP      Z, bios_conin                   ; Wait for a key then go to main menu..
                    LD      C, A
                    PUSH    HL
                    CALL    bios_conout
                    POP     HL
                    JR      _ymodem_err_loop

_ymodem_errors      .DW     _y_msg_timeout
                    .DW     _y_msg_unknown
                    .DW     _y_msg_cancel     
                    .DW     _y_msg_packet
                    .DW     _y_msg_length
                    .DW     _y_msg_no_dest
                    .DW     _y_msg_send
                    .DW     _y_msg_files

_y_msg_timeout      .DB     "Timeout", ESCAPE_CHAR, "K", 0
_y_msg_unknown      .DB     "Unknown packet", ESCAPE_CHAR, "K", 0
_y_msg_cancel       .DB     "Cancel", ESCAPE_CHAR, "K", 0
_y_msg_packet       .DB     "Packet (", 

_packet_err_code    .DB     "0)", ESCAPE_CHAR, "K", 0

_y_msg_length       .DB     "File length", ESCAPE_CHAR, "K", 0
_y_msg_no_dest      .DB     "No destination", ESCAPE_CHAR, "K", 0
_y_msg_send         .DB     "Send Timeout", ESCAPE_CHAR, "K", 0
_y_msg_files        .DB     "Multiple files", ESCAPE_CHAR, "K", 0

_ymodem_success     CALL    m_print_inline           
                    .DB     CARRIAGE_RETURN, "OK ",0
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_length_high)
                    CP      0FFh
                    JR      Z, _ymodem_no_high
                    ADD     A, '0'
                    LD      C, A
                    CALL    bios_conout
_ymodem_no_high     LD      A, (MONITOR_START-YMODEM_INFO+ym_length_mid)
                    CALL    hex_out
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_length_low)
                    CALL    hex_out
                    CALL    m_print_inline
                    .DB     " BYTES @ ", 0
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_file_mode)
                    RLA
                    JR      C, _ymodem_show_addr
                    RRA
                    CALL    hex_out
                    LD      C, '/'
                    CALL    bios_conout
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_dest_high)
                    SUB     40h
                    JR      _ymodem_addr

_ymodem_show_addr   LD      A, (MONITOR_START-YMODEM_INFO+ym_dest_high)
_ymodem_addr        CALL    hex_out
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_dest_low)
                    CALL    hex_out
                    CALL    m_print_inline
                    .DB     ESCAPE_CHAR, "K", 0
_ymodem_waitkey     CALL    bios_conist                  
                    AND     A
                    JR      Z, _ymodem_waitkey

                    CALL    bios_conin


                    LD      A, (MONITOR_START-YMODEM_INFO+ym_file_mode)      ; Do something with the file.
                    RLA
                    JR      NC, _ymodem_handle_page

                    LD      HL, ymodem_mem_menu
                    JP      start_menu


_ymodem_handle_page LD      HL, ymodem_page_menu
                    JP      start_menu

_ymodem_view        LD      HL, (MONITOR_START-YMODEM_INFO+ym_dest_low)
                    LD      (monitor_address), HL
                    JP      edit_memory

_ymodem_exec        LD      HL, (MONITOR_START-YMODEM_INFO+ym_dest_low)
                    PUSH    HL
_ymodem_exit        RET

_ymodem_flash       CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, NEWLINE, "Page 00-1f >", ESCAPE_CHAR, "K", 0

                    LD      B, 2
                    CALL    hex_input
                    CALL    delete_or_enter
                    LD      A, (hex_input_result)
                    CP      1fh
                    JR      NC, _ymodem_flash

                    CALL    m_print_inline
                    .DB     " Y/N?", 0
                    CALL    bios_conin
                    CP      'y'
                    JR      NZ, _ymodem_handle_page

                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, NEWLINE, "Writing", ESCAPE_CHAR, "K", 0

                    LD      A, (hex_input_result)
                    RLA
                    RLA
                    LD      D, A

                    LD      A, (MONITOR_START-YMODEM_INFO+ym_file_mode)         ; Page loaded
_next_page          LD      (_ymodem_page), A
                    OUT     (IO_MEM_1), A

                    LD      HL, (MONITOR_START-YMODEM_INFO+ym_length_mid)
                    LD      A, L
                    AND     0c0h
                    OR      H
                    JR      NZ, _full_page

                    LD      BC, (MONITOR_START-YMODEM_INFO+ym_length_low)
                    LD      A, B
                    OR      C
                    JR      Z, _flash_done
                    LD      HL, 4000h
                    CALL    flash_write

_flash_done         LD      A, RAM_PAGE_0
                    OUT     (IO_MEM_0), A

                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, NEWLINE, "Done ", ESCAPE_CHAR, "K", 0           
                    JP      bios_conin

_full_page          LD      BC, 0040h
                    XOR     A
                    SBC     HL, BC
                    LD      (MONITOR_START-YMODEM_INFO+ym_length_mid), HL
                    LD      HL, 4000h
                    LD      B, H
                    LD      C, L
                    CALL    flash_write
                    INC     D
                    LD      A,(_ymodem_page)
                    INC     A
                    JR      _next_page

_ymodem_firmware    LD      A, (MONITOR_START-YMODEM_INFO+ym_length_high)
                    AND     A
                    JR      NZ, _not_firmware
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_length_mid)
                    CP      040h
                    JR      NC, _not_firmware

                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "Write firmware, Y/N?", ESCAPE_CHAR, "K", 0
                    CALL    bios_conin
                    CP      'y'
                    JP      NZ, _ymodem_handle_page

                    LD      BC, (MONITOR_START-YMODEM_INFO+ym_length_low)
                    LD      A, (MONITOR_START-YMODEM_INFO+ym_file_mode)         ; Page loaded
                    OUT     (IO_MEM_1), A
                    
                    LD      HL, 4000h
                    LD      D, 0
                    CALL    flash_write

                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, NEWLINE, "Done ", ESCAPE_CHAR, "K", 0
                    LD      DE, (MONITOR_START-YMODEM_INFO+ym_length_low)
                    CALL    hex_word
                    JP      bios_conin

_not_firmware       CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, NEWLINE, "Too large", ESCAPE_CHAR, "K", 0
                    JP      bios_conin


_ymodem_address     .DW     0
_ymodem_page        .DB     0
_ymodem_set         .DB     0

ymodem_mem_menu     .DB     "File actions", 0
                    .DW     _ymodem_view
                    .DB     "View file", 0
                    .DW     _ymodem_exec
                    .DB     "Run", 0
                    .DW     _ymodem_exit
                    .DB     "Main menu", 0
                    .DW     0

ymodem_page_menu    .DB     "File actions", 0
                    .DW     _ymodem_flash
                    .DB     "Copy to flash", 0
                    .DW     boot_without_format
                    .DB     "CPM Drive B", 0
                    .DW     _ymodem_firmware
                    .DB     "Update firmware", 0
                    .DW     _ymodem_exit
                    .DB     "Main menu", 0
                    .DW     0

ymodem_menu         .DB     "Download options", 0
                    .DW     _ymodem_from_file
                    .DB     "Address from file", 0
                    .DW     _ymodem_logical
                    .DB     "CPU (Logical) address",0
                    .DW     _ymodem_physical
                    .DB     "Physical address", 0
                    .DW     0

_ymodem_from_file   LD      DE, 0FFFFh
                    LD      (_ymodem_address), DE
                    LD      (_ymodem_page), DE
_ymodem_transfer    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "Start transfer", ESCAPE_CHAR, "K", 0
                    RET

_ymodem_logical     CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "Address 0000-FFFF >", ESCAPE_CHAR, "K", 0
                    LD      B, 4
                    CALL    hex_input
                    CALL    delete_or_enter
                    LD      A, 0FFh
                    LD      (_ymodem_page), A

_ymodem_set_and_go  LD      DE, (hex_input_result)
                    LD      (_ymodem_address), DE
                    LD      A, 0FFh
                    LD      (_ymodem_set), A
                    JR      _ymodem_transfer

_ymodem_physical    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "Page 20-3F >", ESCAPE_CHAR, "K", 0
                    LD      B, 2
                    CALL    hex_input
                    CALL    delete_or_enter
                    LD      A, (hex_input_result)
                    LD      (_ymodem_page), A
                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, "Offset 0000-3FFF >", ESCAPE_CHAR, "K", 0
                    LD      B, 4
                    CALL    hex_input
                    CALL    delete_or_enter
                    LD      A, (hex_input_result+1)         ; YModem loads to page 1, so allow for offset..
                    OR      040h
                    LD      (hex_input_result+1), A
                    JR      _ymodem_set_and_go

;------------------------------ Memory Editor --------------------------------------------

monitor_address     .DW     08000h              ; Default address is 0x8000
monitor_mode        .DB     0                   ; 0 = show address + 3 characters, ~0 = hide address + 8 characters
edit_col            .DB     0                   ; Column currently being edited..
edit_digit          .DW     0

memory_view         CALL    display_mem_row

_wait_key           CALL    bios_conist
                    AND     A
                    JR      Z, _wait_key
                    CALL    bios_conin

                    CP      KEY_UP
                    JR      NZ, _not_up
memory_up           LD      HL, (monitor_address)
                    LD      DE, 8
                    SBC     HL, DE
                    LD      (monitor_address), HL
                    JR      memory_view

_not_up             CP      KEY_DOWN
                    JR      NZ, _not_down
memory_down         LD      HL, (monitor_address)
                    LD      DE, 8
                    ADD     HL, DE
                    LD      (monitor_address), HL
                    JR      memory_view

_not_down           CP      ' '
                    JR      NZ, _not_space
                    LD      A, (monitor_mode)
                    CPL
                    LD      (monitor_mode), A
                    JR      memory_view

_not_space          CP      CARRIAGE_RETURN
                    JR      Z, _input_address

                    CP      KEY_RIGHT
                    JP      Z, edit_memory
                    CP      KEY_BACKSPACE
                    RET     Z

                    CP      'x'
                    JR      Z, execute
                    JR      _wait_key

_input_address      XOR     A
                    LD      (monitor_mode), A
                    CALL    display_mem_row
                    LD      C, CARRIAGE_RETURN
                    CALL    bios_conout

                    LD      B, 4
                    CALL    hex_input
                    LD      HL, (hex_input_result)
                    LD      (monitor_address), HL
                    JP      memory_view

execute             XOR     A
                    LD      (edit_col), A
execute_col         CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, ESCAPE_CHAR, 'b', CPM_NUM+15, "Execute from ", 0
                    LD      HL, _exec_done
                    PUSH    HL
                    LD      HL, (monitor_address)
                    LD      A, (edit_col)
                    LD      E, A
                    LD      D, 0
                    ADD     HL, DE
                    
                    PUSH    HL
                    EX      DE, HL
                    CALL    hex_word
                    CALL    m_print_inline
                    .DB     " Y/N?", ESCAPE_CHAR, "K", 0

_exec_loop          CALL    bios_conin
                    CP      'y'
                    JR      Z, _exec_go
                    CP      'n'
                    JR      NZ, _exec_loop
                    POP     HL
                    POP     HL
                    JP      memory_view

_exec_go            CALL    m_print_inline
                    .DB     NEWLINE, CARRIAGE_RETURN, "Running", ESCAPE_CHAR, "K", 0
                    RET

_exec_done          PUSH    AF
                    CALL    m_print_inline
                    .DB     NEWLINE, CARRIAGE_RETURN, "Done. A=",0
                    POP     AF
                    CALL    hex_out
                    CALL    m_print_inline
                    .DB     ESCAPE_CHAR, "K", 0
                    CALL    bios_conin ;pause for a key, then return to memory edit at the execution location


edit_memory         XOR     A
_set_col_and_edit   LD      (edit_col), A
_edit_loop          CALL    display_mem_row
                    LD      A, (edit_col)
                    ADD     A, A
                    LD      C, A
                    LD      A, (monitor_mode)
                    AND     A
                    JR      NZ, _address_hidden
                    LD      A, 5
                    ADD     A, C
                    LD      C, A
_address_hidden     LD      A, (cursor_row)
                    ADD     A, 31
                    LD      (_edit_set_row), A
                    LD      A, C
                    ADD     A, 32
                    LD      (_edit_set_col), A

                    CALL    m_print_inline
                    .DB     ESCAPE_CHAR, 'b', CPM_NUM+8         ; Set the correct brightness
                    .DB     ESCAPE_CHAR, 'Y'                    ; And position the cursor
_edit_set_row       .DB     0
_edit_set_col       .DB     0
                    .DB     0

                    LD      DE, 0200h
_edit_next_digit    LD      (edit_digit), DE

_edit_input         CALL    bios_conin
                    CP      'x'
                    JP      Z, execute_col

                    CP      KEY_RIGHT
                    JR      NZ, _not_right
_edit_right         LD      A, (edit_col)
                    CP      7
                    JR      Z, _edit_wrap_down
                    INC     A
                    JR      _set_col_and_edit

_edit_wrap_down     XOR     A
                    LD      (edit_col),A
_edit_down          LD      DE, 08h
_edit_move          LD      HL, (monitor_address)
                    ADD     HL, DE
                    LD      (monitor_address), HL
                    JP      _edit_loop

_not_right          CP      KEY_LEFT
                    JR      NZ, _not_left
                    LD      A, (edit_col)
                    AND     A
                    JR      Z, _edit_wrap_up
                    DEC     A
                    JR      _set_col_and_edit

_edit_wrap_up       LD      A, 7
                    LD      (edit_col),A
_edit_up            LD      DE, 0FFF8h
                    JR      _edit_move

_not_left           CP      KEY_UP
                    JP      Z, _edit_up
                    CP      KEY_DOWN
                    JP      Z, _edit_down
                    CP      KEY_BACKSPACE
                    JP      NZ, _not_delete

                    LD      A, (edit_digit+1)
                    CP      2
                    JP      Z, memory_view
                    JP      _edit_loop

_not_delete         CALL    valid_hex_char
                    JR      C, _edit_input

                    LD      C, A
                    CALL    hex_char_to_num
                    PUSH    AF
                    CALL    bios_conout
                    POP     AF
                    
                    LD      DE, (edit_digit)
                    SLA     E
                    SLA     E
                    SLA     E
                    SLA     E
                    OR      E
                    LD      E, A
                    DEC     D
                    JR      NZ, _edit_next_digit

                    LD      A, (edit_col)
                    LD      C, A
                    LD      B, 0
                    LD      HL, (monitor_address)
                    ADD     HL, BC
                    LD      (HL), E
                    CALL    display_mem_row
                    JR      _edit_right

display_mem_row     LD      C, CARRIAGE_RETURN
                    CALL    bios_conout
                    LD      A, (monitor_mode)
                    AND     A
                    JR      NZ, _hex_values

                    CALL    m_print_inline
                    .DB     CARRIAGE_RETURN, ESCAPE_CHAR, 'b', CPM_NUM+15, 0

                    LD      DE, (monitor_address)
                    CALL    hex_word

                    LD      C, ' '
                    CALL    bios_conout

_hex_values         CALL    m_print_inline
                    .DB     ESCAPE_CHAR, 'b', CPM_NUM+8, 0

                    LD      HL, (monitor_address)
                    LD      B, 8
_mem_hex            LD      A, (HL)
                    PUSH    HL
                    PUSH    BC
                    CALL    hex_out
                    POP     BC
                    POP     HL
                    INC     HL
                    DJNZ    _mem_hex

                    CALL    m_print_inline
                    .DB     ESCAPE_CHAR, 'b', CPM_NUM+15, 0

                    LD      HL, (monitor_address)
                    LD      B, 3
                    LD      A, (monitor_mode)
                    AND     A
                    JR      Z, _mem_char
                    LD      B, 8

_mem_char           LD      A, (HL)
                    CP      ' '
                    JP      NC, _not_control_char
                    LD      A, '.'
_not_control_char   CP      128
                    JP      C, _not_extended_char
                    LD      A, '.'
_not_extended_char  PUSH    HL
                    PUSH    BC
                    LD      C, A
                    CALL    bios_conout
                    POP     BC
                    POP     HL
                    INC     HL
                    DJNZ    _mem_char
                    RET

; Format memory disk
;
format_memdisk      LD      A, 1
                    LD      C, A
                    CALL    bios_seldsk

                    LD      HL, BIOS_SECTOR_ADDRESS     ; Sector buffer
                    LD      (_fmt_address),HL

                    LD      D, H                        ; Fill sector buffer with 0E5h (blank byte)
                    LD      E, L
                    INC     DE
                    LD      A, 0E5h
                    LD      (HL),A
                    LD      BC, 07fh
                    LDIR

                    LD      A,BIOS_BOOT_TRACKS          ; First track (Offset = 2)
_fmt_track_loop     LD      (_fmt_track),A
                    LD      C,A                         ; Set track
                    CALL    bios_settrk

                    XOR     A                           ; Initial sector
_fmt_sector_loop    LD      (_fmt_sector),A

                    CP      MEMDISK_SECTORS
                    JR      Z,_fmt_next_track
                    LD      C,A                         ; Set sector
                    CALL    bios_setsec
                    LD      BC,(_fmt_address)           ; Address to write from
                    CALL    bios_setdma
                    CALL    bios_write
                    LD      A,(_fmt_sector)

                    INC     A
                    JR      _fmt_sector_loop

_fmt_next_track     LD      A,(_fmt_track)
                    CP      MEMDISK_TRACKS
                    RET     Z
                    INC     A
                    JR      _fmt_track_loop

_fmt_track          .DB     0
_fmt_sector         .DB     0
_fmt_address        .DW     0

;------------------------------------------------------
; Read hex input into the (input_hex) address
; Params - B = number of characters to input
;
hex_input           LD      A, B
                    LD      (_hi_size), A
                    LD      HL, 0
                    LD      (hex_input_result), HL

_hi_loop            PUSH    BC
_hi_loop_join       CALL    hex_char_in
                    CP      KEY_BACKSPACE
                    JR      Z, _hi_delete
                    LD      C, A
                    PUSH    AF
                    CALL    bios_conout
                    POP     AF
                    CALL    hex_char_to_num
                    LD      HL, (hex_input_result)
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A

                    SLA     A
                    RL      L
                    RL      H
                    SLA     A
                    RL      L
                    RL      H
                    SLA     A
                    RL      L
                    RL      H
                    SLA     A
                    RL      L
                    RL      H
                    LD      (hex_input_result), HL
                    POP     BC
                    DJNZ    _hi_loop
                    RET

_hi_size            .DB     0

_hi_delete          POP     BC
_hi_delete_join     LD      A, (_hi_size)
                    CP      B
                    JR      Z, _hi_loop
                    INC     B
                    PUSH    BC

                    LD      HL, (hex_input_result)
                    SRL     H
                    RR      L
                    SRL     H
                    RR      L
                    SRL     H
                    RR      L
                    SRL     H
                    RR      L
                    LD      (hex_input_result), HL

                    CALL    m_print_inline
                    .DB     ESCAPE_CHAR, "D ", ESCAPE_CHAR, "D", 0
                    JR      _hi_loop_join

hex_input_result    .DW     0

delete_or_enter     ; Wait for Delete or enter keys and handle..
                    CALL    bios_conin
                    CP      CARRIAGE_RETURN
                    RET     Z
                    LD      B, 0
                    CP      KEY_BACKSPACE
                    CALL    Z, _hi_delete_join
                    JR      delete_or_enter


;------------------------------------------------------
; Menu system
menu_index          .DB     0
menu_address        .DW     0
menu_current        .DW     0

start_menu          XOR    A
                    LD     (menu_index), A
                    LD     (menu_address), HL

_menu_loop          CALL   _display_menu
                    LD     BC, 600
                    CALL   pause_for_ticks
                    CALL   bios_conist
                    AND    A
                    RET    Z

_menu_key           CALL   bios_conin
                    CP     KEY_DOWN
                    JR     NZ, _menu_up

                    LD      A, (menu_index)
                    INC     A
_menu_set_index     LD      (menu_index),A
                    JR      _menu_loop

_menu_up            CP      KEY_UP
                    JR      NZ, _menu_delete
                    LD      A, (menu_index)
                    DEC     A
                    JR      Z, _menu_loop
                    JR      _menu_set_index

_menu_delete        CP      KEY_BACKSPACE
                    RET     Z

_menu_enter         CP      KEY_ENTER
                    JR      NZ, _menu_loop
                    LD      A, (menu_index)
                    AND     A
                    JR      Z, _menu_loop
                    LD      HL, (menu_current)
                    LD      A, (HL)
                    INC     HL
                    LD      H, (HL)
                    LD      L, A
                    PUSH    HL
                    RET



_display_menu       LD      C, CARRIAGE_RETURN
                    CALL    bios_conout

                    LD      A, (menu_index)
                    LD      HL, (menu_address)
_entry_loop         AND     A
                    JR      Z, _display_entry
                    LD      B, A
_next_menu          LD      A, (HL)
                    INC     HL
                    AND     A
                    JR      NZ, _next_menu

                    LD      (menu_current), HL
                    LD      A, (HL)
                    INC     HL
                    LD      E, (HL)
                    INC     HL
                    OR      E
                    JR      Z, _menu_end
                    DJNZ    _next_menu
                    
_display_entry      LD      A, (HL)
                    AND     A
                    JR      Z, _entry_end
                    LD      C, A
                    PUSH    HL
                    CALL    bios_conout
                    POP     HL
                    INC     HL
                    JR      _display_entry
_entry_end          LD      C, ESCAPE_CHAR
                    CALL    bios_conout
                    LD      C, 'K'
                    JP      bios_conout

_menu_end           LD      A, (menu_index)
                    DEC     A
                    LD      (menu_index), A
                    JR      _display_menu


;------------------------------------------------------
; Write the Hex value of DE as four characters to conout
;
hex_word            PUSH    DE
                    LD      A, D
                    CALL    hex_out
                    POP     DE
                    LD      A, E                ; Fall into hex_out..

;------------------------------------------------------
; Write the Hex value of A as two characters to conout
;
hex_out             LD      C, A
                    SRL     A
                    SRL     A
                    SRL     A
                    SRL     A
                    PUSH    BC
                    CALL    _nibble
                    POP     BC
                    LD      A, C

_nibble             AND     $0F      ;LOW NIBBLE ONLY
                    ADD     A,$90
                    DAA 
                    ADC     A,$40
                    DAA 
                    LD      C,A
                    JP      bios_conout


;------------------------------------------------------
; Only accept hex characters (0-9, a-f), or DELETE from the input
; Returns with character in A, a-f are capitalised
;
hex_char_in         CALL    bios_conin
                    CP      KEY_BACKSPACE
                    RET     Z
                    CALL    valid_hex_char
                    JR      C, hex_char_in
                    RET
;
; Return with carry CLEAR if the character is a valid hex digit
; Enter with A = character to test
; Returns with A capitalised
valid_hex_char      CP      '0'
                    RET     C
                    CP      ':'
                    CCF
                    RET     NC
                    CP      'a'
                    RET     C
                    CP      'g'
                    RES     5, a                ; Capitalise it..
                    CCF
                    RET

hex_char_to_num     CP      'A'
                    JR      NC, _alpha_char
                    SUB     '0'
                    RET
_alpha_char         SUB     'A'-10
                    RET

;
; Pause for BC ticks
; Uses HL, DE
;
pause_for_ticks     LD      DE, (timer)
_pause_loop         PUSH    BC
                    PUSH    DE
                    CALL    bios_conist
                    POP     DE
                    POP     BC
                    AND     A
                    RET     NZ
                    LD      HL, (timer)
                    SBC     HL, DE
                    SBC     HL, BC
                    JR      C, _pause_loop
                    RET
;
; Detect (and time) interrupt
; Enter with A containing the mask for which bits of the timer byte we check for zero
; Return when the timer is zero, with BC containing 72 + 48*t-states taken
;
detect_int          LD      BC, 0
                    LD      D, A
_wait_for_tick      LD      A, (timer)               ; 13            ; Loop = 13+4+5+6+4+4+12 (=48) * BC + (13 + 4 + 11 + 13 + 4 + 17 + 10 (CALL)) = 72
                    AND     D                        ; 4
                    RET     Z                        ; 5 / 11
                    INC     BC                       ; 6
                    LD      A, C                     ; 4
                    OR      B                        ; 4
                    JR      NZ, _wait_for_tick       ; 7 / 12
                    RET
;
; Fast int routine to allow us to time CPU speed
;
timer_int           DI
                    PUSH    HL
                    LD      HL, (timer)
                    INC     HL
                    LD      (timer), HL
                    POP     HL
                    EI
                    RETI

; Divide HL by C (unsigned)
;Inputs:
;     HL is the numerator
;     C is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is not changed
;     DE is not changed
;     HL is the quotient
;
divide_hl_c
                    LD      B, 16
                    XOR     A
_div0               ADD     HL, HL
                    RLA
                    CP      C
                    JR      C,_div1
                    INC     L
                    SUB     C
_div1               DJNZ    _div0
                    RET

;
; Convert DE to a five digit BCD value stored in bcd_scratch
; 
de_to_bcd           XOR     A
                    LD      HL, bcd_scratch
                    LD      B, 5
_clear_scratch      LD      (HL), A
                    INC     HL
                    DJNZ    _clear_scratch
    
                    LD      B, 16           ; Convert 16 bits
_bcd_loop           LD      C, 5
                    LD      HL, bcd_scratch
_correct_digits     LD      A, (HL)
                    CP      5
                    JR      C, _digit_ok
                    ADD     A, 3
                    LD      (HL), A
_digit_ok           INC     HL
                    DEC     C
                    JR      NZ, _correct_digits                   

                    LD      HL, bcd_scratch
                    LD      C, 5
                    SLA     E
                    RL      D

_shift_digits       LD      A, (HL)
                    RL      A
                    BIT     4, A
                    JR      Z, _skip_carry
                    AND     0Fh
                    SCF
_skip_carry         LD      (HL), A
                    INC     HL
                    DEC     C
                    JR      NZ, _shift_digits
                    DJNZ    _bcd_loop
                    RET

bcd_scratch         .DB      0,0,0,0,0      ; Five bytes - 0 to 99,999. Smallest digit (units) first

                    .INCLUDE  "monitor_rtc.asm"
                    .INCLUDE "ymodem.asm"

.IF $ >= BIOS_START
    .ECHO "End of Monitor is too high ("
    .ECHO $
    .ECHO " > "
    .ECHO BIOS_START
    .ECHO ") \n\n"
    .STOP
.ENDIF

.ECHO "Spare after monitor "
.ECHO BIOS_START-$
.ECHO "\n\n"

                    .FILL  BIOS_START-$

                    .INCLUDE "bios.asm"
                    .END
