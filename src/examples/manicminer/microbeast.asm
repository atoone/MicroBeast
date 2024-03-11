; Setup routines for ManicMiner on MicroBeast
;
; Initialises the memory map and configures VideoBeast to emulate a Sinclair screen.
;
                
                INCLUDE "microbeast.inc"                   

                DI                                      ; Relocate the pages..
                LD      A, 021h
                OUT     (IO_PAGE_2), A
                INC     A
                OUT     (IO_PAGE_3), A
                JP      microbeast_init

microbeast_init LD      A, VIDEOBEAST_PAGE              ; VideoBeast in Bank 1 (4000h-7fffh)
                OUT     (IO_PAGE_1), A

                LD      A, VB_UNLOCK                    ; Unlock registers
                LD      (VB_REGISTERS_LOCKED), A

                LD      A, MODE_640 | MODE_DOUBLE | MODE_MAP_16K
                LD      (VB_MODE), A 

                LD      A, 0
                LD      (VB_PAGE_0), A

                LD      HL, VB_LAYER_0                  ; Disable all layers
                LD      DE, 16
                LD      B, 6

clear_layers    LD      (HL), A
                ADD     HL, DE
                DJNZ    clear_layers

                LD      A, 1                            ; Palette 4-7 in bottom half of registers
                LD      (VB_LOWER_REGS), A

                LD      HL, sinclair_pal                ; Copy our sinclair colours into palette 7
                LD      DE, VB_REGISTERS + 32*3
                LD      BC, 32
                LDIR  
                
                LD      HL, sinclair_layer              ; Then set up the top layer as our display
                LD      DE, VB_LAYER_5
                LD      BC, 16
                LDIR

                LD      HL, 38FFh                       ; Now clear it ready for a high-res bitmap
                LD      (VBASE), HL

                LD      HL, VBASE
                LD      DE, VBASE+2
                LD      BC, 8192
                LDIR

                ; Set up the VideoBeast memory map to emulate a Sinclair layout.
                LD      A, MODE_640 | MODE_DOUBLE | MODE_MAP_SINCLAIR
                LD      (VB_MODE), A
                LD      A, 0ch
                LD      (VB_PAGE_1), A  ; Bitmap base
                LD      A, 0
                LD      (VB_PAGE_2), A  ; Screen offsets
                LD      A, 1
                LD      (VB_PAGE_3), A  ; Rest of 16K

                LD      HL, VBASE          ; Now clear the screen
                LD      DE, VBASE+1
                LD      BC, 6143
                LD      (HL), 0
                LDIR

                XOR     A                  ; And lock the registers
                LD      (VB_REGISTERS_LOCKED), A

                JP      BEGIN

beast_layer     DB    TYPE_BITMAP_4, 4, 4+16-2, 4, 4+32, 0A8h, 0, 068h
                DB    010h         ; Bitmap in page 10h
                DB    0h           ; 
                DB    01h          ; Palette 1
                DB    0            ; 
                DB    0, 0, 0, 0

sinclair_layer  DB    TYPE_TEXT, 4, 4+24-2, 4, 4+32, 0, 0, 0
                DB    0            ; Character map at offset 0
                DB    010h         ; Font at 16 * 2k -> 32kb
                DB    017h         ; Palette 7, Sinclair layout
                DB    0ch          ; Bitmap at 12 * 16k -> 192Kb
                DB    0, 0, 0, 0

                ; Sinclair palette (black, blue, red, magenta, green, cyan, yellow, white)
sinclair_pal    DW    00000h, 00018h, 06000h, 06018h, 00300h, 00318h, 06300h, 06318h  ; Normal
                DW    00000h, 0001Ch, 07000h, 0701Ch, 00380h, 0039Ch, 07380h, 0739Ch  ; Bright
