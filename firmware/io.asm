;
; I/O routines.. specifically keyboard and serial
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


keyboard_init       LD      HL, keyboard_state
                    LD      B, io_data_end - keyboard_state
                    XOR     A
_init_loop          LD      (HL),A
                    INC     HL
                    DEC     B
                    JR      NZ, _init_loop
                    XOR     A
                    LD      (input_size),A
                    LD      (input_free),A
                    LD      (input_pos),A
                    RET

; Poll the keyboard, adding raw codes to the keyboard_state buffer, and decoded characters to the input_buffer
;
keyboard_poll       LD      BC, 0FE00h          ; Keyboard row 0
                    LD      HL, keyboard
_poll_loop          IN      A, (C)              ; BC -> Keyboard row port..
                    LD      D, 1                ; D -> Current Bit
                    LD      E, A                ; E -> Key row bit set
_next_key           LD      (keyboard_pos), HL
                    AND     D
                    JR      NZ, _released
                                                ; Key is pressed... add it to state buffer
                    PUSH    BC
                    LD      A, (HL)             ; Raw key code in A

                    LD      HL, keyboard_state
                    LD      B, _key_state_size
_check_pressed      CP      (HL)
                    JP     Z, _do_nothing      ; Key already in state table - nothing to do..
                    INC     HL
                    DEC     B
                    JR      NZ, _check_pressed
                                                ; Key wasn't pressed, so add it to the first free slot
                    LD      HL, keyboard_state
                    LD      B, _key_state_size
                    LD      C, A
                    XOR     A
_find_free          CP      (HL)
                    JR      Z, _key_pressed
                    INC     HL
                    DEC     B
                    JR      NZ, _find_free
                    JP      _do_nothing         ; No free slots, so ignore the key

_key_pressed        LD      (HL), C             ; Found free slot, store the raw key code

                                                ; Now find the actual character code and add it to the input buffer
                    LD      A, KEY_SHIFT        ; Handle modifier keys
                    CP      C
                    LD      B, KEY_SHIFT_BIT
                    JR      Z, _modifier
                    LD      A, KEY_CTRL
                    CP      C
                    LD      B, KEY_CTRL_BIT
                    JR      Z, _modifier         

                    LD      HL, (keyboard_pos)  ; Get the current keyboard character location
                    LD      BC, _keyboard_size
                    LD      A, (key_shift_state)
                    AND     A
                    JR      Z, _get_key
_modifier_offset    ADD     HL, BC
                    DEC     A
                    JR      NZ, _modifier_offset

                    LD      A, (HL)             ; Check for special control characters 
                    LD      C, A
                    AND     CTRL_KEY_MASK
                    CP      CTRL_KEY_CHECK
                    JR      NZ, _get_key

                    LD      A, (HL)             ; Store them in a separate location
                    LD      (control_key_pressed), A
                    JR      _do_nothing

                                                ; Write the character to the input buffer
_get_key            LD      A, (HL)             ; Get the actual character...
                    AND     A                   ; Skip blank character codes
                    JR      Z, _do_nothing

                    LD      L, A                ; Store it in L

                    LD      A, (input_size)     ; Now check we have space
                    CP      _input_buffer_size
                    JR      Z, _do_nothing

                    INC     A
                    LD      (input_size), A

                    LD      B, 0
                    LD      A, (input_free)
                    LD      C, A
                    LD      A, L                ; Get the character from L
                    LD      HL, input_buffer
                    ADD     HL, BC
                    LD      (HL), A             ; Store the character

                    INC     C                   ; Point to next byte in input
                    LD      A, 0Fh
                    AND     C
                    LD      (input_free), A

                    POP     BC
                    JR      _poll_next

_modifier           LD      A, (key_shift_state)
                    OR      B
                    LD      (key_shift_state), A
                    JR      _do_nothing

                                                ; Key is not pressed... remove it from the state buffer if it was pressed (key up event)
                                                ; TODO: This is rather inefficient...
_released           PUSH    BC
                    LD      A, (HL)             ; Raw key code in A
                    AND     A
                    JR      Z, _do_nothing      ; Ignore character zero

                    LD      HL, keyboard_state
                    LD      B, _key_state_size
_check_released     CP      (HL)
                    JR      Z, _handle_release
                    INC     HL
                    DEC     B
                    JR      NZ, _check_released
                    JR      _do_nothing         ; Code not in state buffer, not released

_handle_release     LD      C, A
                    XOR     A
                    LD      (HL), A             ; Remove it from the buffer 

                                                ; TODO: We should probably tell someone about this...
                    LD      A, KEY_SHIFT        ; Handle modifier keys
                    CP      C
                    LD      B, KEY_SHIFT_BIT
                    JR      Z, _modifier_up
                    LD      A, KEY_CTRL
                    CP      C
                    LD      B, KEY_CTRL_BIT
                    JR      Z, _modifier_up     

_do_nothing         POP     BC

_poll_next          LD      HL, (keyboard_pos)
                    LD      A, E                ; Get the bitmask back
                    INC     HL
                    SLA     D
                    BIT     6, D
                    JP      Z, _next_key

                    RLC     B                   ; Move to the next key row
                    LD      A, 0FEh
                    CP      B
                    JP      NZ, _poll_loop
                    RET

_modifier_up        LD      A, (key_shift_state)
                    XOR     B
                    LD      (key_shift_state), A
                    JR      _do_nothing

;
; Reads the next available character in A, returning that or 0 if none are available
; Z flag is set if no character
; Uses HL, BC, A
read_character      LD      A, (input_size)
                    AND     A
                    RET     Z

                    DI                          ; Make sure we don't get into a race condition..
                    LD      A, (input_size)
                    DEC     A
                    LD      (input_size),A
                    LD      A, (input_pos)
                    LD      C, A
                    INC     A
                    AND     0Fh
                    LD      (input_pos),A
                    LD      B, 0
                    LD      HL, input_buffer
                    ADD     HL, BC
                    LD      A, (HL)
                    OR      A
                    EI
                    RET

;
; Beep  - Middle C is 261.625Hz = 30578 cycles at 8Mhz - 15289 per half cycle
; Call with: HL - cycle time ( 0E80h = Middle C )
;             E - Number of cycles
;


play_tone           IN      A, (AUDIO_PORT)        ; 200 cycles = 2/3 of a sec
                    LD      D, A
_beep_loop          LD      A, D
                    XOR     AUDIO_MASK
                    OUT     (AUDIO_PORT), A

                    LD      C, L
_beep_delay0        LD      B, H
_beep_delay1        DJNZ    _beep_delay1        ; 13 * (count-2) + 8
                    DEC     C
                    JR      NZ, _beep_delay0

                    LD      A, D          
                    OUT     (AUDIO_PORT), A

                    LD      C, L
_beep_delay2        LD      B, H
_beep_delay3        DJNZ    _beep_delay3        ; 13 * (count-2) + 8
                    DEC     C
                    JR      NZ, _beep_delay2      

                    DEC     E
                    JR      NZ, _beep_loop
                    RET

;
; Get the next key press
;
get_key             CALL    read_character
                    LD      B, 0
                    DJNZ    $
                    JR      Z, get_key
                    RET
;
; Wait for a key to be pressed and released
;
;
wait_for_key        CALL    read_character
                    LD      B, 0
                    DJNZ    $
                    JR      Z, wait_for_key

;
; wait until there are no keys being pressed
;
;
wait_no_keys        CALL    read_character
                    JR      NZ, wait_no_keys
                    LD      BC, 0h              ; Make sure key is released
                    IN      A, (C)
                    AND     03Fh
                    CP      03Fh
                    JR      NZ, wait_no_keys
                    RET

; Non-printing key codes
;
KEY_ENTER       .EQU    13
KEY_DELETE      .EQU    127
KEY_CTRL_C      .EQU    03h
KEY_CTRL_E      .EQU    05h

KEY_CTRL_P      .EQU    10h
KEY_CTRL_R      .EQU    12h
KEY_CTRL_S      .EQU    13h
KEY_CTRL_U      .EQU    15h
KEY_CTRL_X      .EQU    18h
KEY_CTRL_Z      .EQU    1Ah

KEY_BACKSPACE   .EQU    08h

; Modifier and special keys have key codes with the top bit set..
;
KEY_UP          .EQU    128
KEY_DOWN        .EQU    129
KEY_LEFT        .EQU    130
KEY_RIGHT       .EQU    131
KEY_SHIFT       .EQU    132
KEY_CTRL        .EQU    134

; 144 = 90h
;
CTRL_KEY_MASK   .EQU    0F8h
CTRL_KEY_CHECK  .EQU    090h

KEY_CTRL_UP     .EQU    144             ; These characters start on an exact multiple of 8 so they 
KEY_CTRL_DOWN   .EQU    145             ; Can easily be detected
KEY_CTRL_LEFT   .EQU    146
KEY_CTRL_RIGHT  .EQU    147
KEY_CTRL_ENTER  .EQU    148

_keyboard_size  .EQU    48

KEY_SHIFT_BIT   .EQU    1
KEY_CTRL_BIT    .EQU    2

keyboard        .DB    "vcxz", KEY_SHIFT, 0
                .DB    "gfdsa", KEY_CTRL
                .DB    "trewq", KEY_DOWN
                .DB    "54321", KEY_UP  
                .DB    "67890", KEY_BACKSPACE
                .DB    "yuiop;"
                .DB    "hjkl.", KEY_ENTER
                .DB    "bnm ", KEY_LEFT, KEY_RIGHT

_shifted        .DB     "VCXZ", 0, 0
                .DB     "GFDSA", 0
                .DB     "TREWQ", 0              ; Shift + down?
                .DB     "%$", 35, 34, "!", 0    ; Shift + up
                .DB     "^&*()", 0              ; Shift + delete
                .DB     "YUIOP:"
                .DB     "HJKL,", 0              ; Shift + enter
                .DB     "BNM", 0,0,0            ; Shift left + right

_ctrl           .DB    0,KEY_CTRL_C,KEY_CTRL_X,KEY_CTRL_Z,0,0
                .DB    0,0,0,KEY_CTRL_S,0,0
                .DB    0,KEY_CTRL_R,KEY_CTRL_E,0,0,KEY_CTRL_DOWN
                .DB    0,0,0,0,0,KEY_CTRL_UP
                .DB    0,0,0,0,0,KEY_DELETE
                .DB    0,KEY_CTRL_U, "+=-", 0
                .DB    0, "<@>_", KEY_CTRL_ENTER
                .DB    0, "?/", 0,KEY_CTRL_LEFT,KEY_CTRL_RIGHT

_shift_ctrl     .DB    0,0,0,0,0,0
                .DB    0,0,0,0,0,0
                .DB    0,0,0,0,0,0
                .DB    0,0,0,0,0,0
                .DB    0,0,0,0,0,0
                .DB    0,0,0,0,KEY_CTRL_P,0
                .DB    0,0,0,0,0,0
                .DB    0,0,0,0,0,0
