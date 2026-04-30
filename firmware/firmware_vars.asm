;
; Shared data - common state data for routines
;
;

                    .ORG    VAR_AREA_START

control_key_pressed .BLOCK  1               

scratch_pad         .BLOCK  26              ; 26 byte scratch area used for composing display output (eg. rtc time display etc.)

temp_data           .BLOCK  8               ; 8 byte general data area

menu_start          .BLOCK  2               ; Start address of current menu definition
menu_item_start     .BLOCK  2               ; Start address of first item in menu
menu_count          .BLOCK  1               ; Number of items in menu
menu_index          .BLOCK  1               ; Current menu item
menu_timer          .BLOCK  1               ; Time since menu was displayed
menu_enabled        .BLOCK  1               ; D0 - D7 -> Menu item 1 to 8 set enabled (1) or disabled (0) 

cursor_pos          .BLOCK  1               ; Position of cursor for prompt
temp_byte           .BLOCK  1               

; Display functions
display_address     .BLOCK  1               ; byte - address of the display driver (right or left) being written to


DEVICE_MICRO        .EQU    001h            ; ID for the hardware we're running on
DEVICE_NANO         .EQU    002h

DISPLAY_LCD         .EQU    001h            ; Bitmask for detected displays
DISPLAY_LED         .EQU    002h            ; Note that this must be 2

;
; Panic codes
;
PANIC_0001          .EQU    0F001h
PANIC_0002          .EQU    0F002h
PANIC_0003          .EQU    0F003h
PANIC_0004          .EQU    0F004h

;
; Boot mode
;
NORMAL_BOOT         .EQU    0FFh
SKIP_OPTS           .EQU    000h             ; Skip reading boot options from RTC RAM

; Boot options
BOOT_TO_CPM         .EQU    001h
BOOT_NO_LED         .EQU    002h
BOOT_RESTORE_B      .EQU    004h
BOOT_TTY_INPUT      .EQU    008h