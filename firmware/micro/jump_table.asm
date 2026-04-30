;
; MicroBeast jump table
;
;  __  __ _                ____                 _   
; |  \/  (_) ___ _ __ ___ | __ )  ___  __ _ ___| |_ 
; | |\/| | |/ __| '__/ _ \|  _ \ / _ \/ _` / __| __|
; | |  | | | (__| | | (_) | |_) |  __/ (_| \__ \ |_ 
; |_|  |_|_|\___|_|  \___/|____/ \___|\__,_|___/\__|                                                   
;                                                   
;


.IF JUMP_TABLE_SIZE != 21
    .ECHO "Jump table size is inconsistent"
    .STOP
.ENDIF

                    JP          load_ccp            ; 21 (0FDBEh) - Load the CP/M CCP
                    JP          configure_hardware  ; 20 (0FDC1h) - Set up default page mapping and interrupt handler
                    JP          i2c_ack             ; 19 (0FDC4h) - Send an i2c ACK.
                    JP          set_usr_interrupt   ; 18 (0FDC7h) - Set the User interrupt vector. HL = 0 to clear, or address of user routine. HL= 0FFFFh to query.
                    JP          bios_flash_write    ; 17 (0FDCAh) - Erase and write flash data. Data is written to 4K sectors, which are erased before writing.
                    JP          get_disk_page       ; 16 (0FDCDh) - Get the page in RAM/ROM being used as the base for the drive selected by A, or zero if error.
                    JP          rtc_get_time_hl     ; 15 (0FDD0h) - Get the time to the 7 bytes pointed to by HL. Returns carry set if sucessful
                    JP          disp_char_bright    ; 14 (0FDD3h) - Set LED Digit A to brightness C
                    JP          disp_bitmask        ; 13 (0FDD6h) - Directly write bitmask in HL to display column A
                    JP          m_print_inline      ; 12 (0FDD9h) - Print the characters following the call instruction
                    JP          get_page_mapping    ; 11 (0FDDCh) - Return the logical (cpu) page C (0-2) in A
                    JP          set_page_mapping    ; 10 (0FDDFh) - Set the logical (cpu) page in A (0-2) to the physical (RAM/ROM) page in E
                    JP          i2c_start           ; 9  (0FDE2h) - Sends I2C start sequence
                    JP          i2c_stop            ; 8  (0FDE5h) - Sends I2C stop sequence
                    JP          i2c_write           ; 7  (0FDE8h) - Write A as a byte to i2c bus. Carry SET if success. i2c_stop is not called.
                    JP          i2c_read            ; 6  (0FDEBh) - Read byte from i2C into A, without ACK
                    JP          i2c_write_to        ; 5  (0FDEEh) - Prepare to write to Device address H, Register L. Carry SET if success. i2c_stop is not called.
                    JP          i2c_read_from       ; 4  (0FDF1h) - Read a byte int A from Device address H, Register L. Carry SET if success. i2c_stop is not called.
                    JP          wait_for_key        ; 3  (0FDF4h) - Waits for until a key is pressed and released
                    JP          play_note           ; 2  (0FDF7h) - Plays the note defined by DE (octave, note) and C (duration, tenths)
                    JP          get_version         ; 1  (0FDFAh) - Returns the Bios version in A
