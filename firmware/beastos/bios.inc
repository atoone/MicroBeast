;
; MicroBeast BIOS.inc
;
; Include file for the MicroBeast BIOS Jump table and CP/M BIOS calls
;
; For BIOS version 1.6+
;

;
; CP/M BDOS 2.2 call vectors. CALL BDOS with C set to one of the following values
;  Reference: http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm
;
BDOS                    .EQU    00005h

BDOS_RESET              .EQU    00h
BDOS_CONIN              .EQU    01h
BDOS_CONOUT             .EQU    02h
BDOS_READIN             .EQU    03h
BDOS_PUNCHOUT           .EQU    04h
BDOS_LISTOUT            .EQU    05h
BDOS_CONIO              .EQU    06h
BDOS_GETIOBYTE          .EQU    07h
BDOS_SETIOBYTE          .EQU    08h
BDOS_PRINTSTRING        .EQU    09h
BDOS_READBUFFER         .EQU    0Ah
BDOS_CONSOLESTATUS      .EQU    0Bh
BDOS_GETVERSION         .EQU    0Ch
BDOS_RESETDISK          .EQU    0Dh
BDOS_SELECTDISK         .EQU    0Eh
BDOS_OPENFILE           .EQU    0Fh
BDOS_CLOSEFILE          .EQU    10h
BDOS_SEARCHFIRST        .EQU    11h
BDOS_SEARCHNEXT         .EQU    12h
BDOS_DELETEFILE         .EQU    13h
BDOS_READSEQ            .EQU    14h
BDOS_WRITESEQ           .EQU    15h
BDOS_MAKEFILE           .EQU    16h
BDOS_RENAMEFILE         .EQU    17h
BDOS_GETLOGINVECTOR     .EQU    18h
BDOS_GETCURRENTDISK     .EQU    19h
BDOS_SETDMAADDRESS      .EQU    1Ah
BDOS_GETALLOCVECTOR     .EQU    1Bh
BDOS_WRITEPROTECT       .EQU    1Ch
BDOS_GETREADONLYVEC     .EQU    1Dh
BDOS_SETFILEATTR        .EQU    1Eh
BDOS_GETDISKPARAMS      .EQU    1Fh
BDOS_GETUSERCODE        .EQU    20h
BDOS_READRANDOM         .EQU    21h
BDOS_WRITERANDOM        .EQU    22h
BDOS_GETFILESIZE        .EQU    23h
BDOS_SETRANDOMRECORD    .EQU    24h
BDOS_RESETDRIVE         .EQU    25h
BDOS_WRITERANDOMZERO    .EQU    26h


;
; Direct access to bios entrypoints - use at own risk
;
BIOS_START              .EQU    0EA00h           ; If (WHEN) the BIOS start address changes, this will be invalidated

BIOS_BOOT               .EQU    BIOS_START
BIOS_WBOOT              .EQU    BIOS_START+003h
BIOS_CONIST             .EQU    BIOS_START+006h  ; Console status - Return A = 0FFH if character ready, 00H if not
BIOS_CONIN              .EQU    BIOS_START+009h  ; Console input  - Wait for input, returning character in A
BIOS_CONOUT             .EQU    BIOS_START+00Ch  ; Console OUTput - Write character in C to console
BIOS_LIST               .EQU    BIOS_START+00Fh  ; List device OUTput
BIOS_PUNCH_OUT          .EQU    BIOS_START+012h  ; Punch card device OUTput
BIOS_READ_IN            .EQU    BIOS_START+015h  ; Card Reader input
BIOS_DSK_HOME           .EQU    BIOS_START+018h  ; Home disk
BIOS_DSK_SELECT         .EQU    BIOS_START+01Bh  ; Select disk
BIOS_DSK_TRACK          .EQU    BIOS_START+01Eh  ; Select track
BIOS_DSK_SECTOR         .EQU    BIOS_START+021h  ; Select sector
BIOS_DSK_DMA            .EQU    BIOS_START+024h  ; Set DMA ADDress
BIOS_DSK_READ           .EQU    BIOS_START+027h  ; Read 128 bytes
BIOS_DSK_WRITE          .EQU    BIOS_START+02Ah  ; Write 128 bytes
BIOS_LIST_STATUS        .EQU    BIOS_START+02Dh  ; List status
BIOS_SECTOR_TRANSLATE   .EQU    BIOS_START+030h  ; Sector translate


;
; MicroBeast BIOS Specific routines. These are placed at the end of the BIOS and should(!) be fixed for direct calls.
;
;


;
; CALL MBB_GET_VERSION - Get the current BIOS version
;   Returns: A = Major, minor version in upper, lower nibble. e.g. 016h = version 1.6
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
; CALL MBB_GET_PAGE - Get page mapping
;   Parameters:
;       C = Logical (CPU) page to get (0-2)
;   Returns 
;       A = Physical page (00-1F: ROM 20-3F: RAM), or 0FFH for error
;
MBB_GET_PAGE            .EQU    0FDDCh

;
; CALL MBB_PRINT - Print following inline text, zero terminated
; .DB "Test to print", 0
;
MBB_PRINT               .EQU    0FDD9h

;
; CALL MBB_WRITE_LED - Directly write bitmask to LED display (Check Font editor online for bit order)
;   Parameters:
;       HL = Bit pattern to write to LED digit
;       A  = Column (0-23)
;
MBB_WRITE_LED           .EQU    0FDD6h

;
; CALL MBB_LED_BRIGHTNESS - Set segments in digit A to brightness C
;   Parameters:
;       A  = Column (0-23)
;       C  = Brightness (0-128)
;
MBB_LED_BRIGHTNESS      .EQU    0FDD3h

;
; CALL MBB_RTC_TIME - Get the current time from the RTC
;   Parameters: 
;       HL = Address of 7 byte time data block to store current time 
;   Returns:
;       Carry SET if success
;
; Time Data block
;    HL    -> Seconds - 2 digits BCD
;    HL+1  -> Minutes - 2 digits BCD 
;    HL+2  -> Hour - 24hr clock, 2 digits BCD 
;    HL+3  -> Weekday (1-7. Monday=1)
;    HL+4  -> Day   1-31, 2 digits BCD 
;    HL+5  -> Month 1-12, 2 digits BCD 
;    HL+6  -> Year, 2 digits BCD 
;
MBB_RTC_TIME            .EQU    0FDD0h

; CALL MBB_GET_DRIVE_PAGE - Get the page in memory being used as the base for the drive selected by A
;   Parameters:
;       A = Drive number 0, 1
;   Returns:
;       A = Page in ROM/RAM for the given drive
;  or   A = 0 if the selected drive is not supported.
;
MBB_GET_DRIVE_PAGE      .EQU    0FDCDh

; CALL MBB_FLASH_WRITE - Erase and write flash data. Data is written to 4K sectors, which are erased 
; before writing. This uses Page 0 to write the data, so the source must be above 3FFFh
; Data is written from the start of the specified 4K sector
; Note: This means if BC is an exact multiple of sector size, D is returned as the previous sector
;
;   Parameters:
;       D -> 7 bit index of 4K sector being written
;       HL -> Address of source data
;       BC -> bytes to write
;   Returns:
;       D pointing to last sector written
;
MBB_FLASH_WRITE         .EQU    0FDCAh

; CALL MBB_SET_USR_INT - Set or query the user interrupt. 
; The specified routine will be called after keyboard polling, every 60th of a second. The shadow register 
; set is selected before the call (EXX), and AF is preserved. The routine should RETurn normally. 
; Interrupt routines survive warm reboots, but no special measures are taken to ensure the memory they 
; occupy is preserved.
;
;   Parameters: 
;       HL = Address of user interrupt routine, or zero to disable. Call with 0FFFFh to query the current value
;   Returns:
;       The address of the current user interrupt routine, or zero if none is configured.
;
MBB_SET_USR_INT         .EQU    0FDC7h

