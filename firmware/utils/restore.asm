;
; RESTORE - MicroBeast RAM Disk restore utility
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
; Restore.com - command line tool that restores the RAM Disk contents from the Flash memory, starting at page 010h
;
; This expects to find a CP/M disk image in Flash memory, starting at page 010h. The contents are restored, and any
; spare space on the disk is marked as empty. The command returns the number of 128 byte sectors found in the disk
; image (including system tracks and directory entries) on success.
;
; Note that on error, the RAM disk may be left in an indeterminate state. Proceed with caution
;

;
; Restore - notes
;
; Disk has <x> sectors assigned to system data (in our case, 2)
; Then up to 256 blocks (of 1024, 2048, 4096 etc. bytes) in the allocation vector
;   Blocks are assigned in order of high bit to low in each byte, sequentially in the vector
;   Directory is located in the allocation vector (64 entries x 32 bytes = 2Kb, ie first two bits for 1024 byte blocks)
;   System tracks are not part of the allocation vector.
;
; Disk image size  = System tracks x sector count x 128 bytes  +  count of maximal bit in alloc vector x block size
;
; Restrictions:
;                   This code assumes block size MUST be 1024 bytes (1Kb)
;                   Number of sectors per track MUST be less than 256
;                   System area + directory MUST occupy less than 16Kb
;                   Disk stores no more than 256Kb including system tracks
;
;

                        .ORG    0100h

                        .INCLUDE "beastos/bios.inc"

RAM_DISK                .EQU    1                               ; The drive (RAM drive) we restore to

FLASH_DRIVE_PAGE        .EQU    010h                            ; Page in flash we restore the drive from..

IO_PAGE_1               .EQU    071h      ; Page 1: 4000h - 7fffh
IO_PAGE_2               .EQU    072h      ; Page 2: 8000h - Cfffh

SECTORS_IN_1K           .EQU    8         ; Number of 128 byte sectors in 1Kb
BLOCK_SIZE              .EQU    3         ; We're assuming a block size of 1K in most of this code

; Disk parameter block offsets
BSH_OFFSET              .EQU    2         ; Number of 128 bytes sectors per "Allocation Block" ( determined by the data block allocation size. Stored as 2's-logarithm. )
DSM_OFFSET              .EQU    5         ; Total storage capacity of the disk drive. Number of the last Allocation Block ( Number of entries per disk -1 )
DRM_OFFSET              .EQU    7         ; Total number of directory entries that can be stored on this drive.
AL0_OFFSET              .EQU    9         ; Starting value of the first two bytes of the allocation table.
AL1_OFFSET              .EQU    10
SYS_TRACK_OFFSET        .EQU    13        ; Number of system reserved tracks at the beginning of the ( logical ) disk

                        LD      (old_stack), SP
                        LD      SP, old_stack

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
                        JP      _exit_message

_block_size_ok          LD      B, (IX+SYS_TRACK_OFFSET)        ; B is the number of reserved (system) tracks
                        LD      C, (IX)                         ; C is number of sectors per track
                        XOR     A
_sys_sector_calc        ADD     A, C
                        DJNZ    _sys_sector_calc

                        ; A now holds number of 128 byte sectors used for system data at start of disk
                        LD      L, 0                            ; Count directory blocks in L

                        LD      C, (IX+AL0_OFFSET)              ; Add directory blocks
                        LD      B, 8
_count_al0              SLA     C
                        JR      NC, _next_al0
                        INC     L
_next_al0               DJNZ    _count_al0

                        LD      C, (IX+AL1_OFFSET)
                        LD      B, 8
_count_al1              SLA     C
                        JR      NC, _next_al1
                        INC     L
_next_al1               DJNZ    _count_al1

                        LD      H, L                            ; Remember block count for later
                        LD      B, (IX+BSH_OFFSET)
_shift_dir_block        SLA     L                               ; Convert to sector count
                        DJNZ    _shift_dir_block

                        LD      (system_sectors), A             ; Total  sectors for system tracks
                        ADD     A, L

                        CP      16*SECTORS_IN_1K                                 
                        JR      C, _system_size_ok              ; Check we can read in a single page... (less than 16kb)

                        LD      DE, error_system_size
                        JP      _exit_message

_system_size_ok         LD      C, 0
                        SRL     A
                        RR      C
                        LD      B, A
                        PUSH    BC                              ; How many bytes for system+directory

                        LD      A, H
                        LD      (directory_blocks), A

                        LD      C, 1                            ; Remember what the current page mappings are so we can restore them later
                        CALL    MBB_GET_PAGE
                        LD      (old_page_1), A

                        LD      C, 2
                        CALL    MBB_GET_PAGE
                        LD      (old_page_2), A

                        LD      A, RAM_DISK                     ; Get the base page for the RAM disk in memory
                        CALL    MBB_GET_DRIVE_PAGE
                        LD      (ram_drive_page), A

                        DI
                        OUT     (IO_PAGE_2), A

                        LD      A, FLASH_DRIVE_PAGE
                        LD      (source_page), A
                        OUT     (IO_PAGE_1), A

                        LD      HL, 04000h                      ; Copy system + directory to base of RAM drive
                        LD      DE, 08000h
                        POP     BC

                        LDIR

                        LD      (flash_source_address), HL      ; Remember where we got to..
                        LD      (disk_dest_address), DE

                        LD      A, (old_page_1)
                        OUT     (IO_PAGE_1), A

                        LD      A, (old_page_2)
                        OUT     (IO_PAGE_2), A
                        EI

                        LD      A, (IX+DSM_OFFSET)              ; Index of last block on drive (total number of blocks-1)
                        SRL     A
                        SRL     A
                        SRL     A
                        INC     A

                        LD      C, A
                        LD      B, 0
                        PUSH    BC                              ; BC is size of ALV area (DSM/8)+1

                        LD      C, BDOS_RESETDISK               ; De-Select RAM Disk
                        CALL    BDOS

                        LD      C, BDOS_SELECTDISK              ; Re-Select RAM Disk
                        LD      E, RAM_DISK
                        CALL    BDOS

                        LD      C, BDOS_GETALLOCVECTOR          ; Get the Alloc Vector address
                        CALL    BDOS
                        LD      (alloc_vector_ptr), HL

                        ; Now calculate how much data we need to copy to restore the entire drive...

                        POP     DE
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

_exit_message           LD      C, BDOS_PRINTSTRING
                        CALL    BDOS
_finish                 
                        LD      A, (current_disk)
                        LD      E, A
                        LD      C, BDOS_SELECTDISK              ; Restore user's disk
                        CALL    BDOS

                        LD      SP, (old_stack)
                        RET

                        ; Now HL is number of 1Kb blocks needed to be copied to restore drive image (excluding system tracks)
_found_end              LD      (blocks_copied), HL             ; Store this for reporting.

                        LD      A, (directory_blocks)
                        LD      C, A
                        XOR     A
                        LD      B, A
                        SBC     HL, BC                          ; ~We've already copied directory blocks, now do the rest...
                        
                        JR      _start_copy

_copy_block             PUSH    HL                              ; HL is number of blocks

                        DI
                        LD      A, (source_page)
                        OUT     (IO_PAGE_1), A

                        LD      A, (ram_drive_page)
                        OUT     (IO_PAGE_2), A

                        LD      DE, (disk_dest_address)
                        LD      HL, (flash_source_address)

                        LD      A, SECTORS_IN_1K
_copy_sector            LD      BC, 128
                        LDIR

                        BIT     7, H                            ; Have we overflowed our page boundary?
                        JR      Z, _next_sector

                        ; Move to next page (both overflow simultaneously)
                        LD      HL, 04000h
                        LD      DE, 08000h

                        PUSH    AF
                        LD      A, (source_page)
                        INC     A
                        LD      (source_page), A
                        OUT     (IO_PAGE_1), A

                        LD      A, (ram_drive_page)
                        INC     A
                        LD      (ram_drive_page), A
                        OUT     (IO_PAGE_2), A

                        POP     AF

_next_sector            DEC     A
                        JR      NZ, _copy_sector

                        LD      A, (old_page_1)
                        OUT     (IO_PAGE_1), A

                        LD      A, (old_page_2)
                        OUT     (IO_PAGE_2), A

                        EI

                        LD      (flash_source_address), HL      ; Remember where we got to..
                        LD      (disk_dest_address), DE

                        POP     HL
                        DEC     HL
_start_copy             LD      A, H
                        OR      L
                        JR      NZ, _copy_block

                        ; At this point, we've copied all of the disk image that is allocated... fill the rest up with 0E5h

                        LD      BC, (blocks_copied)
                        LD      L, (IX+DSM_OFFSET)              ; Index of last block on drive (total number of blocks-1)
                        XOR     A
                        LD      H, A
                        INC     HL
                        SBC     HL, BC                          ; How many blocks to go...
                        JR      _start_fill

_fill_block             PUSH    HL

                        DI

                        LD      A, (ram_drive_page)
                        OUT     (IO_PAGE_2), A

                        LD      DE, (disk_dest_address)
                        
                        LD      A, SECTORS_IN_1K
_fill_sector            PUSH    DE
                        POP     HL
                        INC     DE
                        LD      (HL), 0E5h

                        LD      BC, 127
                        LDIR

                        BIT     6, D                            ; Have we overflowed our page boundary?
                        JR      Z, _fill_next

                        ; Move to next page
                        LD      DE, 08000h

                        PUSH    AF

                        LD      A, (ram_drive_page)
                        INC     A
                        LD      (ram_drive_page), A
                        OUT     (IO_PAGE_2), A

                        LD      A, 0E5h
                        LD      (HL), A

                        POP     AF

_fill_next              DEC     A
                        JR      NZ, _fill_sector

                        LD      A, (old_page_2)
                        OUT     (IO_PAGE_2), A

                        EI

                        LD      (disk_dest_address), DE
                        POP     HL
                        DEC     HL
_start_fill             LD      A, H
                        OR      L
                        JR      NZ, _fill_block

                        ; Disk is restored...

                        LD      HL, (blocks_copied)          ; How many blocks we restored
                        LD      A, (IX+BSH_OFFSET)
_mul_block              ADD     HL, HL
                        DEC     A
                        JR      NZ, _mul_block
                        LD      A, (system_sectors)
                        LD      C, A
                        LD      B, 0
                        ADD     HL, BC

                        ; HL Now holds the total number of sectors restored including system tracks...
                        LD      DE, digit_store
                        CALL    Num2Dec

                        LD      HL, digit_store
                        LD      B, 5
_find_start             LD      A, (HL)
                        CP      '0'
                        JR      NZ, _start_num
                        INC     HL
                        DJNZ    _find_start

_start_num              LD      DE, restored_sectors
                        LD      C, B
                        LD      B, 0
                        LDIR

                        LD      HL, restored_end
                        LD      BC, restored_end_len
                        LDIR

                        LD      DE, restored_message
                        JP      _exit_message

restored_message        .DB    "Restored "
restored_sectors        .BLOCK 5
restored_end            .DB    " sectors OK\n\r$"
restored_end_len        .EQU   $-restored_end

;
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


stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0
alloc_vector_ptr        .DW     0

blocks_copied           .DW     0           ; Number of blocks to be copied by restore...

old_page_1              .DB     0
old_page_2              .DB     0

ram_drive_page          .DB     0           ; Base page for the target RAM drive
source_page             .DB     0           ; Soruce page for the restore

flash_source_address    .DW     0           ; Where we're copying from
disk_dest_address       .DW     0           ; Where we're copying to

current_disk            .DB     0           ; Used to restore disk once restore is complete..
system_sectors          .DB     0           ; Number of 128 byte sectors for system tracks and directory entries
directory_blocks        .DB     0           ; Number of allocation blocks used by the directory

digit_store             .BLOCK  6

error_empty             .DB     "ERROR: Disk empty, cannot restore.\n\r$"
error_block_size        .DB     "ERROR: Block size must be 1K.\n\r$"
error_system_size       .DB     "ERROR: System data too large.\n\r$"

                        .END