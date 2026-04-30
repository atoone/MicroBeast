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
KEY_ESCAPE      .EQU    1Bh

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
KEY_CTRL_SPACE  .EQU    149 
KEY_CTRL_D      .EQU    150