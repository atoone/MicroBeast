;
; Flash update routines
;
; Note that any memory write operations *at all* during flash updates will cancel the current operation.
; That means no data can be stored to memory, no stack operations (call, push), no interrupts.
; 
;
                    .MODULE     flash

_cmd_1_addr         .EQU  05555h
_cmd_2_addr         .EQU  02AAAh

_bank_mask          .EQU  03FFFh                ; One memory bank is 14 bits -> 16Kb
_sector_mask        .EQU  00FFFh                ; A sector is 12 bits -> 4Kb

_cmd_1_addr_bank    .EQU  _cmd_1_addr >> 14
_cmd_2_addr_bank    .EQU  _cmd_2_addr >> 14
_cmd_3_addr_bank    .EQU  _cmd_1_addr_bank
_cmd_4_addr_bank    .EQU  _cmd_1_addr_bank
_cmd_5_addr_bank    .EQU  _cmd_2_addr_bank

_cmd_1_logical_addr .EQU  _cmd_1_addr & _bank_mask
_cmd_2_logical_addr .EQU  _cmd_2_addr & _bank_mask
_cmd_3_logical_addr .EQU  _cmd_1_logical_addr
_cmd_4_logical_addr .EQU  _cmd_1_logical_addr
_cmd_5_logical_addr .EQU  _cmd_2_logical_addr

_cmd_1_data         .EQU  0AAh
_cmd_2_data         .EQU  055h
_cmd_3_data_write   .EQU  0A0h
_cmd_3_data_erase   .EQU  080h
_cmd_4_data         .EQU  0AAh
_cmd_5_data         .EQU  055h

_cmd_6_data_erase   .EQU  030h

;
; Enter with A -> 7 bit index of 4K sector to be erased.
;
; Preserves BC, DE, HL
;
; Note this uses bank 0, and leaves it configured for the page containing the erased sector
;
; Typical time to erase sector ~18ms
;
flash_sector_erase  DI                          ; Disable interrupts
                    PUSH    HL
                    PUSH    BC
                    PUSH    DE

                    AND     07fh
                    LD      D, A
                    SRL     D
                    SRL     D                   ; D is now the bank number

                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A
                    AND     030h
                    LD      E, A                ; E is the sector within the bank shifted into bits 13 & 12

                    LD      C, IO_MEM_0         ; Use bank 0 to write to
                    LD      A, _cmd_1_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_1_logical_addr
                    LD      (HL), _cmd_1_data

                    LD      A, _cmd_2_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_2_logical_addr
                    LD      (HL), _cmd_2_data

                    LD      A, _cmd_3_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_3_logical_addr
                    LD      (HL), _cmd_3_data_erase

                    LD      A, _cmd_4_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_4_logical_addr
                    LD      (HL), _cmd_4_data

                    LD      A, _cmd_5_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_5_logical_addr
                    LD      (HL), _cmd_5_data

                    OUT     (C), D                  ; Switch to the bank containing our sector
                    LD      H, E                    ; And write the sector bits as an address (bits 0-11 are ignored)
                    LD      (HL), _cmd_6_data_erase

_wait_erase         LD      A,(HL)
                    RLC     A
                    JR      NC, _wait_erase

                    POP     DE
                    POP     BC
                    POP     HL
                    EI
                    RET

;
; Enter with A -> Byte to write
;            D -> 7 bit index of 4K sector being written
;            HL -> 12 bit address of byte within sector
;
; Preserves D, HL
; Uses A, BC, E
;
; Typical time to erase byte ~14us
;
flash_write_byte    DI
                    LD      E, A                ; Preserve our byte
                    
                    LD      A, H                ; Make sure HL is within our sector
                    AND     _sector_mask >> 8
                    LD      H, A

                    LD      A, D                ; Make sure D is a valid sector index
                    AND     07fh
                    LD      D, A
                    LD      B, A

                    LD      A, D                ; Get the bottom 2 bits of our sector index..
                    AND     03h
                    SLA     A
                    SLA     A
                    SLA     A
                    SLA     A
                    OR      H
                    LD      H, A                ; ..and OR them into H to get a 14 bit address within our bank

                    SRL     D
                    SRL     D                   ; D is now our bank number

                    PUSH    HL

                    LD      C, IO_MEM_0         ; Use bank 0 to write to
                    LD      A, _cmd_1_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_1_logical_addr
                    LD      (HL), _cmd_1_data

                    LD      A, _cmd_2_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_2_logical_addr
                    LD      (HL), _cmd_2_data

                    LD      A, _cmd_3_addr_bank
                    OUT     (C), A
                    LD      HL, _cmd_3_logical_addr
                    LD      (HL), _cmd_3_data_write

                    OUT     (C), D
                    POP     HL
                    LD      (HL), E

_wait_byte          LD      A, (HL)
                    XOR     E
                    RLC     A
                    JR      NC, _wait_byte

                    LD      A, H                ; Clear bits 13 & 12 to restore HL to sector address..
                    AND     _sector_mask >> 8
                    LD      H, A
               
                    LD      D, B                ; And restore D
                    EI
                    RET

;
; Write a flash data block. This uses Page 0 to write the data, so the source must be above 4000h
;
;       D -> 7 bit index of 4K sector being written
;       HL -> Address of source data
;       BC -> bytes to write
;

flash_write         PUSH    IX
                    PUSH    HL
                    POP     IX
                    LD      HL, 0

_erase_sector       ; Lower 12 bits of HL are zero, erase sector before writing bytes
                    LD      A, D
                    CALL    flash_sector_erase
_write_loop         LD      A, (IX+0)
                    PUSH    BC
                    CALL    flash_write_byte
                    POP     BC

                    INC     IX
                    DEC     BC
                    LD      A, B
                    OR      C
                    JR      Z, _success

                    INC     HL
                    LD      A, L
                    AND     A
                    JR      NZ, _write_loop
                    LD      A, H
                    AND     _sector_mask >> 8
                    LD      H, A
                    JR      NZ, _write_loop

                    INC     D
                    JR      _erase_sector

_success            POP     IX
                    RET

                    .MODULE main
