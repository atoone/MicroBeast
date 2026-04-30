;
; NanoBeast hardware specific routines
;
;  _   _                   ____                 _   
; | \ | | __ _ _ __   ___ | __ )  ___  __ _ ___| |_ 
; |  \| |/ _` | '_ \ / _ \|  _ \ / _ \/ _` / __| __|
; | |\  | (_| | | | | (_) | |_) |  __/ (_| \__ \ |_ 
; |_| \_|\__,_|_| |_|\___/|____/ \___|\__,_|___/\__|
;                                                   
;
                    .MODULE  nanobeast

; Play a note
; D = Octave 2-6
; E = Note 0-11
; C = 1-15 duration, ~tenths of a second
;
play_nano           LD      A, 7
                    SUB     D
                    LD      D, 0
                    LD      HL, _note_table
                    ADD     HL, DE
                    ADD     HL, DE

                    LD      E, (HL)
                    INC     HL
                    LD      D, (HL)

_note_octave        AND     A
                    JR      Z, _note_shifted

                    SRL     D
                    RR      E
                    DEC     A
                    JR      _note_octave

_note_shifted       LD      B, C
                    LD      C, A        ; A is zero from previous octave calc
                    SLA     B    
                    SLA     B    
                    SLA     B    
                    SLA     B           ; Now BC = 4096 * C

                    IN      A, (AUDIO_PORT)
                    LD      (_tone_val), A
                    DI

_tone_loop          ; 186 T-states          
                    XOR     A                   ; 4
                    ADD     HL, DE              ; 11
                    CCF                         ; 4   Complement carry
                    RLA                         ; 4   Carry into bit 1
                    DEC     A                   ; 4 

                    ; Waste 12 t states:
                    JR      _next               ; 12
_next
                    AND     NAUDIO_MASK         ; 7

_tone_val           .EQU    $+1
                    XOR     0                   ; 7
                    LD      (_tone_val), A      ; 13
                    OR      NAUDIO_REGISTER     ; 7

                    OUT     (AUDIO_PORT),A      ; 12

                    LD      A, B                ; 4
                    LD      B, 5                ; 7
                    DJNZ    $                   ; 4 * 13 + 8 = 60
                    LD      B, A                ; 4

                    DEC     BC                  ; 6
                    LD      A, B                ; 4
                    OR      C                   ; 4
                    JR      NZ, _tone_loop      ; 12

                    EI
                    RET

_note_table         .DW 6379
                    .DW 6757
                    .DW 7158
                    .DW 7585
                    .DW 8035
                    .DW 8512
                    .DW 9023
                    .DW 9553
                    .DW 10124
                    .DW 10730
                    .DW 11360
                    .DW 12045
                    .DW 0

                    .MODULE main