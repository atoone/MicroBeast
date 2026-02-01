;
; Simple-ish CP/M compatible BIOS
;
; References - http://www.gaby.de/cpm/manuals/archive/cpm22htm/axb.htm - CPM Manual 'Simple skeletal BIOS'
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

BIOS_START          .EQU    0EA00h   ; If this is changed, CP/M must be rebuilt and the disk image updated
BIOS_TOP            .EQU    0FDFDh

CCP                 .EQU    BIOS_START - 01600h
BDOS                .EQU    CCP + 0806h

CCP_SECTOR_COUNT    .EQU    (BIOS_START-CCP)/128

.IF (CCP_SECTOR_COUNT * 128) < (BIOS_START-CCP)
    .ECHO "CCP isn't an exact multiple of 128 byte sectors\n"
    .ECHO "  Got "
    .ECHO (BIOS_START-CCP)
    .ECHO "\n"
    .STOP
.ENDIF

iobyte              .EQU    03h     ; Location of Intel standard I/O definition byte
usrdrv              .EQU    04h     ; Location of Current user number and drive
tpabuf              .EQU    0080h   ; Default I/O buffer and command line storage

IO_BAT              .EQU    02h     ; CONsole IO defined by RDR for input, LST for output

bios_start          .ORG    BIOS_START

                    JP      bios_boot     ;  0 Initialize
wboote              JP      bios_wboot    ;  1 Warm boot
                    JP      bios_conist   ;  2 Console status - Return A = 0FFH if character ready, 00H if not
                    JP      bios_conin    ;  3 Console input  - Wait for input, returning character in A
                    JP      bios_conout   ;  4 Console OUTput - Write character in C to console
                    JP      bios_list     ;  5 List OUTput
                    JP      bios_punch    ;  6 punch OUTput
                    JP      bios_reader   ;  7 Reader input
                    JP      bios_home     ;  8 Home disk
                    JP      bios_seldsk   ;  9 Select disk
                    JP      bios_settrk   ; 10 Select track
                    JP      bios_setsec   ; 11 Select sector
                    JP      bios_setdma   ; 12 Set DMA ADDress
                    JP      bios_read     ; 13 Read 128 bytes
                    JP      bios_write    ; 14 Write 128 bytes
                    JP      bios_listst   ; 15 List status
                    JP      bios_sectrn   ; 16 Sector translate

MEMDISK_SECTORS     .EQU    26
MEMDISK_TRACKS      .EQU    79

BIOS_BOOT_TRACKS    .EQU    2
BIOS_SECTOR_ADDRESS .EQU    tpabuf

DRIVE_A_PAGE        .EQU    04h     ; Page 4 of ROM - offset 010000h
DRIVE_B_PAGE        .EQU    25h     ; Page 5 of RAM

CONSOLE_PAGE        .EQU    24h     ; Page 4 of RAM - Console emulation for non-VideoBeast systems

; Disk Parameter Headers -------------------------------------------------------
; These are 256K discs, equivalent to this disc format (for cpmtools)
; 
; References : https://www.idealine.info/sharpmz/dpb.htm - Explanation of values
;              https://jeelabs.org/article/1715b/        - Bootstrapping CP/M
;
; diskdef memotech-type50
;  seclen 128
;  tracks 79
;  sectrk 26
;  blocksize 1024
;  maxdir 64
;  skew 1
;  boottrk 2
;  os 2.2
; end
;
MAX_DRIVES          .EQU    2

dpbase              .DW     0,0,0,0,dirbuf,dpb0,0,sys_alv0      ; Disk 0 is Flash
                    .DW     0,0,0,0,dirbuf,dpb1,0,sys_alv1      ; Disk 1 is RAM

dpb0                .DW     MEMDISK_SECTORS     ; SPT - sectors per track
                    .DB     3                   ; BSH - block shift factor  BSH+BLM together mean 1024 byte blocksize
                    .DB     7                   ; BLM - block mask
                    .DB     0                   ; EXM - Extent mask
                    .DW     247                 ; DSM - Storage size (blocks - 1)
                    .DW     63                  ; DRM - Number of directory entries - 1
                    .DB     192                 ; AL0 - 1 bit set per directory block
                    .DB     0                   ; AL1 - ... 8 more bits
                    .DW     0                   ; CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
                    .DW     BIOS_BOOT_TRACKS    ; OFF - Reserved tracks

dpb1                .DW     MEMDISK_SECTORS     ; SPT - sectors per track
                    .DB     3                   ; BSH - block shift factor  BSH+BLM together mean 1024 byte blocksize
                    .DB     7                   ; BLM - block mask
                    .DB     0                   ; EXM - Extent mask
                    .DW     247                 ; DSM - Storage size (blocks - 1)
                    .DW     63                  ; DRM - Number of directory entries - 1
                    .DB     192                 ; AL0 - 1 bit set per directory block
                    .DB     0                   ; AL1 - ... 8 more bits
                    .DW     0                   ; CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
                    .DW     BIOS_BOOT_TRACKS    ; OFF - Reserved tracks

dirbuf              .FILL   128, 0 ; disk directory scratch area

; BIOS Entry points ---------------------------------------------------------------

bios_boot     ;  0 Initialize - This is called on first boot when CCP and BIOS have all been read into memory. Initialise hardware and start CCP
                    DI
                    LD      SP,000h
                    LD      HL,BIOS_START        ; Why are we doing this?
                    LD      (0FFFEh),HL
                    CALL    configure_hardware
                    XOR     A
                    LD      (usrdrv),A
                    INC     A
                    LD      (iobyte),A           ; Input on keyboard, output on display

                    LD      A, (boot_mode)       ; If we need to restore the B drive on boot, patch the CCP command
                    AND     BOOT_RESTORE_B       ; See CP/M 2.2 Application Node 01 2/20/82 "The CCP Auto-Load Feature"
                    JR      Z, start_cpm

                    LD      HL, _restore_command ; Auto-run the RESTORE command
                    LD      DE, CCP+7
                    LD      BC, _restore_command_len
                    LDIR
                    LD      A, (boot_mode)       ; Clear the boot_mode flag to prevent accidentally overwriting drive B
                    XOR     BOOT_RESTORE_B
                    LD      (boot_mode), A
                    JR      start_cpm

_restore_command     .DB     7, "RESTORE", 0
_restore_command_len .EQU   $-_restore_command

;------------------------------------------------------                    
bios_wboot    ;  1 Warm boot - Hardware is intialised, but CCP should be reloaded before being run
                    DI
                    LD      SP,000h
                    ;CALL    setup_screen
                    CALL    load_ccp

start_cpm           EI                           ; Make sure interrupts are enabled
                    LD      HL,tpabuf            ; Address of BIOS DMA buffer
                    LD      (sys_dmaaddr),hl
                    LD      A, 0C3h              ; Opcode for 'JP'
                    LD      (00h),A              ; Load at start of RAM
                    LD      HL,wboote            ; Address of jump for a warm boot
                    LD      (01h),HL
                    LD      (05h),a              ; Opcode for 'JP'
                    LD      HL,BDOS              ; Address of jump for the BDOS
                    LD      (06h),HL
                    LD      A,(usrdrv)           ; Save new drive number (0)  ; TODO: Ugh? Where is this set, what does it mean???
                    LD      C, A                 ; Pass drive number in C
                    JP      CCP                  ; Start CP/M by jumping to the CCP

                    ; Load CCP - Note we're doing this through BIOS calls, so if we move the OS to a different
                    ;       drive, the code should still function...
load_ccp            LD      C, 0
                    CALL    bios_seldsk
                    CALL    bios_home            ; Go to track 0

                    LD      B, CCP_SECTOR_COUNT
                    LD      C, 0                 ; Track number
                    LD      D, 0                 ; Sector to read - start with sector 0 (TODO: Check sectors are 0 based)
                    LD      HL, CCP
_read_ccp           PUSH    BC
                    PUSH    DE
                    PUSH    HL
                    LD      C, D                 ; Set the sector to read
                    CALL    bios_setsec
                    POP     BC
                    PUSH    BC
                    CALL    bios_setdma
                    CALL    bios_read
                    AND     A                    ; Reboot if error 
                    JR      NZ, bios_wboot

                    POP     HL                   ; Calculate next address to read
                    LD      DE, 128
                    ADD     HL, DE
                    POP     DE                   ; Count down the sectors
                    POP     BC
                    DEC     B
                    RET     Z                    ; And return if we've read 'em all

                    INC     D                    ; Otherwise, increment sector   
                    LD      A, D
                    CP      27
                    JR      C, _read_ccp

                    LD      D, 1                 ; Or, set sector back to 1 and increment track 
                    INC     C

                    PUSH    BC
                    PUSH    DE
                    PUSH    HL
                    CALL    bios_settrk
                    POP     HL
                    POP     DE
                    POP     BC
                    JR      _read_ccp


                    
;------------------------------------------------------  
bios_conist   ; CONSOLE STATUS, - Return A = 0FFH if character ready, 00H if not
                    LD      A, (iobyte)                ; Check input on CON
                    AND     03h
                    JR      Z, _coninst_tty
                    CP      IO_BAT
                    JR      Z, _coninst_rdr

_coninst_kbd        LD      A, (console_identify)
                    AND     A
                    JR      NZ, _coninst_has_char

                    LD      A, (input_size)
                    AND     A
                    RET     Z
_coninst_has_char   LD      A, 0FFh
                    RET
 
_coninst_tty        XOR     A
                    CALL    uart_ready
                    RET     NC
                    DEC     A
                    RET     
_coninst_rdr        LD      A, (iobyte)                 ; Input is determined by RDR
                    AND     0Ch
                    JR      Z, _coninst_tty
                    JR      _coninst_kbd

;------------------------------------------------------  
bios_conin    ;  3 Console input - Wait for input, returning character in A
                    LD      A, (iobyte)
                    AND     03h
                    JR      Z, _conin_tty
                    CP      02h
                    JR      Z, _conin_rdr
                    
_conin_kbd          LD      A, (console_identify)           ; If the terminal has been sent an identity request escape sequence, return the response
                    DEC     A
                    JP      M, _conin_read_char
                    LD      (console_identify), A
                    LD      HL, _indentity_sequence
                    LD      C, A
                    LD      B, 0
                    ADD     HL, BC
                    LD      A, (HL) 
                    RET        

_conin_tty          CALL    uart_receive
                    RET     C
                    JR      _conin_tty
     
_conin_rdr          LD      A, (iobyte)
                    AND     0ch
                    JR      Z, _conin_tty
                    JR      _conin_kbd

_conin_read_char    LD      A, (input_size)                 ; Don't blink cursor if there is a character already waiting..
                    AND     A
                    JR      Z, _conin_wait
                    JP      get_key

_conin_wait         LD      A, (console_flags)              ; Turn the cursor on..
                    OR      CFLAGS_SHOW_CURSOR
                    LD      (console_flags), A
                    DI
                    LD      DE, (cursor_row)
                    LD      A, D                            ; Force cursor update...
                    DEC     A
                    LD      (cursor_col),A
                    CALL    _conout_csr_update
                    EI
                    CALL    get_key
                    LD      B, A
                    LD      A, (console_flags)
                    AND     ~CFLAGS_SHOW_CURSOR
                    LD      (console_flags), A
                    ;
                    PUSH    BC
                    LD      E, 0
                    DI
                    CALL    update_cursor
                    EI
                    POP     BC
                    LD      A, B
                    RET
     
_indentity_sequence .DB     'K', '/', ESCAPE_CHAR           ; RETURNED BY VT-52 emulation - note sequence is reversed
IDENTITY_LENGTH     .EQU    3

;------------------------------------------------------  
bios_conout   ;  4 Console OUTput  - Write character in C to console
                    LD      A, (iobyte)
                    AND     03h
                    CP      IO_BAT
                    JR      NZ, _conout_disp_tty

                    LD      A, (iobyte)
                    AND     0C0h
                    JR      NZ, _conout_disp 
                    LD      A, C
                    JP      uart_send

_conout_disp_tty    LD      A, C
                    CALL    uart_send

_conout_disp        LD      A, (console_escape)             ; Test to see if handling an escape sequence and expect more parameters
                    OR      A
                    JP      NZ, _conout_escape_seq

                    LD      A, (console_flags)              ; Test to see if we're expecting an escape character
                    AND     CFLAGS_ESCAPE
                    JP      Z, _conout_check_esc

                                                            ; If so, this is the first character after we got an escape...
                    LD      DE, (cursor_row)                ; Get cursor position in DE
                    LD      A,(console_flags)               ; Reset the escape flag
                    AND     ~CFLAGS_ESCAPE
                    LD      (console_flags),A

                    LD      A, C

                    CP      'A'
                    JR      NZ, _conout_not_up
                    DEC     E
                    JP      _conout_csr_update

_conout_not_up      CP      'B'
                    JR      NZ, _conout_not_down
                    INC     E
                    JP      _conout_csr_update

_conout_not_down    CP      'C'
                    JR      NZ, _conout_not_right
                    LD      A, (console_width)
                    CP      D
                    RET     Z                           
                    INC     D
                    JP      _conout_csr_update

_conout_not_right   CP      'D'
                    JR      NZ, _conout_not_left
                    DEC     D
                    RET     Z
                    JP      _conout_csr_update

_conout_not_left    CP      'F'                         ; Enter graphics mode.. not supported
                    RET     Z

                    CP      'G'                         ; Exit graphics mode
                    RET     Z

                    CP      'H'
                    JR      NZ, _conout_not_home
                    LD      DE, 0101h
                    JP      _conout_csr_update

_conout_not_home    CP      'I'                         ; Reverse line feed. Insert line above and move cursor up. Not supported
                    RET     Z                    

                    CP      'J'
                    JR      NZ, _conout_not_clr_sc

                    CALL    _conout_clr_ln
                    LD      BC, (cursor_row)
                    LD      C, 0
_conout_clr_scrn    INC     B
                    LD      A, (console_height)
                    CP      B
                    JP      Z, _redraw_buffer
                    PUSH    BC
                    LD      A, B
                    CALL    clear_screen_row
                    POP     BC
                    JR      _conout_clr_scrn

_conout_not_clr_sc  CP      'K'
                    JR      NZ, _conout_not_clr_ln

                    CALL   _conout_clr_ln
                    JP     _redraw_buffer

_conout_clr_ln      LD      BC, (cursor_row)
                    DEC     B
                    LD      A, C
                    DEC     A
                    LD      C, B
                    JP      clear_screen_row

_conout_not_clr_ln  CP      'Y'
                    JR      NZ, _conout_not_pos

_conout_start_esc   LD      (console_escape), A         ; Start an escape sequence
                    XOR     A
                    LD      (console_param1), A
                    RET

_conout_not_pos     CP      'Z'
                    JR      NZ, _conout_not_ident
                    LD      A, IDENTITY_LENGTH
                    LD      (console_identify), A
                    RET

_conout_not_ident   CP      'b'
                    JR      Z, _conout_start_esc
                    CP      'c'
                    JR      Z, _conout_start_esc

                    ; TODO: Any addtional escape sequences here...
                    RET

_conout_check_esc   LD      A, C                    
                    CP      ESCAPE_CHAR
                    JP      NZ, _conout_character

                    LD      A, (console_flags)
                    OR      CFLAGS_ESCAPE
                    LD      (console_flags), A
                    XOR     A
                    LD      (console_escape),A
                    RET

_conout_escape_seq  LD      A,(console_escape)
                    CP      'Y'
                    JR      Z, _conout_esc_pos
                    CP      'b'
                    JR      Z, _conout_esc_foreg
                    CP      'c'
                    JR      Z, _conout_esc_backg

                    ; All unknown sequences reset the escape sequence
_conout_reset_seq   XOR     A
                    LD      (console_escape),A
                    RET

_conout_esc_pos     LD      A, (console_param1)
                    AND     A
                    JR      NZ, _conout_pos_param
                    LD      A, C
                    LD      (console_param1),A
                    RET

_conout_pos_param   SUB     31
                    LD      E, A
                    LD      A, C
                    SUB     31
                    LD      D, A
                    CALL    _conout_reset_seq
                    JR      _conout_csr_update

_conout_esc_backg   LD      A, (console_colour)
                    AND     0F0h
                    LD      B, A
                    LD      A, C
                    SUB     31
                    AND     0Fh
_conout_set_colour  OR      B
                    LD      (console_colour), A
                    JR      _conout_reset_seq

_conout_esc_foreg   LD      A, (console_colour)
                    AND     0Fh
                    LD      B, A
                    LD      A, C
                    SUB     31
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A
                    JR      _conout_set_colour

; Cursor position has changed, check if we need to update the whole display.
; This is entered with DE as D = new cursor column, E = new cursor row
;         Writes new cursor poition to (cursor_row, cursor_column)
;         Returns HL = updated display column, row to track the cursor position..
; Assume column is always within range, row may be before start/after end of visible screen
;
_conout_csr_update  LD      HL, (display_row)           ; HL = current display column, row..
                    LD      BC, (cursor_row)            ; BC = old values of cursor column, row
                    LD      A, E                        
                    CP      C
                    LD      (cursor_row), A
                    JR      NZ, _conout_check_row       ; If cursor row has changed, we must update display_row and optionally screen_offset

_conout_track_col   LD      A, D
                    CP      B
                    LD      (cursor_col), A
                    JR      NZ, _conout_check_col       ; If only column has changed, we may update display_col..
                    JP      _redraw_buffer              ; Otherwise, nothing has changed. Make sure display is up to date

_conout_check_row   AND     A                           
                    JR      NZ, _conout_chk_bottom         
                    INC     A                           ; We're above the screen, fix the cursor_row but set L (display row) to -1 
                    LD      (cursor_row), A

                    XOR     A

_conout_chk_bottom  DEC     A
                    LD      L, A                        ; Update the display row in HL which will force refresh
                    LD      A, (console_height)
                    CP      L
                    JR      NZ, _conout_not_bottom

                    LD      (cursor_row), A

_conout_not_bottom  LD      A, D                        ; Write col here since it wasn't previously set...
                    LD      (cursor_col), A

_conout_check_col   LD      A, H                        ; Current display col
                    INC     A
                    SUB     D                           ; Subtract new cursor col
                    JR      NC, _conout_scroll_l        ; Cursor col is before beginning of screen

                    LD      A, (console_flags)
                    AND     CFLAGS_SHOW_CURSOR
                    LD      A, 1
                    JR      Z, _conout_keep_left
                    DEC     A
_conout_keep_left   ADD     A, DISPLAY_WIDTH          
                    LD      B, A
                    ADD     A, H                        ; Right hand edge of display...
                    CP      D
                    JR      NC, _conout_refresh

                    LD      A, D                        ; Cursor col is after end of screen
                    SUB     B
                    JR      NC, _conout_scroll_done
                    XOR     A
                    JR      _conout_scroll_done

_conout_scroll_l    LD      A, D
                    DEC     A
_conout_scroll_done LD      H, A


; We enter with HL = new display column, row
; At this point one or both of display row or column may changed, so update the whole display...   
; If row is -1, we're before the beginning of the screen - need to scroll up
; And if row > console_height, we need to scroll down.. Display row stays constant, but screen_offset changes..

; Do scroll first, then only change display row/col if console_flags is set to track cursor..
; If display row/col have changed, compare screen buffer with display buffer and update whichever characters/brightnesses have changed..
;
; 
_conout_refresh     
                    LD      A, L
                    OR      A
                    JP      P, _conout_row_postv

                    ; Display row negative
                    XOR     A
                    LD      L, A                        ; Reset display row to zero
                    LD      A, (screen_offset)
                    DEC     A
                    AND     03Fh
                    LD      (screen_offset), A
                    PUSH    HL
                    LD      C, 0
                    CALL    clear_screen_row
                    POP     HL
                    JR      _conout_update_display

_conout_row_postv   LD      A, (console_height)
                    LD      C, A                        ; Remember for later on
                    CP      L
                    JR      NZ, _conout_update_display

                    ; display row below screen
                    PUSH    HL
                    LD      A, (screen_offset)
                    INC     A
                    AND     03Fh
                    LD      (screen_offset), A
                    ; SUB     C
                    AND     03Fh
                    LD      L, A

                    LD      A, (screen_page)
                    CP      VIDEOBEAST_PAGE
                    JR      NZ, _not_videobeast

                    DI
                    OUT     (IO_MEM_1), A
                    LD      A, VB_UNLOCK
                    LD      (VB_REGISTERS_LOCKED), A
                    LD      A, L
                    ADD     A, A
                    ADD     A, A
                    ADD     A, A
                    LD      (VB_LAYER_4+LAYER_SCROLL_Y), A
                    LD      A, 010h
                    JR      C, _conout_scroll_xy
                    XOR     A
_conout_scroll_xy   LD      (VB_LAYER_4+LAYER_SCROLL_XY), A
                    LD      (VB_REGISTERS_LOCKED), A    ; Either value will re-lock registers..

                    LD      A, (page_1_mapping)
                    OUT     (IO_MEM_1), A
                    EI 

_not_videobeast     LD      A, C
                    
                    LD      C, 0
                    CALL    clear_screen_row
                    POP     HL 
                    DEC     L

_conout_update_display
                    ; We've scrolled if necessary, update the display row if required..
                    LD      A, (console_flags)
                    AND     CFLAGS_TRACK_CURSOR         
                    JR      Z, _redraw_buffer
                    LD      (display_row), HL           ; Only move display row if we're tracking the cursor

_redraw_buffer      DI
                    CALL    unsafe_redraw
                    EI
                    RET

;----------------------------------------------------------------------------------------------------
; Note that this uses Mem Page 1
;
unsafe_redraw       LD      A, (console_flags)
                    AND     CFLAGS_LED_OFF
                    RET     NZ

unsafe_led_redraw   LD      HL, (display_row)       ; Calculate our screen source in DE
                    LD      A, (screen_offset)      
                    ADD     A, L

                    AND     03Fh
                    OR      040h                    ; We're going to use page 1 for the screen buffer
                    LD      D, A
                    LD      A, H
                    SLA     A
                    LD      E, A

                    LD      HL, display_buffer
                    LD      B, DISPLAY_WIDTH
                    LD      C, 0

                    LD      A, (console_flags)      ; Don't draw last character if we've moved
                    AND     CFLAGS_SHOW_MOVED | CFLAGS_LED_OFF
                    JR      Z, _full_redraw
                    DEC     B

_full_redraw        LD      A, (screen_page)
                    OUT     (IO_MEM_1), A

_redraw_loop        LD      A, (DE)
                    CP      (HL)
                    JR      Z, _redraw_skip_char
                    LD      (HL), A
                    PUSH    BC
                    PUSH    HL
                    PUSH    DE
                    CALL    disp_character
                    POP     DE
                    POP     HL
                    POP     BC

_redraw_skip_char   INC     HL
                    INC     DE

                    LD      A, (console_flags)
                    AND     CFLAGS_SHOW_MOVED | CFLAGS_LED_OFF
                    LD      A, (DE)  
                    JR      Z, _redraw_normal

                    SRL     A
                    SRL     A
                    INC     A

_redraw_normal      CP      (HL)
                    JR      Z, _redraw_skip_bri
                    LD      (HL), A
                    PUSH    BC
                    PUSH    HL
                    PUSH    DE                
                    LD      A, (HL)             ; Ugh... disp_char_bright has parameters in other order..
                    SRL     A
                    AND     078h
                    LD      B, A
                    LD      A, C
                    LD      C, B
                    CALL    disp_char_bright    ; Column A, brightness C
                    POP     DE
                    POP     HL
                    POP     BC

_redraw_skip_bri    INC     HL
                    INC     DE
                    INC     C
                    DJNZ    _redraw_loop

                    LD      A, (console_flags)
                    LD      C, A
                    AND     CFLAGS_SHOW_MOVED | CFLAGS_LED_OFF
                    JR      Z, _redraw_done

                    ; We've moved the cursor, so draw the last character as our location bitmap..
_redraw_moved       LD      (HL), 0
                    INC     HL
                    LD      (HL), DISP_DEFAULT_BRIGHTNESS
                    LD      A, C
                    AND     CFLAGS_LED_OFF
                    LD      A, C
                    JR      Z, _led_normal

                    LD      HL, LED_OFF_BITMAP
                    JR      _redraw_map2

_led_normal         AND     CFLAGS_TRACK_CURSOR
                    JR      NZ, _redraw_tracking

                    LD      HL, 0
                    LD      BC, (cursor_row)
                    DEC     C
                    
                    LD      DE, (display_row)
                    LD      A, E
                    AND     A
                    JR      NZ, _redraw_not_top
                    LD      HL, MOVE_TOP_BITMAP
                    JR      _redraw_not_bottom

_redraw_not_top     LD      A, (console_height)
                    DEC     A
                    CP      E
                    JR      NZ, _redraw_not_bottom
                    LD      HL, MOVE_BOTTOM_BITMAP

_redraw_not_bottom  LD      A, E
                    CP      C
                    LD      BC, 0
                    JR      NZ, _redraw_not_row
                    LD      C, MOVE_ROW_BITMAP_L
                    JR      _redraw_map

_redraw_not_row     LD      B, MOVE_BELOW_BITMAP_H
                    JR      C, _redraw_not_above
                    JR      _redraw_map

_redraw_not_above   LD      B, MOVE_ABOVE_BITMAP_H

_redraw_map         ADD     HL, BC
                    LD      A, (display_col)
                    AND     A
                    JR      NZ, _redraw_map2
                    LD      A, MOVE_AT_LEFT_BITMAP
                    OR      L
                    LD      L, A
_redraw_map2        LD      A, DISPLAY_WIDTH-1
                    CALL    disp_bitmask

                    LD      A, DISPLAY_WIDTH-1
                    LD      C, DISP_DEFAULT_BRIGHTNESS
                    CALL    disp_char_bright

_redraw_done        LD      A, (page_1_mapping)
                    OUT     (IO_MEM_1), A
                    RET

_redraw_tracking    LD      HL, 2d3fh          ; Tracking symbol
                    JR      _redraw_map2

MOVE_TOP_BITMAP     .EQU    0001h
MOVE_BOTTOM_BITMAP  .EQU    0008h
MOVE_ROW_BITMAP_L   .EQU    0c0h
MOVE_ABOVE_BITMAP_H .EQU    05h
MOVE_BELOW_BITMAP_H .EQU    28h
MOVE_AT_LEFT_BITMAP .EQU    030h
LED_OFF_BITMAP      .EQU    0907h

;---------------------------------------- Simple character output.. 
_conout_character   LD      DE, (cursor_row)
                    CP      CARRIAGE_RETURN
                    JR      NZ, _conout_not_cr
   
                    LD      D, 1
                    JP      _conout_csr_update

_conout_not_cr      CP      NEWLINE
                    JR      NZ, _conout_not_lf

                    INC     E
                    JP      _conout_csr_update

_conout_not_lf      CP      BACKSPACE_CHAR
                    JR      NZ, _conout_visible

                    DEC     D
                    JP      NZ, _conout_csr_update
                    RET

                    ; Now, C is character to write,
_conout_visible     LD      DE, (cursor_row)
                    DEC     D                       ; 1 based col
                    DEC     E                       ; 1 based row

                    LD      A, (screen_offset)      ; Write the character and colour into our screen buffer
                    ADD     A, E

                    AND     03Fh
                    OR      040h                    ; We're going to use page 1 for the screen buffer
                    LD      H, A
                    LD      A, D
                    SLA     A
                    LD      L, A
                    LD      A, (screen_page)
                    OUT     (IO_MEM_1), A
                    LD      (HL), C
                    LD      A, (console_colour)
                    INC     HL
                    LD      (HL), A
                    LD      A, (page_1_mapping)
                    OUT     (IO_MEM_1), A

                    LD      DE, (cursor_row)
                    LD      A, (console_width)
                    LD      L, A
                    LD      A, D
                    CP      L
                    JR      Z, _conout_wrap
                    INC     D
                    JP      _conout_csr_update

_conout_wrap        LD      D, 1
                    INC     E
                    JP      _conout_csr_update          ; If we've wrapped, use the new wrap position..
;
;
; Fill the row of the screen buffer with space chars..
; Enter with A -> row of screen buffer, C -> start column
;          Uses HL, C
;
clear_screen_row    LD      H, A
                    LD      A, (screen_offset)
                    ADD     A, H

                    AND    03Fh
                    OR     040h
                    LD     H, A
                    LD     A, C
                    ADD    A, C
                    LD     L, A

                    LD      A, (console_colour)
                    LD      C, A

                    LD      A, (screen_page)
                    OUT     (IO_MEM_1), A

_clear_loop         LD      A, ' '
                    LD      (HL), A
                    INC     L
                    LD      (HL), C
                    INC     L
                    LD      A, 0FEh
                    CP      L
                    JR      NZ, _clear_loop

                    LD      A, (page_1_mapping)
                    OUT     (IO_MEM_1), A
                    RET
;------------------------------------------------------  
bios_list     ;  5 List OUTput
                    XOR     A
                    RET
                    
;------------------------------------------------------  
bios_punch    ;  6 punch OUTput
                    XOR     A
                    RET
                    
;------------------------------------------------------  
bios_reader   ;  7 Reader input
                    RET
                    

                    
;------------------------------------------------------  
bios_seldsk   ;  9 Select disk - Select disc in C, returns HL =  address of DPH, or 0 if error
                    ; Store C in A, Check drive is in range
                    LD      A, C
                    LD      HL, 0
                    CP      MAX_DRIVES
                    RET     NC

                    LD      B, 0
                    SLA     C
                    SLA     C
                    SLA     C
                    SLA     C
                    LD      HL, dpbase
                    ADD     HL, BC
                    LD      (sys_seldsk), A
                    RET

;------------------------------------------------------  
bios_home     ;  8 Home disk
                    LD      C, 0            
;------------------------------------------------------  
bios_settrk   ; 10 Select track - Move drive to track stored in C - 0 based (0-76)
                    LD      A, C
                    LD      (sys_track), A
                    RET
                    
;------------------------------------------------------  
bios_setsec   ; 11 Select sector - Move drive to sector stored in BC - 1 based (1-26) - TODO: Confirm this, not sure if true..
                    LD      (sys_sector), BC
                    RET
                    
;------------------------------------------------------  
bios_setdma   ; 12 Set DMA ADDress - Set the DMA address to BC - source or destination for disk read/write
              ; Note: CP/M 2.2 appears to only set this to the DIRBUF address defined in the DPF, or the USER DMA address (0x80h)
                    LD      (sys_dmaaddr), BC
                    RET
                    
;------------------------------------------------------  
;
; Uses Mem Page 1, 2
;
bios_read     ; 13 Read 128 bytes
                    CALL    _get_memdisc_addr
                    DI
                    OUT     (IO_MEM_1), A
                    SET     6, B            ; Point B into page 1
                    PUSH    BC
                    POP     HL
                    LD      C, 128

                    LD      DE, (sys_dmaaddr)
                    LD      A, D
                    RLCA
                    RLCA
                    AND     03h             ; Bottom two bits
                    OR      RAM_PAGE_0
                    LD      B, A            ; B is destination page
_read_page          OUT     (IO_MEM_2), A

                    SET     7, D            ; Point D to second page
                    RES     6, D

_read_next          LDI
                    LD      A, C
                    OR      A
                    JR      Z, _read_write_done

                    BIT     6, D
                    JR      Z, _read_next

                    INC     B
                    LD      A, B
                    JR      _read_page

_read_write_done    LD      A, (page_1_mapping)   ; Return page map to normal
                    OUT     (IO_MEM_1), A
                    LD      A, (page_2_mapping)
                    OUT     (IO_MEM_2), A
                    EI
                    XOR     A               ; No errors
                    RET
                    
;------------------------------------------------------  
;
; Uses Mem Page 1, 2
;
bios_write    ; 14 Write 128 bytes
                    LD      A, (sys_seldsk)
                    OR      A
                    JR      NZ, _write_ok
                    INC     A
                    RET

_write_ok           CALL    _get_memdisc_addr
                    DI
                    OUT     (IO_MEM_1), A
                    SET     6, B
                    PUSH    BC
                    POP     DE
                    LD      C, 128

                    LD      HL, (sys_dmaaddr)
                    LD      A, H
                    RLCA
                    RLCA
                    AND     03h              ; Bottom two bits
                    OR      RAM_PAGE_0
                    LD      B, A             ; B is source page
_write_page         OUT     (IO_MEM_2), A

                    SET     7, H
                    RES     6, H

_write_next         LDI
                    LD      A, C
                    OR      A
                    JR      Z, _read_write_done

                    BIT     6, H
                    JR      Z, _write_next

                    INC     B
                    LD      A, B
                    JR      _write_page
                    
; IN THIS CASE, WE HAVE SAVED THE DISK NUMBER IN 'DISKNO' (0, 1)
;           THE TRACK NUMBER IN 'TRACK' (0-76)
;           THE SECTOR NUMBER IN 'SECTOR' (1-26)
;           THE DMA ADDRESS IN 'DMAAD' (0-65535)
;
; Returns BC = address in page for sector
;          A = page number (ROM/RAM)
;
; Note: BC is always aligned to page boundaries, so a sector will never overlap the end of a page.
;
_get_memdisc_addr   LD      HL, 0
                    LD      BC, (sys_track)     ; C is track, B is sector (up to 256!)
                    LD      L, B
                    LD      B, H 
                    SLA     C                   ; x 2
                    RL      B
                    ADD     HL, BC
                    SLA     C                   ; x 4
                    RL      B
                    SLA     C                   ; x 8
                    RL      B
                    ADD     HL, BC
                    SLA     C                   ; x 16
                    RL      B
                    ADD     HL, BC              ; HL = Sector + BC * (2 + 8 + 16) = sector + track * 26

                    LD      A, L
                    AND     07Fh
                    LD      B, A
                    LD      C, 0
                    SRL     B
                    RR      C                   ; BC = Address in page of sector

                    SLA     L
                    RL      H                   ; H is now page number 

                    LD      A, (sys_seldsk)
                    OR      A
                    JR      Z, _get_memdisk_a
                    LD      A, (drive_b_mem_page)
                    ADD     A, H
                    RET
_get_memdisk_a      LD      A, (drive_a_mem_page)
                    ADD     A, H
                    RET


;------------------------------------------------------  
bios_listst   ; 15 List status
                    XOR     A
                    RET
                    
;------------------------------------------------------  
bios_sectrn   ; 16 Sector translate - BC = logical sector number (zero based), DE = address of translation table. Return HL as physical sector number
                    LD      L, C                ; No skewing needed, just return BC in HL
                    LD      H, B
                    RET
                    
;------------------------------------------------------
; Inline print. Preserves HL, DE, BC
;
m_print_inline      EX      (SP), HL
_inline_loop        LD      A, (HL)
                    INC     HL
                    AND     A
                    JR      Z, _inline_done
                    CALL    m_print_a_safe
                    JR      _inline_loop

_inline_done        EX      (SP), HL
                    RET

;------------------------------------------------------
; Print character in A. Preserves HL, DE, BC
;
m_print_a_safe      PUSH    HL
                    PUSH    DE
                    PUSH    BC
                    LD      C, A
                    CALL    bios_conout
                    POP     BC
                    POP     DE
                    POP     HL
                    RET

;------------------------------------------------------  

configure_hardware  DI     
                    LD      A, RAM_PAGE_0
                    OUT     (IO_MEM_0), A       ; Page 0 is RAM 0 
                    LD      (page_0_mapping), A
                    INC     A
                    OUT     (IO_MEM_1), A       ; Page 1 is RAM 1
                    LD      (page_1_mapping), A
                    INC      A
                    OUT     (IO_MEM_2), A       ; Page 2 is RAM 2 
                    LD      (page_2_mapping), A
                    INC     A                   ; Assume we're in RAM 3
                    LD      (page_3_mapping), A

                    LD      HL, 0FE00h          ; Set up the IM 2 table
                    LD      B, 0
_fill_vector        LD      (HL), 0FDh
                    INC     HL
                    DJNZ    _fill_vector

                    CALL    keyboard_init       ; Set up the keyboard status tables

                    LD      A, 0C3h             ; JP reset   instruction
                    LD      (0FDFDh), A
                    LD      HL, interrupt_handler
                    LD      (0FDFEh), HL

                    LD      HL, 0
                    LD      (user_interrupt), HL

                    LD      A, 2
                    OUT     (PIO_B_CTRL),A      ; Zero interrupt vector

                    LD      A, 0B7h             ; Enable interrupts on any of the following bits
                    OUT     (PIO_B_CTRL),A
                    NOP
                    LD      A, 0CFh             ; Just B5 (RTC interrupt) 
                    OUT     (PIO_B_CTRL),A

                    LD      A, 0FEh
                    LD      I, A
                    IM      2

                    CALL    setup_screen

                    LD      A, DRIVE_A_PAGE
                    LD      (drive_a_mem_page), A

                    EI

                    LD      A, 0
                    CALL    uart_init           ; Reinitialise the UART to make sure we've not missed anything

                    CALL    rtc_init            ; Make sure clock is running and reset time if necesary

_set_ctrl           LD      B, 4                ; Set RTC Coarse mode and Output Pin to Square wave - gives 64 Hz pulse
_set_ctrl_loop      PUSH    BC
                    LD      H, RTC_ADDRESS      
                    LD      L, RTC_REG_CTRL
                    CALL    i2c_write_to
                    JR      NC, _rtc_ack_error
                    LD      A, RTC_64HZ_ENABLED
                    CALL    i2c_write
                    JR      NC, _rtc_ack_error
                    XOR     A
                    CALL    i2c_write
_rtc_ack_error      CALL    i2c_stop

                    CALL    _pause

                    CALL    _check_ctrl
                    POP     BC
                    RET     Z
                    DJNZ    _set_ctrl_loop
                    RET

_pause              LD      B, 0
                    DJNZ    $
                    RET

; Check that the control is set to coarse trim and 0 offset
; Returns with Zero flag set if settings are good.
;
_check_ctrl         LD      H, RTC_ADDRESS      
                    LD      L, RTC_REG_CTRL
                    CALL    i2c_read_from
                    LD      D, 2
                    JR      NC, _ctrl_error
                    LD      E, A
                    CALL    i2c_ack
                    CALL    i2c_read
                    LD      D, A
                    CALL    i2c_stop
                    LD      A, E
                    LD      B, 4
                    CP      RTC_64HZ_ENABLED
                    RET     NZ
_ctrl_error         LD      A, D
                    AND     A
                    RET 

; SHOULD NOT BE CALLED WITH INTERRUPTS ENABLED!
;
setup_screen        LD      A, VIDEOBEAST_PAGE
                    OUT     (IO_MEM_1), A
                    LD      HL, PAGE_1_START
                    XOR     A
                    LD      B, A
_videobeast_check   LD      (HL), A
                    CP      (HL)
                    JR      NZ, _no_videobeast
                    ADD     A, 13
                    DJNZ    _videobeast_check

                    LD      A, VIDEOBEAST_PAGE
                    LD      (_screen_defaults), A
                    LD      HL, 0501Eh          ; 80 x 30 screen
                    LD      (_screen_size), HL

                    LD      A, VB_UNLOCK
                    LD      (VB_REGISTERS_LOCKED), A
                    LD      A, MODE_848 | MODE_MAP_16K
                    LD      (VB_MODE), A
                    XOR     A
                    LD      (VB_PAGE_0), A
                    LD      (VB_LAYER_5), A             ; Clear page 'above' our console

                    LD      HL, _videobeast
                    LD      DE, VB_LAYER_4
                    LD      BC, _videobeast_length
                    LDIR
                    LD      (VB_REGISTERS_LOCKED), A  ; Lock registers

_no_videobeast      LD      DE, screen_page     ; Copy the startup defaults to the shared_data area
                    LD      HL, _screen_defaults
                    LD      BC, _defaults_length
                    LDIR
                    LD      A, (screen_page)    ; Clear the screen buffer
                    OUT     (IO_MEM_1), A       ; Screen buffer is in PAGE_1
                    LD      HL, PAGE_1_START
                    LD      DE, PAGE_1_START+2
                    LD      C, ' '
                    LD      A, (console_colour)
                    LD      B, A
                    LD      (PAGE_1_START), BC
                    LD      BC, 16378           ; Don't over write last couple of bytes (VideoBeast)
                    LDIR

                    CALL    disp_clear          ; Clear the LED screen

restore_page_return LD      A, (page_1_mapping)       ; Return Page 1 to normal RAM
                    OUT     (IO_MEM_1), A
                    RET

_screen_defaults    .DB     CONSOLE_PAGE        ; Screen buffer page
                    .DB     0                   ; Row offset in buffer
                    .DB     0,0                 ; Row, column being shown on LED Display
                    .DB     1,1                 ; Row, column of cursor
_screen_size        .DB     24,64               ; Console height (rows), width (columns)
                    .DB     0F0h                ; Current colour [7:4] = background, [3:0] = foreground
default_screen_flags .DB     CFLAGS_TRACK_CURSOR ; Flags
                    .DB     0                   ; Timer
                    .DB     0, 0                ; Escape char and first parameter
                    .DB     0                   ; Disable identifier sequence
_defaults_length    .EQU    $-_screen_defaults

_videobeast         .DB     TYPE_TEXT, 1, 30, 2, 81         ; Text, top, bottom, left, right
                    .DB     0, 0, 0                         ; No scroll
                    .DB     0, 010h                         ; Char map in page 0, font 16x2K -> 32K
                    .DB     7, 0                            ; Palette 0, no hi-res
_videobeast_length  .EQU    $-_videobeast

interrupt_handler   DI
                    LD      (intr_stack), SP
                    LD      SP, intr_stack
                    PUSH    AF
                    EXX
                    CALL    keyboard_poll

                    LD      A,(control_key_pressed)
                    AND     A
                    CALL    NZ, handle_screen_shift

                    LD      A, (console_timer)
                    DEC     A
                    JP      M, _not_moved
                    LD      (console_timer), A
                    JR      NZ, _not_moved

                    LD      A, (console_flags)
                    AND     ~CFLAGS_SHOW_MOVED
                    LD      (console_flags), A
                    CALL    unsafe_redraw

_not_moved          LD      HL, (timer)
                    LD      E, L                ; E is old low byte of timer - used to blink cursor
                    INC     HL
                    LD      (timer), HL
                    LD      A, H
                    OR      L
                    JR      NZ, _timer_done
                    LD      HL, (timer+2)
                    INC     HL
                    LD      (timer+2),HL   

_timer_done         LD      A, (console_flags)
                    AND     CFLAGS_SHOW_CURSOR
                    JR      Z, _int_done

                    LD      A, (timer)          ; Blink when timer bit changes
                    XOR     E
                    AND     020h
                    JR      Z, _int_done
                    CALL    update_cursor

_int_done           LD      HL, (user_interrupt)
                    LD      A, H
                    OR      L
                    CALL    NZ, _do_usr_interrupt

                    EXX
                    POP     AF
                    LD      SP, (intr_stack)
                    EI
_do_reti            RETI

_do_usr_interrupt   JP      (HL)

; Enter with A containing a special control character
;
;
handle_screen_shift CP      KEY_CTRL_UP
                    JR      NZ, _not_ctrl_up

                    LD      A, (display_row)
                    DEC     A
                    JP      M, _shift_done
_shift_row          PUSH    AF
                    LD      E, 0
                    CALL    update_cursor
                    POP     AF
                    LD      (display_row), A

_shift_complete     LD      A, (console_flags)
                    AND     ~CFLAGS_TRACK_CURSOR
_flags_and_redraw   OR      CFLAGS_SHOW_MOVED
                    LD      (console_flags), A
                    LD      A, SHOW_MOVE_DELAY
                    LD      (console_timer),A
                    CALL    unsafe_led_redraw       ; Always redraw regardless of LED status
                    JR      _shift_done

_not_ctrl_up        CP      KEY_CTRL_DOWN
                    JR      NZ, _not_ctrl_down

_shift_down         LD      A, (console_height)
                    LD      C, A
                    LD      A, (display_row)
                    INC     A
                    CP      C
                    JR      Z, _shift_done
                    JR      _shift_row

_not_ctrl_down      CP      KEY_CTRL_RIGHT
                    JR      NZ, _not_ctrl_right

                    LD      A, (console_width)
                    SUB     DISPLAY_WIDTH-1
                    LD      C, A
                    LD      A, (display_col)
                    INC     A
                    CP      C
                    JR      Z, _shift_done
                    JR      _shift_col

_not_ctrl_right     CP      KEY_CTRL_LEFT
                    JR      NZ, _not_ctrl_left

                    LD      A, (display_col)
                    DEC     A
                    JP      M, _shift_done
_shift_col          PUSH    AF
                    LD      E, 0
                    CALL    update_cursor
                    POP     AF
                    LD      (display_col), A
                    JR      _shift_complete

_not_ctrl_left      CP      KEY_CTRL_ENTER
                    JR      NZ, _not_ctrl_enter
                    LD      A, (cursor_row)
                    DEC     A
                    LD      (display_row), A
                    LD      A, (cursor_col)
                    SUB     DISPLAY_WIDTH-2
                    JR      NC, _col_ok
                    XOR     A

_col_ok             LD      (display_col), A
                    LD      A, (console_flags)
                    OR      CFLAGS_TRACK_CURSOR
                    JR      _flags_and_redraw

_not_ctrl_enter     CP      KEY_CTRL_SPACE
                    JR      NZ, _not_ctrl_space

                    XOR     A
                    LD      (display_col), A
                    JR      _shift_down

_not_ctrl_space     CP      KEY_CTRL_D
                    JR      NZ, _shift_done

                    LD      A, (console_flags)
                    XOR     CFLAGS_LED_OFF
                    JR      _flags_and_redraw

_shift_done         XOR     A
                    LD      (control_key_pressed),A
                    RET

;
; Blinks the cursor 
;  Enter with E = timer low byte. 
;  If CURSOR_BIT is 1, show the cursor at the line, otherwise restore the existing character
;
update_cursor       LD      A, (display_row)    ; Are we on the same row as the cursor?
                    LD      B, A
                    LD      A, (cursor_row)
                    DEC     A
                    CP      B
                    RET     NZ

                    LD      A, (display_col)    ; Check the cursor column is within the display window
                    LD      B, A
                    LD      A, (cursor_col)
                    DEC     A
                    SUB     B
                    RET     M

                    LD      B, 0
                    LD      C, A

                    LD      A, (screen_page)
                    CP      VIDEOBEAST_PAGE
                    JR      NZ, _skip_videobeast

                    OUT     (IO_MEM_1), A

                    LD      A, (screen_offset)
                    LD      H, A
                    LD      A, (cursor_row)         ; 1 based
                    DEC     A
                    ADD     A, H
                    AND     03Fh
                    OR      040h                    ; Page 1 for videobeast
                    LD      H, A
                    LD      A, (cursor_col)
                    DEC     A
                    ADD     A, A
                    LD      L, A
                    INC     L

                    LD      A, E
                    AND     20h
                    LD      A, (console_colour)
                    JR      Z, _normal
                    RRC     A 
                    RRC     A
                    RRC     A
                    RRC     A
_normal             LD      (HL), A

                    DEC     HL
                    LD      A, (page_1_mapping)
                    OUT     (IO_MEM_1), A

_skip_videobeast    LD      A, C
                    CP      DISPLAY_WIDTH
                    RET     NC

                    LD      A, (console_flags)
                    AND     CFLAGS_LED_OFF
                    RET     NZ

                    ; At this point, BC holds the current display column for the cursor..
                    LD      HL, display_buffer
                    ADD     HL, BC
                    ADD     HL, BC

                    LD      A, E
                    AND     20h
                    LD      A, (HL)
                    JR      Z, _unblink
                    LD      A, '_'
_unblink            JP    disp_character

                    .INCLUDE "../ports.asm"

                    .INCLUDE "../io.asm"
                    .INCLUDE "../uart.asm"
                    .INCLUDE "../i2c.asm"

                    .INCLUDE "../disp.asm"
                    .INCLUDE "../font.asm"
                    .INCLUDE "bios_rtc.asm"
                    .INCLUDE "../flash.asm"
                    .INCLUDE "videobeast.asm"
;
;
; Page mapping - since the BIOS uses other pages to manage disk and screen, it must also manage the expected page for the user 
; programs, to prevent them from being unexpectedly changed (eg. after interrupts).
;

;
;
; Page mapping - since the BIOS uses other pages to manage disk and screen, it must also manage the expected page for the user 
; programs, to prevent them from being unexpectedly changed (eg. after interrupts).
;
; Get the User page mapping. Sets A to the physical (RAM/ROM) page selelcted for logical page C (0-2)
; Returns 0FFh for invalid page values
get_page_mapping    LD      A, C
                    CALL    _mapping_address
                    LD      A, 0FFH
                    RET     NC
                    LD      A, (HL)
                    RET

; Set the User page mapping. Sets page A (0-2) to the physical (RAM/ROM) page in E
; Returns with carry SET if successful. The given logical page will now point to the physical page in RAM or ROM
;
set_page_mapping    CALL    _mapping_address
                    RET     NC
                    LD      (HL), E 

                    ADD     A, IO_MEM_0             ; NOTE: Order is important here. Interrupts may occur after the page is stored (above)
                    LD      C, A                    ; This may result in the page being prematurely mapped, but that's OK.
                    OUT     (C), E                  ; If we tried to set the page before storing the new default we'd have to disable interrupts
                    SCF                             ; To avoid a race condition
                    RET

_mapping_address    CP      4
                    RET     NC
                    LD      C, A
                    LD      B, 0
                    LD      HL, page_0_mapping
                    ADD     HL, BC
                    SCF
                    RET

; Get the page in memory being used as the base for the drive selected by A
; Returns A = Page in ROM/RAM for the given drive
;    or   A = 0 if the selected drive is not supported.
;
get_disk_page       CP      MAX_DRIVES
                    JR      NC, _disk_page_err
                    LD      C, A
                    LD      B, 0
                    LD      HL, drive_a_mem_page
                    ADD     HL, BC
                    LD      A, (HL)
                    RET
_disk_page_err      XOR     A
                    RET

get_version         LD      A, 017h
                    RET

;
; Erase and write flash data. Data is written to 4K sectors, which are erased before writing.
; This uses Page 0 to write the data, so the source must be above 3FFFh
;
;       D -> 7 bit index of 4K sector being written
;       HL -> Address of source data
;       BC -> bytes to write
;
; Returns D pointing to last sector written
; Note: This means if BC is an exact multiple of sector size, D is returned as the previous sector

bios_flash_write    CALL    flash_write 
                    LD      A, (page_0_mapping)
                    OUT     (IO_MEM_0), A
                    RET 

;
; Set or query the user interrupt. The specified routine will be called after keyboard polling, every 60th of a 
; second. The shadow register set is selected before the call (EXX), and AF is preserved. The routine should 
; RETurn normally. Interrupt routines survive warm reboots, but no special measures are taken to ensure the
; memory they occupy is preserved.
;
;   Parameters: 
;       HL = Address of user interrupt routine, or zero to disable. Call with 0FFFFh to query the current value
;   Returns:
;       The address of the current user interrupt routine, or zero if none is configured.
;
;
set_usr_interrupt   LD      A, H
                    AND     L
                    INC     A
                    JR      Z, _return_usr_int
                    LD      (user_interrupt), HL
_return_usr_int     LD      HL, (user_interrupt)
                    RET

JUMP_TABLE_SIZE     .EQU    19

.IF $ > (BIOS_TOP - (3*JUMP_TABLE_SIZE))
    .ECHO "BIOS No room for Jump Table ("
    .ECHO $
    .ECHO " > "
    .ECHO (BIOS_TOP-(3*JUMP_TABLE_SIZE))
    .ECHO ") \n\n"
    .STOP
.ENDIF

BIOS_SPARE          .EQU    BIOS_TOP - $ - (3*JUMP_TABLE_SIZE)
                    .FILL   BIOS_SPARE, 0

                    JP          i2c_ack             ; 19 (0FDC4h) - Send an i2c ACK.
                    JP          set_usr_interrupt   ; 18 (0FDC7h) - Set the User interrupt vector. HL = 0 to clear, or address of user routine. HL= 0FFFFh to query.
                    JP          bios_flash_write    ; 17 (0FDCAh) - Erase and write flash data. Data is written to 4K sectors, which are erased before writing.
                    JP          get_disk_page       ; 16 (0FDCDh) - Get the page in RAM/ROM being used as the base for the drive selected by A, or zero if error.
                    JP          rtc_get_time_hl     ; 15 (0FDD0h) - Get the time to the 7 bytes pointed to by HL. Returns carry set if sucessful
                    JP          disp_char_bright    ; 14 (0FDD3h) - Set LED Digit A to brightness C
                    JP          disp_bitmask        ; 13 (0FDD6h) - Directly write bitmask in HL to display column A
                    JP          m_print_inline      ; 12 (0FDD9h) - Print the characters following the call instruction
                    JP          get_page_mapping    ; 11 (0FDDCh) - Return the logical (cpu) page C (0-2) in A
                    JP          set_page_mapping    ; 10 (0FDDFh) - Set the logical (cpu) page in A (0-2) to the physical (RAM/ROM) page in E
                    JP          i2c_start           ; 9  (0FDE2h) - Sends I2C start sequence
                    JP          i2c_stop            ; 8  (0FDE5h) - Sends I2C stop sequence
                    JP          i2c_write           ; 7  (0FDE8h) - Write A as a byte to i2c bus. Carry SET if success. i2c_stop is not called.
                    JP          i2c_read            ; 6  (0FDEBh) - Read byte from i2C into A, without ACK
                    JP          i2c_write_to        ; 5  (0FDEEh) - Prepare to write to Device address H, Register L. Carry SET if success. i2c_stop is not called.
                    JP          i2c_read_from       ; 4  (0FDF1h) - Read a byte int A from Device address H, Register L. Carry SET if success. i2c_stop is not called.
                    JP          wait_for_key        ; 3  (0FDF4h) - Waits for until a key is pressed and released
                    JP          play_note           ; 2  (0FDF7h) - Plays the note defined by DE (octave, note) and C (duration, tenths)
                    JP          get_version         ; 1  (0FDFAh) - Returns the Bios version in A


.IF $ > BIOS_TOP
    .ECHO "End of BIOS is too high ("
    .ECHO $
    .ECHO " > "
    .ECHO BIOS_TOP
    .ECHO ") \n\n"
    .STOP
.ENDIF

.ECHO "Bios Size is "
.ECHO BIOS_TOP-BIOS_START-BIOS_SPARE
.ECHO ". Limit is "
.ECHO BIOS_TOP-BIOS_START
.ECHO ". Spare "
.ECHO BIOS_SPARE
.ECHO "\n\n"

                    .INCLUDE shared_data.asm
                    .END