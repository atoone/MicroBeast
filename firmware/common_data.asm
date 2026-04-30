;
; Common Data - Used by both boot firmware and BIOS
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