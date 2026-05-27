;
; OLED - Demonstrate writing to an SSD1306 OLED controller over I2C
;
; Copyright (c) 2026 Andy Toone for Feersum Technology Ltd.
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
; Command line: OLED
;
; Displays an animation on an attached OLED display
;
;
                        .ORG    0100h

                        .INCLUDE "beastos/beastos.inc"


; Address is 0x3C for 32 pixel displays, 0x3D otherwise
SSD_ADDRESS             .EQU    03Ch

DISP_HEIGHT             .EQU    32
DISP_WIDTH              .EQU    128

; Generate display voltage from internal 3.3v source
;
; Uncomment the following to use an external source:
;
; #DEFINE EXTERNAL_VCC

#IFDEF EXTERNAL_VCC
_SSD_CHARGEPUMP         .EQU    010h
_SSD_PRECHARGE          .EQU    022h
#ELSE
_SSD_CHARGEPUMP         .EQU    014h
_SSD_PRECHARGE          .EQU    0F1h
#ENDIF

;
;
;
#IF DISP_HEIGHT == 32
_SSD_COMPINS            .EQU    002h
#ELSE
_SSD_COMPINS            .EQU    012h
#ENDIF

                        LD      (old_stack), SP
                        LD      SP, old_stack

                        CALL    display

                        LD      SP, (old_stack)
                        RET



display                 DI
                        LD      HL, display_init_1
                        CALL    ssd_sequence
                        LD      A, 1
                        JR      NC, ssd_error

                        LD      HL, display_init_2
                        CALL    ssd_sequence
                        LD      A, 2
                        JR      NC, ssd_error

                        LD      HL, display_init_3
                        CALL    ssd_sequence
                        LD      A, 3
                        JR      NC, ssd_error
                       
                        LD      HL, display_set_start
                        CALL    ssd_sequence
                        LD      A, 4
                        JR      NC, ssd_error
                       
                        LD      HL, logo_1
                        CALL    ssd_sequence
                        LD      E, 96
                        CALL    ssd_space

                        LD      HL, logo_2
                        CALL    ssd_sequence
                        LD      E, 96
                        CALL    ssd_space

                        LD      HL, logo_3
                        CALL    ssd_sequence
                        LD      E, 32
                        CALL    ssd_space

                        LD      HL, display_nano
                        CALL    ssd_sequence
                        LD      A, 5
                        JR      NC, ssd_error

                        LD      HL, display_beast
                        CALL    ssd_sequence
                        LD      A, 6
                        JR      NC, ssd_error

                        LD      E, 16
                        CALL    ssd_space

                        LD      HL, logo_4
                        CALL    ssd_sequence
                        LD      E, 96
                        CALL    ssd_space
                        EI
                        JR      animate

ssd_error               EI 
                        ADD     A, '0'
                        LD      (_ssd_err_msg), A
                        CALL    MBB_PRINT
                        .DB     "\r\nSSD Error :"
_ssd_err_msg            .DB     "0 \r\n", 0

                        RET

animate                 LD      A, 1
                        LD      (anim_dir), A
                        LD      A, 64
                        LD      (anim_pos), A

anim_loop               LD      A, (anim_dir)
                        LD      E, A
                        LD      A, (anim_pos)
                        ADD     A, E
                        LD      (anim_pos), A

                        CP      32
                        JR      Z, _reverse
                        CP      80
                        JR      Z, _reverse 

_anim_go                DI
                        CALL    ssd_column

                        LD      HL, display_nano
                        CALL    ssd_sequence

                        LD      HL, display_beast
                        CALL    ssd_sequence
                        EI 

                        LD      E, 0FFh
                        LD      C, BDOS_CONIO
                        CALL    BDOS

                        AND     A
                        RET     NZ

                        JR      anim_loop

_reverse                LD      A, (anim_dir)
                        NEG
                        LD      (anim_dir),A
                        LD      A, (anim_pos)
                        JR      _anim_go



SSD_COMMAND             .EQU    000h
SSD_DATA                .EQU    040h
SSD_DATA_CONTINUES      .EQU    000h

SET_MEMORY_MODE         .EQU    020h
SET_COLUMN_ADDRESS      .EQU    021h
SET_PAGE_ADDRESS        .EQU    022h
SET_DEACTIVATE_SCROLL   .EQU    02Eh

SET_STARTLINE           .EQU    040h
SET_CONTRAST            .EQU    081h
SET_CHARGEPUMP          .EQU    08Dh

SET_SEGREMAP            .EQU    0A0h
SET_DISPLAYALLON_RESUME .EQU    0A4h
SET_NORMAL_DISPLAY      .EQU    0A6h
DISPLAY_ON              .EQU    0AFh
DISPLAY_OFF             .EQU    0AEh
SET_MULTIPLEX           .EQU    0A8h

SET_COMSCAN_INC         .EQU    0C0h
SET_COMSCAN_DEC         .EQU    0C8h 

SET_DISPLAY_OFFSET      .EQU    0D3h
SET_DISPLAY_CLOCK_DIV   .EQU    0D5h
SET_PRECHARGE           .EQU    0D9h
SET_COMPINS             .EQU    0DAh



display_init_1          .DB     6,  SSD_COMMAND
                        .DB         DISPLAY_OFF
                        .DB         SET_DISPLAY_CLOCK_DIV, 080h
                        .DB         SET_MULTIPLEX, DISP_HEIGHT-1

display_init_2          .DB     10, SSD_COMMAND
                        .DB         SET_DISPLAY_OFFSET, 0
                        .DB         SET_STARTLINE | 000h
                        .DB         SET_CHARGEPUMP, _SSD_CHARGEPUMP
                        .DB         SET_MEMORY_MODE, 000h
                        .DB         SET_SEGREMAP | 001h
                        .DB         SET_COMSCAN_DEC

display_init_3          .DB     11, SSD_COMMAND
                        .DB         SET_COMPINS, _SSD_COMPINS
                        .DB         SET_CONTRAST, 08Fh
                        .DB         SET_PRECHARGE, _SSD_PRECHARGE
                        .DB         SET_DISPLAYALLON_RESUME
                        .DB         SET_NORMAL_DISPLAY
                        .DB         SET_DEACTIVATE_SCROLL
                        .DB         DISPLAY_ON

display_set_start       .DB      7, SSD_COMMAND
                        .DB         SET_PAGE_ADDRESS, 000h, DISP_HEIGHT-1
                        .DB         SET_COLUMN_ADDRESS, 000h, DISP_WIDTH-1

display_space           .DB     9,  SSD_DATA
                        .DB         000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

display_nano            .DB     25, SSD_DATA
                        .DB         0, 254, 12, 48, 64, 254, 0, 112, 136
                        .DB         136, 120, 128, 0, 240, 8, 8, 248
                        .DB         0, 112, 136, 136, 112, 0, 0

display_beast           .DB     25, SSD_DATA
                        .DB         0, 254, 146, 146, 108, 0, 112, 168
                        .DB         168, 176, 0, 112, 136, 248, 0, 144
                        .DB         168, 72, 0, 126, 136, 136, 0, 0

logo_1                  .DB     33, SSD_DATA 
                        .DB         0, 0, 0, 0, 192, 224, 240, 248
                        .DB         252, 192, 128, 8, 196, 228, 4, 228
                        .DB         20, 228, 4, 228, 196, 8, 128, 192
                        .DB         252, 248, 240, 224, 192, 0, 0, 0

logo_2                  .DB     33, SSD_DATA 
                        .DB         0, 0, 124, 15, 3, 135, 15, 7
                        .DB         113, 225, 195, 225, 243, 225, 224, 192
                        .DB         128, 192, 224, 241, 243, 225, 195, 225
                        .DB         113, 7, 15, 135, 3, 15, 60, 0

logo_3                  .DB     33, SSD_DATA 
                        .DB         0, 28, 96, 128, 16, 8, 5, 55
                        .DB         191, 255, 252, 248, 249, 253, 247, 255
                        .DB         231, 255, 247, 253, 249, 248, 252, 255
                        .DB         191, 55, 5, 8, 16, 128, 96, 30

logo_4                  .DB     33, SSD_DATA 
                        .DB         0, 0, 0, 0, 1, 2, 4, 8
                        .DB         24, 25, 46, 39, 99, 71, 71, 67
                        .DB         67, 71, 71, 71, 99, 39, 46, 25
                        .DB         24, 8, 4, 2, 1, 0, 0, 0



;
; Write Zero bytes to SSD display, for count in E
;
; Returns NC if error
;
ssd_space               LD          H, SSD_ADDRESS
                        LD          L, SSD_DATA
                        CALL        MBB_I2C_WR_ADDRESS
                        RET         NC
_space_loop             XOR         A
                        CALL        MBB_I2C_WRITE
                        RET         NC
                        DEC         E
                        JR          NZ, _space_loop
                        CALL        MBB_I2C_STOP
                        RET


_set_column             .DB     4,  SSD_COMMAND
                        .DB         SET_COLUMN_ADDRESS
_set_column_val         .DB         000h, DISP_WIDTH-1

;
; Set the current column to A
; 
;
ssd_column              LD          (_set_column_val), A
                        LD          HL, _set_column

;
; Send ssd sequence 
;
; Call with HL = location of sequence, starting with byte count
;
; Returns with carry set if sequence was successfully sent.
;
ssd_sequence            LD          D, SSD_ADDRESS

;
; Send i2c sequence 
;
; Call with  D = Address of device
;           HL = location of sequence, starting with byte count
;
; Returns with carry set if sequence was successfully sent.
;
i2c_sequence            CALL        MBB_I2C_START
                        LD          A, D
                        SLA         A
                        CALL        MBB_I2C_WRITE
                        LD          E, (HL)
                        INC         HL
_sequence_loop          LD          A, (HL)
                        INC         HL
                        CALL        MBB_I2C_WRITE
                        RET         NC
                        DEC         E
                        JR          NZ, _sequence_loop
                        CALL        MBB_I2C_STOP
                        RET

anim_pos                .DB         0
anim_dir                .DB         0

stack_space             .BLOCK  32          ; 16 deep stack..
old_stack               .DW     0


                        .END