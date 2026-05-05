;
; Common Data - Variables used by both boot firmware and BIOS
; 
;


; I2C/Port B routines
port_b_mode         .EQU    0FF00h
nio_i2c_data        .EQU    0FF00h          ; Nanobeast I2C state shares location with port b mode..
port_b_dir          .EQU    0FF01h
port_b_data         .EQU    0FF02h

; Boot 
boot_mode           .EQU    0FF03h          ; Boot options byte, once keyboard has been checked. Default/unset is zero
device_id           .EQU    0FF04h          ; Identify the device we're booting on - DEVICE_MICRO or DEVICE_NANO
display_detect      .EQU    0FF05h          ; Which display(s) are detected - bitmask of DISPLAY_LED, DISPLAY_LCD

timer               .EQU    0FF06h          ; 2 Words - counts up by 1 every 64th of a second. Rollover ~2 years.

VAR_AREA_START      .EQU    0FF0Ah

;---------------------------------------------------------------------
; Constants used in vars above
;
DEVICE_MICRO        .EQU    001h            ; ID for the hardware we're running on (stored in device_id)
DEVICE_NANO         .EQU    002h

DISPLAY_LCD         .EQU    001h            ; Bitmask for detected displays (stored in display_detect)
DISPLAY_LED         .EQU    002h            ; Note that this must be 2

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