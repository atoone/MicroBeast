;
; Write - MicroBeast RAM Disk flash write utility
;
; Copyright (c) 2025 Andy Toone for Feersum Technology Ltd.
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

;
; Write the RAM Disk image to FLASH Rom starting at page 010h (256K)
; This can then be restored with the RESTORE utility.
;
; If any command line parameter is given, just report the total number of sectors and exit
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/bios.inc"

CMD_LEN                 .EQU    00080h

RAM_DISK                .EQU    1                               ; The drive (RAM drive) we restore to

FLASH_DRIVE_PAGE        .EQU    010h                            ; Page in flash we restore the drive from..
FLASH_MASK              .EQU    07Fh

IO_PAGE_1               .EQU    071h      ; Page 1: 4000h - 7fffh
IO_PAGE_2               .EQU    072h      ; Page 2: 8000h - Cfffh

SECTORS_IN_1K           .EQU    8         ; Number of 128 byte sectors in 1Kb
SECTORS_IN_4K           .EQU    SECTORS_IN_1K * 4

BLOCK_SIZE              .EQU    3         ; We're assuming a block size of 1K in most of this code

RETRY_COUNT             .EQU    2         ; One more than the number of retries

SAFE_STACK              .EQU    0C100h    ; In top page as we can't use Page 0 (flash write), Page 1 or Page 2

; Disk parameter block offsets
BSH_OFFSET              .EQU    2         ; Number of 128 bytes sectors per "Allocation Block" ( determined by the data block allocation size. Stored as 2's-logarithm. )
DSM_OFFSET              .EQU    5         ; Total storage capacity of the disk drive. Number of the last Allocation Block ( Number of entries per disk -1 )
DRM_OFFSET              .EQU    7         ; Total number of directory entries that can be stored on this drive.
AL0_OFFSET              .EQU    9         ; Starting value of the first two bytes of the allocation table.
AL1_OFFSET              .EQU    10
SYS_TRACK_OFFSET        .EQU    13        ; Number of system reserved tracks at the beginning of the ( logical ) disk


                        LD      (old_stack), SP
                        LD      SP, SAFE_STACK

                        ; Preserve current disk
                        LD      C, BDOS_GETCURRENTDISK
                        CALL    BDOS
                        LD      (current_disk), A

                        LD      C, BDOS_SELECTDISK              ; Select RAM Disk
                        LD      E, RAM_DISK
                        CALL    BDOS

                        ; Get diskparams in HL
                        LD      C, BDOS_GETDISKPARAMS
                        CALL    BDOS              

                        PUSH    HL
                        POP     IX

                        LD      A, (IX+BSH_OFFSET)
                        CP      BLOCK_SIZE
                        JR      Z, _block_size_ok

                        LD      DE, error_block_size

_exit_message           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
_finish                 
                        LD      A, (current_disk)
                        LD      E, A
                        LD      C, BDOS_SELECTDISK              ; Restore user's disk
                        CALL    BDOS

                        LD      SP, (old_stack)
                        RET

_block_size_ok          LD      B, (IX+SYS_TRACK_OFFSET)        ; B is the number of reserved (system) tracks
                        LD      C, (IX)                         ; C is number of sectors per track
                        XOR     A
_sys_sector_calc        ADD     A, C
                        DJNZ    _sys_sector_calc

                        ; A now holds number of 128 byte sectors used for system data at start of disk
                        LD      (system_sectors), A             ; Total  sectors for system tracks + directory


                        ; Fetch the block count for the disk...
                        LD      C, BDOS_RESETDISK               ; De-Select RAM Disk
                        CALL    BDOS

                        LD      C, BDOS_SELECTDISK              ; Re-Select RAM Disk
                        LD      E, RAM_DISK
                        CALL    BDOS

                        LD      C, BDOS_GETALLOCVECTOR          ; Get the Alloc Vector address
                        CALL    BDOS

                        ; Now calculate how much data we need to copy to save the entire drive...
                        LD      A, (IX+DSM_OFFSET)              ; Index of last block on drive (total number of blocks-1)
                        SRL     A
                        SRL     A
                        SRL     A
                        INC     A

                        LD      D, 0 
                        LD      E, A                            ; DE is size of ALV area (DSM/8)+1

                        ADD     HL, DE                          
                        DEC     HL
                        EX      DE, HL                          ; DE Points to end of alloc vector

                        ADD     HL, HL
                        ADD     HL, HL
                        ADD     HL, HL                          ; HL is maximum possible number of blocks

_check_loop             LD      A, (DE)
                        LD      B, 8
_check_block            RRCA 
                        JR      C, _found_end
                        DEC     HL
                        DJNZ    _check_block

                        DEC     DE
                        LD      A, L
                        OR      H
                        JR      NZ, _check_loop

                        LD      DE, error_empty
                        JR      _exit_message

                        ; Now HL is maximum allocated block on the disk... convert to sectors
_found_end              LD      B, (IX+BSH_OFFSET)
_adjust_block           ADD     HL, HL
                        DJNZ    _adjust_block
                        LD      A, (system_sectors)
                        LD      C, A
                        ADD     HL, BC

                        ; HL is total sectors on disk, including the system tracks..
                        ; Now either report the number of sectors that would be saved, or write disk to Flash

                        LD      A, (CMD_LEN)
                        OR      A
                        JR      Z, write_flash

just_report             LD      DE, digit_store
                        CALL    Num2Dec

                        LD      HL, digit_store
                        CALL    adjust_digits

                        LD      DE, report_count
                        LD      C, B
                        LD      B, 0
                        LDIR

                        LD      HL, report_end
                        LD      BC, report_end_len
                        LDIR

                        LD      DE, report_message
                        JP      _exit_message

write_flash             ; Write HL sectors to flash.
                        LD      (total_sectors), HL
                        PUSH    HL

                        LD      DE, sure_message
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

_wait_key               LD      E, 0FFh
                        LD      C, BDOS_CONIO
                        CALL    BDOS
                        AND     A
                        JR      Z, _wait_key

                        POP     HL
                        CP      'y'
                        JP      Z, _sure
                        CP      'Y'
                        JP      Z,_sure
                        JR      just_report

_sure                   PUSH    HL
                        LD      DE, writing_message
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

                        LD      C, 1                            ; Remember what the current page mappings are so we can restore them later
                        CALL    MBB_GET_PAGE
                        LD      (old_page_1), A

                        LD      C, 2
                        CALL    MBB_GET_PAGE
                        LD      (old_page_2), A

                        LD      A, RAM_DISK                     ; Get the base page for the RAM disk in memory
                        CALL    MBB_GET_DRIVE_PAGE
                        LD      (ram_drive_page), A

                        LD      A, FLASH_DRIVE_PAGE
                        LD      (dest_page), A

                        SLA     A
                        SLA     A
                        AND     FLASH_MASK
                        LD      (flash_block), A

                        LD      HL, 08000h
                        LD      (dest_address), HL

                        LD      DE, 04000h
                        LD      (source_address), DE

                        POP     HL

                        ; HL counts sectors to be stored..
flash_loop              PUSH    HL
                        LD      A, (ram_drive_page)
                        LD      E, A
                        LD      A, 1
                        CALL    MBB_SET_PAGE

                        LD      A, (dest_page)
                        LD      E, A
                        LD      A, 2
                        CALL    MBB_SET_PAGE

                        POP     HL
                        LD      BC, SECTORS_IN_4K
                        AND     A
                        SBC     HL, BC
                        JR      NC, _sector_size_ok
                        ADD     HL, BC
                        LD      B, H
                        LD      C, L
                        LD      HL, 0

_sector_size_ok         PUSH    HL                      ; C is now sectors to compare, HL is remaining sectors
                        LD      B, C
                        LD      C, 0
                        SRL     B
                        RR      C
                        LD      (block_size), BC

                        LD      A, RETRY_COUNT+1
                        LD      (retries), A

_start_compare          LD      HL, (dest_address)
                        LD      DE, (source_address)

_compare_loop           LD      A, (DE)
                        INC     DE
                        CPI

                        JP      NZ, _block_differs
                        JP      PE, _compare_loop
                        ; Disk Sectors match, so go to next flash block

_next_block             LD      HL, flash_block
                        INC     (HL)

                        LD      A, (retries)
                        CP      RETRY_COUNT+1
                        JR      Z, _no_write

                        LD      HL, block_write
                        INC     (HL)

_no_write               LD      BC, 4096
                        LD      HL, (dest_address)              
                        ADD     HL, BC
                        LD      (dest_address), HL

                        LD      HL, (source_address)
                        ADD     HL, BC
                        LD      (source_address), HL

                        BIT     7,H
                        JR      Z, _no_block_overflow

                        LD      HL, 08000h
                        LD      (dest_address), HL

                        LD      DE, 04000h
                        LD      (source_address), DE

                        LD      HL, ram_drive_page
                        INC     (HL)
                        LD      HL, dest_page
                        INC     (HL)

_no_block_overflow      POP     HL
                        LD      A, H
                        OR      L
                        JP      NZ, flash_loop
                        JR      report_success

_block_differs          LD      HL, retries
                        DEC     (HL)
                        JR      Z, _fail_retry

;       D -> 7 bit index of 4K sector being written
;       HL -> Address of source data
;       BC -> bytes to write
                        LD      HL, (source_address)
                        LD      BC, (block_size)
                        LD      A, (flash_block)
                        LD      D, A
                        CALL    MBB_FLASH_WRITE

                        LD      BC, (block_size)
                        JR      _start_compare

_fail_retry             CALL    restore_pages
                        LD      DE, error_retry
                        JP      _exit_message

report_success          ; ---- Disk write complete
                        CALL    restore_pages

                        ; Report number of sectors/blocks 
                        LD      A, (block_write)
                        AND     A
                        LD      DE, unchanged_message
                        JP      Z, _exit_message

                        LD      L, A
                        LD      H, 0
                        LD      DE, digit_store
                        CALL    Num2Dec

                        LD      HL, digit_store
                        CALL    adjust_digits

                        LD      DE, block_count
                        LD      C, B
                        LD      B, 0
                        LDIR

                        LD      HL, block_end
                        LD      BC, block_end_len
                        LDIR

                        LD      DE, block_message
                        LD      C, BDOS_PRINTSTRING
                        CALL    BDOS

                        LD      HL, (total_sectors)
                        LD      DE, digit_store

                        CALL    Num2Dec

                        LD      HL, digit_store
                        CALL    adjust_digits
  
                        LD      DE, saved_count
                        LD      C, B
                        LD      B, 0
                        LDIR

                        LD      HL, saved_end
                        LD      BC, saved_end_len
                        LDIR

                        LD      DE, saved_message
                        JP      _exit_message

restore_pages           LD      A, (old_page_1)
                        LD      E, A
                        LD      A, 1
                        CALL    MBB_SET_PAGE

                        LD      A, (old_page_2)
                        LD      E, A
                        LD      A, 2
                        JP     MBB_SET_PAGE

; Convert number in HL to 5 digit decimal string stored at DE
;
;   Code from https://map.grauw.nl/sources/external/z80bits.html#5.1
;
Num2Dec                 LD      BC,-10000
                        CALL    _digit
                        LD      BC,-1000
                        CALL    _digit
                        LD      BC,-100
                        CALL    _digit
                        LD      C,-10
                        CALL    _digit
                        LD      C,B

_digit                  LD      A,'0'-1
_digit_loop             INC     A
                        ADD     HL,BC
                        JR      C,_digit_loop
                        SBC     HL,BC

                        LD      (DE),A
                        INC     DE
                        RET

;
; Given HL points to a 5 digit decimal string created by num2dec above, return the 
; address of the first non-zero digit in HL, and the remaining digit count in B
;
adjust_digits           LD      B, 5
_find_start             LD      A, (HL)
                        CP      '0'
                        RET     NZ
                        INC     HL
                        DJNZ    _find_start
                        RET

old_stack               .DW     0

digit_store             .BLOCK  6

block_size              .DW     0           ; How many bytes in the current block to compare..
total_sectors           .DW     0

dest_address            .DW     0
source_address          .DW     0

current_disk            .DB     0

system_sectors          .DB     0

old_page_1              .DB     0
old_page_2              .DB     0

ram_drive_page          .DB     0           ; Base page for the target RAM drive
dest_page               .DB     0           ; Dest page for the save

flash_block             .DB     0
block_write             .DB     0           ; How many blocks were written

retries                 .DB     0

report_message          .DB    "\n\rNo write. "
report_count            .BLOCK 5
report_end              .DB    " sectors.$"
report_end_len          .EQU   $-report_end

block_message           .DB     "\n\rUpdated "
block_count             .BLOCK 5
block_end               .DB     " 4K blocks.$"
block_end_len           .EQU   $-block_end

saved_message           .DB     "\n\rWrote "
saved_count             .BLOCK 5
saved_end               .DB     " sectors OK.$"
saved_end_len           .EQU   $-saved_end

sure_message            .DB     "Write FLASH. Sure? Y/N$"
writing_message         .DB     "\n\rUpdating. Please wait.$"
unchanged_message       .DB     "\n\rDisk not changed. OK$"
error_retry             .DB     "\n\rERROR: Flash write failed.$"

error_empty             .DB     "ERROR: Disk empty, cannot write.$"
error_block_size        .DB     "ERROR: Block size must be 1K.$"

                        .END