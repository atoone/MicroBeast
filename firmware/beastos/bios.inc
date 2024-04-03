;
; MicroBeast BIOS.inc
;
; Include file for the MicroBeast BIOS Jump table and CP/M BIOS calls
;
; For BIOS version 1.6+
;


CPM_BOOT                .EQU    0EE00h
CPM_WBOOT               .EQU    0EE03h
CPM_CONIST              .EQU    0EE06h  ; Console status - Return A = 0FFH if character ready, 00H if not
CPM_CONIN               .EQU    0EE09h  ; Console input  - Wait for input, returning character in A
CPM_CONOUT              .EQU    0EE0Ch  ; Console OUTput - Write character in C to console
CPM_LIST                .EQU    0EE0Fh  ; List device OUTput
CPM_PUNCH_OUT           .EQU    0EE12h  ; Punch card device OUTput
CPM_READ_IN             .EQU    0EE15h  ; Card Reader input
CPM_DSK_HOME            .EQU    0EE18h  ; Home disk
CPM_DSK_SELECT          .EQU    0EE1Bh  ; Select disk
CPM_DSK_TRACK           .EQU    0EE1Eh  ; Select track
CPM_DSK_SECTOR          .EQU    0EE21h  ; Select sector
CPM_DSK_DMA             .EQU    0EE24h  ; Set DMA ADDress
CPM_DSK_READ            .EQU    0EE27h  ; Read 128 bytes
CPM_DSK_WRITE           .EQU    0EE2Ah  ; Write 128 bytes
CPM_LIST_STATUS         .EQU    0EE2Dh  ; List status
CPM_SECTOR_TRANSLATE    .EQU    0EE30h  ; Sector translate

;
; CALL MBB_GET_VERSION - Get the current BIOS version
;   Returns: A = Major, minor version in upper, lower nibble.
;
MBB_GET_VERSION         .EQU    0FDFAh

;
; CALL MBB_PLAY_NOTE - Play a note on the speaker
;   Parameters: 
;       D = Octave 2-6
;       E = Note 0-11
;       C = 1-15 duration, ~tenths of a second
;
MBB_PLAY_NOTE           .EQU    0FDF7h

;
; CALL MBB_WAIT_KEY - Waits for until a key is pressed and released
;
MBB_WAIT_KEY            .EQU    0FDF4h

;
; CALL MBB_I2C_RD_ADDRESS - Read a byte from device, with address. i2c_stop is not called.
;   Parameters:
;       H = Device ID
;       L = Address
;   Returns:
;       A = Byte read
;       Carry SET if success. 
;
MBB_I2C_RD_ADDRESS      .EQU    0FDF1h

;
; CALL MBB_I2C_WR_ADDRESS - Start writing to a device, with address. i2c_stop is not called.
;   Parameters:
;       H = Device ID
;       L = Address
;   Returns:
;       Carry SET if success.
;
MBB_I2C_WR_ADDRESS      .EQU    0FDEEh

;
; CALL MBB_I2C_READ - Read a byte from current device, without ACK.
;   Returns:
;       A = Byte read
;
MBB_I2C_READ            .EQU    0FDEBh

;
; CALL MBB_I2C_WRITE - Write a byte to current device. i2c_stop is not called.
;   Parameters:
;       A = Byte to write
;   Returns:
;       Carry SET if success.
;
MBB_I2C_WRITE           .EQU    0FDE8h

;
; CALL MBB_I2C_STOP - Send I2C Stop sequence
;
MBB_I2C_STOP            .EQU    0FDE5h

;
; CALL MBB_I2C_START - Send I2C Start sequence
;
MBB_I2C_START           .EQU    0FDE2h

;
; CALL MBB_SET_PAGE - Set page mapping
;   Parameters:
;       A = Logical (CPU) page to set (0-2)
;       E = Physical page (00-1F: ROM 20-3F: RAM)
;
MBB_SET_PAGE            .EQU    0FDDFh

;
; CALL MBB_PRINT - Print following inline text
; .DB "Test to print", 0
;
MBB_PRINT               .EQU    0FDDCh
