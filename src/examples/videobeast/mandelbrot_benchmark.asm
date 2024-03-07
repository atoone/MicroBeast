;
; Mandelbrot demo for VideoBeast on MicroBeast.
;
; Load to 08000h and execute via Memory Editor in MicroBeast Monitor
;
; Based on Matt Heffernan’s Mandlebrot Benchmark
;
; Build with:
;  tasm -t80 -b mandel.asm mandel_m8000.bin
;

                  .MODULE  main

                  .ORG   08000h

;--------------------------- BIOS routines ----------------------------------------
BIOS_SET_PAGE     .EQU  0fde2h            ; BIOS function - Set bank in A to page in E

;------------- Constants for this app -----------------------------------------------
VBASE             .EQU  04000h            ; The base address we'll use for VideoBeast

CHAR_PLING        .EQU  33                ; We'll redefine this character to draw the pixels

MAND_XMIN:        .equ  0FD80h   ; -2.5
MAND_XMAX:        .equ  00380h   ; 3.5    ; Actually width
MAND_YMIN:        .equ  0FF00h   ; -1
MAND_YMAX:        .equ  00200h   ; 2      ; Actually height

MAND_WIDTH:       .equ  32
MAND_HEIGHT:      .equ  22
MAND_MAX_IT:      .equ  15

;-------------------------- VideoBeast register definitions -----------------------
V_REGS            .EQU  VBASE + 03F00h

VB_MODE           .EQU  V_REGS + 0FFh
VB_UNLOCK         .EQU  V_REGS + 0FEh
VB_BACKGROUND     .EQU  V_REGS + 0FCh
VB_RASTER         .EQU  V_REGS + 0FAh
VB_PAGE_0         .EQU  V_REGS + 0F9h
VB_PAGE_1         .EQU  V_REGS + 0F8h
VB_PAGE_2         .EQU  V_REGS + 0F7h
VB_PAGE_3         .EQU  V_REGS + 0F6h
VB_LOWER_REGS     .EQU  V_REGS + 0F5h
VB_MATHS_XY       .EQU  V_REGS + 0E4h
VB_MATHS_Y        .EQU  V_REGS + 0E2h
VB_MATHS_X        .EQU  V_REGS + 0E0h
VB_LAYER_0        .EQU  V_REGS + 080h     ; Start of Layer definitions

LAYER_TYPE_TEXT   .EQU  1

MODE_DOUBLE       .EQU  8
MODE_640x480      .EQU  0
MODE_848x480      .EQU  1

REGS_PALETTE      .EQU  0

;--- Offsets in layer definition -----
LAYER_TOP         .EQU  1
LAYER_BOTTOM      .EQU  2
LAYER_LEFT        .EQU  3
LAYER_RIGHT       .EQU  4

;--- Offset in text layers -----------
TEXT_MAP_BASE     .EQU  8                 ; 16K page of text map
TEXT_FONT_BASE    .EQU  9                 ; 2K page of font
TEXT_PALETTE      .EQU  10                ; [3:0] - palette index
TEXT_BITMAP       .EQU  11                ; 16K page of high res bitmap

NUM_LAYERS        .EQU  6
UNLOCK_REGS       .EQU  0F3h

FONT_PAGE         .EQU  8                 ; The page for font data (4K pages)



;------------- Set up our screen: 320 x 240 with a text layer -----------------------
;
reset             LD    A, 01             ; Page VideoBeast into Bank 1 (0x4000-0x7FFF)
                  LD    E, 40h
                  CALL  BIOS_SET_PAGE

                  DI                      ; Stop the BIOS from interrupting us

                  LD    A, UNLOCK_REGS    ; Unlock registers
                  LD    (VB_UNLOCK), A

                                          ; Set mode to 320 x 240
                  LD    A, MODE_640x480 | MODE_DOUBLE
                  LD    (VB_MODE), A

                  LD    HL, 0008h
                  LD    (VB_BACKGROUND), HL

                  LD    HL, VB_LAYER_0    ; Disable all layers
                  LD    B, 16*NUM_LAYERS
clear_layers      LD    (HL), 0
                  INC   HL
                  DJNZ  clear_layers
                                       ; Set up text layer
                  LD    A, LAYER_TYPE_TEXT            
                  LD    (VB_LAYER_0), A
                  LD    A, 4
                  LD    (VB_LAYER_0+LAYER_TOP), A
                  LD    (VB_LAYER_0+LAYER_LEFT), A
                  LD    A, 4+MAND_HEIGHT
                  LD    (VB_LAYER_0+LAYER_BOTTOM), A
                  LD    A, 4+MAND_WIDTH
                  LD    (VB_LAYER_0+LAYER_RIGHT), A
                  LD    A, FONT_PAGE * 2
                  LD    (VB_LAYER_0+TEXT_FONT_BASE), A

                                       ; Set the palette
                  LD    A, REGS_PALETTE
                  LD    (VB_LOWER_REGS), A


                  LD    BC, 8000h
                  LD    (V_REGS), BC

                  LD    IX, V_REGS+2
                  LD    HL, 1080h
                  LD    B, 14

pal_loop          LD    (IX), L
                  INC   IX
                  LD    (IX), H
                  INC   IX

                  LD    DE, 0004h
                  BIT   1, B
                  JR    NZ, pal_not_odd
                  LD    DE, 1080h
pal_not_odd       ADD   HL, DE

                  DJNZ  pal_loop
                  LD    (IX), 0
                  LD    (IX+1), 0

                                       ; Now update our font to draw a block character

                  LD    A, FONT_PAGE   ; Set VB page to the font data
                  LD    (VB_PAGE_0), A

                  LD    A, 0ffh        ; Update our character to a square block
                  LD    HL, VBASE+(8*CHAR_PLING)   
                  LD    (HL), A
                  INC   HL
                  LD    B, 6
char_loop         LD    (HL), 81h
                  INC   HL
                  DJNZ  char_loop
                  LD    (HL),A

                  LD    A, 0           ; Set VB page to text layer
                  LD    (VB_PAGE_0), A

                  CALL  clear_screen

                                       ; Display Prompt to press a key
                  LD    HL, wait_message  
                  LD    DE, VBASE + ((MAND_HEIGHT/2)<<8) + 8
message_loop      LDI
                  LD    A, 0E0h        ; Foreground colour 14 (0eh), background 0 
                  LD    (DE), A
                  INC   DE
                  LD    A, (HL)
                  AND   A
                  JR    NZ, message_loop

                                       ; Wait for keypress
_wait             LD    BC,0FD00h      ; A9 is low -> Read Row 1
                  IN    A, (C)         ; A contains keys G, F, D, S, A, CTRL
                  AND   03Fh
                  CP    03Fh
                  JP    Z, _wait

                  CALL  clear_screen

                  CALL  plot           ; Draw the Mandelbrot

                  EI
                  RET

wait_message      .DB   "Press S to start", 0

clear_screen:
                  LD    H, VBASE >> 8  ; Fill text layer with our character, set transparent

_next_row         LD    L, 0
                  LD    B, MAND_WIDTH
_fill_row         LD    (HL),CHAR_PLING
                  INC   L
                  LD    (HL),00h          
                  INC   L
                  DJNZ  _fill_row

                  INC   H
                  LD    A, H
                  CP    (VBASE>>8)+MAND_HEIGHT+1
                  JR    NZ, _next_row
                  RET

plot:
                  LD    BC,0           ; X = 0, Y = 0
_pl_loop:
                  CALL  mand_get
                  INC   A
                  LD    E,A            ; E = Num iterations

                  LD    A, B           ; Set attribute at the correct screen location B=X, C=Y
                  SLA   A
                  INC   A
                  LD    L, A
                  LD    A, C
                  ADD   A, VBASE >> 8
                  LD    H, A
                  LD    (HL), E

                  INC   B              ; Increment x
                  LD    A,MAND_WIDTH
                  CP    B
                  JP    NZ,_pl_loop    ; Loop until x = width

                  LD    B,0            ; X = 0
                  INC   C              ; Increment y
                  LD    A,MAND_HEIGHT
                  CP    C
                  JP    NZ,_pl_loop    ; Loop until y = height
                  RET


mand_i:        .db 0

mand_x0:       .dw 0
mand_y0:       .dw 0
mand_x:        .dw 0
mand_y:        .dw 0
mand_x2:       .dw 0
mand_y2:       .dw 0
mand_xtemp:    .dw 0

mand_get:   ; Input:
            ;  B,C - X,Y bitmap coordinates
            ; Output: A - # iterations executed (0 to MAND_MAX_IT-1)
                  PUSH  BC             ; preserve BC (X,Y)
                  LD    C,0            ; BC = X
                  LD    D,MAND_WIDTH   ; DE = width
                  LD    E,0
                  CALL  fp_divide      ; HL = X/width
                  LD    C,L            ; BC = X/width
                  LD    B,H
                  LD    DE,MAND_XMAX   ; DE = Xmax
                  CALL  fp_multiply    ; HL = X/width*Xmax
                  LD    DE,MAND_XMIN   ; DE = Xmin
                  ADD   HL,DE          ; HL = X/width*Xmax + Xmin
                  LD    (mand_x0),HL   ; X0 = HL
                  POP   BC             ; retrieve X,Y from stack

                  PUSH  BC             ; put X,Y back on stack
                  LD    B,C
                  LD    C,0            ; BC = Y
                  LD    DE,MAND_YMAX   ; DE = Ymax
                  CALL  fp_multiply    ; HL = Y*Ymax
                  LD    C,L
                  LD    B,H            ; BC = Y*Ymax
                  LD    D,MAND_HEIGHT  ; DE = height
                  LD    E,0
                  CALL  fp_divide      ; HL = Y*Ymax/height
                  LD    DE,MAND_YMIN   ; DE = Ymin
                  ADD   HL,DE          ; HL = Y*Ymax/height + Ymin
                  LD    (mand_y0),HL   ; Y0 = HL

                  LD    HL,0
                  LD    (mand_x),HL    ; X = 0
                  LD    (mand_y),HL    ; Y = 0
                  XOR   A              ; I = 0
_loopi:
                  PUSH  AF             ; A = I
                  LD    BC,(mand_x)    ; BC = X
                  LD    D,B
                  LD    E,C            ; DE = X
                  CALL  fp_multiply    ; HL = X^2
                  PUSH  HL             ; put X^2 on stack
                  LD    BC,(mand_y)    ; BC = Y
                  LD    D,B
                  LD    E,C            ; DE = Y
                  CALL  fp_multiply    ; HL = Y^2
                  POP   DE             ; DE = X^2
                  PUSH  DE             ; get X^2 from stack and put it back again
                  PUSH  HL             ; HL = Y^2
                  ADD   HL,DE          ; HL = X^2+Y^2
                  POP   BC             ; BC = Y^2
                  POP   DE             ; DE = X^2
                  LD    A,4            ; A = 4
                  SUB   H              ; A = 4 - int(X^2 + Y^2)
                  JP    C,_dec_i       ; if (4 - int(X^2 + Y^2) < 0)  -> exit
                  JP    NZ,_do_it      ; if (4 - int(X^2 + Y^2) != 0) -> do_it
                  LD    A,L            ; A = frac(X^2 + Y^2)
                  OR    A              ; z-flag set if A == 0
                  JR    NZ,_dec_i      ; int(X^2 + Y^2) == 4  but frac(X^2 + Y^2) != 0 -> exit

_do_it:                                ; we get here with c-flag always clear
                  EX    DE,HL          ; HL = X^2
                  SBC   HL,BC          ; HL = X^2 - Y^2
                  LD    DE,(mand_x0)   ; DE = X0
                  ADD   HL,DE          ; HL =  X^2 - Y^2 + X0
                  PUSH  HL             ; Xtemp = HL
                  LD    BC,(mand_x)    ; BC = X
                  SLA   C
                  RL    B              ; BC = 2*X
                  LD    DE,(mand_y)    ; DE = Y
                  CALL  fp_multiply    ; HL = 2*X*Y
                  LD    DE,(mand_y0)   ; DE = Y0
                  ADD   HL,DE          ; HL = 2*X*Y + Y0
                  LD    (mand_y),HL    ; Y = HL
                  POP   HL             ; HL = Xtemp
                  LD    (mand_x),HL    ; X = HL
                  POP   AF             ; A = I
                  INC   A              ; A = I + 1
                  CP    MAND_MAX_IT    ; is A == maxI
                  JP    NZ,_loopi
                  PUSH  AF             ; need to push af on stack since there is another branch to _dec_i
_dec_i:
                  POP   AF             ; A = I
                  DEC   A              ; A = I - 1
                  POP   BC             ; restore BC (X,Y)
                  RET

; Fixed point maths routines, calculate results as 8.8 (8 bit integer, 8 bit fraction)
;
; FP Registers:
;  FP_A: BC
;  FP_B: DE
;  FP_C: HL
;  FP_R: L'

fp_floor_byte:                         ; A = floor(FP_C)
                  LD    A,H
                  BIT   7,A
                  RET   Z
                  LD    A,0
                  CP    L
                  LD    A,H
                  RET   Z
                  DEC   A
                  RET

fp_floor:                              ; FP_C = floor(FP_C)
                  BIT   7,H
                  JP    Z,fl_zerofrac
                  LD    A,0
                  CP    L
                  RET   Z
                  DEC   H
fl_zerofrac:
                  LD    L,0
                  RET

fp_divide:                             ; FP_C = FP_A / FP_B; FP_REM = FP_A % FP_B
                  PUSH  DE             ; preserve FP_B
                  BIT   7,B
                  JP    NZ,div_abs_a   ; get |FP_A| if negative
                  LD    H,B
                  LD    L,C            ; FP_C = FP_A
                  JP    div_check_sign_b
div_abs_a:
                  LD    HL,0
                  OR    A
                  SBC   HL,BC          ; FP_C = |FP_A|
div_check_sign_b:
                  BIT   7,D
                  JP    Z,div_shift_b
                  PUSH  HL             ; preserve FP_C
                  LD    HL,0
                  OR    A
                  SBC   HL,DE
                  EX    DE,HL          ; FP_B = |FP_B|
                  POP   HL             ; restore FP_C
div_shift_b:
                  LD    E,D
                  LD    D,0
                  PUSH  BC             ; preserve FP_A
                  PUSH  DE             ; copy FP_B
                  EXX                  ; to DE' register
                  POP   DE
                  LD    HL,0           ; FP_R in HL' register
                  EXX
                  LD    B,16
div_loop1:
                  ADD   HL,HL          ; Shift hi bit of FP_C into REM
                  EXX                  ; switch to alternative registers set
                  ADC   HL,HL          ; 16-bit left shift
                  LD    A,L
                  SUB   E              ; trial subtraction
                  LD    C,A
                  LD    A,H
                  SBC   A,D
                  JP    C,div_loop2    ; Did subtraction succeed?
                  LD    L,C            ; if yes, save it
                  LD    H,A
                  EXX                  ; switch to primary registers set
                  INC   L              ; and record a 1 in the quotient
                  EXX                  ; switch to alternative registers set
div_loop2:
                  EXX                  ; switch to primary registers set
                  DJNZ  div_loop1      ; decrement register B and loop while B>0
                  POP   BC             ; restore FP_A
                  POP   DE             ; restore FP_B
                  BIT   7,D
                  JP    NZ,div_check_cancel
                  BIT   7,B
                  RET   Z
                  JP    div_negative
div_check_cancel:
                  BIT   7,B
                  RET   NZ
div_negative:
                  PUSH  BC
                  LD    B,H
                  LD    C,L
                  LD    HL,0
                  OR    A
                  SBC   HL,BC
                  POP   BC
                  RET


fp_multiply:      ; VideoBeast maths accelerator HL = BC * DE
                  LD    (VB_MATHS_X), BC
                  LD    (VB_MATHS_Y), DE
                  LD    HL, (VB_MATHS_XY+1)
                  RET

fp_multiply_x:    ; FP_C = FP_A * FP_B; FP_R overflow
                  PUSH  BC             ; preserve FP_A
                  PUSH  DE             ; preserve FP_B
                  BIT   7,B
                  JP    Z,mul_check_sign_b
                  LD    HL,0
                  OR    A
                  SBC   HL,BC
                  LD    B,H
                  LD    C,L            ; FP_A = |FP_A|
mul_check_sign_b:
                  BIT   7,D
                  JP    Z,mul_init_c
                  LD    HL,0
                  OR    A
                  SBC   HL,DE
                  LD    D,H
                  LD    E,L            ; FP_B = |FP_B|
mul_init_c:
                  LD    HL,0           ; fp_scratch in register H'
                  EXX                  ; fp_remainder in register L'
                  LD    HL,0
                  EXX                  ; switch to primary registers set
                  LD    A,16           ; fp_i in register A
mul_loop1:
                  SRL   D
                  RR    E
                  JP    NC,mul_loop2
                  ADD   HL,BC
mul_loop2:
                  RR    H
                  RR    L
                  EXX                  ; switch to alternative registers set
                  RR    H
                  RR    L
                  EXX                  ; switch to primary registers set
                  DEC   A
                  JP    NZ,mul_loop1
                  LD    A,L
                  EXX                  ; switch to alternative registers set
                  LD    E,A            ; we don't values in primary set anymore
                  LD    D,0            ; so will use alternative set as primary
                  LD    B,8            ; register B as loop counter
mul_loop3:
                  SRL   D
                  RR    E
                  RR    H
                  RR    L
                  DJNZ  mul_loop3      ; decrement and loop
                  POP   DE             ; restore FP_B
                  POP   BC             ; restore FP_A
                  BIT   7,D
                  JP    NZ,mul_check_cancel
                  BIT   7,B
                  RET   Z
                  JP    mul_negative
mul_check_cancel:
                  BIT   7,B
                  RET   NZ
mul_negative:
                  PUSH  BC             ; preserve FP_A
                  LD    B,H
                  LD    C,L
                  LD    HL,0
                  OR    A
                  SBC   HL,BC
                  POP   BC             ; restore FP_A
                  RET


                  .END
