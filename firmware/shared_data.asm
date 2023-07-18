;
; Shared data - common state data for routines
;
;


; I2C/Port B routines
port_b_mode         .equ    0FF00h
port_b_dir          .equ    0FF01h
port_b_data         .equ    0FF02h

; Boot 
boot_mode           .equ    0FF03h          ; Zero = normal boot, non-zero = delete pressed
temp_byte           .equ    0FF04h

; Display functions
display_address     .equ    0FF05h          ; byte - address of the display driver (right or left) being written to

;
; Stuff
timer               .equ    0FF06h          ; Word

; General I/O
;
; This MUST start with keyboard_state, and will all be reset to zero when io_init is called
;
_key_state_size     .EQU    8               ; 8 key rollover

keyboard_state      .EQU    0FF08h          ; state buffer - 8 bytes containing raw key codes for keys currently pressed
keyboard_pos        .EQU    0FF10h          ; Internal state
key_shift_state     .EQU    0FF12h          ; Holds state of shift and control keys in bits 0 and 1 respectively
last_keycode        .EQU    0FF13h          ; The last keycode that was pressed, for repeats..
key_repeat_time     .EQU    0FF14h            ; How many poll events since the key state last changed

_input_buffer_size  .EQU    16
input_buffer        .EQU    0FF15h          ; 16 byte input buffer. Note wraparound is handled by bitmasks, so don't change this length
input_pos           .EQU    0FF25h          ; Next read position in input buffer
input_free          .EQU    0FF26h          ; Next write position in input buffer
input_size          .EQU    0FF27h          ; Bytes occupied in the input buffer

io_data_end         .EQU    0FF28h          ; Byte after IO data block, used to reset values to zero

control_key_pressed .EQU    0FF29h

scratch_pad         .EQU    0FF2Ah          ; 26 byte scratch area used for composing display output (eg. rtc time display etc.)

temp_data           .EQU    0FF44h          ; 8 byte general data area

menu_start          .EQU    0FF4Ch          ; Start address of current menu definition
menu_item_start     .EQU    0FF4Eh          ; Start address of first item in menu
menu_count          .EQU    0FF50h          ; Number of items in menu
menu_index          .EQU    0FF51h          ; Current menu item
menu_timer          .EQU    0FF52h          ; Time since menu was displayed
menu_enabled        .EQU    0FF53h          ; D0 - D7 -> Menu item 1 to 8 set enabled (1) or disabled (0) 

cursor_pos          .EQU    0FF54h          ; Position of cursor for prompt

;
; Panic codes
;
PANIC_0001          .EQU    0F001h
PANIC_0002          .EQU    0F002h
PANIC_0003          .EQU    0F003h
PANIC_0004          .EQU    0F004h