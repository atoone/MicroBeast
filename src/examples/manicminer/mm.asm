; Manic Miner disassembly, with additional changes to support MicroBeast & VideoBeast
; https://skoolkit.ca
;
; Copyright 1983 Bug-Byte Ltd (Manic Miner)
; Copyright 2010, 2012-2019 Richard Dymond (this disassembly)
;
; From https://gitlab.com/z80-source-code-software/other-systems/manic-miner-disassembly---zx-spectrum/-/blob/master/mm.asm
;
; Build Sinclair version with: pasmo --tapbas --equ SINCLAIR mm.asm mm.tap mm.sym
; Build VideoBeast version with: pasmo mm.asm mm1_m4000.bin
;

  ORG 32768
;
; Additional definitions
;
; 

IF DEFINED SINCLAIR
  ; Input ports
  PORT_ZXCV         EQU 0FEFEh     ; Port to read Shift-Z-X-C-V
  PORT_ASDF         EQU 0FDFEh     ; Port to read A-S-D-F-G
  PORT_QWER         EQU 0FBFEh
  PORT_1234         EQU 0F7FEh
  PORT_6789         EQU 0EFFEh
  PORT_POIU         EQU 0DFFEh
  PORT_HJKL         EQU 0BFFEh     ; Port to read H-J-K-L-Enter
  PORT_BNMSS        EQU 07FFEh     ; Port to read B-N-M-Symbol_Shift-Space

  PORT_ALL_KEYS     EQU 254
  PORT_KEMPSTON     EQU 31

  ; Key bitmasks - bit is SET for key being pressed
  KEY_SPACE         EQU 1
  KEY_8             EQU 4
  KEY_5             EQU 8
  KEY_ENTER         EQU 1

  ; Output ports
  PORT_SOUND        EQU 254
  PORT_BORDER       EQU 254

  SOUND_BIT         EQU 24
ELSE
  ; Input ports
  PORT_ZXCV         EQU 0FE00h     ; Port to read Shift-Z-X-C-V
  PORT_ASDF         EQU 0FD00h     ; Port to read A-S-D-F-G
  PORT_QWER         EQU 0FB00h
  PORT_1234         EQU 0F700h
  PORT_6789         EQU 0EF00h
  PORT_POIU         EQU 0DF00h
  PORT_HJKL         EQU 0BF00h     ; Port to read H-J-K-L-Enter
  PORT_BNMSS        EQU 07F00h     ; Port to read B-N-M-Symbol_Shift-Space

  PORT_ALL_KEYS     EQU 0
  PORT_KEMPSTON     EQU 31

  ; Key bitmasks - bit is SET for key being pressed
  KEY_SPACE         EQU 8
  KEY_8             EQU 4
  KEY_5             EQU 1
  KEY_ENTER         EQU 32

  ; Output ports
  PORT_SOUND        EQU 0
  PORT_BORDER       EQU 0

  SOUND_BIT         EQU 64
ENDIF

;
; Memory locations
; 
MICROBEAST_START  EQU 09400h
FONT_LOCATION     EQU 09900h
DATA_LOCATION     EQU 09D00h
STACK_TOP         EQU DATA_LOCATION-2

; Buffer addresses
ATTR_BUFFER       EQU 23552     ; 5C00h
ATTR_CACHE        EQU 24064     ; 5E00h

SCREEN_BUFFER     EQU 24576     ; 6000h
SCREEN_CACHE      EQU 28672     ; 7000h

SCREEN_LOCATION   EQU 16384     ; 4000h
SCREEN_BOTTOM     EQU 20480     ; Bottom third of screen
ATTR_LOCATION     EQU 22528     ; 5800h

GAME_OVER_ATTR    EQU 22730     ; Location of game over message attributes..
GAME_OVER_ATTR1   EQU 22738

AIR_ROW_HIGH      EQU 82        ; Pixel location of Air bar

;
; Note: PRINTCHAR_0 routine expects font at 3D00h
;

; Cavern name
;
; The cavern name is copied here and then used by the routine at STARTGAME.
CAVERNNAME:
  DEFS 32

; Cavern tiles
;
; The cavern tiles are copied here by the routine at STARTGAME and then used to
; draw the cavern by the routine at DRAWSHEET.
;
; The extra tile at EXTRA behaves like a floor tile, and is used as such in The
; Endorian Forest, Attack of the Mutant Telephones, Ore Refinery, Skylab
; Landing Bay and The Bank. It is also used in The Menagerie as spider silk,
; and in Miner Willy meets the Kong Beast and Return of the Alien Kong Beast as
; a switch.
BACKGROUND:
  DEFS 9                  ; Background tile (also used by the routines at
                          ; MOVEWILLY, CRUMBLE, LIGHTBEAM, EUGENE, KONGBEAST
                          ; and WILLYATTR)
FLOOR:
  DEFS 9                  ; Floor tile (also used by the routine at LIGHTBEAM)
CRUMBLING:
  DEFS 9                  ; Crumbling floor tile (also used by the routine at
                          ; MOVEWILLY)
WALL:
  DEFS 9                  ; Wall tile (also used by the routines at MOVEWILLY,
                          ; MOVEWILLY2 and LIGHTBEAM)
CONVEYOR:
  DEFS 9                  ; Conveyor tile (also used by the routine at
                          ; MOVEWILLY2)
NASTY1:
  DEFS 9                  ; Nasty tile 1 (also used by the routines at
                          ; MOVEWILLY and WILLYATTR)
NASTY2:
  DEFS 9                  ; Nasty tile 2 (also used by the routines at
                          ; MOVEWILLY and WILLYATTR)
EXTRA:
  DEFS 9                  ; Extra tile (also used by the routine at CHKSWITCH)

; Willy's pixel y-coordinate (x2)
;
; Initialised by the routine at STARTGAME, and used by the routines at
; MOVEWILLY, MOVEWILLY2, WILLYATTRS and DRAWWILLY. Holds the LSB of the address
; of the entry in the screen buffer address lookup table at SBUFADDRS that
; corresponds to Willy's pixel y-coordinate; in practice, this is twice Willy's
; actual pixel y-coordinate.
PIXEL_Y:
  DEFB 0

; Willy's animation frame
;
; Initialised upon entry to a cavern or after losing a life by the routine at
; STARTGAME, used by the routine at DRAWWILLY, and updated by the routine at
; MOVEWILLY2. Possible values are 0, 1, 2 and 3.
FRAME:
  DEFB 0

; Willy's direction and movement flags
;
; Initialised by the routine at STARTGAME.
;
; +--------+-----------------------------------------+-----------------------+
; | Bit(s) | Meaning                                 | Used by               |
; +--------+-----------------------------------------+-----------------------+
; | 0      | Direction Willy is facing (reset=right, | MOVEWILLY2, DRAWWILLY |
; |        | set=left)                               |                       |
; | 1      | Willy's movement flag (set=moving)      | MOVEWILLY, MOVEWILLY2 |
; | 2-7    | Unused (always reset)                   |                       |
; +--------+-----------------------------------------+-----------------------+
DMFLAGS:
  DEFB 0

; Airborne status indicator
;
; Initialised by the routine at STARTGAME, and used by the routines at LOOP,
; MOVEWILLY, MOVEWILLY2 and KILLWILLY. Possible values are:
;
; +-------+---------------------------------------------------------------+
; | Value | Meaning                                                       |
; +-------+---------------------------------------------------------------+
; | 0     | Willy is neither falling nor jumping                          |
; | 1     | Willy is jumping                                              |
; | 2-11  | Willy is falling, and can land safely                         |
; | 12+   | Willy is falling, and has fallen too far to land safely (see  |
; |       | MOVEWILLY2)                                                   |
; | 255   | Willy has collided with a nasty or a guardian (see KILLWILLY) |
; +-------+---------------------------------------------------------------+
AIRBORNE:
  DEFB 0

; Address of Willy's location in the attribute buffer at 23552
;
; Initialised by the routine at STARTGAME, used by the routines at MOVEWILLY,
; CHKPORTAL, CHKSWITCH, WILLYATTRS and DRAWWILLY, and updated by the routine at
; MOVEWILLY2.
LOCATION:
  DEFW 0

; Jumping animation counter
;
; Initialised by the routine at STARTGAME, and used by the routines at
; MOVEWILLY and MOVEWILLY2.
JUMPING:
  DEFB 0

; Conveyor definition
;
; The conveyor definition is copied here by the routine at STARTGAME.
CONVDIR:
  DEFB 0                  ; Direction (0=left, 1=right; used by the routines at
                          ; MOVEWILLY2 and MVCONVEYOR)
CONVLOC:
  DEFW 0                  ; Address of the conveyor's location in the screen
                          ; buffer at 28672 (used by the routine at MVCONVEYOR)
CONVLEN:
  DEFB 0                  ; Length (used by the routine at MVCONVEYOR)

; Border colour
;
; Initialised and used by the routine at STARTGAME, and also used by the
; routines at LOOP, MOVEWILLY and KONGBEAST.
BORDER:
  DEFB 0

; Attribute of the last item drawn
;
; Used by the routines at EUGENE and DRAWITEMS. Holds the attribute byte of the
; last item drawn, or 0 if all the items have been collected.
ITEMATTR:
  DEFB 0

; Item definitions
;
; The item definitions are copied here by the routine at STARTGAME, and then
; used by the routine at DRAWITEMS. An item definition contains the following
; information:
;
; +---------+-----------------------------------------------------------------+
; | Byte(s) | Contents                                                        |
; +---------+-----------------------------------------------------------------+
; | 0       | Current attribute                                               |
; | 1,2     | Address of the item's location in the attribute buffer at 23552 |
; | 3       | MSB of the address of the item's location in the screen buffer  |
; |         | at SCREEN_BUFFER                                                        |
; | 4       | Unused (always 255)                                             |
; +---------+-----------------------------------------------------------------+
ITEMS:
  DEFS 5                  ; Item 1
  DEFS 5                  ; Item 2
  DEFS 5                  ; Item 3
  DEFS 5                  ; Item 4
  DEFS 5                  ; Item 5
  DEFB 0                  ; Terminator (set to 255)

; Portal definition
;
; The portal definition is copied here by the routine at STARTGAME.
PORTAL:
  DEFB 0                  ; Attribute byte (used by the routines at DRAWITEMS
                          ; and CHKPORTAL)
PORTALG:
  DEFS 32                 ; Graphic data (used by the routine at CHKPORTAL)
PORTALLOC1:
  DEFW 0                  ; Address of the portal's location in the attribute
                          ; buffer at 23552 (used by the routine at CHKPORTAL)
PORTALLOC2:
  DEFW 0                  ; Address of the portal's location in the screen
                          ; buffer at SCREEN_BUFFER (used by the routine at CHKPORTAL)

; Item graphic
;
; The item graphic is copied here by the routine at STARTGAME, and then used by
; the routine at DRAWITEMS.
ITEM:
  DEFS 8

; Remaining air supply
;
; Initialised (always to 63 in practice) and used by the routine at STARTGAME,
; updated by the routine at DECAIR, and also used by the routine at NXSHEET.
; Its value ranges from 36 to 63 and is actually the LSB of the display file
; address for the cell at the right end of the air bar. The amount of air to
; draw in this cell is determined by the value of the game clock at CLOCK.
AIR:
  DEFB 0

; Game clock
;
; Initialised by the routine at STARTGAME, updated on every pass through the
; main loop by the routine at DECAIR, and used for timing purposes by the
; routines at MOVEHG, EUGENE and KONGBEAST. Its value (which is always a
; multiple of 4) is also used by the routine at DECAIR to compute the amount of
; air to draw in the cell at the right end of the air bar.
CLOCK:
  DEFB 0

; Horizontal guardians
;
; The horizontal guardian definitions are copied here by the routine at
; STARTGAME, and then used by the routines at MOVEHG and DRAWHG. There are four
; slots, each one seven bytes long, used to hold the state of the horizontal
; guardians in the current cavern.
;
; For each horizontal guardian, the seven bytes are used as follows:
;
; +------+--------------------------------------------------------------------+
; | Byte | Contents                                                           |
; +------+--------------------------------------------------------------------+
; | 0    | Bit 7: animation speed (0=normal, 1=slow)                          |
; |      | Bits 0-6: attribute (BRIGHT, PAPER and INK)                        |
; | 1,2  | Address of the guardian's location in the attribute buffer at      |
; |      | 23552                                                              |
; | 3    | MSB of the address of the guardian's location in the screen buffer |
; |      | at SCREEN_BUFFER                                                           |
; | 4    | Animation frame                                                    |
; | 5    | LSB of the address of the leftmost point of the guardian's path in |
; |      | the attribute buffer                                               |
; | 6    | LSB of the address of the rightmost point of the guardian's path   |
; |      | in the attribute buffer                                            |
; +------+--------------------------------------------------------------------+
HGUARDS:
  DEFS 7                  ; Horizontal guardian 1
HGUARD2:
  DEFS 7                  ; Horizontal guardian 2
  DEFS 7                  ; Horizontal guardian 3
  DEFS 7                  ; Horizontal guardian 4
  DEFB 0                  ; Terminator (set to 255)

; Eugene's direction or the Kong Beast's status
;
; Initialised by the routine at STARTGAME, and used by the routines at EUGENE
; (to hold Eugene's direction: 0=down, 1=up) and KONGBEAST (to hold the Kong
; Beast's status: 0=on the ledge, 1=falling, 2=dead).
EUGDIR:
  DEFB 0

; Eugene's or the Kong Beast's pixel y-coordinate
;
; Initialised by the routine at STARTGAME, and used by the routines at START
; (to hold the index into the message scrolled across the screen after the
; theme tune has finished playing), ENDGAM (to hold the distance of the boot
; from the top of the screen as it descends onto Willy), EUGENE (to hold
; Eugene's pixel y-coordinate) and KONGBEAST (to hold the Kong Beast's pixel
; y-coordinate).
EUGHGT:
  DEFB 0

; Vertical guardians
;
; The vertical guardian definitions are copied here by the routine at
; STARTGAME, and then used by the routines at SKYLABS and VGUARDIANS. There are
; four slots, each one seven bytes long, used to hold the state of the vertical
; guardians in the current cavern.
;
; For each vertical guardian, the seven bytes are used as follows:
;
; +------+------------------------------+
; | Byte | Contents                     |
; +------+------------------------------+
; | 0    | Attribute                    |
; | 1    | Animation frame              |
; | 2    | Pixel y-coordinate           |
; | 3    | x-coordinate                 |
; | 4    | Pixel y-coordinate increment |
; | 5    | Minimum pixel y-coordinate   |
; | 6    | Maximum pixel y-coordinate   |
; +------+------------------------------+
;
; In most of the caverns that do not have vertical guardians, this area is
; overwritten by unused bytes from the cavern definition. The exception is
; Eugene's Lair: the routine at STARTGAME copies the graphic data for the
; Eugene sprite into the last 32 bytes of this area, where it is then used by
; the routine at EUGENE.
VGUARDS:
  DEFS 7                  ; Vertical guardian 1
  DEFS 7                  ; Vertical guardian 2
  DEFS 7                  ; Vertical guardian 3
  DEFS 7                  ; Vertical guardian 4
  DEFB 0                  ; Terminator (set to 255 in caverns that have four
                          ; vertical guardians)
  DEFS 6                  ; Spare

; Guardian graphic data
;
; The guardian graphic data is copied here by the routine at STARTGAME, and
; then used by the routines at DRAWHG, SKYLABS, VGUARDIANS and KONGBEAST.
GGDATA:
  DEFS 256

; Willy sprite graphic data
;
; Used by the routines at START, LOOP and DRAWWILLY.
MANDAT:
  DEFB 6,0,62,0,124,0,52,0,62,0,60,0,24,0,60,0
  DEFB 126,0,126,0,247,0,251,0,60,0,118,0,110,0,119,0
  DEFB 1,128,15,128,31,0,13,0,15,128,15,0,6,0,15,0
  DEFB 27,128,27,128,27,128,29,128,15,0,6,0,6,0,7,0
WILLYR2:
  DEFB 0,96,3,224,7,192,3,64,3,224,3,192,1,128,3,192
  DEFB 7,224,7,224,15,112,15,176,3,192,7,96,6,224,7,112
WILLYR3:
  DEFB 0,24,0,248,1,240,0,208,0,248,0,240,0,96,0,240
  DEFB 1,248,3,252,7,254,6,246,0,248,1,218,3,14,3,132
  DEFB 24,0,31,0,15,128,11,0,31,0,15,0,6,0,15,0
  DEFB 31,128,63,192,127,224,111,96,31,0,91,128,112,192,33,192
  DEFB 6,0,7,192,3,224,2,192,7,192,3,192,1,128,3,192
  DEFB 7,224,7,224,14,240,13,240,3,192,6,224,7,96,14,224
  DEFB 1,128,1,240,0,248,0,176,1,240,0,240,0,96,0,240
  DEFB 1,248,1,216,1,216,1,184,0,240,0,96,0,96,0,224
  DEFB 0,96,0,124,0,62,0,44,0,124,0,60,0,24,0,60
  DEFB 0,126,0,126,0,239,0,223,0,60,0,110,0,118,0,238

IF (LOW MANDAT) NE 0
  .ERROR "Mandat is not on a page boundary "
ENDIF

; Screen buffer address lookup table
;
; Used by the routines at ENDGAM, EUGENE, SKYLABS, VGUARDIANS, KONGBEAST and
; DRAWWILLY. The value of the Nth entry (0<=N<=127) in this lookup table is the
; screen buffer address for the point with pixel coordinates (x,y)=(0,N), with
; the origin (0,0) at the top-left corner.
SBUFADDRS:
  DEFW 24576              ; y=0
  DEFW 24832              ; y=1
  DEFW 25088              ; y=2
  DEFW 25344              ; y=3
  DEFW 25600              ; y=4
  DEFW 25856              ; y=5
  DEFW 26112              ; y=6
  DEFW 26368              ; y=7
  DEFW 24608              ; y=8
  DEFW 24864              ; y=9
  DEFW 25120              ; y=10
  DEFW 25376              ; y=11
  DEFW 25632              ; y=12
  DEFW 25888              ; y=13
  DEFW 26144              ; y=14
  DEFW 26400              ; y=15
  DEFW 24640              ; y=16
  DEFW 24896              ; y=17
  DEFW 25152              ; y=18
  DEFW 25408              ; y=19
  DEFW 25664              ; y=20
  DEFW 25920              ; y=21
  DEFW 26176              ; y=22
  DEFW 26432              ; y=23
  DEFW 24672              ; y=24
  DEFW 24928              ; y=25
  DEFW 25184              ; y=26
  DEFW 25440              ; y=27
  DEFW 25696              ; y=28
  DEFW 25952              ; y=29
  DEFW 26208              ; y=30
  DEFW 26464              ; y=31
  DEFW 24704              ; y=32
  DEFW 24960              ; y=33
  DEFW 25216              ; y=34
  DEFW 25472              ; y=35
  DEFW 25728              ; y=36
  DEFW 25984              ; y=37
  DEFW 26240              ; y=38
  DEFW 26496              ; y=39
  DEFW 24736              ; y=40
  DEFW 24992              ; y=41
  DEFW 25248              ; y=42
  DEFW 25504              ; y=43
  DEFW 25760              ; y=44
  DEFW 26016              ; y=45
  DEFW 26272              ; y=46
  DEFW 26528              ; y=47
  DEFW 24768              ; y=48
  DEFW 25024              ; y=49
  DEFW 25280              ; y=50
  DEFW 25536              ; y=51
  DEFW 25792              ; y=52
  DEFW 26048              ; y=53
  DEFW 26304              ; y=54
  DEFW 26560              ; y=55
  DEFW 24800              ; y=56
  DEFW 25056              ; y=57
  DEFW 25312              ; y=58
  DEFW 25568              ; y=59
  DEFW 25824              ; y=60
  DEFW 26080              ; y=61
  DEFW 26336              ; y=62
  DEFW 26592              ; y=63
  DEFW 26624              ; y=64
  DEFW 26880              ; y=65
  DEFW 27136              ; y=66
  DEFW 27392              ; y=67
  DEFW 27648              ; y=68
  DEFW 27904              ; y=69
  DEFW 28160              ; y=70
  DEFW 28416              ; y=71
  DEFW 26656              ; y=72
  DEFW 26912              ; y=73
  DEFW 27168              ; y=74
  DEFW 27424              ; y=75
  DEFW 27680              ; y=76
  DEFW 27936              ; y=77
  DEFW 28192              ; y=78
  DEFW 28448              ; y=79
  DEFW 26688              ; y=80
  DEFW 26944              ; y=81
  DEFW 27200              ; y=82
  DEFW 27456              ; y=83
  DEFW 27712              ; y=84
  DEFW 27968              ; y=85
  DEFW 28224              ; y=86
  DEFW 28480              ; y=87
  DEFW 26720              ; y=88
  DEFW 26976              ; y=89
  DEFW 27232              ; y=90
  DEFW 27488              ; y=91
  DEFW 27744              ; y=92
  DEFW 28000              ; y=93
  DEFW 28256              ; y=94
  DEFW 28512              ; y=95
  DEFW 26752              ; y=96
  DEFW 27008              ; y=97
  DEFW 27264              ; y=98
  DEFW 27520              ; y=99
  DEFW 27776              ; y=100
  DEFW 28032              ; y=101
  DEFW 28288              ; y=102
  DEFW 28544              ; y=103
  DEFW 26784              ; y=104
  DEFW 27040              ; y=105
  DEFW 27296              ; y=106
  DEFW 27552              ; y=107
  DEFW 27808              ; y=108
  DEFW 28064              ; y=109
  DEFW 28320              ; y=110
  DEFW 28576              ; y=111
  DEFW 26816              ; y=112
  DEFW 27072              ; y=113
  DEFW 27328              ; y=114
  DEFW 27584              ; y=115
  DEFW 27840              ; y=116
  DEFW 28096              ; y=117
  DEFW 28352              ; y=118
  DEFW 28608              ; y=119
  DEFW 26848              ; y=120
  DEFW 27104              ; y=121
  DEFW 27360              ; y=122
  DEFW 27616              ; y=123
  DEFW 27872              ; y=124
  DEFW 28128              ; y=125
  DEFW 28384              ; y=126
  DEFW 28640              ; y=127

IF (LOW SBUFADDRS) NE 0
  .ERROR "SBUFADDRS is not on a page boundary "
ENDIF

; The game has just loaded
BEGIN:
  DI                      ; Disable interrupts
  LD SP,STACK_TOP         ; Place the stack somewhere safe (near the end of the
                          ; source code remnants at SOURCE)
  JP START                ; Display the title screen and play the theme tune

; Current cavern number
;
; Initialised by the routine at START, used by the routines at STARTGAME, LOOP,
; DRAWSHEET and DRAWHG, and updated by the routine at NXSHEET.
SHEET:
  DEFB 0

; Left-right movement table
;
; Used by the routine at MOVEWILLY2. The entries in this table are used to map
; the existing value (V) of Willy's direction and movement flags at DMFLAGS to
; a new value (V'), depending on the direction Willy is facing and how he is
; moving or being moved (by 'left' and 'right' keypresses and joystick input,
; or by a conveyor).
;
; One of the first four entries is used when Willy is not moving.
LRMOVEMENT:
  DEFB 0                  ; V=0 (facing right, no movement) + no movement: V'=0
                          ; (no change)
  DEFB 1                  ; V=1 (facing left, no movement) + no movement: V'=1
                          ; (no change)
  DEFB 0                  ; V=2 (facing right, moving) + no movement: V'=0
                          ; (facing right, no movement) (i.e. stop)
  DEFB 1                  ; V=3 (facing left, moving) + no movement: V'=1
                          ; (facing left, no movement) (i.e. stop)
; One of the next four entries is used when Willy is moving left.
  DEFB 1                  ; V=0 (facing right, no movement) + move left: V'=1
                          ; (facing left, no movement) (i.e. turn around)
  DEFB 3                  ; V=1 (facing left, no movement) + move left: V'=3
                          ; (facing left, moving)
  DEFB 1                  ; V=2 (facing right, moving) + move left: V'=1
                          ; (facing left, no movement) (i.e. turn around)
  DEFB 3                  ; V=3 (facing left, moving) + move left: V'=3 (no
                          ; change)
; One of the next four entries is used when Willy is moving right.
  DEFB 2                  ; V=0 (facing right, no movement) + move right: V'=2
                          ; (facing right, moving)
  DEFB 0                  ; V=1 (facing left, no movement) + move right: V'=0
                          ; (facing right, no movement) (i.e. turn around)
  DEFB 2                  ; V=2 (facing right, moving) + move right: V'=2 (no
                          ; change)
  DEFB 0                  ; V=3 (facing left, moving) + move right: V'=0
                          ; (facing right, no movement) (i.e. turn around)
; One of the final four entries is used when Willy is being pulled both left
; and right; each entry leaves the flags at DMFLAGS unchanged (so Willy carries
; on moving in the direction he's already moving, or remains stationary).
  DEFB 0                  ; V=V'=0 (facing right, no movement)
  DEFB 1                  ; V=V'=1 (facing left, no movement)
  DEFB 2                  ; V=V'=2 (facing right, moving)
  DEFB 3                  ; V=V'=3 (facing left, moving)

; 'AIR'
;
; Used by the routine at STARTGAME.
MESSAIR:
  DEFM "AIR"

; Unused
  DEFM "0000"

; High score
;
; Used by the routine at LOOP and updated by the routine at ENDGAM.
HGHSCOR:
  DEFM "000000"

; Score
;
; Initialised by the routine at STARTGAME, and used by the routines at LOOP,
; ENDGAM, NXSHEET and INCSCORE.
SCORE:
  DEFM "0000"             ; Overflow digits (these may be updated, but are
                          ; never printed)
SCORBUF:
  DEFM "000000"

; 'High Score 000000   Score 000000'
;
; Used by the routine at STARTGAME.
MESSHSSC:
  DEFM "High Score 000000   Score 000000"

; 'Game'
;
; Used by the routine at ENDGAM.
MESSG:
  DEFM "Game"

; 'Over'
;
; Used by the routine at ENDGAM.
MESSO:
  DEFM "Over"

; Lives remaining
;
; Initialised to 2 by the routine at START, and used and updated by the
; routines at LOOP and INCSCORE.
NOMEN:
  DEFB 0

; Screen flash counter
;
; Initialised by the routine at START, and used by the routines at LOOP and
; INCSCORE.
FLASH:
  DEFB 0

; Kempston joystick indicator
;
; Initialised by the routine at START, and used by the routines at LOOP,
; MOVEWILLY2 and CHECKENTER. Holds 1 if a joystick is present, 0 otherwise.
KEMP:
  DEFB 0

; Game mode indicator
;
; Initialised by the routine at START, and used by the routines at STARTGAME,
; LOOP and NXSHEET. Holds 0 when a game is in progress, or a value from 1 to 64
; when in demo mode.
DEMO:
  DEFB 0

; In-game music note index
;
; Initialised by the routine at START, and used and updated by the routine at
; LOOP.
NOTEINDEX:
  DEFB 0

; Music flags
;
; The keypress flag in bit 0 is initialised by the routine at START; bits 0 and
; 1 are checked and updated by the routine at LOOP.
;
; +--------+-----------------------------------------------------------------+
; | Bit(s) | Meaning                                                         |
; +--------+-----------------------------------------------------------------+
; | 0      | Keypress flag (set=H-ENTER being pressed, reset=no key pressed) |
; | 1      | In-game music flag (set=music off, reset=music on)              |
; | 2-7    | Unused                                                          |
; +--------+-----------------------------------------------------------------+
MUSICFLAGS:
  DEFB 0

; 6031769 key counter
;
; Used by the routines at LOOP and NXSHEET.
CHEAT:
  DEFB 0

; 6031769
;
; Used by the routine at LOOP. In each pair of bytes here, bits 0-4 of the
; first byte correspond to keys 1-2-3-4-5, and bits 0-4 of the second byte
; correspond to keys 0-9-8-7-6; among those bits, a zero indicates a key being
; pressed.
  DEFB %00011111,%00011111 ; (no keys pressed)
CHEATDT:
  DEFB %00011111,%00001111 ; 6
  DEFB %00011111,%00011110 ; 0
  DEFB %00011011,%00011111 ; 3
  DEFB %00011110,%00011111 ; 1
  DEFB %00011111,%00010111 ; 7
  DEFB %00011111,%00001111 ; 6
  DEFB %00011111,%00011101 ; 9

; Title screen tune data (The Blue Danube)
;
; Used by the routine at PLAYTUNE. The tune data is organised into 95 groups of
; three bytes each, one group for each note in the tune. The first byte in each
; group determines the duration of the note, and the second and third bytes
; determine the frequency (and also the piano keys that light up).
THEMETUNE:
  DEFB 80,128,129
  DEFB 80,102,103
  DEFB 80,86,87
  DEFB 50,86,87
  DEFB 50,171,203
  DEFB 50,43,51
  DEFB 50,43,51
  DEFB 50,171,203
  DEFB 50,51,64
  DEFB 50,51,64
  DEFB 50,171,203
  DEFB 50,128,129
  DEFB 50,128,129
  DEFB 50,102,103
  DEFB 50,86,87
  DEFB 50,96,86
  DEFB 50,171,192
  DEFB 50,43,48
  DEFB 50,43,48
  DEFB 50,171,192
  DEFB 50,48,68
  DEFB 50,48,68
  DEFB 50,171,192
  DEFB 50,136,137
  DEFB 50,136,137
  DEFB 50,114,115
  DEFB 50,76,77
  DEFB 50,76,77
  DEFB 50,171,192
  DEFB 50,38,48
  DEFB 50,38,48
  DEFB 50,171,192
  DEFB 50,48,68
  DEFB 50,48,68
  DEFB 50,171,192
  DEFB 50,136,137
  DEFB 50,136,137
  DEFB 50,114,115
  DEFB 50,76,77
  DEFB 50,76,77
  DEFB 50,171,203
  DEFB 50,38,51
  DEFB 50,38,51
  DEFB 50,171,203
  DEFB 50,51,64
  DEFB 50,51,64
  DEFB 50,171,203
  DEFB 50,128,129
  DEFB 50,128,129
  DEFB 50,102,103
  DEFB 50,86,87
  DEFB 50,64,65
  DEFB 50,128,171
  DEFB 50,32,43
  DEFB 50,32,43
  DEFB 50,128,171
  DEFB 50,43,51
  DEFB 50,43,51
  DEFB 50,128,171
  DEFB 50,128,129
  DEFB 50,128,129
  DEFB 50,102,103
  DEFB 50,86,87
  DEFB 50,64,65
  DEFB 50,128,152
  DEFB 50,32,38
  DEFB 50,32,38
  DEFB 50,128,152
  DEFB 50,38,48
  DEFB 50,38,48
  DEFB 50,0,0
  DEFB 50,114,115
  DEFB 50,114,115
  DEFB 50,96,97
  DEFB 50,76,77
  DEFB 50,76,153
  DEFB 50,76,77
  DEFB 50,76,77
  DEFB 50,76,153
  DEFB 50,91,92
  DEFB 50,86,87
  DEFB 50,51,205
  DEFB 50,51,52
  DEFB 50,51,52
  DEFB 50,51,205
  DEFB 50,64,65
  DEFB 50,102,103
  DEFB 100,102,103
  DEFB 50,114,115
  DEFB 100,76,77
  DEFB 50,86,87
  DEFB 50,128,203
  DEFB 25,128,0
  DEFB 25,128,129
  DEFB 50,128,203
  DEFB 255                ; End marker

; In-game tune data (In the Hall of the Mountain King)
;
; Used by the routine at LOOP.
GAMETUNE:
  DEFB 128,114,102,96,86,102,86,86,81,96,81,81,86,102,86,86
  DEFB 128,114,102,96,86,102,86,86,81,96,81,81,86,86,86,86
  DEFB 128,114,102,96,86,102,86,86,81,96,81,81,86,102,86,86
  DEFB 128,114,102,96,86,102,86,64,86,102,128,102,86,86,86,86

; Display the title screen and play the theme tune
;
; Used by the routines at BEGIN, LOOP and ENDGAM.
;
; The first thing this routine does is initialise some game status buffer
; variables in preparation for the next game.
START:
  XOR A                   ; A=0
  LD (SHEET),A            ; Initialise the current cavern number at SHEET
  LD (KEMP),A             ; Initialise the Kempston joystick indicator at KEMP
  LD (DEMO),A             ; Initialise the game mode indicator at DEMO
  LD (NOTEINDEX),A        ; Initialise the in-game music note index at
                          ; NOTEINDEX
  LD (FLASH),A            ; Initialise the screen flash counter at FLASH
  LD A,2                  ; Initialise the number of lives remaining at NOMEN
  LD (NOMEN),A            ;
  LD HL,MUSICFLAGS        ; Initialise the keypress flag in bit 0 at MUSICFLAGS
  SET 0,(HL)              ;
; Next, prepare the screen.
  LD HL,SCREEN_LOCATION   ; Clear the entire display file
  LD DE,SCREEN_LOCATION+1 ;
  LD BC,6143              ;
  LD (HL),0               ;
  LDIR                    ;
  LD HL,TITLESCR1         ; Copy the graphic data at TITLESCR1 to the top
  LD DE,SCREEN_LOCATION   ; two-thirds of the display file
  LD BC,4096              ;
  LDIR                    ;
  LD HL,18493             ; Draw Willy at (9,29)
  LD DE,WILLYR2           ;
  LD C,0                  ;
  CALL DRWFIX             ;
  LD HL,CAVERN19          ; Copy the attribute bytes from CAVERN19 to the top
  LD DE,22528             ; third of the attribute file
  LD BC,256               ;
  LDIR                    ;
  LD HL,LOWERATTRS        ; Copy the attribute bytes from LOWERATTRS to the
  LD BC,512               ; bottom two-thirds of the attribute file
  LDIR                    ;
; Now check whether there is a joystick connected.
  LD BC,PORT_KEMPSTON     ; This is the joystick port
  DI                      ; Disable interrupts (which are already disabled)
  XOR A                   ; A=0
START_0:
  IN E,(C)                ; Combine 256 readings of the joystick port in A; if
  OR E                    ; no joystick is connected, some of these readings
  DJNZ START_0            ; will have bit 5 set
  AND 32                  ; Is a joystick connected (bit 5 reset)?
  JR NZ,START_1           ; Jump if not
  LD A,1                  ; Set the Kempston joystick indicator at KEMP to 1

IF DEFINED SINCLAIR
  LD (KEMP),A             ;
ELSE
  NOP
  NOP
ENDIF

; And finally, play the theme tune and check for keypresses.
START_1:
  LD IY,THEMETUNE         ; Point IY at the theme tune data at THEMETUNE
  CALL PLAYTUNE           ; Play the theme tune
  JP NZ,STARTGAME         ; Start the game if ENTER or the fire button was
                          ; pressed
  XOR A                   ; Initialise the game status buffer variable at
  LD (EUGHGT),A           ; EUGHGT; this will be used as an index for the
                          ; message scrolled across the screen
START_2:
IF NOT DEFINED SINCLAIR
  LD BC,25000
START_DELAY
  DEC C
  JR NZ, START_DELAY
  DJNZ START_DELAY
ENDIF
  LD A,(EUGHGT)           ; Pick up the message index from EUGHGT
  LD IX,MESSINTRO         ; Point IX at the corresponding location in the
  LD IXl,A                ; message at MESSINTRO
  LD DE,20576             ; Print 32 characters of the message at (19,0)
  LD C,32                 ;
  CALL PMESS              ;
  LD A,(EUGHGT)           ; Pick up the message index from EUGHGT
  AND 6                   ; Keep only bits 1 and 2, and move them into bits 6
  RRCA                    ; and 7, so that A holds 0, 64, 128 or 192; this
  RRCA                    ; value determines the animation frame to use for
  RRCA                    ; Willy
  LD E,A                  ; Point DE at the graphic data for Willy's sprite
  LD D,HIGH MANDAT        ; (MANDAT+A)
  LD HL,18493             ; Draw Willy at (9,29)
  LD C,0                  ;
  CALL DRWFIX             ;
  LD BC,100               ; Pause for about 0.1s
START_3:
  DJNZ START_3            ;
  DEC C                   ;
  JR NZ,START_3           ;
  LD BC,PORT_HJKL             ; Read keys H-J-K-L-ENTER
  IN A,(C)                ;
  AND KEY_ENTER           ; Keep only bit 0 of the result (ENTER)
  CP KEY_ENTER            ; Is ENTER being pressed?
  JR NZ,STARTGAME         ; If so, start the game
  LD A,(EUGHGT)           ; Pick up the message index from EUGHGT
  INC A                   ; Increment it
  CP 224                  ; Set the zero flag if we've reached the end of the
                          ; message
  LD (EUGHGT),A           ; Store the new message index at EUGHGT
  JR NZ,START_2           ; Jump back unless we've finished scrolling the
                          ; message across the screen
  LD A,64                 ; Initialise the game mode indicator at DEMO to 64:
  LD (DEMO),A             ; demo mode
; This routine continues into the one at STARTGAME.

; Start the game (or demo mode)
;
; Used by the routine at START.
STARTGAME:
  LD HL,SCORE             ; Initialise the score at SCORE
  LD DE,SCORE+1           ;
  LD BC,9                 ;
  LD (HL),48              ;
  LDIR                    ;
; This entry point is used by the routines at LOOP (when teleporting into a
; cavern or reinitialising the current cavern after Willy has lost a life) and
; NXSHEET.
NEWSHT:
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  SLA A                   ; Point HL at the first byte of the cavern definition
  SLA A                   ;
  ADD A,HIGH CAVERN0      ;
  LD H,A                  ;
  LD L,0                  ;
  LD DE,ATTR_CACHE       ; Copy the cavern's attribute bytes into the buffer
  LD BC,512               ; at 24064
  LDIR                    ;
  LD DE,CAVERNNAME        ; Copy the rest of the cavern definition into the
  LD BC,512               ; game status buffer at 32768
  LDIR                    ;
  CALL DRAWSHEET          ; Draw the current cavern to the screen buffer at
                          ; 28672
  LD HL,SCREEN_BOTTOM     ; Clear the bottom third of the display file
  LD DE,SCREEN_BOTTOM+1   ;
  LD BC,2047              ;
  LD (HL),0               ;
  LDIR                    ;
  LD IX,CAVERNNAME        ; Print the cavern name (see CAVERNNAME) at (16,0)
  LD C,32                 ;
  LD DE,SCREEN_BOTTOM     ;
  CALL PMESS              ;
  LD IX,MESSAIR           ; Print 'AIR' (see MESSAIR) at (17,0)
  LD C,3                  ;
  LD DE,SCREEN_BOTTOM+32  ;
  CALL PMESS              ;
  LD A,82                 ; Initialise A to 82; this is the MSB of the display
                          ; file address at which to start drawing the bar that
                          ; represents the air supply
STARTGAME_0:
  LD H,A                  ; Prepare HL and DE for drawing a row of pixels in
  LD D,A                  ; the air bar
  LD L,36                 ;
  LD E,37                 ;
  LD B,A                  ; Save the display file address MSB in B briefly
  LD A,(AIR)              ; Pick up the value of the initial air supply from
                          ; AIR
  SUB 36                  ; Now C determines the length of the air bar (in cell
  LD C,A                  ; widths)
  LD A,B                  ; Restore the display file address MSB to A
  LD B,0                  ; Now BC determines the length of the air bar (in
                          ; cell widths)
  LD (HL),255             ; Draw a single row of pixels across C cells
  LDIR                    ;
  INC A                   ; Increment the display file address MSB in A (moving
                          ; down to the next row of pixels)
  CP 86                   ; Have we drawn all four rows of pixels in the air
                          ; bar yet?
  JR NZ,STARTGAME_0       ; If not, jump back to draw the next one
  LD IX,MESSHSSC          ; Print 'High Score 000000   Score 000000' (see
  LD DE,SCREEN_BOTTOM+96  ; MESSHSSC) at (19,0)
  LD C,32                 ;
  CALL PMESS              ;
  LD A,(BORDER)           ; Pick up the border colour for the current cavern
                          ; from BORDER
  LD C,PORT_BORDER        ; Set the border colour
  OUT (C),A               ;
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  JR Z,LOOP               ; If not, enter the main loop now
  LD A,64                 ; Reset the game mode indicator at DEMO to 64 (we're
  LD (DEMO),A             ; in demo mode)
; This routine continues into the main loop at LOOP.

; Main loop
;
; The routine at STARTGAME continues here.
;
; The first thing to do is check whether there are any remaining lives to draw
; at the bottom of the screen.
LOOP:

IF NOT DEFINED SINCLAIR
  LD  BC, 26000
MB_DELAY
  NOP
  DEC C
  JR  NZ, MB_DELAY
  DJNZ    MB_DELAY

ENDIF

  LD A,(NOMEN)            ; Pick up the number of lives remaining from NOMEN
  LD HL,20640             ; Set HL to the display file address at which to draw
                          ; the first Willy sprite
  OR A                    ; Are there any lives remaining?
  JR Z,LOOP_1             ; Jump if not
  LD B,A                  ; Initialise B to the number of lives remaining
; The following loop draws the remaining lives at the bottom of the screen.
LOOP_0:
  LD C,0                  ; C=0; this tells the sprite-drawing routine at
                          ; DRWFIX to overwrite any existing graphics
  PUSH HL                 ; Save HL and BC briefly
  PUSH BC                 ;
  LD A,(NOTEINDEX)        ; Pick up the in-game music note index from
                          ; NOTEINDEX; this will determine the animation frame
                          ; for the Willy sprites
  RLCA                    ; Now A=0 (frame 0), 32 (frame 1), 64 (frame 2) or 96
  RLCA                    ; (frame 3)
  RLCA                    ;
  AND 96                  ;
  LD E,A                  ; Point DE at the corresponding Willy sprite (at
  LD D,HIGH MANDAT        ; MANDAT+A)
  CALL DRWFIX             ; Draw the Willy sprite on the screen
  POP BC                  ; Restore HL and BC
  POP HL                  ;
  INC HL                  ; Move HL along to the location at which to draw the
  INC HL                  ; next Willy sprite
  DJNZ LOOP_0             ; Jump back to draw any remaining sprites
; Now draw a boot if cheat mode has been activated.
LOOP_1:
  LD A,(CHEAT)            ; Pick up the 6031769 key counter from CHEAT
  CP 7                    ; Has 6031769 been keyed in yet?
  JR NZ,LOOP_2            ; Jump if not
  LD DE,BOOT              ; Point DE at the graphic data for the boot (at BOOT)
  LD C,0                  ; C=0 (overwrite mode)
  CALL DRWFIX             ; Draw the boot at the bottom of the screen next to
                          ; the remaining lives
; Next, prepare the screen and attribute buffers for drawing to the screen.
LOOP_2:
  LD HL,ATTR_CACHE       ; Copy the contents of the attribute buffer at 24064
  LD DE,ATTR_BUFFER          ; (the attributes for the empty cavern) into the
  LD BC,512               ; attribute buffer at 23552
  LDIR                    ;
  LD HL,SCREEN_CACHE      ; Copy the contents of the screen buffer at 28672
  LD DE,SCREEN_BUFFER     ; (the tiles for the empty cavern) into the screen
  LD BC,4096              ; buffer at 24576
  LDIR                    ;
  CALL MOVEHG             ; Move the horizontal guardians in the current cavern
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  CALL Z,MOVEWILLY        ; If not, move Willy
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  CALL Z,WILLYATTRS       ; If not, check and set the attribute bytes for
                          ; Willy's sprite in the buffer at 23552, and draw
                          ; Willy to the screen buffer at 24576
  CALL DRAWHG             ; Draw the horizontal guardians in the current cavern
  CALL MVCONVEYOR         ; Move the conveyor in the current cavern
  CALL DRAWITEMS          ; Draw the items in the current cavern and collect
                          ; any that Willy is touching
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 4                    ; Are we in Eugene's Lair?
  CALL Z,EUGENE           ; If so, move and draw Eugene
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 13                   ; Are we in Skylab Landing Bay?
  JP Z,SKYLABS            ; If so, move and draw the Skylabs
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 8                    ; Are we in Wacky Amoebatrons or beyond?
  CALL NC,VGUARDIANS      ; If so, move and draw the vertical guardians
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 7                    ; Are we in Miner Willy meets the Kong Beast?
  CALL Z,KONGBEAST        ; If so, move and draw the Kong Beast
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 11                   ; Are we in Return of the Alien Kong Beast?
  CALL Z,KONGBEAST        ; If so, move and draw the Kong Beast
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 18                   ; Are we in Solar Power Generator?
  CALL Z,LIGHTBEAM        ; If so, move and draw the light beam
; This entry point is used by the routine at SKYLABS.
LOOP_3:
  CALL CHKPORTAL          ; Draw the portal, or move to the next cavern if
                          ; Willy has entered it
; This entry point is used by the routine at KILLWILLY.
LOOP_4:
  LD HL,SCREEN_BUFFER     ; Copy the contents of the screen buffer at 24576 to
  LD DE,SCREEN_LOCATION   ; the display file
  LD BC,4096              ;
  LDIR                    ;
  LD A,(FLASH)            ; Pick up the screen flash counter from FLASH
  OR A                    ; Is it zero?
  JR Z,LOOP_5             ; Jump if so
  DEC A                   ; Decrement the screen flash counter at FLASH
  LD (FLASH),A            ;
  RLCA                    ; Move bits 0-2 into bits 3-5 and clear all the other
  RLCA                    ; bits
  RLCA                    ;
  AND 56                  ;
  LD HL,ATTR_BUFFER          ; Set every attribute byte in the buffer at 23552 to
  LD DE,ATTR_BUFFER+1        ; this value
  LD BC,511               ;
  LD (HL),A               ;
  LDIR                    ;
LOOP_5:
  LD HL,ATTR_BUFFER          ; Copy the contents of the attribute buffer at 23552
  LD DE,22528             ; to the attribute file
  LD BC,512               ;
  LDIR                    ;
  LD IX,SCORBUF           ; Print the score (see SCORBUF) at (19,26)
  LD DE,20602             ;
  LD C,6                  ;
  CALL PMESS              ;
  LD IX,HGHSCOR           ; Print the high score (see HGHSCOR) at (19,11)
  LD DE,20587             ;
  LD C,6                  ;
  CALL PMESS              ;
  CALL DECAIR             ; Decrease the air remaining in the current cavern
  JP Z,MANDEAD            ; Jump if there's no air left
; Now check whether SHIFT and SPACE are being pressed.
  LD BC,PORT_ZXCV         ; Read keys SHIFT-Z-X-C-V
  IN A,(C)                ;
  LD E,A                  ; Save the result in E
  LD B,HIGH PORT_BNMSS    ; Read keys B-N-M-SS-SPACE
  IN A,(C)                ;
  OR E                    ; Combine the results
  AND KEY_SPACE           ; Are SHIFT and SPACE being pressed?
  JP Z,START              ; If so, quit the game
; Now read the keys A, S, D, F and G (which pause the game).
  LD B,HIGH PORT_ASDF     ; Read keys A-S-D-F-G
  IN A,(C)                ;
  AND 31                  ; Are any of these keys being pressed?
  CP 31                   ;
  JR Z,LOOP_7             ; Jump if not
LOOP_6:
  LD B,HIGH NOT PORT_ASDF ; Read every half-row of keys except A-S-D-F-G
  IN A,(C)                ;
  AND 31                  ; Are any of these keys being pressed?
  CP 31                   ;
  JR Z,LOOP_6             ; Jump back if not (the game is still paused)
; Here we check whether Willy has had a fatal accident.
LOOP_7:
  LD A,(AIRBORNE)         ; Pick up the airborne status indicator from AIRBORNE
  CP 255                  ; Has Willy landed after falling from too great a
                          ; height, or collided with a nasty or a guardian?
  JP Z,MANDEAD            ; Jump if so
; Now read the keys H, J, K, L and ENTER (which toggle the in-game music).
  LD B,HIGH PORT_HJKL     ; Prepare B for reading keys H-J-K-L-ENTER
  LD HL,MUSICFLAGS        ; Point HL at the music flags at MUSICFLAGS
  IN A,(C)                ; Read keys H-J-K-L-ENTER
  AND 31                  ; Are any of these keys being pressed?
  CP 31                   ;
  JR Z,LOOP_8             ; Jump if not
  BIT 0,(HL)              ; Were any of these keys being pressed the last time
                          ; we checked?
  JR NZ,LOOP_9            ; Jump if so
  LD A,(HL)               ; Set bit 0 (the keypress flag) and flip bit 1 (the
  XOR 3                   ; in-game music flag) at MUSICFLAGS
  LD (HL),A               ;
  JR LOOP_9
LOOP_8:
  RES 0,(HL)              ; Reset bit 0 (the keypress flag) at MUSICFLAGS
LOOP_9:
  BIT 1,(HL)              ; Has the in-game music been switched off?
  JR NZ,NONOTE4           ; Jump if so
; The next section of code plays a note of the in-game music.
  LD A,(NOTEINDEX)        ; Increment the in-game music note index at NOTEINDEX
  INC A                   ;
  LD (NOTEINDEX),A        ;
  AND 126                 ; Point HL at the appropriate entry in the tune data
  RRCA                    ; table at GAMETUNE
  LD E,A                  ;
  LD D,0                  ;
  LD HL,GAMETUNE          ;
  ADD HL,DE               ;
  LD A,(BORDER)           ; Pick up the border colour for the current cavern
                          ; from BORDER
  LD E,(HL)               ; Initialise the pitch delay counter in E
  LD BC,3                 ; Initialise the duration delay counters in B (0) and
                          ; C (3)
TM51:
  OUT (PORT_SOUND),A      ; Produce a note of the in-game music
SEE37708:
  DEC E                   ;
  JR NZ,NOFLP6            ;
  LD E,(HL)               ;
  XOR 24                  ;
NOFLP6:
  DJNZ TM51               ;
  DEC C                   ;
  JR NZ,TM51              ;
; If we're in demo mode, check the keyboard and joystick and return to the
; title screen if there's any input.
NONOTE4:
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  JR Z,NODEM1             ; Jump if not
  DEC A                   ; We're in demo mode; is it time to show the next
                          ; cavern?
  JP Z,MANDEAD            ; Jump if so
  LD (DEMO),A             ; Update the game mode indicator at DEMO
  LD BC,PORT_ALL_KEYS     ; Read every row of keys on the keyboard
  IN A,(C)                ;
  AND 31                  ; Are any keys being pressed?
  CP 31                   ;
  JP NZ,START             ; If so, return to the title screen
  LD A,(KEMP)             ; Pick up the Kempston joystick indicator from KEMP
  OR A                    ; Is there a joystick connected?
  JR Z,NODEM1             ; Jump if not
  IN A,(PORT_KEMPSTON)    ; Collect input from the joystick
  OR A                    ; Is the joystick being moved or the fire button
                          ; being pressed?
  JP NZ,START             ; If so, return to the title screen
; Here we check the teleport keys.
NODEM1:
  LD BC,PORT_6789         ; Read keys 6-7-8-9-0
  IN A,(C)                ;
  BIT 4,A                 ; Is '6' (the activator key) being pressed?
  JP NZ,CKCHEAT           ; Jump if not
  LD A,(CHEAT)            ; Pick up the 6031769 key counter from CHEAT
  CP 7                    ; Has 6031769 been keyed in yet?
  JP NZ,CKCHEAT           ; Jump if not
  LD B,HIGH PORT_1234     ; Read keys 1-2-3-4-5
  IN A,(C)                ;
  CPL                     ; Keep only bits 0-4 and flip them
  AND 31                  ;
  CP 20                   ; Is the result 20 or greater?
  JP NC,CKCHEAT           ; Jump if so (this is not a cavern number)
  LD (SHEET),A            ; Store the cavern number at SHEET
  JP NEWSHT               ; Teleport into the cavern
; Now check the 6031769 keys.
CKCHEAT:
  LD A,(CHEAT)            ; Pick up the 6031769 key counter from CHEAT
  CP 7                    ; Has 6031769 been keyed in yet?
  JP Z,LOOP               ; If so, jump back to the start of the main loop
  RLCA                    ; Point IX at the corresponding entry in the 6031769
  LD E,A                  ; table at CHEATDT
  LD D,0                  ;
  LD IX,CHEATDT           ;
  ADD IX,DE               ;
  LD BC,PORT_1234         ; Read keys 1-2-3-4-5
  IN A,(C)                ;
  AND 31                  ; Keep only bits 0-4
  CP (IX+0)               ; Does this match the first byte of the entry in the
                          ; 6031769 table?
  JR Z,CKNXCHT            ; Jump if so
  CP 31                   ; Are any of the keys 1-2-3-4-5 being pressed?
  JP Z,LOOP               ; If not, jump back to the start of the main loop
  CP (IX-2)               ; Does the keyboard reading match the first byte of
                          ; the previous entry in the 6031769 table?
  JP Z,LOOP               ; If so, jump back to the start of the main loop
  XOR A                   ; Reset the 6031769 key counter at CHEAT to 0 (an
  LD (CHEAT),A            ; incorrect key is being pressed)
  JP LOOP                 ; Jump back to the start of the main loop
CKNXCHT:
  LD B,HIGH PORT_6789     ; Read keys 6-7-8-9-0
  IN A,(C)                ;
  AND 31                  ; Keep only bits 0-4
  CP (IX+1)               ; Does this match the second byte of the entry in the
                          ; 6031769 table?
  JR Z,INCCHT             ; If so, jump to increment the 6031769 key counter
  CP 31                   ; Are any of the keys 6-7-8-9-0 being pressed?
  JP Z,LOOP               ; If not, jump back to the start of the main loop
  CP (IX-1)               ; Does the keyboard reading match the second byte of
                          ; the previous entry in the 6031769 table?
  JP Z,LOOP               ; If so, jump back to the start of the main loop
  XOR A                   ; Reset the 6031769 key counter at CHEAT to 0 (an
  LD (CHEAT),A            ; incorrect key is being pressed)
  JP LOOP                 ; Jump back to the start of the main loop
INCCHT:
  LD A,(CHEAT)            ; Increment the 6031769 key counter at CHEAT (the
  INC A                   ; next key in the sequence is being pressed)
  LD (CHEAT),A            ;
  JP LOOP                 ; Jump back to the start of the main loop
; The air in the cavern has run out, or Willy has had a fatal accident, or it's
; demo mode and it's time to show the next cavern.
MANDEAD:
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Is it demo mode?
  JP NZ,NXSHEET           ; If so, move to the next cavern
  LD A,71                 ; A=71 (INK 7: PAPER 0: BRIGHT 1)
; The following loop fills the top two thirds of the attribute file with a
; single value (71, 70, 69, 68, 67, 66, 65 or 64) and makes a sound effect.
LPDEAD1:
  LD HL,22528             ; Fill the top two thirds of the attribute file with
  LD DE,22529             ; the value in A
  LD BC,511               ;
  LD (HL),A               ;
  LDIR                    ;


  LD E,A                  ; Save the attribute byte (64-71) in E for later
                          ; retrieval
  CPL                     ; D=63-8*(E AND 7); this value determines the pitch
  AND 7                   ; of the short note that will be played
  RLCA                    ;
  RLCA                    ;
  RLCA                    ;
  OR 7                    ;
  LD D,A                  ;
  LD C,E                  ; C=8+32*(E AND 7); this value determines the
  RRC C                   ; duration of the short note that will be played
  RRC C                   ;
  RRC C                   ;
  OR 16                   ; Set bit 4 of A (for no apparent reason)
  XOR A                   ; Set A=0 (this will make the border black)
TM21:
  OUT (PORT_SOUND),A      ; Produce a short note whose pitch is determined by D
  XOR 24                  ; and whose duration is determined by C
  LD B,D                  ;
TM22:
  DJNZ TM22               ;
IF NOT DEFINED SINCLAIR
  LD  B, 4
DEAD_BEEP
  NOP
  DJNZ DEAD_BEEP
ENDIF
  DEC C                   ;
  JR NZ,TM21              ;
  LD A,E                  ; Restore the attribute byte (originally 71) to A
  DEC A                   ; Decrement it (effectively decrementing the INK
                          ; colour)
  CP 63                   ; Have we used attribute value 64 (INK 0) yet?
  JR NZ,LPDEAD1           ; If not, jump back to update the INK colour in the
                          ; top two thirds of the screen and make another sound
                          ; effect
; Finally, check whether any lives remain.
  LD HL,NOMEN             ; Pick up the number of lives remaining from NOMEN
  LD A,(HL)               ;
  OR A                    ; Are there any lives remaining?
  JP Z,ENDGAM             ; If not, display the game over sequence
  DEC (HL)                ; Decrease the number of lives remaining by one
  JP NEWSHT               ; Jump back to reinitialise the current cavern

; Display the game over sequence
;
; Used by the routine at LOOP. First check whether we have a new high score.
ENDGAM:
  LD HL,HGHSCOR           ; Point HL at the high score at HGHSCOR
  LD DE,SCORBUF           ; Point DE at the current score at SCORBUF
  LD B,6                  ; There are 6 digits to compare
LPHGH:
  LD A,(DE)               ; Pick up a digit of the current score
  CP (HL)                 ; Compare it with the corresponding digit of the high
                          ; score
  JP C,FEET               ; Jump if it's less than the corresponding digit of
                          ; the high score
  JP NZ,NEWHGH            ; Jump if it's greater than the corresponding digit
                          ; of the high score
  INC HL                  ; Point HL at the next digit of the high score
  INC DE                  ; Point DE at the next digit of the current score
  DJNZ LPHGH              ; Jump back to compare the next pair of digits
NEWHGH:
  LD HL,SCORBUF           ; Replace the high score with the current score
  LD DE,HGHSCOR           ;
  LD BC,6                 ;
  LDIR                    ;
; Now prepare the screen for the game over sequence.
FEET:
  LD HL,SCREEN_LOCATION   ; Clear the top two-thirds of the display file
  LD DE,SCREEN_LOCATION+1 ;
  LD BC,4095              ;
  LD (HL),0               ;
  LDIR                    ;
  XOR A                   ; Initialise the game status buffer variable at
  LD (EUGHGT),A           ; EUGHGT; this variable will determine the distance
                          ; of the boot from the top of the screen
  LD DE,WILLYR2           ; Draw Willy at (12,15)
  LD HL,18575             ;
  LD C,0                  ;
  CALL DRWFIX             ;
  LD DE,PLINTH            ; Draw the plinth (see PLINTH) underneath Willy at
  LD HL,18639             ; (14,15)
  LD C,0                  ;
  CALL DRWFIX             ;
; The following loop draws the boot's descent onto the plinth that supports
; Willy.
LOOPFT:
  LD A,(EUGHGT)           ; Pick up the distance variable from EUGHGT
  LD C,A                  ; Point BC at the corresponding entry in the screen
  LD B,HIGH SBUFADDRS     ; buffer address lookup table at SBUFADDRS
  LD A,(BC)               ; Point HL at the corresponding location in the
  OR 15                   ; display file
  LD L,A                  ;
  INC BC                  ;
  LD A,(BC)               ;
  SUB 32                  ;
  LD H,A                  ;
  LD DE,BOOT              ; Draw the boot (see BOOT) at this location, without
  LD C,0                  ; erasing the boot at the previous location; this
  CALL DRWFIX             ; leaves the portion of the boot sprite that's above
                          ; the ankle in place, and makes the boot appear as if
                          ; it's at the end of a long, extending trouser leg
  LD A,(EUGHGT)           ; Pick up the distance variable from EUGHGT
  CPL                     ; A=255-A
  LD E,A                  ; Store this value (63-255) in E; it determines the
                          ; (rising) pitch of the sound effect that will be
                          ; made
  XOR A                   ; A=0 (black border)
  LD BC,64                ; C=64; this value determines the duration of the
                          ; sound effect
TM111:
  OUT (PORT_SOUND),A      ; Produce a short note whose pitch is determined by E
  XOR 24                  ;
  LD B,E                  ;
TM112:
  DJNZ TM112              ;
  DEC C                   ;
  JR NZ,TM111             ;
  LD HL,22528             ; Prepare BC, DE and HL for setting the attribute
  LD DE,22529             ; bytes in the top two-thirds of the screen
  LD BC,511               ;
  LD A,(EUGHGT)           ; Pick up the distance variable from EUGHGT
  AND 12                  ; Keep only bits 2 and 3
  RLCA                    ; Shift bits 2 and 3 into bits 3 and 4; these bits
                          ; determine the PAPER colour: 0, 1, 2 or 3
  OR 71                   ; Set bits 0-2 (INK 7) and 6 (BRIGHT 1)
  LD (HL),A               ; Copy this attribute value into the top two-thirds
  LDIR                    ; of the screen
  LD A,(EUGHGT)           ; Add 4 to the distance variable at EUGHGT; this will
  ADD A,4                 ; move the boot sprite down two pixel rows
  LD (EUGHGT),A           ;
  CP 196                  ; Has the boot met the plinth yet?
  JR NZ,LOOPFT            ; Jump back if not
; Now print the "Game Over" message, just to drive the point home.
  LD IX,MESSG             ; Print "Game" (see MESSG) at (6,10)
  LD C,4                  ;
  LD DE,16586             ;
  CALL PMESS              ;
  LD IX,MESSO             ; Print "Over" (see MESSO) at (6,18)
  LD C,4                  ;
  LD DE,16594             ;
  CALL PMESS              ;
  LD BC,0                 ; Prepare the delay counters for the following loop;
  LD D,6                  ; the counter in C will also determine the INK
                          ; colours to use for the "Game Over" message
; The following loop makes the "Game Over" message glisten for about 1.57s.
TM91:
  DJNZ TM91               ; Delay for about a millisecond
  LD A,C                  ; Change the INK colour of the "G" in "Game" at
  AND 7                   ; (6,10)
  OR 64                   ;
  LD (GAME_OVER_ATTR),A   ;
  INC A                   ; Change the INK colour of the "a" in "Game" at
  AND 7                   ; (6,11)
  OR 64                   ;
  LD (GAME_OVER_ATTR+1),A            ;
  INC A                   ; Change the INK colour of the "m" in "Game" at
  AND 7                   ; (6,12)
  OR 64                   ;
  LD (GAME_OVER_ATTR+2),A            ;
  INC A                   ; Change the INK colour of the "e" in "Game" at
  AND 7                   ; (6,13)
  OR 64                   ;
  LD (GAME_OVER_ATTR+3),A            ;
  INC A                   ; Change the INK colour of the "O" in "Over" at
  AND 7                   ; (6,18)
  OR 64                   ;
  LD (GAME_OVER_ATTR1),A            ;
  INC A                   ; Change the INK colour of the "v" in "Over" at
  AND 7                   ; (6,19)
  OR 64                   ;
  LD (GAME_OVER_ATTR1+1),A            ;
  INC A                   ; Change the INK colour of the "e" in "Over" at
  AND 7                   ; (6,20)
  OR 64                   ;
  LD (GAME_OVER_ATTR1+2),A            ;
  INC A                   ; Change the INK colour of the "r" in "Over" at
  AND 7                   ; (6,21)
  OR 64                   ;
  LD (GAME_OVER_ATTR1+3),A            ;
  DEC C                   ; Decrement the counter in C
  JR NZ,TM91              ; Jump back unless it's zero
  DEC D                   ; Decrement the counter in D (initially 6)
  JR NZ,TM91              ; Jump back unless it's zero
  JP START                ; Display the title screen and play the theme tune

; Decrease the air remaining in the current cavern
;
; Used by the routines at LOOP, LIGHTBEAM and NXSHEET. Returns with the zero
; flag set if there is no air remaining.
DECAIR:
  LD A,(CLOCK)            ; Update the game clock at CLOCK
  SUB 4                   ;
  LD (CLOCK),A            ;
  CP 252                  ; Was it just decreased from zero?
  JR NZ,DECAIR_0          ; Jump if not
  LD A,(AIR)              ; Pick up the value of the remaining air supply from
                          ; AIR
  CP 36                   ; Has the air supply run out?
  RET Z                   ; Return (with the zero flag set) if so
  DEC A                   ; Decrement the air supply at AIR
  LD (AIR),A              ;
  LD A,(CLOCK)            ; Pick up the value of the game clock at CLOCK
DECAIR_0:
  AND 224                 ; A=INT(A/32); this value specifies how many pixels
  RLCA                    ; to draw from left to right in the cell at the right
  RLCA                    ; end of the air bar
  RLCA                    ;
  LD E,0                  ; Initialise E to 0 (all bits reset)
  OR A                    ; Do we need to draw any pixels in the cell at the
                          ; right end of the air bar?
  JR Z,DECAIR_2           ; Jump if not
  LD B,A                  ; Copy the number of pixels to draw (1-7) to B
DECAIR_1:
  RRC E                   ; Set this many bits in E (from bit 7 towards bit 0)
  SET 7,E                 ;
  DJNZ DECAIR_1           ;
DECAIR_2:
  LD A,(AIR)              ; Pick up the value of the remaining air supply from
                          ; AIR
  LD L,A                  ; Set HL to the display file address at which to draw
  LD H,AIR_ROW_HIGH       ; the top row of pixels in the cell at the right end
                          ; of the air bar
  LD B,4                  ; There are four rows of pixels to draw
DECAIR_3:
  LD (HL),E               ; Draw the four rows of pixels at the right end of
  INC H                   ; the air bar
  DJNZ DECAIR_3           ;
  XOR A                   ; Reset the zero flag to indicate that there is still
  INC A                   ; some air remaining; these instructions are
                          ; redundant, since the zero flag is already reset at
                          ; this point
  RET

; Draw the current cavern to the screen buffer at 28672
;
; Used by the routine at STARTGAME.
DRAWSHEET:
  LD IX,ATTR_CACHE       ; Point IX at the first byte of the attribute buffer
                          ; at 24064
  LD A,HIGH SCREEN_CACHE ; Set the operand of the 'LD D,n' instruction at
  LD (SBMSB+1),A          ; SBMSB (below) to 112
  CALL DRAWSHEET_0        ; Draw the tiles for the top half of the cavern to
                          ; the screen buffer at 28672
  LD IX,ATTR_CACHE+256   ; Point IX at the 256th byte of the attribute buffer
                          ; at 24064 in preparation for drawing the bottom half
                          ; of the cavern; this instruction is redundant, since
                          ; IX already holds 24320
  LD A,HIGH SCREEN_CACHE+2048                ; Set the operand of the 'LD D,n' instruction at
  LD (SBMSB+1),A          ; SBMSB (below) to 120 (Second third of screen buffer)
DRAWSHEET_0:
  LD C,0                  ; C will count 256 tiles
; The following loop draws 256 tiles (for either the top half or the bottom
; half of the cavern) to the screen buffer at 28672.
DRAWSHEET_1:
  LD E,C                  ; E holds the LSB of the screen buffer address
  LD A,(IX+0)             ; Pick up an attribute byte from the buffer at 24064;
                          ; this identifies the type of tile to draw
  LD HL,BACKGROUND        ; Move HL through the attribute bytes and graphic
  LD BC,72                ; data of the background, floor, crumbling floor,
  CPIR                    ; wall, conveyor and nasty tiles starting at
                          ; BACKGROUND until we find a byte that matches the
                          ; attribute byte of the tile to be drawn
  LD C,E                  ; Restore the value of the tile counter in C
  LD B,8                  ; There are eight bytes in the tile
SBMSB:
  LD D,0                  ; This instruction is set to either 'LD D,112' or 'LD
                          ; D,120' above; now DE holds the appropriate address
                          ; in the screen buffer at 28672
DRAWSHEET_2:
  LD A,(HL)               ; Copy the tile graphic data to the screen buffer at
  LD (DE),A               ; 28672
  INC HL                  ;
  INC D                   ;
  DJNZ DRAWSHEET_2        ;
  INC IX                  ; Move IX along to the next byte in the attribute
                          ; buffer
  INC C                   ; Have we drawn 256 tiles yet?
  JP NZ,DRAWSHEET_1       ; If not, jump back to draw the next one
; The empty cavern has been drawn to the screen buffer at 28672. If we're in
; The Final Barrier, however, there is further work to do.
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 19                   ; Is it The Final Barrier?
  RET NZ                  ; Return if not
  LD HL,TITLESCR1         ; Copy the graphic data from TITLESCR1 to the top
  LD DE,SCREEN_CACHE     ; half of the screen buffer at 28672
  LD BC,2048              ;
  LDIR                    ;
  RET

; Move Willy (1)
;
; Used by the routine at LOOP. This routine deals with Willy if he's jumping or
; falling.
MOVEWILLY:
  LD A,(AIRBORNE)         ; Pick up the airborne status indicator from AIRBORNE
  CP 1                    ; Is Willy jumping?
  JR NZ,MOVEWILLY_3       ; Jump if not
; Willy is currently jumping.
  LD A,(JUMPING)          ; Pick up the jumping animation counter (0-17) from
                          ; JUMPING
  RES 0,A                 ; Now -8<=A<=8 (and A is even)
  SUB 8                   ;
  LD HL,PIXEL_Y           ; Adjust Willy's pixel y-coordinate at PIXEL_Y
  ADD A,(HL)              ; depending on where Willy is in the jump
  LD (HL),A               ;
  CALL MOVEWILLY_7        ; Adjust Willy's attribute buffer location at
                          ; LOCATION depending on his pixel y-coordinate
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  CP (HL)                 ; Is the top-left cell of Willy's sprite overlapping
                          ; a wall tile?
  JP Z,MOVEWILLY_10       ; Jump if so
  INC HL                  ; Point HL at the top-right cell occupied by Willy's
                          ; sprite
  CP (HL)                 ; Is the top-right cell of Willy's sprite overlapping
                          ; a wall tile?
  JP Z,MOVEWILLY_10       ; Jump if so
  LD A,(JUMPING)          ; Increment the jumping animation counter at JUMPING
  INC A                   ;
  LD (JUMPING),A          ;
  SUB 8                   ; A=J-8, where J (1-18) is the new value of the
                          ; jumping animation counter
  JP P,MOVEWILLY_0        ; Jump if J>=8
  NEG                     ; A=8-J (1<=J<=7, 1<=A<=7)
MOVEWILLY_0:
  INC A                   ; A=1+ABS(J-8)
  RLCA                    ; D=8*(1+ABS(J-8)); this value determines the pitch
  RLCA                    ; of the jumping sound effect (rising as Willy rises,
  RLCA                    ; falling as Willy falls)
  LD D,A                  ;
  LD C,32                 ; This value determines the duration of the jumping
                          ; sound effect
  LD A,(BORDER)           ; Pick up the border colour for the current cavern
                          ; from BORDER
MOVEWILLY_1:
  OUT (PORT_SOUND),A      ; Make a jumping sound effect
  XOR 24                  ;
  LD B,D                  ;
MOVEWILLY_2:
  DJNZ MOVEWILLY_2        ;
  DEC C                   ;
  JR NZ,MOVEWILLY_1       ;
  LD A,(JUMPING)          ; Pick up the jumping animation counter (1-18) from
                          ; JUMPING
  CP 18                   ; Has Willy reached the end of the jump?
  JP Z,MOVEWILLY_8        ; Jump if so
  CP 16                   ; Is the jumping animation counter now 16?
  JR Z,MOVEWILLY_3        ; Jump if so
  CP 13                   ; Is the jumping animation counter now 13?
  JP NZ,MOVEWILLY2_6      ; Jump if not
; If we get here, then Willy is standing on the floor, or he's falling, or his
; jumping animation counter is 13 (at which point Willy is on his way down and
; is exactly two cell-heights above where he started the jump) or 16 (at which
; point Willy is on his way down and is exactly one cell-height above where he
; started the jump).
MOVEWILLY_3:
  LD A,(PIXEL_Y)          ; Pick up Willy's pixel y-coordinate from PIXEL_Y
  AND 15                  ; Does Willy's sprite occupy six cells at the moment?
  JR NZ,MOVEWILLY_4       ; Jump if so
  LD HL,(LOCATION)        ; Pick up Willy's attribute buffer coordinates from
                          ; LOCATION
  LD DE,64                ; Point HL at the left-hand cell below Willy's sprite
  ADD HL,DE               ;
  LD A,(CRUMBLING)        ; Pick up the attribute byte of the crumbling floor
                          ; tile for the current cavern from CRUMBLING
  CP (HL)                 ; Does the left-hand cell below Willy's sprite
                          ; contain a crumbling floor tile?
  CALL Z,CRUMBLE          ; If so, make it crumble
  LD A,(NASTY1)           ; Pick up the attribute byte of the first nasty tile
                          ; for the current cavern from NASTY1
  CP (HL)                 ; Does the left-hand cell below Willy's sprite
                          ; contain a nasty tile?
  JR Z,MOVEWILLY_4        ; Jump if so
  LD A,(NASTY2)           ; Pick up the attribute byte of the second nasty tile
                          ; for the current cavern from NASTY2
  CP (HL)                 ; Does the left-hand cell below Willy's sprite
                          ; contain a nasty tile?
  JR Z,MOVEWILLY_4        ; Jump if so
  INC HL                  ; Point HL at the right-hand cell below Willy's
                          ; sprite
  LD A,(CRUMBLING)        ; Pick up the attribute byte of the crumbling floor
                          ; tile for the current cavern from CRUMBLING
  CP (HL)                 ; Does the right-hand cell below Willy's sprite
                          ; contain a crumbling floor tile?
  CALL Z,CRUMBLE          ; If so, make it crumble
  LD A,(NASTY1)           ; Pick up the attribute byte of the first nasty tile
                          ; for the current cavern from NASTY1
  CP (HL)                 ; Does the right-hand cell below Willy's sprite
                          ; contain a nasty tile?
  JR Z,MOVEWILLY_4        ; Jump if so
  LD A,(NASTY2)           ; Pick up the attribute byte of the second nasty tile
                          ; for the current cavern from NASTY2
  CP (HL)                 ; Does the right-hand cell below Willy's sprite
                          ; contain a nasty tile?
  JR Z,MOVEWILLY_4        ; Jump if so
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  CP (HL)                 ; Set the zero flag if the right-hand cell below
                          ; Willy's sprite is empty
  DEC HL                  ; Point HL at the left-hand cell below Willy's sprite
  JP NZ,MOVEWILLY2        ; Jump if the right-hand cell below Willy's sprite is
                          ; not empty
  CP (HL)                 ; Is the left-hand cell below Willy's sprite empty?
  JP NZ,MOVEWILLY2        ; Jump if not
MOVEWILLY_4:
  LD A,(AIRBORNE)         ; Pick up the airborne status indicator from AIRBORNE
  CP 1                    ; Is Willy jumping?
  JP Z,MOVEWILLY2_6       ; Jump if so
; If we get here, then Willy is either in the process of falling or just about
; to start falling.
  LD HL,DMFLAGS           ; Reset bit 1 at DMFLAGS: Willy is not moving left or
  RES 1,(HL)              ; right
  OR A                    ; Is Willy already falling?
  JP Z,MOVEWILLY_9        ; Jump if not
  INC A                   ; Increment the airborne status indicator at AIRBORNE
  LD (AIRBORNE),A         ;
  RLCA                    ; D=16*A; this value determines the pitch of the
  RLCA                    ; falling sound effect
  RLCA                    ;
  RLCA                    ;
  LD D,A                  ;
  LD C,32                 ; This value determines the duration of the falling
                          ; sound effect
  LD A,(BORDER)           ; Pick up the border colour for the current cavern
                          ; from BORDER
MOVEWILLY_5:
  OUT (PORT_SOUND),A      ; Make a falling sound effect
  XOR 24                  ;
  LD B,D                  ;
MOVEWILLY_6:
  DJNZ MOVEWILLY_6        ;
  DEC C                   ;
  JR NZ,MOVEWILLY_5       ;
  LD A,(PIXEL_Y)          ; Add 8 to Willy's pixel y-coordinate at PIXEL_Y;
  ADD A,8                 ; this moves Willy downwards by 4 pixels
  LD (PIXEL_Y),A          ;
MOVEWILLY_7:
  AND 240                 ; L=16*Y, where Y is Willy's screen y-coordinate
  LD L,A                  ; (0-14)
  XOR A                   ; Clear A and the carry flag
  RL L                    ; Now L=32*(Y-8*INT(Y/8)), and the carry flag is set
                          ; if Willy is in the lower half of the cavern (Y>=8)
  ADC A,92                ; H=92 or 93 (MSB of the address of Willy's location
  LD H,A                  ; in the attribute buffer)
  LD A,(LOCATION)         ; Pick up Willy's screen x-coordinate (1-29) from
  AND 31                  ; bits 0-4 at LOCATION
  OR L                    ; Now L holds the LSB of Willy's attribute buffer
  LD L,A                  ; address
  LD (LOCATION),HL        ; Store Willy's updated attribute buffer location at
                          ; LOCATION
  RET
; Willy has just finished a jump.
MOVEWILLY_8:
  LD A,6                  ; Set the airborne status indicator at AIRBORNE to 6:
  LD (AIRBORNE),A         ; Willy will continue to fall unless he's landed on a
                          ; wall or floor block
  RET
; Willy has just started falling.
MOVEWILLY_9:
  LD A,2                  ; Set the airborne status indicator at AIRBORNE to 2
  LD (AIRBORNE),A         ;
  RET
; The top-left or top-right cell of Willy's sprite is overlapping a wall tile.
MOVEWILLY_10:
  LD A,(PIXEL_Y)          ; Adjust Willy's pixel y-coordinate at PIXEL_Y so
  ADD A,16                ; that the top row of cells of his sprite is just
  AND 240                 ; below the wall tile
  LD (PIXEL_Y),A          ;
  CALL MOVEWILLY_7        ; Adjust Willy's attribute buffer location at
                          ; LOCATION to account for this new pixel y-coordinate
  LD A,2                  ; Set the airborne status indicator at AIRBORNE to 2:
  LD (AIRBORNE),A         ; Willy has started falling
  LD HL,DMFLAGS           ; Reset bit 1 at DMFLAGS: Willy is not moving left or
  RES 1,(HL)              ; right
  RET

; Animate a crumbling floor tile in the current cavern
;
; Used by the routine at MOVEWILLY.
;
; HL Address of the crumbling floor tile's location in the attribute buffer at
;    23552
CRUMBLE:
  LD C,L                  ; Point BC at the bottom row of pixels of the
  LD A,H                  ; crumbling floor tile in the screen buffer at 28672
  ADD A,27                ; FIXME: Magic number..
  OR 7                    ;
  LD B,A                  ;
CRUMBLE_0:
  DEC B                   ; Collect the pixels from the row above in A
  LD A,(BC)               ;
  INC B                   ; Copy these pixels into the row below it
  LD (BC),A               ;
  DEC B                   ; Point BC at the next row of pixels up
  LD A,B                  ; Have we dealt with the bottom seven pixel rows of
  AND 7                   ; the crumbling floor tile yet?
  JR NZ,CRUMBLE_0         ; If not, jump back to deal with the next one up
  XOR A                   ; Clear the top row of pixels in the crumbling floor
  LD (BC),A               ; tile
  LD A,B                  ; Point BC at the bottom row of pixels in the
  ADD A,7                 ; crumbling floor tile
  LD B,A                  ;
  LD A,(BC)               ; Pick up the bottom row of pixels in A
  OR A                    ; Is the bottom row clear?
  RET NZ                  ; Return if not
; The bottom row of pixels in the crumbling floor tile is clear. Time to put a
; background tile in its place.
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  INC H                   ; Set HL to the address of the crumbling floor tile's
  INC H                   ; location in the attribute buffer at 24064
  LD (HL),A               ; Set the attribute at this location to that of the
                          ; background tile
  DEC H                   ; Set HL back to the address of the crumbling floor
  DEC H                   ; tile's location in the attribute buffer at 23552
  RET

; Move Willy (2)
;
; Used by the routine at MOVEWILLY. This routine checks the keyboard and
; joystick, and moves Willy left or right if necessary.
;
; HL Attribute buffer address of the left-hand cell below Willy's sprite
MOVEWILLY2:
  LD A,(AIRBORNE)         ; Pick up the airborne status indicator from AIRBORNE
  CP 12                   ; Has Willy just landed after falling from too great
                          ; a height?
  JP NC,KILLWILLY_0       ; If so, kill him
  LD E,255                ; Initialise E to 255 (all bits set); it will be used
                          ; to hold keyboard and joystick readings
  XOR A                   ; Reset the airborne status indicator at AIRBORNE
  LD (AIRBORNE),A         ; (Willy has landed safely)
  LD A,(CONVEYOR)         ; Pick up the attribute byte of the conveyor tile for
                          ; the current cavern from CONVEYOR
  CP (HL)                 ; Does the attribute byte of the left-hand cell below
                          ; Willy's sprite match that of the conveyor tile?
  JR Z,MOVEWILLY2_0       ; Jump if so
  INC HL                  ; Point HL at the right-hand cell below Willy's
                          ; sprite
  CP (HL)                 ; Does the attribute byte of the right-hand cell
                          ; below Willy's sprite match that of the conveyor
                          ; tile?
  JR NZ,MOVEWILLY2_1      ; Jump if not
MOVEWILLY2_0:
  LD A,(CONVDIR)          ; Pick up the direction byte of the conveyor
                          ; definition from CONVDIR (0=left, 1=right)
  SUB 3                   ; Now E=253 (bit 1 reset) if the conveyor is moving
  LD E,A                  ; left, or 254 (bit 0 reset) if it's moving right
MOVEWILLY2_1:
  LD BC, PORT_POIU        ; Read keys P-O-I-U-Y (right, left, right, left,
  IN A,(C)                ; right) into bits 0-4 of A
  AND 31                  ; Set bit 5 and reset bits 6 and 7
  OR 32                   ;
  AND E                   ; Reset bit 0 if the conveyor is moving right, or bit
                          ; 1 if it's moving left
  LD E,A                  ; Save the result in E
  LD BC, PORT_QWER        ; Read keys Q-W-E-R-T (left, right, left, right,
  IN A,(C)                ; left) into bits 0-4 of A
  AND 31                  ; Keep only bits 0-4, shift them into bits 1-5, and
  RLC A                   ; set bit 0
  OR 1                    ;
  AND E                   ; Merge this keyboard reading into bits 1-5 of E
  LD E,A                  ;
  LD B,HIGH PORT_1234     ; Read keys 1-2-3-4-5 ('5' is left) into bits 0-4 of
  IN A,(C)                ; A
  RRCA                    ; Rotate the result right and set bits 0-2 and 4-7;
  OR NOT KEY_5            ; this ignores every key except '5' (left)
  AND E                   ; Merge this reading of the '5' key into bit 3 of E
  LD E,A                  ;
  LD B,HIGH PORT_6789     ; Read keys 0-9-8-7-6 ('8' is right) into bits 0-4 of
  IN A,(C)                ; A
  OR NOT KEY_8            ; Set bits 0, 1 and 3-7; this ignores every key
                          ; except '8' (right)
  AND E                   ; Merge this reading of the '8' key into bit 2 of E
  LD E,A                  ;
  LD A,(KEMP)             ; Collect the Kempston joystick indicator from KEMP
  OR A                    ; Is the joystick connected?
  JR Z,MOVEWILLY2_2       ; Jump if not
  LD BC,PORT_KEMPSTON     ; Collect input from the joystick
  IN A,(C)                ;
  AND 3                   ; Keep only bits 0 (right) and 1 (left) and flip them
  CPL                     ;
  AND E                   ; Merge this reading of the joystick right and left
  LD E,A                  ; buttons into bits 0 and 1 of E
; At this point, bits 0-5 in E indicate the direction in which Willy is being
; moved or trying to move. If bit 0, 2 or 4 is reset, Willy is being moved or
; trying to move right; if bit 1, 3 or 5 is reset, Willy is being moved or
; trying to move left.
MOVEWILLY2_2:
  LD C,0                  ; Initialise C to 0 (no movement)
  LD A,E                  ; Copy the movement bits into A
  AND 42                  ; Keep only bits 1, 3 and 5 (the 'left' bits)
  CP 42                   ; Are any of these bits reset?
  JR Z,MOVEWILLY2_3       ; Jump if not
  LD C,4                  ; Set bit 2 of C: Willy is moving left
MOVEWILLY2_3:
  LD A,E                  ; Copy the movement bits into A
  AND 21                  ; Keep only bits 0, 2 and 4 (the 'right' bits)
  CP 21                   ; Are any of these bits reset?
  JR Z,MOVEWILLY2_4       ; Jump if not
  SET 3,C                 ; Set bit 3 of C: Willy is moving right
MOVEWILLY2_4:
  LD A,(DMFLAGS)          ; Pick up Willy's direction and movement flags from
                          ; DMFLAGS
  ADD A,C                 ; Point HL at the entry in the left-right movement
  LD C,A                  ; table at LRMOVEMENT that corresponds to the
  LD B,0                  ; direction Willy is facing, and the direction in
  LD HL,LRMOVEMENT        ; which he is being moved or trying to move
  ADD HL,BC               ;
  LD A,(HL)               ; Update Willy's direction and movement flags at
  LD (DMFLAGS),A          ; DMFLAGS with the entry from the left-right movement
                          ; table
; That is left-right movement taken care of. Now check the jump keys.
  LD BC,PORT_ZXCV AND PORT_BNMSS             ; Read keys SHIFT-Z-X-C-V and B-N-M-SS-SPACE
  IN A,(C)                ;
  AND 31                  ; Are any of these keys being pressed?
  CP 31                   ;
  JR NZ,MOVEWILLY2_5      ; Jump if so
  LD B,HIGH PORT_6789     ; Read keys 0-9-8-7-6 into bits 0-4 of A
  IN A,(C)                ;
  AND 9                   ; Keep only bits 0 (the '0' key) and 3 (the '7' key)
  CP 9                    ; Is '0' or '7' being pressed?
  JR NZ,MOVEWILLY2_5      ; Jump if so
  LD A,(KEMP)             ; Collect the Kempston joystick indicator from KEMP
  OR A                    ; Is the joystick connected?
  JR Z,MOVEWILLY2_6       ; Jump if not
  LD BC,PORT_KEMPSTON     ; Collect input from the joystick
  IN A,(C)                ;
  BIT 4,A                 ; Is the fire button being pressed?
  JR Z,MOVEWILLY2_6       ; Jump if not
; A jump key or the fire button is being pressed. Time to make Willy jump.
MOVEWILLY2_5:
  XOR A                   ; Initialise the jumping animation counter at JUMPING
  LD (JUMPING),A          ;
  INC A                   ; Set the airborne status indicator at AIRBORNE to 1:
  LD (AIRBORNE),A         ; Willy is jumping
; This entry point is used by the routine at MOVEWILLY.
MOVEWILLY2_6:
  LD A,(DMFLAGS)          ; Pick up Willy's direction and movement flags from
                          ; DMFLAGS
  AND 2                   ; Is Willy moving?
  RET Z                   ; Return if not
  LD A,(DMFLAGS)          ; Pick up Willy's direction and movement flags from
                          ; DMFLAGS
  AND 1                   ; Is Willy facing right?
  JP Z,MOVEWILLY2_9       ; Jump if so
; Willy is moving left.
  LD A,(FRAME)            ; Pick up Willy's animation frame from FRAME
  OR A                    ; Is it 0?
  JR Z,MOVEWILLY2_7       ; If so, jump to move Willy's sprite left across a
                          ; cell boundary
  DEC A                   ; Decrement Willy's animation frame at FRAME
  LD (FRAME),A            ;
  RET
; Willy's sprite is moving left across a cell boundary. In the comments that
; follow, (x,y) refers to the coordinates of the top-left cell currently
; occupied by Willy's sprite.
MOVEWILLY2_7:
  LD HL,(LOCATION)        ; Collect Willy's attribute buffer coordinates from
                          ; LOCATION
  DEC HL                  ; Point HL at the cell at (x-1,y+1)
  LD DE,32                ;
  ADD HL,DE               ;
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  LD A,(PIXEL_Y)          ; Pick up Willy's pixel y-coordinate from PIXEL_Y
  AND 15                  ; Does Willy's sprite currently occupy only two rows
                          ; of cells?
  JR Z,MOVEWILLY2_8       ; Jump if so
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  ADD HL,DE               ; Point HL at the cell at (x-1,y+2)
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  OR A                    ; Clear the carry flag for subtraction
  SBC HL,DE               ; Point HL at the cell at (x-1,y+1)
MOVEWILLY2_8:
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  OR A                    ; Clear the carry flag for subtraction
  SBC HL,DE               ; Point HL at the cell at (x-1,y)
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  LD (LOCATION),HL        ; Save Willy's new attribute buffer coordinates (in
                          ; HL) at LOCATION
  LD A,3                  ; Change Willy's animation frame at FRAME from 0 to 3
  LD (FRAME),A            ;
  RET
; Willy is moving right.
MOVEWILLY2_9:
  LD A,(FRAME)            ; Pick up Willy's animation frame from FRAME
  CP 3                    ; Is it 3?
  JR Z,MOVEWILLY2_10      ; If so, jump to move Willy's sprite right across a
                          ; cell boundary
  INC A                   ; Increment Willy's animation frame at FRAME
  LD (FRAME),A            ;
  RET
; Willy's sprite is moving right across a cell boundary. In the comments that
; follow, (x,y) refers to the coordinates of the top-left cell currently
; occupied by Willy's sprite.
MOVEWILLY2_10:
  LD HL,(LOCATION)        ; Collect Willy's attribute buffer coordinates from
                          ; LOCATION
  INC HL                  ; Point HL at the cell at (x+2,y)
  INC HL                  ;
  LD DE,32                ; Prepare DE for addition
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  ADD HL,DE               ; Point HL at the cell at (x+2,y+1)
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  LD A,(PIXEL_Y)          ; Pick up Willy's pixel y-coordinate from PIXEL_Y
  AND 15                  ; Does Willy's sprite currently occupy only two rows
                          ; of cells?
  JR Z,MOVEWILLY2_11      ; Jump if so
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  ADD HL,DE               ; Point HL at the cell at (x+2,y+2)
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  OR A                    ; Clear the carry flag for subtraction
  SBC HL,DE               ; Point HL at the cell at (x+2,y+1)
MOVEWILLY2_11:
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; current cavern from WALL
  OR A                    ; Clear the carry flag for subtraction
  SBC HL,DE               ; Point HL at the cell at (x+2,y)
  CP (HL)                 ; Is there a wall tile in the cell pointed to by HL?
  RET Z                   ; Return if so without moving Willy (his path is
                          ; blocked)
  DEC HL                  ; Point HL at the cell at (x+1,y)
  LD (LOCATION),HL        ; Save Willy's new attribute buffer coordinates (in
                          ; HL) at LOCATION
  XOR A                   ; Change Willy's animation frame at FRAME from 3 to 0
  LD (FRAME),A            ;
  RET

; Kill Willy
;
; Used by the routine at WILLYATTR when Willy hits a nasty.
KILLWILLY:
  POP HL                  ; Drop the return address from the stack
; This entry point is used by the routines at MOVEWILLY2 (when Willy lands
; after falling from too great a height), DRAWHG (when Willy collides with a
; horizontal guardian), EUGENE (when Willy collides with Eugene), VGUARDIANS
; (when Willy collides with a vertical guardian) and KONGBEAST (when Willy
; collides with the Kong Beast).
KILLWILLY_0:
  POP HL                  ; Drop the return address from the stack
; This entry point is used by the routine at SKYLABS when a Skylab falls on
; Willy.
KILLWILLY_1:
  LD A,255                ; Set the airborne status indicator at AIRBORNE to
  LD (AIRBORNE),A         ; 255 (meaning Willy has had a fatal accident)
  JP LOOP_4               ; Jump back into the main loop

; Move the horizontal guardians in the current cavern
;
; Used by the routine at LOOP.
MOVEHG:
  LD IY,HGUARDS           ; Point IY at the first byte of the first horizontal
                          ; guardian definition at HGUARDS
  LD DE,7                 ; Prepare DE for addition (there are 7 bytes in a
                          ; guardian definition)
; The guardian-moving loop begins here.
MOVEHG_0:
  LD A,(IY+0)             ; Pick up the first byte of the guardian definition
  CP 255                  ; Have we dealt with all the guardians yet?
  RET Z                   ; Return if so
  OR A                    ; Is this guardian definition blank?
  JR Z,MOVEHG_6           ; If so, skip it and consider the next one
  LD A,(CLOCK)            ; Pick up the value of the game clock at CLOCK
  AND 4                   ; Move bit 2 (which is toggled on each pass through
  RRCA                    ; the main loop) to bit 7 and clear all the other
  RRCA                    ; bits
  RRCA                    ;
  AND (IY+0)              ; Combine this bit with bit 7 of the first byte of
                          ; the guardian definition, which specifies the
                          ; guardian's animation speed: 0=normal, 1=slow
  JR NZ,MOVEHG_6          ; Jump to consider the next guardian if this one is
                          ; not due to be moved on this pass
; The guardian will be moved on this pass.
  LD A,(IY+4)             ; Pick up the current animation frame (0-7)
  CP 3                    ; Is it 3 (the terminal frame for a guardian moving
                          ; right)?
  JR Z,MOVEHG_2           ; Jump if so to move the guardian right across a cell
                          ; boundary or turn it round
  CP 4                    ; Is the current animation frame 4 (the terminal
                          ; frame for a guardian moving left)?
  JR Z,MOVEHG_4           ; Jump if so to move the guardian left across a cell
                          ; boundary or turn it round
  JR NC,MOVEHG_1          ; Jump if the animation frame is 5, 6 or 7
  INC (IY+4)              ; Increment the animation frame (this guardian is
                          ; moving right)
  JR MOVEHG_6             ; Jump forward to consider the next guardian
MOVEHG_1:
  DEC (IY+4)              ; Decrement the animation frame (this guardian is
                          ; moving left)
  JR MOVEHG_6             ; Jump forward to consider the next guardian
MOVEHG_2:
  LD A,(IY+1)             ; Pick up the LSB of the address of the guardian's
                          ; location in the attribute buffer at 23552
  CP (IY+6)               ; Has the guardian reached the rightmost point in its
                          ; path?
  JR NZ,MOVEHG_3          ; Jump if not
  LD (IY+4),7             ; Set the animation frame to 7 (turning the guardian
                          ; round to face left)
  JR MOVEHG_6             ; Jump forward to consider the next guardian
MOVEHG_3:
  LD (IY+4),0             ; Set the animation frame to 0 (the initial frame for
                          ; a guardian moving right)
  INC (IY+1)              ; Increment the guardian's x-coordinate (moving it
                          ; right across a cell boundary)
  JR MOVEHG_6             ; Jump forward to consider the next guardian
MOVEHG_4:
  LD A,(IY+1)             ; Pick up the LSB of the address of the guardian's
                          ; location in the attribute buffer at 23552
  CP (IY+5)               ; Has the guardian reached the leftmost point in its
                          ; path?
  JR NZ,MOVEHG_5          ; Jump if not
  LD (IY+4),0             ; Set the animation frame to 0 (turning the guardian
                          ; round to face right)
  JR MOVEHG_6             ; Jump forward to consider the next guardian
MOVEHG_5:
  LD (IY+4),7             ; Set the animation frame to 7 (the initial frame for
                          ; a guardian moving left)
  DEC (IY+1)              ; Decrement the guardian's x-coordinate (moving it
                          ; left across a cell boundary)
; The current guardian definition has been dealt with. Time for the next one.
MOVEHG_6:
  ADD IY,DE               ; Point IY at the first byte of the next horizontal
                          ; guardian definition
  JR MOVEHG_0             ; Jump back to deal with the next horizontal guardian

; Move and draw the light beam in Solar Power Generator
;
; Used by the routine at LOOP.
LIGHTBEAM:
  LD HL,23575             ; Point HL at the cell at (0,23) in the attribute
                          ; buffer at 23552 (the source of the light beam)
  LD DE,32                ; Prepare DE for addition (the beam travels
                          ; vertically downwards to start with)
; The beam-drawing loop begins here.
LIGHTBEAM_0:
  LD A,(FLOOR)            ; Pick up the attribute byte of the floor tile for
                          ; the cavern from FLOOR
  CP (HL)                 ; Does HL point at a floor tile?
  RET Z                   ; Return if so (the light beam stops here)
  LD A,(WALL)             ; Pick up the attribute byte of the wall tile for the
                          ; cavern from WALL
  CP (HL)                 ; Does HL point at a wall tile?
  RET Z                   ; Return if so (the light beam stops here)
  LD A,39                 ; A=39 (INK 7: PAPER 4)
  CP (HL)                 ; Does HL point at a tile with this attribute value?
  JR NZ,LIGHTBEAM_1       ; Jump if not (the light beam is not touching Willy)
  EXX                     ; Switch to the shadow registers briefly (to preserve
                          ; DE and HL)
  CALL DECAIR             ; Decrease the air supply by four units
  CALL DECAIR             ;
  CALL DECAIR             ;
  CALL DECAIR             ;
  EXX                     ; Switch back to the normal registers (restoring DE
                          ; and HL)
  JR LIGHTBEAM_2          ; Jump forward to draw the light beam over Willy
LIGHTBEAM_1:
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the cavern from BACKGROUND
  CP (HL)                 ; Does HL point at a background tile?
  JR Z,LIGHTBEAM_2        ; Jump if so (the light beam will not be reflected at
                          ; this point)
  LD A,E                  ; Toggle the value in DE between 32 and -1 (and
  XOR 223                 ; therefore the direction of the light beam between
  LD E,A                  ; vertically downwards and horizontally to the left):
  LD A,D                  ; the light beam has hit a guardian
  CPL                     ;
  LD D,A                  ;
LIGHTBEAM_2:
  LD (HL),119             ; Draw a portion of the light beam with attribute
                          ; value 119 (INK 7: PAPER 6: BRIGHT 1)
  ADD HL,DE               ; Point HL at the cell where the next portion of the
                          ; light beam will be drawn
  JR LIGHTBEAM_0          ; Jump back to draw the next portion of the light
                          ; beam

; Draw the horizontal guardians in the current cavern
;
; Used by the routine at LOOP.
DRAWHG:
  LD IY,HGUARDS           ; Point IY at the first byte of the first horizontal
                          ; guardian definition at HGUARDS
; The guardian-drawing loop begins here.
DRAWHG_0:
  LD A,(IY+0)             ; Pick up the first byte of the guardian definition
  CP 255                  ; Have we dealt with all the guardians yet?
  RET Z                   ; Return if so
  OR A                    ; Is this guardian definition blank?
  JR Z,DRAWHG_2           ; If so, skip it and consider the next one
  LD DE,31                ; Prepare DE for addition
  LD L,(IY+1)             ; Point HL at the address of the guardian's location
  LD H,(IY+2)             ; in the attribute buffer at 23552
  AND 127                 ; Reset bit 7 (which specifies the animation speed)
                          ; of the attribute byte, ensuring no FLASH
  LD (HL),A               ; Set the attribute bytes for the guardian in the
  INC HL                  ; buffer at 23552
  LD (HL),A               ;
  ADD HL,DE               ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  LD C,1                  ; Prepare C for the call to the drawing routine at
                          ; DRWFIX later on
  LD A,(IY+4)             ; Pick up the animation frame (0-7)
  RRCA                    ; Multiply it by 32
  RRCA                    ;
  RRCA                    ;
  LD E,A                  ; Copy the result to E
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  CP 7                    ; Are we in one of the first seven caverns?
  JR C,DRAWHG_1           ; Jump if so
  CP 9                    ; Are we in The Endorian Forest?
  JR Z,DRAWHG_1           ; Jump if so
  CP 15                   ; Are we in The Sixteenth Cavern?
  JR Z,DRAWHG_1           ; Jump if so
  SET 7,E                 ; Add 128 to E (the horizontal guardians in this
                          ; cavern use frames 4-7 only)
DRAWHG_1:
  LD D,129                ; Point DE at the graphic data for the appropriate
                          ; guardian sprite (at GGDATA+E)
  LD L,(IY+1)             ; Point HL at the address of the guardian's location
  LD H,(IY+3)             ; in the screen buffer at 24576
  CALL DRWFIX             ; Draw the guardian to the screen buffer at 24576
  JP NZ,KILLWILLY_0       ; Kill Willy if the guardian collided with him
; The current guardian definition has been dealt with. Time for the next one.
DRAWHG_2:
  LD DE,7                 ; Point IY at the first byte of the next horizontal
  ADD IY,DE               ; guardian definition
  JR DRAWHG_0             ; Jump back to deal with the next horizontal guardian

; Move and draw Eugene in Eugene's Lair
;
; Used by the routine at LOOP. First we move Eugene up or down, or change his
; direction.
EUGENE:
  LD A,(ITEMATTR)         ; Pick up the attribute of the last item drawn from
                          ; ITEMATTR
  OR A                    ; Have all the items been collected?
  JR Z,EUGENE_0           ; Jump if so
  LD A,(EUGDIR)           ; Pick up Eugene's direction from EUGDIR
  OR A                    ; Is Eugene moving downwards?
  JR Z,EUGENE_0           ; Jump if so
  LD A,(EUGHGT)           ; Pick up Eugene's pixel y-coordinate from EUGHGT
  DEC A                   ; Decrement it (moving Eugene up)
  JR Z,EUGENE_1           ; Jump if Eugene has reached the top of the cavern
  LD (EUGHGT),A           ; Update Eugene's pixel y-coordinate at EUGHGT
  JR EUGENE_2
EUGENE_0:
  LD A,(EUGHGT)           ; Pick up Eugene's pixel y-coordinate from EUGHGT
  INC A                   ; Increment it (moving Eugene down)
  CP 88                   ; Has Eugene reached the portal yet?
  JR Z,EUGENE_1           ; Jump if so
  LD (EUGHGT),A           ; Update Eugene's pixel y-coordinate at EUGHGT
  JR EUGENE_2
EUGENE_1:
  LD A,(EUGDIR)           ; Toggle Eugene's direction at EUGDIR
  XOR 1                   ;
  LD (EUGDIR),A           ;
; Now that Eugene's movement has been dealt with, it's time to draw him.
EUGENE_2:
  LD A,(EUGHGT)           ; Pick up Eugene's pixel y-coordinate from EUGHGT
  AND 127                 ; Point DE at the entry in the screen buffer address
  RLCA                    ; lookup table at SBUFADDRS that corresponds to
  LD E,A                  ; Eugene's y-coordinate
  LD D,131                ;
  LD A,(DE)               ; Point HL at the address of Eugene's location in the
  OR 15                   ; screen buffer at 24576
  LD L,A                  ;
  INC DE                  ;
  LD A,(DE)               ;
  LD H,A                  ;
  LD DE,32992             ; Draw Eugene to the screen buffer at 24576
  LD C,1                  ;
  CALL DRWFIX             ;
  JP NZ,KILLWILLY_0       ; Kill Willy if Eugene collided with him
  LD A,(EUGHGT)           ; Pick up Eugene's pixel y-coordinate from EUGHGT
  AND 120                 ; Point HL at the address of Eugene's location in the
  RLCA                    ; attribute buffer at 23552
  OR 7                    ;
  SCF                     ;
  RL A                    ;
  LD L,A                  ;
  LD A,0                  ;
  ADC A,92                ;
  LD H,A                  ;
  LD A,(ITEMATTR)         ; Pick up the attribute of the last item drawn from
                          ; ITEMATTR
  OR A                    ; Set the zero flag if all the items have been
                          ; collected
  LD A,7                  ; Assume we will draw Eugene with white INK
  JR NZ,EUGENE_3          ; Jump if there are items remaining to be collected
  LD A,(CLOCK)            ; Pick up the value of the game clock at CLOCK
  RRCA                    ; Move bits 2-4 into bits 0-2 and clear the other
  RRCA                    ; bits; this value (which decreases by one on each
  AND 7                   ; pass through the main loop) will be Eugene's INK
                          ; colour
; This entry point is used by the routines at SKYLABS (to set the attributes
; for a Skylab), VGUARDIANS (to set the attributes for a vertical guardian) and
; KONGBEAST (to set the attributes for the Kong Beast).
EUGENE_3:
  LD (HL),A               ; Save the INK colour in the attribute buffer
                          ; temporarily
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  AND 248                 ; Combine its PAPER colour with the chosen INK colour
  OR (HL)                 ;
  LD (HL),A               ; Set the attribute byte for the top-left cell of the
                          ; sprite in the attribute buffer at 23552
  LD DE,31                ; Prepare DE for addition
  INC HL                  ; Set the attribute byte for the top-right cell of
  LD (HL),A               ; the sprite in the attribute buffer at 23552
  ADD HL,DE               ; Set the attribute byte for the middle-left cell of
  LD (HL),A               ; the sprite in the attribute buffer at 23552
  INC HL                  ; Set the attribute byte for the middle-right cell of
  LD (HL),A               ; the sprite in the attribute buffer at 23552
  ADD HL,DE               ; Set the attribute byte for the bottom-left cell of
  LD (HL),A               ; the sprite in the attribute buffer at 23552
  INC HL                  ; Set the attribute byte for the bottom-right cell of
  LD (HL),A               ; the sprite in the attribute buffer at 23552
  RET

; Move and draw the Skylabs in Skylab Landing Bay
;
; Used by the routine at LOOP.
SKYLABS:
  LD IY,VGUARDS           ; Point IY at the first byte of the first vertical
                          ; guardian definition at VGUARDS
; The Skylab-moving loop begins here.
SKYLABS_0:
  LD A,(IY+0)             ; Pick up the first byte of the guardian definition
  CP 255                  ; Have we dealt with all the Skylabs yet?
  JP Z,LOOP_3             ; If so, re-enter the main loop
  LD A,(IY+2)             ; Pick up the Skylab's pixel y-coordinate
  CP (IY+6)               ; Has it reached its crash site yet?
  JR NC,SKYLABS_1         ; Jump if so
  ADD A,(IY+4)            ; Increment the Skylab's y-coordinate (moving it
  LD (IY+2),A             ; downwards)
  JR SKYLABS_2
; The Skylab has reached its crash site. Start or continue its disintegration.
SKYLABS_1:
  INC (IY+1)              ; Increment the animation frame
  LD A,(IY+1)             ; Pick up the animation frame
  CP 8                    ; Has the Skylab completely disintegrated yet?
  JR NZ,SKYLABS_2         ; Jump if not
  LD A,(IY+5)             ; Reset the Skylab's pixel y-coordinate
  LD (IY+2),A             ;
  LD A,(IY+3)             ; Add 8 to the Skylab's x-coordinate (wrapping around
  ADD A,8                 ; at the right side of the screen)
  AND 31                  ;
  LD (IY+3),A             ;
  LD (IY+1),0             ; Reset the animation frame to 0
; Now that the Skylab's movement has been dealt with, time to draw it.
SKYLABS_2:
  LD E,(IY+2)             ; Pick up the Skylab's pixel y-coordinate in E
  RLC E                   ; Point DE at the entry in the screen buffer address
  LD D,131                ; lookup table at SBUFADDRS that corresponds to the
                          ; Skylab's pixel y-coordinate
  LD A,(DE)               ; Point HL at the address of the Skylab's location in
  ADD A,(IY+3)            ; the screen buffer at 24576
  LD L,A                  ;
  INC DE                  ;
  LD A,(DE)               ;
  LD H,A                  ;
  LD A,(IY+1)             ; Pick up the animation frame (0-7)
  RRCA                    ; Multiply it by 32
  RRCA                    ;
  RRCA                    ;
  LD E,A                  ; Point DE at the graphic data for the corresponding
  LD D,129                ; Skylab sprite (at GGDATA+A)
  LD C,1                  ; Draw the Skylab to the screen buffer at 24576
  CALL DRWFIX             ;
  JP NZ,KILLWILLY_1       ; Kill Willy if the Skylab collided with him
  LD A,(IY+2)             ; Point HL at the address of the Skylab's location in
  AND 64                  ; the attribute buffer at 23552
  RLCA                    ;
  RLCA                    ;
  ADD A,92                ;
  LD H,A                  ;
  LD A,(IY+2)             ;
  RLCA                    ;
  RLCA                    ;
  AND 224                 ;
  OR (IY+3)               ;
  LD L,A                  ;
  LD A,(IY+0)             ; Pick up the Skylab's attribute byte
  CALL EUGENE_3           ; Set the attribute bytes for the Skylab
; The current guardian definition has been dealt with. Time for the next one.
  LD DE,7                 ; Point IY at the first byte of the next vertical
  ADD IY,DE               ; guardian definition
  JR SKYLABS_0            ; Jump back to deal with the next Skylab

; Move and draw the vertical guardians in the current cavern
;
; Used by the routine at LOOP.
VGUARDIANS:
  LD IY,VGUARDS           ; Point IY at the first byte of the first vertical
                          ; guardian definition at VGUARDS
; The guardian-moving loop begins here.
VGUARDIANS_0:
  LD A,(IY+0)             ; Pick up the first byte of the guardian definition
  CP 255                  ; Have we dealt with all the guardians yet?
  RET Z                   ; Return if so
  INC (IY+1)              ; Increment the guardian's animation frame
  RES 2,(IY+1)            ; Reset the animation frame to 0 if it overflowed to
                          ; 4
  LD A,(IY+2)             ; Pick up the guardian's pixel y-coordinate
  ADD A,(IY+4)            ; Add the current y-coordinate increment
  CP (IY+5)               ; Has the guardian reached the highest point of its
                          ; path (minimum y-coordinate)?
  JR C,VGUARDIANS_1       ; If so, jump to change its direction of movement
  CP (IY+6)               ; Has the guardian reached the lowest point of its
                          ; path (maximum y-coordinate)?
  JR NC,VGUARDIANS_1      ; If so, jump to change its direction of movement
  LD (IY+2),A             ; Update the guardian's pixel y-coordinate
  JR VGUARDIANS_2
VGUARDIANS_1:
  LD A,(IY+4)             ; Negate the y-coordinate increment; this changes the
  NEG                     ; guardian's direction of movement
  LD (IY+4),A             ;
; Now that the guardian's movement has been dealt with, time to draw it.
VGUARDIANS_2:
  LD A,(IY+2)             ; Pick up the guardian's pixel y-coordinate
  AND 127                 ; Point DE at the entry in the screen buffer address
  RLCA                    ; lookup table at SBUFADDRS that corresponds to the
  LD E,A                  ; guardian's pixel y-coordinate
  LD D,131                ;
  LD A,(DE)               ; Point HL at the address of the guardian's location
  OR (IY+3)               ; in the screen buffer at 24576
  LD L,A                  ;
  INC DE                  ;
  LD A,(DE)               ;
  LD H,A                  ;
  LD A,(IY+1)             ; Pick up the guardian's animation frame (0-3)
  RRCA                    ; Multiply it by 32
  RRCA                    ;
  RRCA                    ;
  LD E,A                  ; Point DE at the graphic data for the appropriate
  LD D,129                ; guardian sprite (at GGDATA+A)
  LD C,1                  ; Draw the guardian to the screen buffer at 24576
  CALL DRWFIX             ;
  JP NZ,KILLWILLY_0       ; Kill Willy if the guardian collided with him
  LD A,(IY+2)             ; Pick up the guardian's pixel y-coordinate
  AND 64                  ; Point HL at the address of the guardian's location
  RLCA                    ; in the attribute buffer at 23552
  RLCA                    ;
  ADD A,92                ;
  LD H,A                  ;
  LD A,(IY+2)             ;
  RLCA                    ;
  RLCA                    ;
  AND 224                 ;
  OR (IY+3)               ;
  LD L,A                  ;
  LD A,(IY+0)             ; Pick up the guardian's attribute byte
  CALL EUGENE_3           ; Set the attribute bytes for the guardian
; The current guardian definition has been dealt with. Time for the next one.
  LD DE,7                 ; Point IY at the first byte of the next vertical
  ADD IY,DE               ; guardian definition
  JR VGUARDIANS_0         ; Jump back to deal with the next vertical guardian

; Draw the items in the current cavern and collect any that Willy is touching
;
; Used by the routine at LOOP.
DRAWITEMS:
  XOR A                   ; Initialise the attribute of the last item drawn at
  LD (ITEMATTR),A         ; ITEMATTR to 0 (in case there are no items left to
                          ; draw)
  LD IY,ITEMS             ; Point IY at the first byte of the first item
                          ; definition at ITEMS
; The item-drawing loop begins here.
DRAWITEMS_0:
  LD A,(IY+0)             ; Pick up the first byte of the item definition
  CP 255                  ; Have we dealt with all the items yet?
  JR Z,DRAWITEMS_3        ; Jump if so
  OR A                    ; Has this item already been collected?
  JR Z,DRAWITEMS_2        ; If so, skip it and consider the next one
  LD E,(IY+1)             ; Point DE at the address of the item's location in
  LD D,(IY+2)             ; the attribute buffer at 23552
  LD A,(DE)               ; Pick up the current attribute byte at the item's
                          ; location
  AND 7                   ; Is the INK white (which happens if Willy is
  CP 7                    ; touching the item)?
  JR NZ,DRAWITEMS_1       ; Jump if not
; Willy is touching this item, so add it to his collection.
  LD HL,33836             ; Add 100 to the score
  CALL INCSCORE_0         ;
  LD (IY+0),0             ; Set the item's attribute byte to 0 so that it will
                          ; be skipped the next time
  JR DRAWITEMS_2          ; Jump forward to consider the next item
; This item has not been collected yet.
DRAWITEMS_1:
  LD A,(IY+0)             ; Pick up the item's current attribute byte
  AND 248                 ; Keep the BRIGHT and PAPER bits, and set the INK to
  OR 3                    ; 3 (magenta)
  LD B,A                  ; Store this value in B
  LD A,(IY+0)             ; Pick up the item's current attribute byte again
  AND 3                   ; Keep only bits 0 and 1 and add the value in B; this
  ADD A,B                 ; maintains the BRIGHT and PAPER bits, and cycles the
                          ; INK colour through 3, 4, 5 and 6
  LD (IY+0),A             ; Store the new attribute byte
  LD (DE),A               ; Update the attribute byte at the item's location in
                          ; the buffer at 23552
  LD (ITEMATTR),A         ; Store the new attribute byte at ITEMATTR as well
  LD D,(IY+3)             ; Point DE at the address of the item's location in
                          ; the screen buffer at 24576
  LD HL,ITEM              ; Point HL at the item graphic for the current cavern
                          ; (at ITEM)
  LD B,8                  ; There are eight pixel rows to copy
  CALL PRINTCHAR_0        ; Draw the item to the screen buffer at 24576
; The current item definition has been dealt with. Time for the next one.
DRAWITEMS_2:
  INC IY                  ; Point IY at the first byte of the next item
  INC IY                  ; definition
  INC IY                  ;
  INC IY                  ;
  INC IY                  ;
  JR DRAWITEMS_0          ; Jump back to deal with the next item
; All the items have been dealt with. Check whether there were any left.
DRAWITEMS_3:
  LD A,(ITEMATTR)         ; Pick up the attribute of the last item drawn at
                          ; ITEMATTR
  OR A                    ; Were any items drawn?
  RET NZ                  ; Return if so (some remain to be collected)
  LD HL,PORTAL            ; Ensure that the portal is flashing by setting bit 7
  SET 7,(HL)              ; of its attribute byte at PORTAL
  RET

; Draw the portal, or move to the next cavern if Willy has entered it
;
; Used by the routine at LOOP. First check whether Willy has entered the
; portal.
CHKPORTAL:
  LD HL,(PORTALLOC1)      ; Pick up the address of the portal's location in the
                          ; attribute buffer at 23552 from PORTALLOC1
  LD A,(LOCATION)         ; Pick up the LSB of the address of Willy's location
                          ; in the attribute buffer at 23552 from LOCATION
  CP L                    ; Does it match that of the portal?
  JR NZ,CHKPORTAL_0       ; Jump if not
  LD A,(32877)            ; Pick up the MSB of the address of Willy's location
                          ; in the attribute buffer at 23552 from 32877
  CP H                    ; Does it match that of the portal?
  JR NZ,CHKPORTAL_0       ; Jump if not
  LD A,(PORTAL)           ; Pick up the portal's attribute byte from PORTAL
  BIT 7,A                 ; Is the portal flashing?
  JR Z,CHKPORTAL_0        ; Jump if not
  POP HL                  ; Drop the return address from the stack
  JP NXSHEET              ; Move Willy to the next cavern
; Willy has not entered the portal, or it's not flashing, so just draw it.
CHKPORTAL_0:
  LD A,(PORTAL)           ; Pick up the portal's attribute byte from PORTAL
  LD (HL),A               ; Set the attribute bytes for the portal in the
  INC HL                  ; buffer at 23552
  LD (HL),A               ;
  LD DE,31                ;
  ADD HL,DE               ;
  LD (HL),A               ;
  INC HL                  ;
  LD (HL),A               ;
  LD DE,PORTALG           ; Point DE at the graphic data for the portal at
                          ; PORTALG
  LD HL,(PORTALLOC2)      ; Pick up the address of the portal's location in the
                          ; screen buffer at 24576 from PORTALLOC2
  LD C,0                  ; C=0: overwrite mode
; This routine continues into the one at DRWFIX.

; Draw a sprite
;
; Used by the routines at START (to draw Willy on the title screen), LOOP (to
; draw the remaining lives), ENDGAM (to draw Willy, the boot and the plinth
; during the game over sequence), DRAWHG (to draw horizontal guardians), EUGENE
; (to draw Eugene in Eugene's Lair), SKYLABS (to draw the Skylabs in Skylab
; Landing Bay), VGUARDIANS (to draw vertical guardians), CHKPORTAL (to draw the
; portal in the current cavern), NXSHEET (to draw Willy above ground and the
; swordfish graphic over the portal in The Final Barrier) and KONGBEAST (to
; draw the Kong Beast in Miner Willy meets the Kong Beast and Return of the
; Alien Kong Beast). If C=1 on entry, this routine returns with the zero flag
; reset if any of the set bits in the sprite being drawn collides with a set
; bit in the background.
;
; C Drawing mode: 0 (overwrite) or 1 (blend)
; DE Address of sprite graphic data
; HL Address to draw at
DRWFIX:
  LD B,16                 ; There are 16 rows of pixels to draw
DRWFIX_0:
  BIT 0,C                 ; Set the zero flag if we're in overwrite mode
  LD A,(DE)               ; Pick up a sprite graphic byte
  JR Z,DRWFIX_1           ; Jump if we're in overwrite mode
  AND (HL)                ; Return with the zero flag reset if any of the set
  RET NZ                  ; bits in the sprite graphic byte collide with a set
                          ; bit in the background (e.g. in Willy's sprite)
  LD A,(DE)               ; Pick up the sprite graphic byte again
  OR (HL)                 ; Blend it with the background byte
DRWFIX_1:
  LD (HL),A               ; Copy the graphic byte to its destination cell
  INC L                   ; Move HL along to the next cell on the right
  INC DE                  ; Point DE at the next sprite graphic byte
  BIT 0,C                 ; Set the zero flag if we're in overwrite mode
  LD A,(DE)               ; Pick up a sprite graphic byte
  JR Z,DRWFIX_2           ; Jump if we're in overwrite mode
  AND (HL)                ; Return with the zero flag reset if any of the set
  RET NZ                  ; bits in the sprite graphic byte collide with a set
                          ; bit in the background (e.g. in Willy's sprite)
  LD A,(DE)               ; Pick up the sprite graphic byte again
  OR (HL)                 ; Blend it with the background byte
DRWFIX_2:
  LD (HL),A               ; Copy the graphic byte to its destination cell
  DEC L                   ; Move HL to the next pixel row down in the cell on
  INC H                   ; the left
  INC DE                  ; Point DE at the next sprite graphic byte
  LD A,H                  ; Have we drawn the bottom pixel row in this pair of
  AND 7                   ; cells yet?
  JR NZ,DRWFIX_3          ; Jump if not
  LD A,H                  ; Otherwise move HL to the top pixel row in the cell
  SUB 8                   ; below
  LD H,A                  ;
  LD A,L                  ;
  ADD A,32                ;
  LD L,A                  ;
  AND 224                 ; Was the last pair of cells at y-coordinate 7 or 15?
  JR NZ,DRWFIX_3          ; Jump if not
  LD A,H                  ; Otherwise adjust HL to account for the movement
  ADD A,8                 ; from the top or middle third of the screen to the
  LD H,A                  ; next one down
DRWFIX_3:
  DJNZ DRWFIX_0           ; Jump back until all 16 rows of pixels have been
                          ; drawn
  XOR A                   ; Set the zero flag (to indicate no collision)
  RET

; Move to the next cavern
;
; Used by the routines at LOOP and CHKPORTAL.
NXSHEET:
  LD A,(SHEET)            ; Pick up the number of the current cavern from SHEET
  INC A                   ; Increment the cavern number
  CP 20                   ; Is the current cavern The Final Barrier?
  JR NZ,NXSHEET_3         ; Jump if not
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  JP NZ,NXSHEET_2         ; Jump if so
  LD A,(CHEAT)            ; Pick up the 6031769 key counter from CHEAT
  CP 7                    ; Is cheat mode activated?
  JR Z,NXSHEET_2          ; Jump if so
; Willy has made it through The Final Barrier without cheating.
  LD C,0                  ; Draw Willy at (2,19) on the ground above the portal
  LD DE,WILLYR3           ;
  LD HL,16467             ;
  CALL DRWFIX             ;
  LD DE,SWORDFISH         ; Draw the swordfish graphic (see SWORDFISH) over the
  LD HL,16563             ; portal
  CALL DRWFIX             ;
  LD HL,22611             ; Point HL at (2,19) in the attribute file
  LD DE,31                ; Prepare DE for addition
  LD (HL),47              ; Set the attributes for the upper half of Willy's
  INC HL                  ; sprite at (2,19) and (2,20) to 47 (INK 7: PAPER 5)
  LD (HL),47              ;
  ADD HL,DE               ; Set the attributes for the lower half of Willy's
  LD (HL),39              ; sprite at (3,19) and (3,20) to 39 (INK 7: PAPER 4)
  INC HL                  ;
  LD (HL),39              ;
  ADD HL,DE               ; Point HL at (5,19) in the attribute file
  INC HL                  ;
  ADD HL,DE               ;
  LD (HL),69              ; Set the attributes for the fish at (5,19) and
  INC HL                  ; (5,20) to 69 (INK 5: PAPER 0: BRIGHT 1)
  LD (HL),69              ;
  ADD HL,DE               ; Set the attribute for the handle of the sword at
  LD (HL),70              ; (6,19) to 70 (INK 6: PAPER 0: BRIGHT 1)
  INC HL                  ; Set the attribute for the blade of the sword at
  LD (HL),71              ; (6,20) to 71 (INK 7: PAPER 0: BRIGHT 1)
  ADD HL,DE               ; Set the attributes at (7,19) and (7,20) to 0 (to
  LD (HL),0               ; hide Willy's feet just below where the portal was)
  INC HL                  ;
  LD (HL),0               ;
  LD BC,0                 ; Prepare C and D for the celebratory sound effect
  LD D,50                 ;
  XOR A                   ; A=0 (black border)
NXSHEET_0:
  OUT (PORT_SOUND),A      ; Produce the celebratory sound effect: Willy has
  XOR 24                  ; escaped from the mine
  LD E,A                  ;
  LD A,C                  ;
  ADD A,D                 ;
  ADD A,D                 ;
  ADD A,D                 ;
  LD B,A                  ;
  LD A,E                  ;
NXSHEET_1:
  DJNZ NXSHEET_1          ;
  DEC C                   ;
  JR NZ,NXSHEET_0         ;
  DEC D                   ;
  JR NZ,NXSHEET_0         ;
NXSHEET_2:
  XOR A                   ; A=0 (the next cavern will be Central Cavern)
NXSHEET_3:
  LD (SHEET),A            ; Update the cavern number at SHEET
; The next section of code cycles the INK and PAPER colours of the current
; cavern.
  LD A,63                 ; Initialise A to 63 (INK 7: PAPER 7)
NXSHEET_4:
  LD HL,22528             ; Set the attributes for the top two-thirds of the
  LD DE,22529             ; screen to the value in A
  LD BC,511               ;
  LD (HL),A               ;
  LDIR                    ;
  LD BC,4                 ; Pause for about 0.004s
NXSHEET_5:
  DJNZ NXSHEET_5          ;
  DEC C                   ;
  JR NZ,NXSHEET_5         ;
  DEC A                   ; Decrement the attribute value in A
  JR NZ,NXSHEET_4         ; Jump back until we've gone through all attribute
                          ; values from 63 down to 1
  LD A,(DEMO)             ; Pick up the game mode indicator from DEMO
  OR A                    ; Are we in demo mode?
  JP NZ,NEWSHT            ; If so, demo the next cavern
; The following loop increases the score and decreases the air supply until it
; runs out.
NXSHEET_6:
  CALL DECAIR             ; Decrease the air remaining in the current cavern
  JP Z,NEWSHT             ; Move to the next cavern if the air supply is now
                          ; gone
  LD HL,33838             ; Add 1 to the score
  CALL INCSCORE_0         ;
  LD IX,SCORBUF           ; Print the new score at (19,26)
  LD C,6                  ;
  LD DE,20602             ;
  CALL PMESS              ;
  LD C,4                  ; This value determines the duration of the sound
                          ; effect
  LD A,(AIR)              ; Pick up the remaining air supply (S) from AIR
  CPL                     ; D=2*(63-S); this value determines the pitch of the
  AND 63                  ; sound effect (which decreases with the amount of
  RLC A                   ; air remaining)
  LD D,A                  ;
NXSHEET_7:
  LD A,0                  ; Produce a short note
  OUT (PORT_SOUND),A      ;
  LD B,D                  ;
NXSHEET_8:
  DJNZ NXSHEET_8          ;
  LD A,24                 ;
  OUT (PORT_SOUND),A      ;
  LD B,D                  ;
NXSHEET_9:
  DJNZ NXSHEET_9          ;
  DEC C                   ;
  JR NZ,NXSHEET_7         ;
  JR NXSHEET_6            ; Jump back to decrease the air supply again

; Add to the score
;
; The entry point to this routine is at INCSCORE_0.
INCSCORE:
  LD (HL),48              ; Roll the digit over from '9' to '0'
  DEC HL                  ; Point HL at the next digit to the left
  LD A,L                  ; Is this the 10000s digit?
  CP 42                   ;
  JR NZ,INCSCORE_0        ; Jump if not
; Willy has scored another 10000 points. Give him an extra life.
  LD A,8                  ; Set the screen flash counter at FLASH to 8
  LD (FLASH),A            ;
  LD A,(NOMEN)            ; Increment the number of lives remaining at NOMEN
  INC A                   ;
  LD (NOMEN),A            ;
; The entry point to this routine is here and is used by the routines at
; DRAWITEMS, NXSHEET and KONGBEAST with HL pointing at the digit of the score
; (see SCORBUF) to be incremented.
INCSCORE_0:
  LD A,(HL)               ; Pick up a digit of the score
  CP 57                   ; Is it '9'?
  JR Z,INCSCORE           ; Jump if so
  INC (HL)                ; Increment the digit
  RET

; Move the conveyor in the current cavern
;
; Used by the routine at LOOP.
MVCONVEYOR:
  LD HL,(CONVLOC)         ; Pick up the address of the conveyor's location in
                          ; the screen buffer at 28672 from CONVLOC
  LD E,L                  ; Copy this address to DE
  LD D,H                  ;
  LD A,(CONVLEN)          ; Pick up the length of the conveyor from CONVLEN
  LD B,A                  ; B will count the conveyor tiles
  LD A,(CONVDIR)          ; Pick up the direction of the conveyor from CONVDIR
  OR A                    ; Is the conveyor moving right?
  JR NZ,MVCONVEYOR_1      ; Jump if so
; The conveyor is moving left.
  LD A,(HL)               ; Copy the first pixel row of the conveyor tile to A
  RLC A                   ; Rotate it left twice
  RLC A                   ;
  INC H                   ; Point HL at the third pixel row of the conveyor
  INC H                   ; tile
  LD C,(HL)               ; Copy this pixel row to C
  RRC C                   ; Rotate it right twice
  RRC C                   ;
MVCONVEYOR_0:
  LD (DE),A               ; Update the first and third pixel rows of every
  LD (HL),C               ; conveyor tile in the screen buffer at 28672
  INC L                   ;
  INC E                   ;
  DJNZ MVCONVEYOR_0       ;
  RET
; The conveyor is moving right.
MVCONVEYOR_1:
  LD A,(HL)               ; Copy the first pixel row of the conveyor tile to A
  RRC A                   ; Rotate it right twice
  RRC A                   ;
  INC H                   ; Point HL at the third pixel row of the conveyor
  INC H                   ; tile
  LD C,(HL)               ; Copy this pixel row to C
  RLC C                   ; Rotate it left twice
  RLC C                   ;
  JR MVCONVEYOR_0         ; Jump back to update the first and third pixel rows
                          ; of every conveyor tile

; Move and draw the Kong Beast in the current cavern
;
; Used by the routine at LOOP.
KONGBEAST:
  LD HL,23558             ; Flip the left-hand switch at (0,6) if Willy is
  CALL CHKSWITCH          ; touching it
  LD A,(EUGDIR)           ; Pick up the Kong Beast's status from EUGDIR
  CP 2                    ; Is the Kong Beast already dead?
  RET Z                   ; Return if so
  LD A,(29958)            ; Pick up the sixth pixel row of the left-hand switch
                          ; from the screen buffer at 28672
  CP 16                   ; Has the switch been flipped?
  JP Z,KONGBEAST_8        ; Jump if not
; The left-hand switch has been flipped. Deal with opening up the wall if that
; is still in progress.
  LD A,(ATTR_CACHE+32*11+17)            ; Pick up the attribute byte of the tile at (11,17)
                          ; in the buffer at 24064
  OR A                    ; Has the wall there been removed yet?
  JR Z,KONGBEAST_2        ; Jump if so
  LD HL,32625             ; Point HL at the bottom row of pixels of the wall
                          ; tile at (11,17) in the screen buffer at 28672
KONGBEAST_0:
  LD A,(HL)               ; Pick up a pixel row
  OR A                    ; Is it blank yet?
  JR NZ,KONGBEAST_1       ; Jump if not
  DEC H                   ; Point HL at the next pixel row up
  LD A,H                  ; Have we checked all 8 pixel rows yet?
  CP 119                  ;
  JR NZ,KONGBEAST_0       ; If not, jump back to check the next one
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  LD (ATTR_CACHE+32*11+17),A            ; Change the attributes at (11,17) and (12,17) in the
  LD (ATTR_CACHE+32*12+17),A            ; buffer at 24064 to match the background tile (the
                          ; wall there is now gone)
  LD A,114                ; Update the seventh byte of the guardian definition
  LD (HGUARD2+6),A        ; at HGUARD2 so that the guardian moves through the
                          ; opening in the wall
  JR KONGBEAST_2
KONGBEAST_1:
  LD (HL),0               ; Clear a pixel row of the wall tile at (11,17) in
                          ; the screen buffer at 28672
  LD L,145                ; Point HL at the opposite pixel row of the wall tile
  LD A,H                  ; one cell down at (12,17)
  XOR 7                   ;
  LD H,A                  ;
  LD (HL),0               ; Clear that pixel row as well
; Now check the right-hand switch.
KONGBEAST_2:
  LD HL,23570             ; Flip the right-hand switch at (0,18) if Willy is
  CALL CHKSWITCH          ; touching it (and it hasn't already been flipped)
  JR NZ,KONGBEAST_4       ; Jump if the switch was not flipped
  XOR A                   ; Initialise the Kong Beast's pixel y-coordinate at
  LD (EUGHGT),A           ; EUGHGT to 0
  INC A                   ; Update the Kong Beast's status at EUGDIR to 1: he
  LD (EUGDIR),A           ; is falling
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  LD (24143),A            ; Change the attributes of the floor beneath the Kong
  LD (24144),A            ; Beast in the buffer at 24064 to match that of the
                          ; background tile
  LD HL,28751             ; Point HL at (2,15) in the screen buffer at 28672
  LD B,8                  ; Clear the cells at (2,15) and (2,16), removing the
KONGBEAST_3:
  LD (HL),0               ; floor beneath the Kong Beast
  INC L                   ;
  LD (HL),0               ;
  DEC L                   ;
  INC H                   ;
  DJNZ KONGBEAST_3        ;
KONGBEAST_4:
  LD A,(EUGDIR)           ; Pick up the Kong Beast's status from EUGDIR
  OR A                    ; Is the Kong Beast still on the ledge?
  JR Z,KONGBEAST_8        ; Jump if so
; The Kong Beast is falling.
  LD A,(EUGHGT)           ; Pick up the Kong Beast's pixel y-coordinate from
                          ; EUGHGT
  CP 100                  ; Has he fallen into the portal yet?
  JR Z,KONGBEAST_7        ; Jump if so
  ADD A,4                 ; Add 4 to the Kong Beast's pixel y-coordinate at
  LD (EUGHGT),A           ; EUGHGT (moving him downwards)
  LD C,A                  ; Copy the pixel y-coordinate to C; this value
                          ; determines the pitch of the sound effect
  LD D,16                 ; This value determines the duration of the sound
                          ; effect
  LD A,(BORDER)           ; Pick up the border colour for the current cavern
                          ; from BORDER
KONGBEAST_5:
  OUT (PORT_SOUND),A      ; Make a falling sound effect
  XOR 24                  ;
  LD B,C                  ;
KONGBEAST_6:
  DJNZ KONGBEAST_6        ;
  DEC D                   ;
  JR NZ,KONGBEAST_5       ;
  LD A,C                  ; Copy the Kong Beast's pixel y-coordinate back into
                          ; A
  RLCA                    ; Point DE at the entry in the screen buffer address
  LD E,A                  ; lookup table at SBUFADDRS that corresponds to the
  LD D,131                ; Kong Beast's pixel y-coordinate
  LD A,(DE)               ; Point HL at the address of the Kong Beast's
  OR 15                   ; location in the screen buffer at 24576
  LD L,A                  ;
  INC DE                  ;
  LD A,(DE)               ;
  LD H,A                  ;
  LD D,129                ; Use bit 5 of the value of the game clock at CLOCK
  LD A,(CLOCK)            ; (which is toggled once every eight passes through
  AND 32                  ; the main loop) to point DE at the graphic data for
  OR 64                   ; the appropriate Kong Beast sprite
  LD E,A                  ;
  LD C,0                  ; Draw the Kong Beast to the screen buffer at 24576
  CALL DRWFIX             ;
  LD HL,33836             ; Add 100 to the score
  CALL INCSCORE_0         ;
  LD A,(EUGHGT)           ; Pick up the Kong Beast's pixel y-coordinate from
                          ; EUGHGT
  AND 120                 ; Point HL at the address of the Kong Beast's
  LD L,A                  ; location in the attribute buffer at 23552
  LD H,23                 ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD A,L                  ;
  OR 15                   ;
  LD L,A                  ;
  LD A,6                  ; The Kong Beast is drawn with yellow INK
  JP EUGENE_3             ; Set the attribute bytes for the Kong Beast
; The Kong Beast has fallen into the portal.
KONGBEAST_7:
  LD A,2                  ; Set the Kong Beast's status at EUGDIR to 2: he is
  LD (EUGDIR),A           ; dead
  RET
; The Kong Beast is still on the ledge.
KONGBEAST_8:
  LD A,(CLOCK)            ; Pick up the value of the game clock at CLOCK
  AND 32                  ; Use bit 5 of this value (which is toggled once
  LD E,A                  ; every eight passes through the main loop) to point
  LD D,129                ; DE at the graphic data for the appropriate Kong
                          ; Beast sprite
  LD HL,24591             ; Draw the Kong Beast at (0,15) in the screen buffer
  LD C,1                  ; at 24576
  CALL DRWFIX             ;
  JP NZ,KILLWILLY_0       ; Kill Willy if he collided with the Kong Beast
  LD A,68                 ; A=68 (INK 4: PAPER 0: BRIGHT 1)
  LD (23599),A            ; Set the attribute bytes for the Kong Beast in the
  LD (23600),A            ; buffer at 23552
  LD (23567),A            ;
  LD (23568),A            ;
  RET

; Flip a switch in a Kong Beast cavern if Willy is touching it
;
; Used by the routine at KONGBEAST. Returns with the zero flag set if Willy
; flips the switch.
;
; HL Address of the switch's location in the attribute buffer at 23552
CHKSWITCH:
  LD A,(LOCATION)         ; Pick up the LSB of the address of Willy's location
                          ; in the attribute buffer at 23552 from LOCATION
  INC A                   ; Is it equal to or one less than the LSB of the
  AND 254                 ; address of the switch's location?
  CP L                    ;
  RET NZ                  ; Return (with the zero flag reset) if not
  LD A,(32877)            ; Pick up the MSB of the address of Willy's location
                          ; in the attribute buffer at 23552 from 32877
  CP H                    ; Does it match the MSB of the address of the
                          ; switch's location?
  RET NZ                  ; Return (with the zero flag reset) if not
  LD A,(32869)            ; Pick up the sixth byte of the graphic data for the
                          ; switch tile from 32869
  LD H,117                ; Point HL at the sixth row of pixels of the switch
                          ; tile in the screen buffer at 28672
  CP (HL)                 ; Has the switch already been flipped?
  RET NZ                  ; Return (with the zero flag reset) if so
; Willy is flipping the switch.
  LD (HL),8               ; Update the sixth, seventh and eighth rows of pixels
  INC H                   ; of the switch tile in the screen buffer at 28672 to
  LD (HL),6               ; make it appear flipped
  INC H                   ;
  LD (HL),6               ;
  XOR A                   ; Set the zero flag: Willy has flipped the switch
  OR A                    ; This instruction is redundant
  RET

; Check and set the attribute bytes for Willy's sprite in the buffer at 23552
;
; Used by the routine at LOOP.
WILLYATTRS:
  LD HL,(LOCATION)        ; Pick up the address of Willy's location in the
                          ; attribute buffer at 23552 from LOCATION
  LD DE,31                ; Prepare DE for addition
  LD C,15                 ; Set C=15 for the top two rows of cells (to make the
                          ; routine at WILLYATTR force white INK)
  CALL WILLYATTR          ; Check and set the attribute byte for the top-left
                          ; cell
  INC HL                  ; Move HL to the next cell to the right
  CALL WILLYATTR          ; Check and set the attribute byte for the top-right
                          ; cell
  ADD HL,DE               ; Move HL down a row and back one cell to the left
  CALL WILLYATTR          ; Check and set the attribute byte for the mid-left
                          ; cell
  INC HL                  ; Move HL to the next cell to the right
  CALL WILLYATTR          ; Check and set the attribute byte for the mid-right
                          ; cell
  LD A,(PIXEL_Y)          ; Pick up Willy's pixel y-coordinate from PIXEL_Y
  LD C,A                  ; Copy it to C
  ADD HL,DE               ; Move HL down a row and back one cell to the left
  CALL WILLYATTR          ; Check and set the attribute byte for the
                          ; bottom-left cell
  INC HL                  ; Move HL to the next cell to the right
  CALL WILLYATTR          ; Check and set the attribute byte for the
                          ; bottom-right cell
  JR DRAWWILLY            ; Draw Willy to the screen buffer at 24576

; Check and set the attribute byte for a cell occupied by Willy's sprite
;
; Used by the routine at WILLYATTRS.
;
; C 15 or Willy's pixel y-coordinate
; HL Address of the cell in the attribute buffer at 23552
WILLYATTR:
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  CP (HL)                 ; Does this cell contain a background tile?
  JR NZ,WILLYATTR_0       ; Jump if not
  LD A,C                  ; Set the zero flag if we are going to retain the INK
  AND 15                  ; colour in this cell; this happens only if the cell
                          ; is in the bottom row and Willy's sprite is confined
                          ; to the top two rows
  JR Z,WILLYATTR_0        ; Jump if we are going to retain the current INK
                          ; colour in this cell
  LD A,(BACKGROUND)       ; Pick up the attribute byte of the background tile
                          ; for the current cavern from BACKGROUND
  OR 7                    ; Set bits 0-2, making the INK white
  LD (HL),A               ; Set the attribute byte for this cell in the buffer
                          ; at 23552
WILLYATTR_0:
  LD A,(NASTY1)           ; Pick up the attribute byte of the first nasty tile
                          ; for the current cavern from NASTY1
  CP (HL)                 ; Has Willy hit a nasty of the first kind?
  JP Z,KILLWILLY          ; Kill Willy if so
  LD A,(NASTY2)           ; Pick up the attribute byte of the second nasty tile
                          ; for the current cavern from NASTY2
  CP (HL)                 ; Has Willy hit a nasty of the second kind?
  JP Z,KILLWILLY          ; Kill Willy if so
  RET

; Draw Willy to the screen buffer at 24576
;
; Used by the routine at WILLYATTRS.
DRAWWILLY:
  LD A,(PIXEL_Y)          ; Pick up Willy's pixel y-coordinate from PIXEL_Y
  LD IXh,HIGH SBUFADDRS   ; Point IX at the entry in the screen buffer address
  LD IXl,A                ; lookup table at SBUFADDRS that corresponds to
                          ; Willy's y-coordinate
  LD A,(DMFLAGS)          ; Pick up Willy's direction and movement flags from
                          ; DMFLAGS
  AND 1                   ; Now E=0 if Willy is facing right, or 128 if he's
  RRCA                    ; facing left
  LD E,A                  ;
  LD A,(FRAME)            ; Pick up Willy's animation frame (0-3) from FRAME
  AND 3                   ; Point DE at the sprite graphic data for Willy's
  RRCA                    ; current animation frame (see MANDAT)
  RRCA                    ;
  RRCA                    ;
  OR E                    ;
  LD E,A                  ;
  LD D,HIGH MANDAT        ;
  LD B,16                 ; There are 16 rows of pixels to copy
  LD A,(LOCATION)         ; Pick up Willy's screen x-coordinate (0-31) from
  AND 31                  ; LOCATION
  LD C,A                  ; Copy it to C
DRAWWILLY_0:
  LD A,(IX+0)             ; Set HL to the address in the screen buffer at 24576
  LD H,(IX+1)             ; that corresponds to where we are going to draw the
  OR C                    ; next pixel row of the sprite graphic
  LD L,A                  ;
  LD A,(DE)               ; Pick up a sprite graphic byte
  OR (HL)                 ; Merge it with the background
  LD (HL),A               ; Save the resultant byte to the screen buffer
  INC HL                  ; Move HL along to the next cell to the right
  INC DE                  ; Point DE at the next sprite graphic byte
  LD A,(DE)               ; Pick it up in A
  OR (HL)                 ; Merge it with the background
  LD (HL),A               ; Save the resultant byte to the screen buffer
  INC IX                  ; Point IX at the next entry in the screen buffer
  INC IX                  ; address lookup table at SBUFADDRS
  INC DE                  ; Point DE at the next sprite graphic byte
  DJNZ DRAWWILLY_0        ; Jump back until all 16 rows of pixels have been
                          ; drawn
  RET

; Print a message
;
; Used by the routines at START, STARTGAME, LOOP, ENDGAM and NXSHEET.
;
; IX Address of the message
; C Length of the message
; DE Display file address
PMESS:
  LD A,(IX+0)             ; Collect a character from the message
  CALL PRINTCHAR          ; Print it
  INC IX                  ; Point IX at the next character in the message
  INC E                   ; Point DE at the next character cell (subtracting 8
  LD A,D                  ; from D compensates for the operations performed by
  SUB 8                   ; the routine at PRINTCHAR)
  LD D,A                  ;
  DEC C                   ; Have we printed the entire message yet?
  JR NZ,PMESS             ; If not, jump back to print the next character
  RET

; Print a single character
;
; Used by the routine at PMESS.
;
; A ASCII code of the character
; DE Display file address
PRINTCHAR:
  LD H,0                  ; Point HL at the bitmap for the character (in the
  LD L,A                  ; ROM
  ADD HL,HL               ;
  ADD HL,HL               ;
  ADD HL,HL               ;
  LD  A,C                 ; Preserve C
  LD  BC, FONT_LOCATION-32*8
  ADD HL, BC
  LD  C, A
  LD  B,8                 ; There are eight pixel rows in a character bitmap
; This entry point is used by the routine at DRAWITEMS to draw an item in the
; current cavern.
PRINTCHAR_0:
  LD A,(HL)               ; Copy the character bitmap to the screen (or item
  LD (DE),A               ; graphic to the screen buffer)
  INC HL                  ;
  INC D                   ;
  DJNZ PRINTCHAR_0        ;
  RET

; Play the theme tune (The Blue Danube)
;
; Used by the routine at START. Returns with the zero flag reset if ENTER or
; the fire button is pressed while the tune is being played.
;
; IY THEMETUNE (tune data)
PLAYTUNE:
  LD A,(IY+0)             ; Pick up the next byte of tune data from the table
                          ; at THEMETUNE
  CP 255                  ; Has the tune finished?
  RET Z                   ; Return (with the zero flag set) if so
  LD C,A                  ; Copy the first byte of data for this note (which
                          ; determines the duration) to C
  LD B,0                  ; Initialise B, which will be used as a delay counter
                          ; in the note-producing loop
  XOR A                   ; Set A=0 (for no apparent reasaon)
  LD D,(IY+1)             ; Pick up the second byte of data for this note
  LD A,D                  ; Copy it to A
  CALL PIANOKEY           ; Calculate the attribute file address for the
                          ; corresponding piano key
  LD (HL),80              ; Set the attribute byte for the piano key to 80 (INK
                          ; 0: PAPER 2: BRIGHT 1)
  LD E,(IY+2)             ; Pick up the third byte of data for this note
  LD A,E                  ; Copy it to A
  CALL PIANOKEY           ; Calculate the attribute file address for the
                          ; corresponding piano key
  LD (HL),40              ; Set the attribute byte for the piano key to 40 (INK
                          ; 0: PAPER 5: BRIGHT 0)
PLAYTUNE_0:
  OUT (PORT_SOUND),A      ; Produce a sound based on the frequency parameters
  DEC D                   ; in the second and third bytes of data for this note
  JR NZ,PLAYTUNE_1        ; (copied into D and E)
  LD D,(IY+1)             ;
  XOR SOUND_BIT           ;
PLAYTUNE_1:
  DEC E                   ;
  JR NZ,PLAYTUNE_2        ;
  LD E,(IY+2)             ;
  XOR SOUND_BIT           ;
PLAYTUNE_2:

IF NOT DEFINED SINCLAIR
  LD   L,4
TUNE_DELAY:
  DEC  L
  JR   NZ, TUNE_DELAY
ENDIF

  DJNZ PLAYTUNE_0         ;
  DEC C                   ;
  JR NZ,PLAYTUNE_0        ;
  CALL CHECKENTER         ; Check whether ENTER or the fire button is being
                          ; pressed
  RET NZ                  ; Return (with the zero flag reset) if it is
  LD A,(IY+1)             ; Pick up the second byte of data for this note
  CALL PIANOKEY           ; Calculate the attribute file address for the
                          ; corresponding piano key
  LD (HL),56              ; Set the attribute byte for the piano key back to 56
                          ; (INK 0: PAPER 7: BRIGHT 0)
  LD A,(IY+2)             ; Pick up the third byte of data for this note
  CALL PIANOKEY           ; Calculate the attribute file address for the
                          ; corresponding piano key
  LD (HL),56              ; Set the attribute byte for the piano key back to 56
                          ; (INK 0: PAPER 7: BRIGHT 0)
  INC IY                  ; Move IY along to the data for the next note in the
  INC IY                  ; tune
  INC IY                  ;
  JR PLAYTUNE             ; Jump back to play the next note

; Calculate the attribute file address for a piano key
;
; Used by the routine at PLAYTUNE. Returns with the attribute file address in
; HL.
;
; A Frequency parameter from the tune data table at THEMETUNE
PIANOKEY:
  SUB 8                   ; Compute the piano key index (K) based on the
  RRCA                    ; frequency parameter (F), and store it in bits 0-4
  RRCA                    ; of A: K=31-INT((F-8)/8)
  RRCA                    ;
  CPL                     ;
  OR 224                  ; A=224+K; this is the LSB
  LD L,A                  ; Set HL to the attribute file address for the piano
  LD H,89                 ; key
  RET

; Check whether ENTER or the fire button is being pressed
;
; Used by the routine at PLAYTUNE. Returns with the zero flag reset if ENTER or
; the fire button on the joystick is being pressed.
CHECKENTER:
  LD A,(KEMP)             ; Pick up the Kempston joystick indicator from KEMP
  OR A                    ; Is the joystick connected?
  JR Z,CHECKENTER_0       ; Jump if not
  IN A,(PORT_KEMPSTON)    ; Collect input from the joystick
  BIT 4,A                 ; Is the fire button being pressed?
  RET NZ                  ; Return (with the zero flag reset) if so
CHECKENTER_0:
  LD BC,PORT_HJKL         ; Read keys H-J-K-L-ENTER
  IN A,(C)                ;
  AND KEY_ENTER           ; Keep only bit 0 of the result (ENTER)
  CP KEY_ENTER            ; Reset the zero flag if ENTER is being pressed
  RET

; Source code remnants
;
; The source code here corresponds to the code at SEE37708.
SOURCE:

          DEFS MICROBEAST_START-$
          INCLUDE "microbeast.asm"


          DEFS FONT_LOCATION-$
          INCLUDE "carton.asm"

; '...MANIC MINER . . © BUG-BYTE ltd. 1983...'
;
; Used by the routine at START.
; At 9D00h
                    DEFS DATA_LOCATION-$

MESSINTRO:
  DEFM ".  .  .  .  .  .  .  .  .  .  . MANIC MINER . . "
  DEFM 127," BUG-BYTE ltd. 1983 . . By Matthew Smith . . . "
  DEFM "Q to P = Left & Right . . Bottom row = Jump . . "
  DEFM "A to G = Pause . . H to L = Tune On/Off . . . "
  DEFM "Guide Miner Willy through 20 lethal caverns"
  DEFM " .  .  .  .  .  .  .  ."

; Attribute data for the bottom two-thirds of the title screen
;
; Used by the routine at START. The graphic data for the middle third of the
; title screen is located at TITLESCR2.
LOWERATTRS:
  DEFB 22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22
  DEFB 22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22
  DEFB 23,23,23,23,23,23,23,23,23,23,23,23,23,23,23,23
  DEFB 23,23,23,23,23,16,16,16,16,16,16,16,16,23,23,23
  DEFB 23,23,23,23,23,23,23,23,23,23,23,23,23,23,23,23
  DEFB 23,23,23,23,23,22,22,22,22,22,22,22,22,23,23,23
  DEFB 19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19
  DEFB 19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19
  DEFB 23,23,23,23,23,23,16,16,16,16,16,16,22,22,22,22
  DEFB 22,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
  DEFB 16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
  DEFB 16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
  DEFB 56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
  DEFB 56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
  DEFB 56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
  DEFB 56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
  DEFB 48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48
  DEFB 48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48
  DEFB 87,87,87,87,87,87,87,87,87,87,103,103,103,103,103,103
  DEFB 103,103,103,103,103,103,103,103,103,103,103,103,103,103,103,103
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  DEFB 69,69,69,69,69,69,69,69,69,69,69,69,69,69,69,69
  DEFB 69,69,69,69,69,69,69,69,69,69,69,69,69,69,69,69
  DEFB 69,69,69,69,69,69,69,69,69,69,69,69,69,69,69,69
  DEFB 69,69,69,69,69,69,69,69,69,69,69,69,69,69,69,69
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Title screen graphic data
;
; Used by the routines at START and DRAWSHEET.
;
; The attributes for the top third of the title screen are located at CAVERN19
; (in the cavern data for The Final Barrier).
;
; The attributes for the middle third of the title screen are located at
; LOWERATTRS.
TITLESCR1:
  DEFB 5,0,0,0,0,0,224,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,1,129,129,128,0,0,0,0,0,0
  DEFB 59,0,8,99,0,0,224,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,255,255,0,0,0,0,7,255,224
  DEFB 3,0,0,84,0,255,0,0,7,224,0,0,15,223,220,0
  DEFB 0,0,0,0,0,0,0,255,255,0,34,34,34,8,224,16
  DEFB 0,255,159,148,243,0,63,192,31,248,3,252,0,0,0,0
  DEFB 0,36,66,66,36,68,0,0,0,0,119,119,119,0,255,0
  DEFB 0,0,0,138,0,7,255,252,7,224,63,255,224,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,74,0,0,0,1,255,255,128,0,0,224,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 1,0,1,185,128,48,255,255,7,192,255,255,15,255,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 1,36,0,18,64,18,64,18,64,1,34,64,17,65,2,16
  DEFB 36,16,33,0,0,16,0,0,0,0,0,0,0,0,0,33
  DEFB 7,0,0,0,0,0,248,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,3,66,66,192,0,0,0,0,0,0
  DEFB 22,0,0,0,0,0,200,0,0,0,0,0,1,240,0,0
  DEFB 0,0,0,0,0,0,0,255,255,0,0,0,0,4,0,32
  DEFB 5,0,0,85,0,255,0,0,127,254,0,0,15,239,120,0
  DEFB 0,0,0,0,0,0,0,129,129,0,119,119,119,9,16,16
  DEFB 0,127,15,85,244,0,127,224,31,248,7,254,0,0,0,0
  DEFB 0,36,66,68,34,66,0,0,0,0,119,119,119,49,255,140
  DEFB 0,0,0,82,0,1,255,254,7,224,127,255,128,0,0,15
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,82,0,112,0,3,255,255,192,0,14,240,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,0,3,16,0,48,127,255,1,240,255,252,1,255,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 1,36,48,33,81,48,36,49,32,32,66,16,52,33,3,18
  DEFB 2,19,64,0,0,66,0,0,0,0,0,0,0,0,0,49
  DEFB 3,0,0,0,0,0,208,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,7,36,36,224,0,0,0,0,0,0
  DEFB 29,0,0,0,0,0,180,0,0,0,0,0,7,248,0,0
  DEFB 0,0,0,0,0,0,0,129,129,0,0,0,0,4,24,32
  DEFB 5,0,0,148,0,208,0,0,127,254,0,0,31,255,151,128
  DEFB 0,101,118,86,134,86,0,129,129,0,119,119,119,9,80,16
  DEFB 0,62,7,85,192,0,255,224,31,248,7,255,0,0,0,0
  DEFB 0,34,66,68,36,66,0,0,0,0,119,119,119,50,255,76
  DEFB 0,0,0,81,0,0,127,254,0,0,127,254,0,0,0,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,6,82,48,127,0,3,255,255,192,0,254,248,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 15,0,0,0,0,0,63,255,7,224,255,240,0,63,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 2,19,21,2,67,96,33,52,80,49,33,80,55,97,80,40
  DEFB 18,3,70,0,0,36,0,0,0,0,0,0,0,0,0,39
  DEFB 1,0,0,0,0,0,224,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,15,24,24,240,0,0,0,0,0,0
  DEFB 31,0,0,0,0,0,246,0,0,0,0,0,15,252,0,0
  DEFB 0,0,0,0,0,0,0,129,129,0,0,0,0,4,0,32
  DEFB 23,0,0,162,0,248,0,0,127,254,0,0,31,255,239,92
  DEFB 112,133,151,84,104,103,0,129,129,0,255,255,255,63,255,252
  DEFB 0,20,2,84,192,1,255,240,31,248,15,255,128,0,0,0
  DEFB 0,66,68,34,36,34,0,0,0,0,119,119,119,52,255,44
  DEFB 0,0,0,149,0,0,31,255,0,0,255,248,0,0,15,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,15,81,248,127,240,7,255,255,224,15,254,248,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 15,0,0,0,0,0,30,127,3,240,255,128,0,3,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 33,48,84,48,103,40,145,32,52,81,144,36,49,84,97,32
  DEFB 52,81,144,0,0,131,0,0,0,0,0,0,0,0,0,115
  DEFB 6,0,0,0,0,0,228,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,31,24,24,248,0,0,0,0,0,0
  DEFB 5,0,7,129,192,48,200,0,0,0,0,0,30,59,176,0
  DEFB 0,0,0,0,0,0,0,129,129,0,0,0,0,4,0,32
  DEFB 29,0,0,170,0,192,0,0,63,252,0,0,14,127,238,222
  DEFB 248,102,102,102,102,102,0,129,129,0,255,255,255,127,255,254
  DEFB 0,0,0,146,128,1,255,240,15,240,15,255,128,0,0,0
  DEFB 0,66,36,66,66,68,0,0,0,0,119,119,119,63,255,252
  DEFB 0,0,0,165,0,0,7,255,3,192,255,224,0,0,63,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,127,137,252,127,255,7,255,255,224,255,254,252,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 63,0,0,0,0,0,0,31,1,128,254,0,0,0,193,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 116,17,87,145,81,33,2,70,25,18,2,73,18,6,116,33
  DEFB 52,97,33,0,0,33,0,0,0,0,0,0,0,0,0,67
  DEFB 11,0,0,0,0,0,208,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,63,36,36,252,0,0,0,0,0,0
  DEFB 3,0,2,195,160,0,208,0,0,0,0,0,29,215,216,0
  DEFB 0,0,0,0,0,0,0,129,129,0,0,0,0,4,0,32
  DEFB 31,0,0,170,0,128,1,128,63,252,1,128,15,191,238,222
  DEFB 248,102,102,102,102,102,0,129,129,0,119,119,119,255,255,255
  DEFB 0,0,0,138,0,3,255,248,15,240,31,255,192,0,0,0
  DEFB 0,36,66,36,36,36,0,0,0,0,119,119,119,48,255,12
  DEFB 0,0,0,169,0,0,1,254,31,248,127,128,0,0,255,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,1,255,170,252,255,255,199,255,255,227,255,255,254,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 255,0,0,0,0,0,0,15,15,192,240,0,0,0,62,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 248,16,47,70,33,113,21,70,49,38,21,66,19,21,3,36
  DEFB 52,81,81,0,0,81,0,0,0,0,0,0,0,0,0,36
  DEFB 5,0,0,0,0,0,180,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,127,66,66,254,0,0,0,0,0,0
  DEFB 6,0,1,83,192,0,184,0,0,0,0,0,11,239,232,0
  DEFB 0,0,0,0,0,0,0,129,129,0,0,0,0,0,0,32
  DEFB 10,0,0,170,0,0,7,128,63,252,1,224,7,223,207,111
  DEFB 120,102,102,102,102,102,0,255,255,0,119,119,119,255,255,255
  DEFB 0,0,0,170,0,3,255,248,15,240,31,255,192,0,0,0
  DEFB 0,34,66,68,34,66,0,0,0,0,119,119,119,48,60,12
  DEFB 0,0,0,170,0,0,0,124,127,254,62,0,0,15,255,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,15,255,170,254,255,255,207,255,255,243,255,255,254,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 255,0,0,0,0,0,0,7,3,240,224,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 1,32,49,32,51,32,49,32,2,16,66,16,18,64,16,66
  DEFB 64,16,66,0,0,130,0,0,0,0,0,0,0,0,0,64
  DEFB 42,0,0,0,0,0,248,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,255,129,129,255,0,0,0,0,0,0
  DEFB 3,0,0,163,0,0,100,0,0,0,0,0,7,223,236,0
  DEFB 0,0,0,0,0,0,0,255,255,0,0,0,0,4,0,32
  DEFB 7,0,0,162,0,0,31,192,63,252,3,248,3,143,135,191
  DEFB 240,102,102,102,102,102,0,255,255,0,119,119,119,255,255,255
  DEFB 0,0,0,170,0,7,255,252,15,240,63,255,224,0,0,0
  DEFB 126,166,246,166,246,166,0,0,0,0,119,119,119,48,0,12
  DEFB 0,0,0,138,0,0,0,24,255,255,24,0,0,255,255,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,63,255,74,255,255,255,207,255,255,243,255,255,255,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 255,0,0,0,0,0,0,1,1,192,128,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 252,189,254,188,253,190,203,223,235,207,205,239,207,191,254,205
  DEFB 188,206,189,0,0,219,0,0,0,0,0,0,0,0,0,189
TITLESCR2:
  DEFB 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
  DEFB 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,130,12,63,134,30,51,128,0,0,34,49,140,60,96
  DEFB 12,96,96,0,0,139,162,251,192,139,160,136,128,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,252,252,254,124,124,0,254,198,254,254
  DEFB 252,0,254,124,0,124,254,16,252,254,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 170,170,170,170,170,170,170,170,170,170,170,170,170,170,170,170
  DEFB 170,170,170,170,170,170,170,170,170,170,170,170,170,170,170,170
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,65,0,12,96,198,14,49,129,0,0,32,49,140,28,96
  DEFB 76,48,112,0,0,217,50,130,32,137,32,133,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,254,254,254,254,254,0,254,230,254,254
  DEFB 254,0,254,254,0,254,254,56,254,254,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 68,68,68,68,68,68,68,68,68,68,68,68,68,68,68,68
  DEFB 68,68,68,68,68,68,68,68,68,68,68,68,68,68,68,68
  DEFB 0,3,255,30,4,14,15,120,58,0,7,248,59,220,30,255
  DEFB 159,240,0,0,0,1,255,136,243,206,137,255,128,0,0,0
  DEFB 0,130,0,12,64,198,6,48,198,0,0,32,49,140,12,97
  DEFB 140,24,16,0,0,169,42,227,192,169,32,130,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,198,198,192,194,194,0,192,246,48,192
  DEFB 198,0,48,198,0,194,48,108,198,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17
  DEFB 17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17
  DEFB 0,6,7,60,14,7,6,48,198,0,8,56,113,142,12,97
  DEFB 140,56,0,0,0,2,4,20,138,36,202,0,0,0,0,0
  DEFB 0,140,0,30,225,239,2,120,56,0,0,112,123,222,4,255
  DEFB 158,14,32,0,0,137,38,130,128,169,32,130,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,254,254,240,248,248,0,240,246,48,240
  DEFB 254,0,48,198,0,248,48,198,254,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,9,139,108,14,7,134,49,131,0,16,44,113,143,12,96
  DEFB 76,24,0,0,0,1,196,34,243,196,170,96,0,0,0,0
  DEFB 0,112,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,7,192,0,0,139,162,250,96,83,190,250,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,252,252,240,62,62,0,240,222,48,240
  DEFB 252,0,48,198,0,62,48,198,252,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,9,147,204,27,6,198,51,128,0,16,44,177,141,140,98
  DEFB 12,24,0,0,0,0,36,62,162,132,154,32,0,0,0,0
  DEFB 255,7,255,255,255,255,255,255,255,255,255,255,255,255,255,255
  DEFB 255,240,31,240,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,192,216,192,134,134,0,192,222,48,192
  DEFB 216,0,48,198,0,134,48,254,216,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,6,35,140,19,6,102,51,0,0,19,38,177,140,204,126
  DEFB 15,240,0,0,0,255,196,34,154,110,137,192,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,192,204,254,254,254,0,254,206,48,254
  DEFB 204,0,48,254,0,254,48,254,204,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,67,12,49,134,54,51,0,0,12,39,49,140,108,98
  DEFB 12,192,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,192,198,254,124,124,0,254,198,48,254
  DEFB 198,0,48,124,0,124,48,198,198,48,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  DEFB 7,199,199,193,7,199,193,7,199,199,193,7,199,193,7,199
  DEFB 193,7,199,199,193,7,199,193,7,199,199,193,7,199,193,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; Central Cavern (teleport: 6)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
; At 0B000h
CAVERN0:
  DEFB 22,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,5,0,0,0,0         ;
  DEFB 5,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,68        ;
  DEFB 0,0,0,68,0,0,0,22       ;
  DEFB 22,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,2,2   ;
  DEFB 2,2,66,2,2,2,2,66       ;
  DEFB 66,66,66,66,66,66,66,22 ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,66,66,66,0,0,0,0     ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,22,22,22,0,68,0,0     ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,66,66,66,66,0,0,0    ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,66,66,22      ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,68,0,0,0        ;
  DEFB 0,0,0,0,22,22,22,2      ;
  DEFB 2,2,2,2,66,66,66,22     ;
  DEFB 22,0,0,0,0,66,66,66     ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,0,0,0,0     ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,22 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "         Central Cavern         " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 66,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 22,34,255,136,255,34,255,136,255 ; Wall
  DEFB 4,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 68,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 5,255,254,126,124,76,76,8,8 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30760              ; Location in the screen buffer at 28672: (9,8)
  DEFB 20                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (0,9)
  DEFW 23561              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (0,29)
  DEFW 23581              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (1,16)
  DEFW 23600              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (4,24)
  DEFW 23704              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (6,30)
  DEFW 23774              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,146,73,182,219,255,255 ; Graphic data
  DEFB 146,73,182,219,255,255,146,73  ;
  DEFB 182,219,255,255,146,73,182,219 ;
  DEFB 255,255,146,73,182,219,255,255 ;
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
  DEFW 26813              ; Location in the screen buffer at 24576: (13,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 252                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 70                 ; Horizontal guardian 1: y=7, initial x=8, 8<=x<=15,
  DEFW 23784              ; speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 232                ;
  DEFB 239                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next byte is copied to VGUARDS and indicates that there are no vertical
; guardians in this cavern.
  DEFB 255                ; Terminator
; The next two bytes are unused.
  DEFB 0,0                ; Unused
; The next 32 bytes define the swordfish graphic that appears in The Final
; Barrier when the game is completed.
SWORDFISH:
  DEFB 2,160,5,67,31,228,115,255    ; Swordfish graphic data
  DEFB 242,248,31,63,255,228,63,195 ;
  DEFB 0,0,1,0,57,252,111,2         ;
  DEFB 81,1,127,254,57,252,1,0      ;
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 31,32,57,224,25,224,15,32   ; Guardian graphic data
  DEFB 159,0,95,128,255,192,94,0   ;
  DEFB 159,192,31,128,14,0,31,0    ;
  DEFB 187,160,113,192,32,128,17,0 ;
  DEFB 7,196,14,124,6,124,35,196   ;
  DEFB 23,192,23,224,63,240,23,240 ;
  DEFB 23,240,39,224,3,128,3,128   ;
  DEFB 6,192,6,192,28,112,6,192    ;
  DEFB 1,242,3,158,1,158,0,242     ;
  DEFB 9,240,5,248,15,252,5,224    ;
  DEFB 9,252,1,248,0,224,0,224     ;
  DEFB 0,224,0,224,0,224,1,240     ;
  DEFB 0,125,0,231,0,103,0,61      ;
  DEFB 0,124,0,127,3,252,0,120     ;
  DEFB 0,124,0,127,0,56,0,56       ;
  DEFB 0,108,0,108,1,199,0,108     ;
  DEFB 190,0,231,0,230,0,188,0     ;
  DEFB 62,0,254,0,63,192,30,0      ;
  DEFB 62,0,254,0,28,0,28,0        ;
  DEFB 54,0,54,0,227,128,54,0      ;
  DEFB 79,128,121,192,121,128,79,0 ;
  DEFB 15,144,31,160,63,240,7,160  ;
  DEFB 63,144,31,128,7,0,7,0       ;
  DEFB 7,0,7,0,7,0,15,128          ;
  DEFB 35,224,62,112,62,96,35,196  ;
  DEFB 3,232,7,232,15,252,15,232   ;
  DEFB 15,232,7,228,1,192,1,192    ;
  DEFB 3,96,3,96,14,56,3,96        ;
  DEFB 4,248,7,156,7,152,4,240     ;
  DEFB 0,249,1,250,3,255,0,122     ;
  DEFB 3,249,1,248,0,112,0,248     ;
  DEFB 5,221,3,142,1,4,0,136       ;

; The Cold Room (teleport: 16)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN1:
  DEFB 22,8,8,8,8,8,8,8        ; Attributes
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,22,22,22,22,22    ;
  DEFB 22,22,22,22,22,22,22,22 ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,13,22       ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,22        ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,11,11,11      ;
  DEFB 75,8,8,8,8,8,8,22       ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,22        ;
  DEFB 22,75,75,75,75,75,75,75 ;
  DEFB 75,75,75,75,75,75,75,75 ;
  DEFB 75,75,75,75,8,8,8,8     ;
  DEFB 8,8,8,8,22,8,8,22       ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,75,75,75      ;
  DEFB 75,22,11,11,22,8,8,22   ;
  DEFB 22,75,11,11,11,11,11,8  ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,22,8,8,22,8,8,22      ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,22,11,11,22,8,8,22    ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,75,75,75,75,75,75,75  ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,22,11,11,22,8,8,22    ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,11,11,11,11,8     ;
  DEFB 8,22,11,11,22,8,8,22    ;
  DEFB 22,8,8,14,14,14,14,8    ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,22,11,11,22,8,8,22    ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,75,75       ;
  DEFB 75,75,8,8,8,8,8,8       ;
  DEFB 8,22,11,11,22,8,8,22    ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 11,11,11,11,8,8,8,8     ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,22        ;
  DEFB 22,8,8,8,8,8,8,8        ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,8         ;
  DEFB 8,8,8,8,8,8,8,22        ;
  DEFB 22,75,75,75,75,75,75,75 ;
  DEFB 75,75,75,75,75,75,75,75 ;
  DEFB 75,75,75,75,75,75,75,75 ;
  DEFB 75,75,75,75,75,75,75,22 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "          The Cold Room         " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 8,0,0,0,0,0,0,0,0  ; Background
  DEFB 75,255,255,219,110,197,64,0,0 ; Floor
  DEFB 11,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 22,34,255,136,255,34,255,136,255 ; Wall
  DEFB 14,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 12,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 13,255,254,94,108,76,76,8,8 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30819              ; Location in the screen buffer at 28672: (11,3)
  DEFB 4                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 11                 ; Item 1 at (1,7)
  DEFW 23591              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 12                 ; Item 2 at (1,24)
  DEFW 23608              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 13                 ; Item 3 at (7,26)
  DEFW 23802              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 14                 ; Item 4 at (9,3)
  DEFW 23843              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 11                 ; Item 5 at (12,19)
  DEFW 23955              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 83                 ; Attribute
  DEFB 255,255,146,73,146,73,146,73 ; Graphic data
  DEFB 146,73,146,73,146,73,146,73  ;
  DEFB 146,73,146,73,146,73,146,73  ;
  DEFB 146,73,146,73,146,73,255,255 ;
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
  DEFW 26813              ; Location in the screen buffer at 24576: (13,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 80,168,84,168,84,44,2,1 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 252                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 14                 ; Horizontal guardian 1: y=3, initial x=18, 1<=x<=18,
  DEFW 23666              ; speed=normal
  DEFB 96                 ;
  DEFB 7                  ;
  DEFB 97                 ;
  DEFB 114                ;
  DEFB 13                 ; Horizontal guardian 2: y=13, initial x=29,
  DEFW 23997              ; 12<=x<=29, speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 172                ;
  DEFB 189                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next byte is copied to VGUARDS and indicates that there are no vertical
; guardians in this cavern.
  DEFB 255                ; Terminator
; The next two bytes are unused.
  DEFB 0,0                ; Unused
; The next 32 bytes define the plinth graphic that appears on the Game Over
; screen.
PLINTH:
  DEFB 255,255,114,78,138,81,170,85 ; Plinth graphic data
  DEFB 74,82,18,72,34,68,42,84      ;
  DEFB 42,84,42,84,42,84,42,84      ;
  DEFB 42,84,42,84,42,84,42,84      ;
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 12,0,30,0,27,0,30,192       ; Guardian graphic data
  DEFB 57,0,50,0,58,0,61,0         ;
  DEFB 109,0,105,0,105,0,97,0      ;
  DEFB 113,0,190,0,8,0,30,0        ;
  DEFB 3,0,7,128,6,192,7,176       ;
  DEFB 14,64,12,128,15,128,13,192  ;
  DEFB 27,64,27,64,22,64,24,64     ;
  DEFB 28,64,47,128,5,64,15,128    ;
  DEFB 0,192,1,224,1,176,1,236     ;
  DEFB 3,144,3,32,3,160,3,208      ;
  DEFB 6,208,6,144,6,144,6,16      ;
  DEFB 7,16,11,232,2,80,7,224      ;
  DEFB 0,48,0,120,0,108,0,123      ;
  DEFB 0,228,0,200,0,232,0,244     ;
  DEFB 1,180,1,148,1,148,1,132     ;
  DEFB 1,196,2,248,0,84,0,248      ;
  DEFB 12,0,30,0,54,0,222,0        ;
  DEFB 39,0,19,0,23,0,47,0         ;
  DEFB 45,128,41,128,41,128,33,128 ;
  DEFB 35,128,31,64,42,0,31,0      ;
  DEFB 3,0,7,128,13,128,55,128     ;
  DEFB 9,192,4,192,5,192,11,192    ;
  DEFB 11,96,9,96,9,96,8,96        ;
  DEFB 8,224,23,208,10,64,7,224    ;
  DEFB 0,192,1,224,3,96,13,224     ;
  DEFB 2,112,1,48,1,240,3,176      ;
  DEFB 2,216,2,216,2,104,2,24      ;
  DEFB 2,56,1,244,2,160,1,240      ;
  DEFB 0,48,0,120,0,216,3,120      ;
  DEFB 0,156,0,76,0,92,0,188       ;
  DEFB 0,182,0,150,0,150,0,134     ;
  DEFB 0,142,0,125,0,16,0,120      ;

; The Menagerie (teleport: 26)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN2:
  DEFB 13,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,67,0,0,0,0,0        ;
  DEFB 0,0,3,0,0,0,0,0         ;
  DEFB 0,0,0,67,0,0,0,13       ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,67,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,69,69,69,69,5,5,5    ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,13        ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,69,69,69,69,69,69,0  ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,69,69,69,69,13    ;
  DEFB 13,3,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,3,0,0,0,0,2,2        ;
  DEFB 2,2,2,2,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,3,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,69,69,69,69,69,69,13  ;
  DEFB 13,67,0,0,0,0,0,0       ;
  DEFB 0,0,0,0,0,0,69,69       ;
  DEFB 69,69,69,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,0,0,0,0,69,69,69     ;
  DEFB 69,69,69,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,69,69,69      ;
  DEFB 69,69,69,69,69,69,69,13 ;
  DEFB 13,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,13        ;
  DEFB 13,69,69,69,69,69,69,69 ;
  DEFB 69,69,69,69,69,69,69,69 ;
  DEFB 69,69,69,69,69,69,69,69 ;
  DEFB 69,69,69,69,69,69,69,13 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "          The Menagerie         " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 69,255,255,102,153,102,153,255,0 ; Floor
  DEFB 5,255,255,102,153,66,24,234,0 ; Crumbling floor
  DEFB 13,129,195,165,153,153,165,195,129 ; Wall
  DEFB 2,240,170,240,102,102,0,0,0 ; Conveyor
  DEFB 6,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 67,16,214,56,214,56,68,198,40 ; Nasty 2
  DEFB 3,16,16,16,16,16,16,16,16 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30758              ; Location in the screen buffer at 28672: (9,6)
  DEFB 6                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (0,6)
  DEFW 23558              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (0,15)
  DEFW 23567              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (0,23)
  DEFW 23575              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (6,30)
  DEFW 23774              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (6,21)
  DEFW 23765              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,68,68,153,153,34,34 ; Graphic data
  DEFB 34,34,153,153,68,68,68,68   ;
  DEFB 153,153,34,34,34,34,153,153 ;
  DEFB 68,68,68,68,153,153,255,255 ;
  DEFW 23933              ; Location in the attribute buffer at 23552: (11,29)
  DEFW 26749              ; Location in the screen buffer at 24576: (11,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 68                 ; Horizontal guardian 1: y=13, initial x=19,
  DEFW 23987              ; 1<=x<=19, speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 161                ;
  DEFB 179                ;
  DEFB 67                 ; Horizontal guardian 2: y=3, initial x=16, 1<=x<=16,
  DEFW 23664              ; speed=normal
  DEFB 96                 ;
  DEFB 7                  ;
  DEFB 97                 ;
  DEFB 112                ;
  DEFB 66                 ; Horizontal guardian 3: y=3, initial x=18,
  DEFW 23666              ; 18<=x<=29, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 114                ;
  DEFB 125                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next byte is copied to VGUARDS and indicates that there are no vertical
; guardians in this cavern.
  DEFB 255                ; Terminator
; The next two bytes are unused.
  DEFB 0,0                ; Unused
; The next 32 bytes define the boot graphic that appears on the Game Over
; screen (see LOOPFT). It also appears at the bottom of the screen next to the
; remaining lives when cheat mode is activated (see LOOP_1).
BOOT:
  DEFB 42,192,53,64,63,192,9,0   ; Boot graphic data
  DEFB 9,0,31,128,16,128,16,128  ;
  DEFB 17,128,34,64,32,184,89,36 ;
  DEFB 68,66,68,2,68,2,255,255   ;
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 3,0,6,128,7,192,3,0          ; Guardian graphic data
  DEFB 1,128,0,192,190,192,227,128  ;
  DEFB 65,0,171,0,127,0,62,0        ;
  DEFB 8,0,8,0,8,0,20,0             ;
  DEFB 0,192,1,160,1,240,0,192      ;
  DEFB 0,96,0,48,47,176,56,224      ;
  DEFB 24,192,48,192,21,192,10,128  ;
  DEFB 21,0,2,0,5,0,0,0             ;
  DEFB 0,48,0,104,0,124,0,48        ;
  DEFB 0,24,0,12,11,236,14,56       ;
  DEFB 4,16,10,176,7,240,3,224      ;
  DEFB 0,128,1,64,0,0,0,0           ;
  DEFB 0,12,0,26,0,31,0,172         ;
  DEFB 1,86,0,171,3,91,3,134        ;
  DEFB 1,12,3,252,1,252,0,248       ;
  DEFB 0,32,0,32,0,80,0,0           ;
  DEFB 48,0,88,0,248,0,53,0         ;
  DEFB 106,128,213,0,218,192,97,192 ;
  DEFB 48,128,63,192,63,128,31,0    ;
  DEFB 4,0,4,0,10,0,0,0             ;
  DEFB 12,0,22,0,62,0,12,0          ;
  DEFB 24,0,48,0,55,208,28,112      ;
  DEFB 8,32,13,80,15,224,7,192      ;
  DEFB 1,0,2,128,0,0,0,0            ;
  DEFB 3,0,5,128,15,128,3,0         ;
  DEFB 6,0,12,0,13,244,7,28         ;
  DEFB 3,24,3,12,3,168,1,80         ;
  DEFB 0,168,0,64,0,160,0,0         ;
  DEFB 0,192,1,96,3,224,0,192       ;
  DEFB 1,128,3,0,3,125,1,199        ;
  DEFB 0,130,0,213,0,254,0,124      ;
  DEFB 0,16,0,16,0,16,0,40          ;

; Abandoned Uranium Workings (teleport: 126)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN3:
  DEFB 41,0,0,0,0,0,0,5        ; Attributes
  DEFB 0,0,0,0,0,0,41,41       ;
  DEFB 41,41,41,41,41,41,41,41 ;
  DEFB 41,41,41,41,41,41,41,41 ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,70,70,70,70,70    ;
  DEFB 70,0,0,0,0,0,0,41       ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,70,70,70,70,41    ;
  DEFB 41,70,0,0,0,0,0,70      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,70,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,70,70,0,0       ;
  DEFB 0,0,0,0,0,70,70,70      ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,6,6,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,0,0,0,0,0,0,70       ;
  DEFB 70,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,70,70,70,0,0,41     ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,70,70,70,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,3,3,3,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,70,41       ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,70,70,70,0      ;
  DEFB 0,0,0,0,0,0,70,70       ;
  DEFB 70,0,0,0,0,0,0,41       ;
  DEFB 41,0,0,0,0,0,70,70      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,5         ;
  DEFB 0,0,0,0,70,70,70,41     ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,70,70,0,0,0,0       ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,41        ;
  DEFB 41,70,70,70,70,70,70,70 ;
  DEFB 70,70,70,70,70,70,70,70 ;
  DEFB 70,70,70,70,70,70,70,70 ;
  DEFB 70,70,70,70,70,70,70,41 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "   Abandoned Uranium Workings   " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 70,255,255,219,110,197,64,0,0 ; Floor
  DEFB 6,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 41,34,255,136,255,34,255,136,255 ; Wall
  DEFB 3,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 4,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 5,16,16,16,84,56,214,56,84 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 1                  ; Direction and movement flags: facing left (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30785              ; Location in the screen buffer at 28672: (10,1)
  DEFB 3                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (0,1)
  DEFW 23553              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (1,12)
  DEFW 23596              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (1,25)
  DEFW 23609              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (6,16)
  DEFW 23760              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (6,30)
  DEFW 23774              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 34,34,17,17,136,136,68,68 ; Graphic data
  DEFB 34,34,17,17,136,136,68,68 ;
  DEFB 34,34,17,17,136,136,68,68 ;
  DEFB 34,34,17,17,136,136,68,68 ;
  DEFW 23613              ; Location in the attribute buffer at 23552: (1,29)
  DEFW 24637              ; Location in the screen buffer at 24576: (1,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 66                 ; Horizontal guardian 1: y=13, initial x=1, 1<=x<=10,
  DEFW 23969              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 161                ;
  DEFB 170                ;
  DEFB 68                 ; Horizontal guardian 2: y=13, initial x=7, 6<=x<=15,
  DEFW 23975              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 166                ;
  DEFB 175                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 7,0,11,128,19,192,19,192      ; Guardian graphic data
  DEFB 19,192,11,128,7,0,1,0         ;
  DEFB 7,0,5,0,7,0,7,128             ;
  DEFB 79,128,95,192,254,192,60,64   ;
  DEFB 1,192,2,224,5,208,5,208       ;
  DEFB 5,208,2,224,1,192,0,64        ;
  DEFB 1,192,1,64,1,192,1,224        ;
  DEFB 35,224,47,240,127,176,31,16   ;
  DEFB 0,112,0,232,1,228,1,228       ;
  DEFB 1,228,0,232,0,112,0,16        ;
  DEFB 0,112,0,80,0,112,0,248        ;
  DEFB 33,248,39,252,127,236,15,196  ;
  DEFB 0,28,0,54,0,99,0,99           ;
  DEFB 0,99,0,54,0,28,0,4            ;
  DEFB 0,28,0,20,0,28,0,30           ;
  DEFB 4,62,4,255,15,251,3,241       ;
  DEFB 56,0,108,0,198,0,198,0        ;
  DEFB 198,0,108,0,56,0,32,0         ;
  DEFB 56,0,40,0,56,0,120,0          ;
  DEFB 124,32,255,32,223,240,143,192 ;
  DEFB 14,0,23,0,39,128,39,128       ;
  DEFB 39,128,23,0,14,0,8,0          ;
  DEFB 14,0,10,0,14,0,31,0           ;
  DEFB 31,132,63,228,55,254,35,240   ;
  DEFB 3,128,7,64,11,160,11,160      ;
  DEFB 11,160,7,64,3,128,2,0         ;
  DEFB 3,128,2,128,3,128,7,128       ;
  DEFB 7,196,15,244,13,254,8,248     ;
  DEFB 0,224,1,208,3,200,3,200       ;
  DEFB 3,200,1,208,0,224,0,128       ;
  DEFB 0,224,0,160,0,224,1,224       ;
  DEFB 1,242,3,250,3,127,2,60        ;

; Eugene's Lair (teleport: 36)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN4:
  DEFB 46,16,16,16,16,16,16,16 ; Attributes
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,19,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 22,16,16,16,16,16,16,46 ;
  DEFB 46,21,21,21,21,21,21,21 ;
  DEFB 21,21,21,21,21,21,16,16 ;
  DEFB 16,16,20,20,20,20,21,21 ;
  DEFB 21,21,21,21,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,21,21,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,22,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,86,86,86,86,86,86 ;
  DEFB 86,86,86,86,16,16,16,46 ;
  DEFB 46,16,16,16,21,21,21,21 ;
  DEFB 21,21,21,21,21,21,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,20,20,21,21,21,21,21 ;
  DEFB 21,21,21,21,21,21,16,16 ;
  DEFB 16,16,21,21,21,21,21,21 ;
  DEFB 21,16,16,16,16,16,21,46 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 46,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,21,21,16,16,16,16,16 ;
  DEFB 46,16,16,16,16,16,46,16 ;
  DEFB 16,46,16,16,16,16,16,16 ;
  DEFB 16,16,16,16,16,16,16,46 ;
  DEFB 46,16,16,16,16,22,16,16 ;
  DEFB 46,16,16,16,16,16,46,16 ;
  DEFB 16,46,46,46,46,46,46,46 ;
  DEFB 22,22,16,16,16,16,16,46 ;
  DEFB 46,21,21,21,21,21,21,21 ;
  DEFB 46,46,46,46,46,46,46,46 ;
  DEFB 46,46,46,46,46,46,46,46 ;
  DEFB 21,21,21,21,21,21,21,46 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "         Eugene's Lair          " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 16,0,0,0,0,0,0,0,0 ; Background
  DEFB 21,255,255,219,110,197,64,0,0 ; Floor
  DEFB 20,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 46,34,255,136,255,34,255,136,255 ; Wall
  DEFB 86,252,102,252,102,0,0,0,0 ; Conveyor
  DEFB 22,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 19,126,60,28,24,24,8,8,8 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 48                 ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23649              ; Location in the attribute buffer at 23552: (3,1)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30738              ; Location in the screen buffer at 28672: (8,18)
  DEFB 10                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 1                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 19                 ; Item 1 at (1,30)
  DEFW 23614              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 20                 ; Item 2 at (6,10)
  DEFW 23754              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 21                 ; Item 3 at (7,29)
  DEFW 23805              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 22                 ; Item 4 at (12,7)
  DEFW 23943              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 19                 ; Item 5 at (12,9)
  DEFW 23945              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 87                 ; Attribute
  DEFB 255,255,170,170,170,170,170,170 ; Graphic data
  DEFB 170,170,170,170,170,170,170,170 ;
  DEFB 170,170,170,170,170,170,170,170 ;
  DEFB 170,170,170,170,170,170,255,255 ;
  DEFW 23983              ; Location in the attribute buffer at 23552: (13,15)
  DEFW 26799              ; Location in the screen buffer at 24576: (13,15)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 31,35,71,255,143,142,140,248 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 22                 ; Horizontal guardian 1: y=3, initial x=12, 1<=x<=12,
  DEFW 23660              ; speed=normal
  DEFB 96                 ;
  DEFB 7                  ;
  DEFB 97                 ;
  DEFB 108                ;
  DEFB 16                 ; Horizontal guardian 2: y=7, initial x=4, 4<=x<=12,
  DEFW 23780              ; speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 228                ;
  DEFB 236                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT and specify Eugene's
; initial direction and pixel y-coordinate.
  DEFB 0                  ; Initial direction (down)
  DEFB 0                  ; Initial pixel y-coordinate
; The next three bytes are unused.
  DEFB 0,0,0              ; Unused
; The next 32 bytes define the Eugene graphic.
EUGENEG:
  DEFB 3,192,15,240,31,248,31,248     ; Eugene graphic data
  DEFB 49,140,14,112,111,246,174,117  ;
  DEFB 177,141,159,249,155,217,140,49 ;
  DEFB 71,226,2,64,2,64,14,112        ;
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 192,0,192,0,192,0,192,0       ; Guardian graphic data
  DEFB 192,0,192,0,192,0,223,192     ;
  DEFB 223,192,255,192,31,192,15,128 ;
  DEFB 119,128,255,0,223,0,223,0     ;
  DEFB 48,0,48,0,48,0,48,0           ;
  DEFB 48,32,48,192,51,0,52,0        ;
  DEFB 55,240,63,240,7,240,3,224     ;
  DEFB 29,224,63,192,55,192,55,192   ;
  DEFB 12,0,12,0,12,32,12,64         ;
  DEFB 12,64,12,128,12,128,13,0      ;
  DEFB 13,252,15,252,1,252,0,248     ;
  DEFB 7,120,15,240,13,240,13,240    ;
  DEFB 3,0,3,0,3,0,3,0               ;
  DEFB 3,2,3,12,3,48,3,64            ;
  DEFB 3,127,3,255,0,127,0,62        ;
  DEFB 1,222,3,252,3,124,3,124       ;
  DEFB 0,192,0,192,0,192,0,192       ;
  DEFB 64,192,48,192,12,192,2,192    ;
  DEFB 254,192,255,192,254,0,124,0   ;
  DEFB 123,128,63,192,62,192,62,192  ;
  DEFB 0,48,0,48,4,48,2,48           ;
  DEFB 2,48,1,48,1,48,0,176          ;
  DEFB 63,176,63,240,63,128,31,0     ;
  DEFB 30,224,15,240,15,176,15,176   ;
  DEFB 0,12,0,12,0,12,0,12           ;
  DEFB 4,12,3,12,0,204,0,44          ;
  DEFB 15,236,15,252,15,224,7,192    ;
  DEFB 7,184,3,252,3,236,3,236       ;
  DEFB 0,3,0,3,0,3,0,3               ;
  DEFB 0,3,0,3,0,3,3,251             ;
  DEFB 3,251,3,255,3,248,1,240       ;
  DEFB 1,238,0,255,0,251,0,251       ;

; Processing Plant (teleport: 136)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN5:
  DEFB 22,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,6,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 68,68,68,0,0,0,0,68     ;
  DEFB 68,0,0,0,0,68,68,68     ;
  DEFB 68,68,0,0,0,0,0,22      ;
  DEFB 22,0,0,68,68,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,68,68,68,22     ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,68        ;
  DEFB 68,68,68,68,0,0,0,22    ;
  DEFB 22,68,68,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,68       ;
  DEFB 68,68,68,68,68,68,68,68 ;
  DEFB 22,68,68,68,68,68,68,68 ;
  DEFB 68,68,0,0,0,0,0,22      ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,6,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,67,0,0,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,68,68,68,22     ;
  DEFB 22,0,0,5,5,5,5,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,68,68       ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,68,68,68,68,68,68,68 ;
  DEFB 68,68,68,68,68,68,68,68 ;
  DEFB 68,68,68,68,68,68,68,68 ;
  DEFB 68,68,68,68,68,68,68,22 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "       Processing Plant         " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 68,255,255,153,153,255,153,102,0 ; Floor
  DEFB 4,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 22,255,153,255,102,255,153,255,102 ; Wall
  DEFB 5,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 67,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 6,60,24,189,231,231,189,24,60 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 48                 ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 3                  ; Animation frame (see FRAME)
  DEFB 1                  ; Direction and movement flags: facing left (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23663              ; Location in the attribute buffer at 23552: (3,15)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30883              ; Location in the screen buffer at 28672: (13,3)
  DEFB 4                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (6,15)
  DEFW 23759              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (6,17)
  DEFW 23761              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (7,30)
  DEFW 23806              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (10,1)
  DEFW 23873              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (11,13)
  DEFW 23917              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,129,129,191,253,191,253 ; Graphic data
  DEFB 176,13,176,13,176,13,240,15     ;
  DEFB 240,15,176,13,176,13,176,13     ;
  DEFB 191,253,191,253,129,129,255,255 ;
  DEFW 23581              ; Location in the attribute buffer at 23552: (0,29)
  DEFW 24605              ; Location in the screen buffer at 24576: (0,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 70                 ; Horizontal guardian 1: y=8, initial x=6, 6<=x<=13,
  DEFW 23814              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 6                  ;
  DEFB 13                 ;
  DEFB 67                 ; Horizontal guardian 2: y=8, initial x=14,
  DEFW 23822              ; 14<=x<=21, speed=normal
  DEFB 104                ;
  DEFB 1                  ;
  DEFB 14                 ;
  DEFB 21                 ;
  DEFB 69                 ; Horizontal guardian 3: y=13, initial x=8, 8<=x<=20,
  DEFW 23976              ; speed=normal
  DEFB 104                ;
  DEFB 2                  ;
  DEFB 168                ;
  DEFB 180                ;
  DEFB 6                  ; Horizontal guardian 4: y=13, initial x=24,
  DEFW 23992              ; 24<=x<=29, speed=normal
  DEFB 104                ;
  DEFB 3                  ;
  DEFB 184                ;
  DEFB 189                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 31,0,127,192,115,224,243,128 ; Guardian graphic data
  DEFB 254,0,248,0,254,0,255,128    ;
  DEFB 127,224,127,192,31,0,10,0    ;
  DEFB 10,0,10,0,10,0,31,0          ;
  DEFB 7,192,31,240,30,112,62,120   ;
  DEFB 63,248,62,0,63,248,63,248    ;
  DEFB 31,240,31,240,7,192,2,128    ;
  DEFB 2,128,7,192,0,0,0,0          ;
  DEFB 1,240,7,252,7,62,15,56       ;
  DEFB 15,224,15,128,15,224,15,248  ;
  DEFB 7,254,7,252,1,240,1,240      ;
  DEFB 0,0,0,0,0,0,0,0              ;
  DEFB 0,124,1,207,1,206,3,252      ;
  DEFB 3,240,3,224,3,240,3,252      ;
  DEFB 1,254,1,255,0,124,0,40       ;
  DEFB 0,40,0,124,0,0,0,0           ;
  DEFB 62,0,243,128,115,128,63,192  ;
  DEFB 15,192,7,192,15,192,63,192   ;
  DEFB 127,128,255,128,62,0,20,0    ;
  DEFB 20,0,62,0,0,0,0,0            ;
  DEFB 15,128,63,224,124,224,28,240 ;
  DEFB 7,240,1,240,7,240,31,240     ;
  DEFB 127,224,63,224,15,128,15,128 ;
  DEFB 0,0,0,0,0,0,0,0              ;
  DEFB 3,224,15,248,14,120,30,124   ;
  DEFB 31,252,0,124,31,252,31,252   ;
  DEFB 15,248,15,248,3,224,1,64     ;
  DEFB 1,64,3,224,0,0,0,0           ;
  DEFB 0,248,3,254,7,206,1,207      ;
  DEFB 0,127,0,31,0,127,1,255       ;
  DEFB 7,254,3,254,0,248,0,80       ;
  DEFB 0,80,0,80,0,80,0,248         ;

; The Vat (teleport: 236)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN6:
  DEFB 77,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,0,0,0,77,77       ;
  DEFB 77,77,77,77,77,77,77,77 ;
  DEFB 77,77,77,77,77,77,77,77 ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,70        ;
  DEFB 70,77,2,2,2,2,2,2       ;
  DEFB 2,2,2,2,2,2,0,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,77,2,2,2,2,2,2        ;
  DEFB 2,2,2,2,2,2,2,77        ;
  DEFB 77,0,0,0,0,0,0,4        ;
  DEFB 4,4,4,4,0,0,70,70       ;
  DEFB 70,77,2,2,2,2,2,2       ;
  DEFB 2,2,2,2,22,2,2,77       ;
  DEFB 77,70,70,70,0,0,0,0     ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,77,2,2,0,2,2,2        ;
  DEFB 2,2,2,2,2,2,2,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,77,2,2,2,2,2,2        ;
  DEFB 2,2,2,0,2,2,2,77        ;
  DEFB 77,70,0,0,0,0,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,77,2,2,2,2,2,22       ;
  DEFB 2,2,2,2,2,2,2,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,70,70       ;
  DEFB 70,77,2,2,2,2,2,2       ;
  DEFB 2,2,2,2,2,2,2,77        ;
  DEFB 77,70,70,70,70,70,70,70 ;
  DEFB 70,70,70,70,0,0,0,0     ;
  DEFB 0,77,2,0,2,2,2,2        ;
  DEFB 2,2,2,2,22,2,2,77       ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,77,2,2,2,2,2,2        ;
  DEFB 2,2,2,2,2,2,0,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,77,77       ;
  DEFB 77,77,2,2,2,2,2,22      ;
  DEFB 2,2,2,2,2,2,2,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,70,70,70,0,0,77,0     ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,77        ;
  DEFB 77,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,77,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,77        ;
  DEFB 77,70,70,70,70,70,70,70 ;
  DEFB 70,70,70,70,70,70,77,77 ;
  DEFB 77,77,77,77,77,77,77,77 ;
  DEFB 77,77,77,77,77,77,77,77 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "            The Vat             " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 70,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,170,85,170,85,170,85,170 ; Crumbling floor
  DEFB 77,34,255,136,255,34,255,136,255 ; Wall
  DEFB 4,244,102,244,0,0,0,0,0 ; Conveyor
  DEFB 21,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 22,165,66,60,219,60,126,165,36 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 28839              ; Location in the screen buffer at 28672: (5,7)
  DEFB 5                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 4                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 19                 ; Item 1 at (3,30)
  DEFW 23678              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 20                 ; Item 2 at (6,20)
  DEFW 23764              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 21                 ; Item 3 at (7,27)
  DEFW 23803              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 22                 ; Item 4 at (10,19)
  DEFW 23891              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 19                 ; Item 5 at (11,30)
  DEFW 23934              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 11                 ; Attribute
  DEFB 255,255,129,129,129,129,129,129 ; Graphic data
  DEFB 129,129,129,129,129,129,255,255 ;
  DEFB 255,255,129,129,129,129,129,129 ;
  DEFB 129,129,129,129,129,129,255,255 ;
  DEFW 23983              ; Location in the attribute buffer at 23552: (13,15)
  DEFW 26799              ; Location in the screen buffer at 24576: (13,15)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 69                 ; Horizontal guardian 1: y=1, initial x=15,
  DEFW 23599              ; 15<=x<=29, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 47                 ;
  DEFB 61                 ;
  DEFB 67                 ; Horizontal guardian 2: y=8, initial x=10, 2<=x<=10,
  DEFW 23818              ; speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 2                  ;
  DEFB 10                 ;
  DEFB 6                  ; Horizontal guardian 3: y=13, initial x=17,
  DEFW 23985              ; 17<=x<=29, speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 177                ;
  DEFB 189                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 24,0,28,0,10,128,15,128   ; Guardian graphic data
  DEFB 12,0,28,0,30,0,29,0       ;
  DEFB 60,0,62,0,62,0,110,0      ;
  DEFB 68,0,66,0,129,0,0,0       ;
  DEFB 0,0,0,0,6,0,7,0           ;
  DEFB 2,160,3,224,3,128,7,0     ;
  DEFB 7,128,7,64,15,0,15,128    ;
  DEFB 15,128,27,128,51,0,64,192 ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 1,128,1,192,0,168,0,248   ;
  DEFB 0,224,1,192,1,224,1,208   ;
  DEFB 3,192,3,224,7,224,62,248  ;
  DEFB 0,0,0,0,0,96,0,112        ;
  DEFB 0,42,0,62,0,56,0,112      ;
  DEFB 0,120,0,116,0,240,0,248   ;
  DEFB 1,248,1,176,3,12,4,0      ;
  DEFB 0,0,0,0,6,0,14,0          ;
  DEFB 84,0,124,0,28,0,14,0      ;
  DEFB 30,0,46,0,15,0,31,0       ;
  DEFB 31,128,13,128,48,192,0,32 ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 1,128,3,128,21,0,31,0     ;
  DEFB 7,0,3,128,7,128,11,128    ;
  DEFB 3,192,7,192,7,224,31,124  ;
  DEFB 0,0,0,0,0,96,0,224        ;
  DEFB 5,64,7,192,1,192,0,224    ;
  DEFB 1,224,2,224,0,240,1,240   ;
  DEFB 1,240,1,216,0,204,3,2     ;
  DEFB 0,24,0,56,1,80,1,240      ;
  DEFB 0,48,0,56,0,120,0,184     ;
  DEFB 0,60,0,124,0,124,0,118    ;
  DEFB 0,34,0,66,0,129,0,0       ;

; Miner Willy meets the Kong Beast (teleport: 1236)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN7:
  DEFB 114,0,5,0,0,0,6,0        ; Attributes
  DEFB 0,0,5,0,0,0,0,0          ;
  DEFB 0,114,6,0,114,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,114,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,66         ;
  DEFB 66,114,0,0,0,0,0,0       ;
  DEFB 0,0,0,0,0,66,66,114      ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,66,66,66,0,0,0,0     ;
  DEFB 0,66,66,66,66,66,66,0    ;
  DEFB 0,114,66,66,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,0,66,66,66     ;
  DEFB 66,0,0,0,0,0,66,114      ;
  DEFB 114,0,66,66,66,0,0,0     ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,66,0,0,0,114       ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 66,66,66,0,0,0,0,0       ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,66,66,66,66,66,0   ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,66,0,0,0,0,0,0       ;
  DEFB 0,0,0,0,66,66,66,0       ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,66,66,66,66,114    ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,66,66,0,0,0,0,0        ;
  DEFB 0,114,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,66,66,0,0      ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,114,0,0,0,0,66,66      ;
  DEFB 66,66,66,0,0,0,0,114     ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,68,68,68,114,0     ;
  DEFB 0,114,66,66,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,114,0        ;
  DEFB 0,114,0,0,0,0,0,4        ;
  DEFB 0,0,0,0,0,0,0,114        ;
  DEFB 114,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66  ;
  DEFB 66,66,66,66,66,66,66,66  ;
  DEFB 66,66,66,66,66,66,66,114 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "Miner Willy meets the Kong Beast" ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 66,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 114,34,255,136,255,34,255,136,255 ; Wall
  DEFB 68,240,102,240,170,0,0,0,0 ; Conveyor
  DEFB 4,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2
  DEFB 6,255,129,129,66,60,16,96,96 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30891              ; Location in the screen buffer at 28672: (13,11)
  DEFB 3                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (2,13)
  DEFW 23629              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (6,14)
  DEFW 23758              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (8,2)
  DEFW 23810              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (13,29)
  DEFW 23997              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255,255,255,255,255 ; Item 5 (unused)
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,128,1,192,3,160,5     ; Graphic data
  DEFB 144,9,200,19,164,37,146,73    ;
  DEFB 201,147,164,37,146,73,201,147 ;
  DEFB 164,37,201,147,146,73,255,255 ;
  DEFW 23983              ; Location in the attribute buffer at 23552: (13,15)
  DEFW 26799              ; Location in the screen buffer at 24576: (13,15)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 128,192,236,114,40,84,138,135 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 68                 ; Horizontal guardian 1: y=13, initial x=9, 1<=x<=9,
  DEFW 23977              ; speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 161                ;
  DEFB 169                ;
  DEFB 195                ; Horizontal guardian 2: y=11, initial x=11,
  DEFW 23915              ; 11<=x<=15, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 107                ;
  DEFB 111                ;
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 5                  ; Horizontal guardian 4: y=7, initial x=18,
  DEFW 23794              ; 18<=x<=21, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 242                ;
  DEFB 245                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT; the first byte specifies
; the Kong Beast's initial status, but the second byte is not used.
  DEFB 0                  ; Initial status (on the ledge)
  DEFB 0                  ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 19,200,29,184,15,240,6,96       ; Guardian graphic data
  DEFB 5,160,2,64,7,224,15,240         ;
  DEFB 31,248,51,204,99,198,70,98      ;
  DEFB 44,52,6,96,2,64,14,112          ;
  DEFB 11,208,13,176,15,240,6,96       ;
  DEFB 5,160,2,64,3,192,31,248         ;
  DEFB 127,254,231,231,131,193,199,227 ;
  DEFB 6,96,12,48,8,16,56,28           ;
  DEFB 28,56,6,96,12,48,102,102        ;
  DEFB 35,196,103,230,55,236,31,248    ;
  DEFB 15,240,7,224,2,64,5,160         ;
  DEFB 6,96,15,240,13,176,11,208       ;
  DEFB 112,14,24,24,12,48,6,96         ;
  DEFB 99,198,39,228,103,230,55,236    ;
  DEFB 31,248,15,240,2,64,5,160        ;
  DEFB 22,104,15,240,13,176,3,192      ;
  DEFB 8,0,5,0,8,128,37,0              ;
  DEFB 72,128,33,0,76,0,51,0           ;
  DEFB 68,128,68,128,136,64,132,64     ;
  DEFB 72,128,72,128,51,0,12,0         ;
  DEFB 2,0,17,32,10,64,17,32           ;
  DEFB 10,64,16,32,3,0,12,192          ;
  DEFB 16,32,16,96,34,144,37,16        ;
  DEFB 24,32,16,32,12,192,3,0          ;
  DEFB 0,64,2,32,4,72,2,36             ;
  DEFB 4,72,2,4,0,200,3,48             ;
  DEFB 4,8,4,8,11,68,8,180             ;
  DEFB 4,8,4,8,3,48,0,192              ;
  DEFB 0,68,1,34,2,68,1,34             ;
  DEFB 2,68,1,2,2,48,0,204             ;
  DEFB 1,66,1,34,2,17,2,33             ;
  DEFB 1,18,1,10,0,204,0,48            ;

; Wacky Amoebatrons (teleport: 46)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN8:
  DEFB 22,0,0,22,0,0,0,0  ; Attributes
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,6,6,6,6,0,0,6   ;
  DEFB 6,6,0,0,6,6,6,6    ;
  DEFB 6,6,6,6,0,0,6,6    ;
  DEFB 6,0,0,6,6,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,6,6,22   ;
  DEFB 22,0,0,6,6,0,0,6   ;
  DEFB 6,6,0,0,4,4,4,4    ;
  DEFB 4,4,4,4,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,6,6    ;
  DEFB 6,0,0,6,6,0,0,22   ;
  DEFB 22,6,6,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,0,0,6,6,0,0,6   ;
  DEFB 6,6,0,0,6,6,6,6    ;
  DEFB 6,6,6,6,0,0,6,6    ;
  DEFB 6,0,0,6,6,0,0,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,6,6,22   ;
  DEFB 22,0,0,0,0,0,0,0   ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22   ;
  DEFB 22,6,6,6,6,6,6,6   ;
  DEFB 6,6,6,6,6,6,6,6    ;
  DEFB 6,6,6,6,6,6,6,6    ;
  DEFB 6,6,6,6,6,6,6,22   ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "        Wacky Amoebatrons       " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 6,255,255,219,110,197,64,0,0 ; Floor
  DEFB 66,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 22,90,90,90,90,90,90,90,90 ; Wall
  DEFB 4,240,102,240,102,0,0,0,0 ; Conveyor
  DEFB 68,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23969              ; Location in the attribute buffer at 23552: (13,1)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30732              ; Location in the screen buffer at 28672: (8,12)
  DEFB 8                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 1                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (1,16)
  DEFW 23600              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255,255,255,255,255 ; Item 2 (unused)
  DEFB 0,255,255,255,255  ; Item 3 (unused)
  DEFB 0,255,255,255,255  ; Item 4 (unused)
  DEFB 0,255,255,255,255  ; Item 5 (unused)
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,128,1,129,129,130,65 ; Graphic data
  DEFB 132,33,136,17,144,9,161,133  ;
  DEFB 161,133,144,9,136,17,132,33  ;
  DEFB 130,65,129,129,128,1,255,255 ;
  DEFW 23553              ; Location in the attribute buffer at 23552: (0,1)
  DEFW 24577              ; Location in the screen buffer at 24576: (0,1)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 68                 ; Horizontal guardian 1: y=3, initial x=12,
  DEFW 23660              ; 12<=x<=18, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 108                ;
  DEFB 114                ;
  DEFB 133                ; Horizontal guardian 2: y=10, initial x=16,
  DEFW 23888              ; 12<=x<=18, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 76                 ;
  DEFB 82                 ;
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 67                 ; Vertical guardian 1: x=5, initial y=8, 5<=y<100,
  DEFB 0                  ; initial y-increment=1
  DEFB 8                  ;
  DEFB 5                  ;
  DEFB 1                  ;
  DEFB 5                  ;
  DEFB 100                ;
  DEFB 4                  ; Vertical guardian 2: x=10, initial y=8, 5<=y<100,
  DEFB 1                  ; initial y-increment=2
  DEFB 8                  ;
  DEFB 10                 ;
  DEFB 2                  ;
  DEFB 5                  ;
  DEFB 100                ;
  DEFB 5                  ; Vertical guardian 3: x=20, initial y=8, 5<=y<100,
  DEFB 2                  ; initial y-increment=1
  DEFB 8                  ;
  DEFB 20                 ;
  DEFB 1                  ;
  DEFB 5                  ;
  DEFB 100                ;
  DEFB 66                 ; Vertical guardian 4: x=25, initial y=8, 5<=y<100,
  DEFB 3                  ; initial y-increment=2
  DEFB 8                  ;
  DEFB 25                 ;
  DEFB 2                  ;
  DEFB 5                  ;
  DEFB 100                ;
  DEFB 255                ; Terminator
; The next 6 bytes are unused.
  DEFB 0,0,0,0,0,0        ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 10,32,22,104,1,80,57,98        ; Guardian graphic data
  DEFB 101,206,3,208,255,238,135,241  ;
  DEFB 119,228,199,255,139,241,50,172 ;
  DEFB 100,166,73,162,18,144,54,152   ;
  DEFB 0,0,5,32,3,64,49,116           ;
  DEFB 29,204,3,208,63,236,7,244      ;
  DEFB 63,224,103,252,11,242,50,172   ;
  DEFB 36,164,11,144,26,216,0,192     ;
  DEFB 0,0,0,0,2,32,9,96              ;
  DEFB 5,200,3,208,31,224,7,248       ;
  DEFB 31,224,23,248,15,240,18,168    ;
  DEFB 5,160,10,176,0,192,0,0         ;
  DEFB 0,0,5,32,3,64,49,116           ;
  DEFB 29,204,3,208,63,236,7,244      ;
  DEFB 63,224,103,252,11,242,50,172   ;
  DEFB 36,164,11,144,26,216,0,192     ;
  DEFB 12,0,12,0,12,0,12,0            ;
  DEFB 12,0,12,0,12,0,12,0            ;
  DEFB 12,0,12,0,255,192,12,0         ;
  DEFB 97,128,210,192,179,64,97,128   ;
  DEFB 3,0,3,0,3,0,3,0                ;
  DEFB 3,0,3,0,3,0,3,0                ;
  DEFB 3,0,3,0,63,240,3,0             ;
  DEFB 24,96,36,208,60,208,24,96      ;
  DEFB 0,192,0,192,0,192,0,192        ;
  DEFB 0,192,0,192,0,192,0,192        ;
  DEFB 0,192,0,192,15,252,0,192       ;
  DEFB 6,24,11,52,13,44,6,24          ;
  DEFB 0,48,0,48,0,48,0,48            ;
  DEFB 0,48,0,48,0,48,0,48            ;
  DEFB 0,48,0,48,3,255,0,48           ;
  DEFB 1,134,2,77,3,205,1,134         ;

; The Endorian Forest (teleport: 146)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN9:
  DEFB 22,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,4,0,68,68,68      ;
  DEFB 22,0,4,0,4,68,68,68     ;
  DEFB 68,68,68,68,68,68,68,22 ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,4,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,68,68,68,68,68,68,0  ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,68,68,68,68,22    ;
  DEFB 22,0,0,4,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,68,68,68,68,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 68,2,2,2,2,2,2,2        ;
  DEFB 22,0,0,0,0,0,0,68       ;
  DEFB 68,68,68,68,68,68,68,22 ;
  DEFB 22,68,68,68,68,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,68,68,68,68,68,68,68 ;
  DEFB 2,2,2,0,0,0,0,22        ;
  DEFB 22,68,68,68,68,68,0,0   ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,4,0,0,0,0,0,0        ;
  DEFB 0,68,68,68,68,68,68,68  ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,68,68,22      ;
  DEFB 22,68,68,68,68,2,2,0    ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,68,68,68,68,68,68,68 ;
  DEFB 0,0,0,0,0,0,4,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 22,0,0,0,0,0,0,4        ;
  DEFB 2,2,2,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,68,68,68,0,0,0,0     ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,68,68,68,22     ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,5         ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "       The Endorian Forest      " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 68,124,255,239,30,12,8,8,8 ; Floor
  DEFB 2,252,255,135,12,8,8,8,0 ; Crumbling floor
  DEFB 22,74,74,74,82,84,74,42,42 ; Wall
  DEFB 67,240,102,240,102,0,0,0,0 ; Conveyor (unused)
  DEFB 69,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 4,72,178,93,18,112,174,169,71 ; Nasty 2
  DEFB 5,255,255,202,101,146,40,130,0 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 64                 ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23681              ; Location in the attribute buffer at 23552: (4,1)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the (unused) conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 28691              ; Location in the screen buffer at 28672: (0,19)
  DEFB 1                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (2,21)
  DEFW 23637              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (1,14)
  DEFW 23598              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (6,12)
  DEFW 23756              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (8,18)
  DEFW 23826              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (1,30)
  DEFW 23614              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 30                 ; Attribute
  DEFB 255,255,248,143,136,145,170,145 ; Graphic data
  DEFB 170,149,138,133,144,145,213,185 ;
  DEFB 213,85,209,69,137,57,137,3      ;
  DEFB 168,171,170,171,138,137,255,255 ;
  DEFW 23980              ; Location in the attribute buffer at 23552: (13,12)
  DEFW 26796              ; Location in the screen buffer at 24576: (13,12)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 8,8,62,95,95,71,97,62 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 248                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 70                 ; Horizontal guardian 1: y=7, initial x=9, 9<=x<=14,
  DEFW 23785              ; speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 233                ;
  DEFB 238                ;
  DEFB 194                ; Horizontal guardian 2: y=10, initial x=12,
  DEFW 23884              ; 8<=x<=14, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 72                 ;
  DEFB 78                 ;
  DEFB 67                 ; Horizontal guardian 3: y=13, initial x=8, 4<=x<=26,
  DEFW 23976              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 164                ;
  DEFB 186                ;
  DEFB 5                  ; Horizontal guardian 4: y=5, initial x=18,
  DEFW 23730              ; 17<=x<=21, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 177                ;
  DEFB 181                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 112,0,80,0,124,0,52,0        ; Guardian graphic data
  DEFB 62,0,62,0,24,0,60,0          ;
  DEFB 126,0,126,0,247,0,251,0      ;
  DEFB 60,0,118,0,110,0,119,0       ;
  DEFB 28,0,20,0,31,0,13,0          ;
  DEFB 15,128,15,128,6,0,15,0       ;
  DEFB 27,128,27,128,27,128,29,128  ;
  DEFB 15,0,6,0,6,0,7,0             ;
  DEFB 7,0,5,0,7,192,3,64           ;
  DEFB 3,224,3,224,1,128,3,192      ;
  DEFB 7,224,7,224,15,112,15,176    ;
  DEFB 3,192,7,96,6,224,7,112       ;
  DEFB 1,192,1,64,1,240,0,208       ;
  DEFB 0,248,0,248,0,96,0,240       ;
  DEFB 1,248,3,252,7,254,6,246      ;
  DEFB 0,248,1,218,3,14,3,132       ;
  DEFB 3,128,6,128,15,128,11,0      ;
  DEFB 31,0,31,0,6,0,15,0           ;
  DEFB 31,128,63,192,127,224,111,96 ;
  DEFB 31,0,91,128,112,192,33,192   ;
  DEFB 0,224,1,160,3,224,2,192      ;
  DEFB 7,192,7,192,1,128,3,192      ;
  DEFB 7,224,7,224,14,240,13,240    ;
  DEFB 3,192,6,224,7,96,14,224      ;
  DEFB 0,56,0,104,0,248,0,176       ;
  DEFB 1,240,1,240,0,96,0,240       ;
  DEFB 1,248,1,216,1,216,1,184      ;
  DEFB 0,240,0,96,0,96,0,224        ;
  DEFB 0,14,0,26,0,62,0,44          ;
  DEFB 0,124,0,124,0,24,0,60        ;
  DEFB 0,126,0,126,0,239,0,223      ;
  DEFB 0,60,0,110,0,118,0,238       ;

; Attack of the Mutant Telephones (teleport: 246)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN10:
  DEFB 14,14,14,14,14,14,14,0  ; Attributes
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,66,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,70,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,65,65,65,65,0,0,0    ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,0,0,0,0,65,65,65     ;
  DEFB 65,65,65,0,0,0,0,65     ;
  DEFB 65,69,69,69,69,69,69,69 ;
  DEFB 65,65,0,0,0,0,0,14      ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 66,0,0,0,0,65,65,14     ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 66,0,0,0,0,0,0,14       ;
  DEFB 14,65,65,0,0,6,6,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 66,0,0,0,0,65,65,14     ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,65,65,65,65,65    ;
  DEFB 65,65,65,65,0,0,0,0     ;
  DEFB 70,0,0,0,0,0,0,14       ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,66,0,0,0        ;
  DEFB 0,0,0,66,0,0,0,0        ;
  DEFB 0,0,0,0,65,0,0,14       ;
  DEFB 14,0,0,0,0,0,1,1        ;
  DEFB 1,65,0,0,66,0,0,0       ;
  DEFB 0,0,0,70,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,70,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,65,65,65,14     ;
  DEFB 14,65,65,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,65        ;
  DEFB 65,65,0,0,0,0,0,14      ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,14        ;
  DEFB 14,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,14 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "Attack of the Mutant Telephones " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 65,255,255,219,110,197,64,0,0 ; Floor
  DEFB 1,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 14,170,85,170,85,170,85,170,85 ; Wall
  DEFB 6,254,102,254,0,0,0,0,0 ; Conveyor
  DEFB 70,16,16,214,56,214,56,84,146 ; Nasty 1
  DEFB 66,16,16,16,16,16,16,16,16 ; Nasty 2
  DEFB 69,255,255,255,255,170,0,0,0 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 16                 ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23587              ; Location in the attribute buffer at 23552: (1,3)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30725              ; Location in the screen buffer at 28672: (8,5)
  DEFB 2                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (0,24)
  DEFW 23576              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (1,30)
  DEFW 23614              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (4,1)
  DEFW 23681              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (6,19)
  DEFW 23763              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (13,30)
  DEFW 23998              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 86                 ; Attribute
  DEFB 255,255,218,171,234,107,255,255 ; Graphic data
  DEFB 144,9,144,9,255,255,144,9       ;
  DEFB 144,9,255,255,144,9,144,9       ;
  DEFB 255,255,144,9,144,9,255,255     ;
  DEFW 23585              ; Location in the attribute buffer at 23552: (1,1)
  DEFW 24609              ; Location in the screen buffer at 24576: (1,1)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 60,90,149,213,213,213,90,60 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 70                 ; Horizontal guardian 1: y=3, initial x=15,
  DEFW 23663              ; 15<=x<=24, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 111                ;
  DEFB 120                ;
  DEFB 196                ; Horizontal guardian 2: y=7, initial x=14,
  DEFW 23790              ; 14<=x<=18, speed=slow
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 238                ;
  DEFB 242                ;
  DEFB 66                 ; Horizontal guardian 3: y=13, initial x=15,
  DEFW 23983              ; 5<=x<=19, speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 165                ;
  DEFB 179                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 67                 ; Vertical guardian 1: x=12, initial y=8, 2<=y<56,
  DEFB 0                  ; initial y-increment=2
  DEFB 8                  ;
  DEFB 12                 ;
  DEFB 2                  ;
  DEFB 2                  ;
  DEFB 56                 ;
  DEFB 4                  ; Vertical guardian 2: x=3, initial y=32, 32<=y<100,
  DEFB 1                  ; initial y-increment=1
  DEFB 32                 ;
  DEFB 3                  ;
  DEFB 1                  ;
  DEFB 32                 ;
  DEFB 100                ;
  DEFB 6                  ; Vertical guardian 3: x=21, initial y=48, 48<=y<100,
  DEFB 2                  ; initial y-increment=1
  DEFB 48                 ;
  DEFB 21                 ;
  DEFB 1                  ;
  DEFB 48                 ;
  DEFB 100                ;
  DEFB 66                 ; Vertical guardian 4: x=26, initial y=48, 4<=y<100,
  DEFB 3                  ; initial y-increment=-3
  DEFB 48                 ;
  DEFB 26                 ;
  DEFB 253                ;
  DEFB 4                  ;
  DEFB 100                ;
  DEFB 255                ; Terminator
; The next 6 bytes are unused.
  DEFB 0,0,0,0,0,0        ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 0,0,0,0,63,252,99,198       ; Guardian graphic data
  DEFB 235,215,232,23,15,240,7,224 ;
  DEFB 12,48,11,208,27,216,28,56   ;
  DEFB 63,252,63,252,63,252,63,252 ;
  DEFB 60,0,127,192,127,248,99,198 ;
  DEFB 8,87,8,23,15,247,7,224      ;
  DEFB 12,48,11,208,27,216,28,56   ;
  DEFB 63,252,63,252,63,252,63,252 ;
  DEFB 0,0,0,0,63,252,99,198       ;
  DEFB 235,215,232,23,15,240,7,224 ;
  DEFB 12,48,11,208,27,216,28,56   ;
  DEFB 63,252,63,252,63,252,63,252 ;
  DEFB 0,60,3,254,31,254,99,198    ;
  DEFB 234,16,232,16,239,240,7,224 ;
  DEFB 12,48,11,208,27,216,28,56   ;
  DEFB 63,252,63,252,63,252,63,252 ;
  DEFB 12,0,22,0,45,0,76,128       ;
  DEFB 140,64,140,64,76,128,45,0   ;
  DEFB 22,0,12,0,55,0,76,0         ;
  DEFB 127,192,255,192,64,128,46,0 ;
  DEFB 3,0,3,0,5,128,7,128         ;
  DEFB 11,64,11,64,7,128,5,128     ;
  DEFB 3,0,3,0,14,192,3,32         ;
  DEFB 63,224,63,240,16,32,7,64    ;
  DEFB 0,192,0,192,0,192,0,192     ;
  DEFB 0,128,0,128,0,192,0,192     ;
  DEFB 0,192,0,192,1,208,4,200     ;
  DEFB 15,252,15,248,0,8,3,176     ;
  DEFB 0,48,0,104,0,180,0,180      ;
  DEFB 1,50,1,50,0,180,0,180       ;
  DEFB 0,104,0,48,0,184,1,50       ;
  DEFB 3,255,1,255,1,0,0,220       ;

; Return of the Alien Kong Beast (teleport: 1246)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN11:
  DEFB 101,0,5,0,0,0,6,0         ; Attributes
  DEFB 0,0,5,0,0,0,0,0           ;
  DEFB 0,101,6,0,0,101,0,0       ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,3           ;
  DEFB 3,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,67,67,67,0,0,0,0      ;
  DEFB 0,3,3,3,3,3,101,0         ;
  DEFB 0,101,3,3,3,3,3,3         ;
  DEFB 67,67,0,0,0,0,0,101       ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,101,0         ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,67,101        ;
  DEFB 101,0,0,0,0,0,67,67       ;
  DEFB 0,0,0,0,0,0,101,0         ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,67,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,101,0         ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,67,67,67,67,67,67,101   ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,67,67,67,67,101,0     ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,67,0        ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,101,67,67,67,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,67,67,0,0,0,0,101       ;
  DEFB 101,67,67,67,67,67,67,0   ;
  DEFB 0,0,0,0,0,0,0,0           ;
  DEFB 0,101,0,0,0,0,0,4         ;
  DEFB 0,0,0,0,4,0,0,101         ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,67,67,67,101,0      ;
  DEFB 0,101,70,70,70,70,70,70   ;
  DEFB 70,70,70,70,70,0,0,101    ;
  DEFB 101,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,101,0         ;
  DEFB 0,101,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,101         ;
  DEFB 101,67,67,67,67,67,67,67  ;
  DEFB 67,67,67,67,67,67,101,101 ;
  DEFB 101,101,67,67,67,67,67,67 ;
  DEFB 67,67,67,67,67,67,67,101  ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM " Return of the Alien Kong Beast " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 67,255,255,219,110,197,64,0,0 ; Floor
  DEFB 3,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 101,34,255,136,255,34,255,136,255 ; Wall
  DEFB 70,240,102,240,170,0,0,0,0 ; Conveyor
  DEFB 4,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2
  DEFB 6,255,129,129,66,60,16,96,96 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30898              ; Location in the screen buffer at 28672: (13,18)
  DEFB 11                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (3,15)
  DEFW 23663              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (7,16)
  DEFW 23792              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (6,2)
  DEFW 23746              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (13,29)
  DEFW 23997              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (5,26)
  DEFW 23738              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 94                 ; Attribute
  DEFB 255,255,128,1,143,241,143,241  ; Graphic data
  DEFB 143,241,143,241,143,241,140,49 ;
  DEFB 140,49,143,241,143,241,143,241 ;
  DEFB 143,241,143,241,128,1,255,255  ;
  DEFW 23983              ; Location in the attribute buffer at 23552: (13,15)
  DEFW 26799              ; Location in the screen buffer at 24576: (13,15)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 128,192,236,114,40,84,138,135 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 68                 ; Horizontal guardian 1: y=13, initial x=9, 1<=x<=9,
  DEFW 23977              ; speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 161                ;
  DEFB 169                ;
  DEFB 198                ; Horizontal guardian 2: y=11, initial x=11,
  DEFW 23915              ; 11<=x<=15, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 107                ;
  DEFB 111                ;
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 5                  ; Horizontal guardian 4: y=6, initial x=25,
  DEFW 23769              ; 25<=x<=28, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 217                ;
  DEFB 220                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT; the first byte specifies
; the Kong Beast's initial status, but the second byte is not used.
  DEFB 0                  ; Initial status (on the ledge)
  DEFB 0                  ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 19,200,29,184,15,240,6,96       ; Guardian graphic data
  DEFB 5,160,2,64,7,224,15,240         ;
  DEFB 31,248,51,204,99,198,70,98      ;
  DEFB 44,52,6,96,2,64,14,112          ;
  DEFB 11,208,13,176,15,240,6,96       ;
  DEFB 5,160,2,64,3,192,31,248         ;
  DEFB 127,254,231,231,131,193,199,227 ;
  DEFB 6,96,12,48,8,16,56,28           ;
  DEFB 28,56,6,96,12,48,102,102        ;
  DEFB 35,196,103,230,55,236,31,248    ;
  DEFB 15,240,7,224,2,64,5,160         ;
  DEFB 6,96,15,240,13,176,11,208       ;
  DEFB 112,14,24,24,12,48,6,96         ;
  DEFB 99,198,39,228,103,230,55,236    ;
  DEFB 31,248,15,240,2,64,5,160        ;
  DEFB 22,104,15,240,13,176,3,192      ;
  DEFB 8,0,5,0,8,128,37,0              ;
  DEFB 72,128,33,0,76,0,51,0           ;
  DEFB 68,128,68,128,136,64,132,64     ;
  DEFB 72,128,72,128,51,0,12,0         ;
  DEFB 2,0,17,32,10,64,17,32           ;
  DEFB 10,64,16,32,3,0,12,192          ;
  DEFB 16,32,16,96,34,144,37,16        ;
  DEFB 24,32,16,32,12,192,3,0          ;
  DEFB 0,64,2,32,4,72,2,36             ;
  DEFB 4,72,2,4,0,200,3,48             ;
  DEFB 4,8,4,8,11,68,8,180             ;
  DEFB 4,8,4,8,3,48,0,192              ;
  DEFB 0,68,1,34,2,68,1,34             ;
  DEFB 2,68,1,2,2,48,0,204             ;
  DEFB 1,66,1,34,2,17,2,33             ;
  DEFB 1,18,1,10,0,204,0,48            ;

; Ore Refinery (teleport: 346)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN12:
  DEFB 22,22,22,22,22,22,22,22 ; Attributes
  DEFB 22,22,22,22,22,22,22,22 ;
  DEFB 22,22,22,22,22,22,22,22 ;
  DEFB 22,22,22,22,22,22,22,22 ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,5        ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,0,0,5,5,5,5,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,5        ;
  DEFB 5,0,0,5,5,5,5,0         ;
  DEFB 0,5,5,5,5,5,0,0         ;
  DEFB 5,5,5,5,0,0,5,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,5        ;
  DEFB 5,5,5,5,0,0,5,5         ;
  DEFB 5,0,0,0,5,5,5,5         ;
  DEFB 5,0,0,5,5,5,5,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,5        ;
  DEFB 5,5,0,0,5,5,5,0         ;
  DEFB 0,5,5,5,5,0,0,5         ;
  DEFB 5,5,5,0,0,5,5,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,6,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,5,5,4,4,4,4,4        ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,4,5,5,22        ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "          Ore Refinery          " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 5,255,255,17,34,68,136,255,255 ; Floor
  DEFB 66,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 22,90,90,90,90,90,90,90,90 ; Wall
  DEFB 4,240,102,240,102,0,0,0,0 ; Conveyor
  DEFB 68,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 69,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 6,255,129,129,129,129,129,129,129 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30947              ; Location in the screen buffer at 28672: (15,3)
  DEFB 26                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 1                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (3,26)
  DEFW 23674              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (6,10)
  DEFW 23754              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (9,19)
  DEFW 23859              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (9,26)
  DEFW 23866              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (12,11)
  DEFW 23947              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 79                 ; Attribute
  DEFB 3,192,7,224,15,240,9,144    ; Graphic data
  DEFB 9,144,7,224,5,160,2,64      ;
  DEFB 97,134,248,31,254,127,5,224 ;
  DEFB 7,160,254,127,248,31,96,6   ;
  DEFW 23969              ; Location in the attribute buffer at 23552: (13,1)
  DEFW 26785              ; Location in the screen buffer at 24576: (13,1)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 24,110,66,219,201,98,126,24 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 252                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 67                 ; Horizontal guardian 1: y=1, initial x=7, 7<=x<=29,
  DEFW 23591              ; speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 39                 ;
  DEFB 61                 ;
  DEFB 196                ; Horizontal guardian 2: y=4, initial x=16, 7<=x<=29,
  DEFW 23696              ; speed=slow
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 135                ;
  DEFB 157                ;
  DEFB 70                 ; Horizontal guardian 3: y=7, initial x=20,
  DEFW 23796              ; 10<=x<=26, speed=normal
  DEFB 96                 ;
  DEFB 7                  ;
  DEFB 234                ;
  DEFB 250                ;
  DEFB 194                ; Horizontal guardian 4: y=10, initial x=18,
  DEFW 23890              ; 7<=x<=29, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 71                 ;
  DEFB 93                 ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 71                 ; Vertical guardian 1: x=5, initial y=8, 8<=y<100,
  DEFB 0                  ; initial y-increment=2
  DEFB 8                  ;
  DEFB 5                  ;
  DEFB 2                  ;
  DEFB 8                  ;
  DEFB 100                ;
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 0,0,0,0,0,0,3,192            ; Guardian graphic data
  DEFB 12,48,16,8,32,4,64,2         ;
  DEFB 128,1,64,2,32,4,208,11       ;
  DEFB 44,52,75,210,18,72,2,64      ;
  DEFB 0,0,0,0,0,0,3,192            ;
  DEFB 12,48,16,8,32,4,64,2         ;
  DEFB 248,31,87,234,43,212,18,72   ;
  DEFB 12,48,3,192,0,0,0,0          ;
  DEFB 4,32,4,32,18,72,75,210       ;
  DEFB 44,52,147,201,167,229,70,98  ;
  DEFB 134,97,71,226,35,196,16,8    ;
  DEFB 12,48,3,192,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,3,192            ;
  DEFB 12,48,18,72,42,84,95,250     ;
  DEFB 246,127,71,226,35,196,16,8   ;
  DEFB 12,48,3,192,0,0,0,0          ;
  DEFB 97,128,178,64,179,192,97,128 ;
  DEFB 12,0,255,192,82,128,18,0     ;
  DEFB 18,0,30,0,12,0,12,0          ;
  DEFB 12,0,12,0,30,0,63,0          ;
  DEFB 24,96,36,208,60,208,24,96    ;
  DEFB 3,0,63,240,20,160,4,128      ;
  DEFB 4,128,7,128,3,0,3,0          ;
  DEFB 7,128,15,192,0,0,0,0         ;
  DEFB 6,24,13,60,13,36,6,24        ;
  DEFB 0,192,15,252,5,40,1,32       ;
  DEFB 1,32,1,224,1,224,3,240       ;
  DEFB 0,0,0,0,0,0,0,0              ;
  DEFB 1,134,3,203,2,75,1,134       ;
  DEFB 0,48,3,255,1,74,0,72         ;
  DEFB 0,72,0,120,0,48,0,48         ;
  DEFB 0,120,0,252,0,0,0,0          ;

; Skylab Landing Bay (teleport: 1346)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN13:
  DEFB 104,8,8,8,8,8,8,8               ; Attributes
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,76                ;
  DEFB 12,8,8,8,8,8,8,8                ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,76,12,8,8,8             ;
  DEFB 8,8,8,76,12,8,8,8               ;
  DEFB 8,8,8,76,12,8,8,8               ;
  DEFB 8,8,8,76,12,8,8,104             ;
  DEFB 104,8,8,8,8,8,8,76              ;
  DEFB 12,8,8,8,8,8,8,8                ;
  DEFB 8,8,8,8,8,8,8,76                ;
  DEFB 12,8,8,8,8,8,8,104              ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,76,12,8             ;
  DEFB 8,8,8,8,8,76,12,8               ;
  DEFB 8,8,8,8,8,76,12,8               ;
  DEFB 8,8,8,8,8,76,12,104             ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,76,12,8,8,8,8,8             ;
  DEFB 8,76,12,8,8,8,8,75              ;
  DEFB 75,75,75,75,75,8,8,8            ;
  DEFB 8,76,12,8,8,8,8,104             ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,76              ;
  DEFB 12,8,8,8,8,8,8,8                ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,8,8,8,8,8,8,8               ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,8                 ;
  DEFB 8,8,8,8,8,8,8,104               ;
  DEFB 104,104,104,104,104,104,104,104 ;
  DEFB 104,104,104,104,104,104,104,104 ;
  DEFB 104,104,104,104,104,104,104,104 ;
  DEFB 104,104,104,104,104,104,104,104 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "       Skylab Landing Bay       " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 8,0,0,0,0,0,0,0,0  ; Background
  DEFB 76,255,255,98,100,120,112,96,96 ; Floor
  DEFB 2,252,255,255,135,255,8,8,0 ; Crumbling floor (unused)
  DEFB 104,1,130,196,232,224,216,188,126 ; Wall
  DEFB 75,240,102,240,102,0,0,0,0 ; Conveyor
  DEFB 0,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 0,72,178,93,18,112,174,169,71 ; Nasty 2 (unused)
  DEFB 12,255,255,70,38,30,14,6,6 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30831              ; Location in the screen buffer at 28672: (11,15)
  DEFB 6                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 6                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 11                 ; Item 1 at (2,23)
  DEFW 23639              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 12                 ; Item 2 at (8,3)
  DEFW 23811              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 13                 ; Item 3 at (7,27)
  DEFW 23803              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 14                 ; Item 4 at (7,16)
  DEFW 23792              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 0,255,255,255,255  ; Item 5 (unused)
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 30                 ; Attribute
  DEFB 255,255,255,255,252,63,248,31 ; Graphic data
  DEFB 240,15,224,7,193,131,194,67   ;
  DEFB 194,67,193,131,224,7,240,15   ;
  DEFB 248,31,252,63,255,255,255,255 ;
  DEFW 23567              ; Location in the attribute buffer at 23552: (0,15)
  DEFW 24591              ; Location in the screen buffer at 24576: (0,15)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 170,170,254,254,254,254,170,170 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 248                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 255                ; Horizontal guardian 1: y=7, initial x=9, 9<=x<=14,
  DEFW 23785              ; speed=slow (unused)
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 233                ;
  DEFB 238                ;
  DEFB 194                ; Horizontal guardian 2: y=10, initial x=12,
  DEFW 23884              ; 8<=x<=14, speed=slow (unused)
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 72                 ;
  DEFB 78                 ;
  DEFB 67                 ; Horizontal guardian 3: y=13, initial x=8, 4<=x<=26,
  DEFW 23976              ; speed=normal (unused)
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 164                ;
  DEFB 186                ;
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 15                 ; Vertical guardian 1: x=1, initial y=0, 0<=y<=72,
  DEFB 0                  ; y-increment=4
  DEFB 0                  ;
  DEFB 1                  ;
  DEFB 4                  ;
  DEFB 0                  ;
  DEFB 72                 ;
  DEFB 13                 ; Vertical guardian 2: x=11, initial y=0, 0<=y<=32,
  DEFB 0                  ; y-increment=1
  DEFB 0                  ;
  DEFB 11                 ;
  DEFB 1                  ;
  DEFB 0                  ;
  DEFB 32                 ;
  DEFB 14                 ; Vertical guardian 3: x=21, initial y=2, 2<=y<=56,
  DEFB 0                  ; y-increment=3
  DEFB 2                  ;
  DEFB 21                 ;
  DEFB 3                  ;
  DEFB 2                  ;
  DEFB 56                 ;
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 3,192,255,255,171,213,255,255  ; Guardian graphic data
  DEFB 19,200,41,148,21,168,11,208    ;
  DEFB 5,160,3,192,3,192,5,160        ;
  DEFB 10,80,20,40,40,20,16,8         ;
  DEFB 0,0,0,0,3,192,255,255          ;
  DEFB 171,213,255,255,19,200,41,148  ;
  DEFB 21,168,11,208,5,160,3,192      ;
  DEFB 3,192,37,160,74,84,20,42       ;
  DEFB 0,0,0,0,0,0,0,7                ;
  DEFB 3,253,255,215,171,248,255,192  ;
  DEFB 3,192,1,128,21,164,75,210      ;
  DEFB 5,164,35,194,11,208,37,168     ;
  DEFB 0,0,0,0,0,0,0,32               ;
  DEFB 2,2,0,21,3,206,15,212          ;
  DEFB 203,200,183,194,227,200,49,129 ;
  DEFB 7,228,195,200,23,194,35,252    ;
  DEFB 0,0,1,0,0,0,8,32               ;
  DEFB 0,0,0,0,33,2,0,17              ;
  DEFB 3,138,14,144,75,192,55,2       ;
  DEFB 98,192,49,1,5,226,195,68       ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,2,0,0,0,0,32               ;
  DEFB 16,8,10,132,0,32,101,0         ;
  DEFB 34,104,8,160,3,208,23,224      ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 2,0,0,32,16,0,0,0              ;
  DEFB 5,16,0,104,34,160,13,208       ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,128              ;
  DEFB 0,32,8,0,2,192,7,96            ;

; The Bank (teleport: 2346)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN14:
  DEFB 14,0,0,0,0,0,14,14      ; Attributes
  DEFB 14,14,14,14,14,14,14,14 ;
  DEFB 14,14,14,14,14,14,14,14 ;
  DEFB 14,14,14,14,14,14,14,14 ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,6,6,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,6,6,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 69,69,69,69,69,69,69,69 ;
  DEFB 69,69,69,69,69,69,69,69 ;
  DEFB 65,65,65,65,65,6,6,14   ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 66,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,66,6,6,14       ;
  DEFB 14,65,65,65,65,65,0,0   ;
  DEFB 70,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,66,6,6,14       ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 65,65,0,0,66,6,6,14     ;
  DEFB 14,0,0,0,0,0,0,1        ;
  DEFB 0,0,0,0,65,65,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,66,6,6,14       ;
  DEFB 14,0,0,65,65,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,65,65,0,0,0,0       ;
  DEFB 0,0,0,0,66,6,6,14       ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,65,65,0,66,6,6,14     ;
  DEFB 14,65,65,0,0,0,0,0      ;
  DEFB 0,0,0,0,65,65,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,70,6,6,14       ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,65,65,0,0,0,0       ;
  DEFB 0,0,0,0,0,6,6,14        ;
  DEFB 14,0,0,0,0,65,65,65     ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,65        ;
  DEFB 65,0,0,0,0,6,6,14       ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,65,65,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,6,6,14        ;
  DEFB 14,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,6,6,14        ;
  DEFB 14,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,65 ;
  DEFB 65,65,65,65,65,65,65,14 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "            The Bank            " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 65,255,255,221,119,170,85,34,0 ; Floor
  DEFB 1,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 14,170,85,170,85,170,85,170,85 ; Wall
  DEFB 69,254,102,254,0,0,0,0,0 ; Conveyor
  DEFB 70,16,16,214,56,214,56,84,146 ; Nasty 1
  DEFB 66,16,16,16,16,16,16,16,16 ; Nasty 2
  DEFB 6,255,255,24,24,24,24,24,24 ; Extra
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 28776              ; Location in the screen buffer at 28672: (3,8)
  DEFB 16                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (2,25)
  DEFW 23641              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (6,12)
  DEFW 23756              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (14,26)
  DEFW 24026              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Item 4 at (6,19) (unused)
  DEFW 23763              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (13,30) (unused)
  DEFW 23998              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 86                 ; Attribute
  DEFB 255,255,128,1,128,1,128,1 ; Graphic data
  DEFB 128,1,136,1,170,1,156,61  ;
  DEFB 255,71,156,1,170,1,136,1  ;
  DEFB 128,1,128,1,128,1,255,255 ;
  DEFW 23649              ; Location in the attribute buffer at 23552: (3,1)
  DEFW 24673              ; Location in the screen buffer at 24576: (3,1)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 124,56,100,222,142,222,130,124 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 252                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 69                 ; Horizontal guardian 1: y=13, initial x=17,
  DEFW 23985              ; 17<=x<=19, speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 177                ;
  DEFB 179                ;
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 6                  ; Vertical guardian 1: x=9, initial y=40, 36<=y<102,
  DEFB 0                  ; initial y-increment=2
  DEFB 40                 ;
  DEFB 9                  ;
  DEFB 2                  ;
  DEFB 36                 ;
  DEFB 102                ;
  DEFB 7                  ; Vertical guardian 2: x=15, initial y=64, 36<=y<102,
  DEFB 1                  ; initial y-increment=1
  DEFB 64                 ;
  DEFB 15                 ;
  DEFB 1                  ;
  DEFB 36                 ;
  DEFB 102                ;
  DEFB 68                 ; Vertical guardian 3: x=21, initial y=80, 32<=y<104,
  DEFB 3                  ; initial y-increment=-3
  DEFB 80                 ;
  DEFB 21                 ;
  DEFB 253                ;
  DEFB 32                 ;
  DEFB 104                ;
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 4 (unused)
  DEFB 255                ; Terminator
; The next 6 bytes are unused.
  DEFB 0,0,0,0,0,0        ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 97,134,159,249,159,249,97,134  ; Guardian graphic data
  DEFB 3,192,255,255,128,1,170,169    ;
  DEFB 159,253,181,89,144,13,181,89   ;
  DEFB 159,253,170,169,128,1,255,255  ;
  DEFB 29,184,34,244,34,244,29,184    ;
  DEFB 3,192,255,255,213,85,191,255   ;
  DEFB 234,173,176,7,229,77,176,7     ;
  DEFB 234,173,191,255,213,85,255,255 ;
  DEFB 7,224,8,16,8,16,7,224          ;
  DEFB 3,192,255,255,255,255,213,87   ;
  DEFB 224,3,202,167,231,243,202,167  ;
  DEFB 224,3,213,87,255,255,255,255   ;
  DEFB 29,184,47,68,47,68,29,184      ;
  DEFB 3,192,255,255,170,171,192,1    ;
  DEFB 149,83,207,249,154,179,207,249 ;
  DEFB 149,83,192,1,170,171,255,255   ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,255,192,129,192        ;
  DEFB 255,192,130,64,254,64,255,192  ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,63,240,32,112          ;
  DEFB 63,240,32,144,63,144,63,240    ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 15,252,8,28,15,252,8,36        ;
  DEFB 15,228,15,252,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,0,0,0,0                ;
  DEFB 0,0,0,0,3,255,2,7              ;
  DEFB 3,255,2,9,3,249,3,255          ;
  DEFB 0,0,0,0,0,0,0,0                ;

; The Sixteenth Cavern (teleport: 12346)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN15:
  DEFB 101,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,66,0,0,0,0,66,0      ;
  DEFB 0,0,0,101,0,0,101,0      ;
  DEFB 0,0,0,0,0,0,66,66        ;
  DEFB 66,0,0,0,0,0,0,101       ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,101,0,0,101,101    ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,66,0,0,0       ;
  DEFB 0,0,0,101,0,0,101,101    ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,66,66,66,66,66,66,101  ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,101,0,0,101,101    ;
  DEFB 101,101,0,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,2,2,70,70,70,70,70   ;
  DEFB 70,70,70,70,70,70,70,70  ;
  DEFB 70,70,70,70,70,70,70,70  ;
  DEFB 70,70,70,0,0,0,0,101     ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,101,101,66,66,0,0    ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,66,0,0,0,0,101       ;
  DEFB 101,66,66,66,66,66,66,66 ;
  DEFB 66,66,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,101        ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,66,0,0,0         ;
  DEFB 0,0,66,0,0,0,0,101       ;
  DEFB 101,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0          ;
  DEFB 0,0,0,0,0,0,0,4          ;
  DEFB 4,4,0,0,0,0,0,101        ;
  DEFB 101,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66  ;
  DEFB 66,66,66,66,66,66,66,66  ;
  DEFB 66,66,66,66,66,66,66,101 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "      The Sixteenth Cavern      " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 66,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 101,73,249,79,73,255,72,120,207 ; Wall
  DEFB 70,240,102,240,170,0,0,0,0 ; Conveyor
  DEFB 4,68,68,68,68,102,238,238,255 ; Nasty 1
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 6,255,129,129,66,60,16,96,96 ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23970              ; Location in the attribute buffer at 23552: (13,2)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30755              ; Location in the screen buffer at 28672: (9,3)
  DEFB 24                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (2,30)
  DEFW 23646              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (7,13)
  DEFW 23789              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (0,1)
  DEFW 23553              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (10,17)
  DEFW 23889              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Item 5 at (5,26) (unused)
  DEFW 23738              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 94                 ; Attribute
  DEFB 255,255,129,129,129,129,255,255 ; Graphic data
  DEFB 129,129,129,129,255,255,129,129 ;
  DEFB 129,129,255,255,129,129,129,129 ;
  DEFB 255,255,129,129,129,129,255,255 ;
  DEFW 23724              ; Location in the attribute buffer at 23552: (5,12)
  DEFW 24748              ; Location in the screen buffer at 24576: (5,12)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 15,9,61,39,244,156,144,240 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 248                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 68                 ; Horizontal guardian 1: y=13, initial x=9, 1<=x<=18,
  DEFW 23977              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 161                ;
  DEFB 178                ;
  DEFB 6                  ; Horizontal guardian 2: y=10, initial x=1, 1<=x<=7,
  DEFW 23873              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 65                 ;
  DEFB 71                 ;
  DEFB 67                 ; Horizontal guardian 3: y=7, initial x=18,
  DEFW 23794              ; 18<=x<=23, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 242                ;
  DEFB 247                ;
  DEFB 133                ; Horizontal guardian 4: y=5, initial x=26,
  DEFW 23738              ; 25<=x<=29, speed=slow
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 185                ;
  DEFB 189                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 1 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 0,0,8,0,20,0,42,0           ; Guardian graphic data
  DEFB 85,0,74,0,132,0,128,192     ;
  DEFB 128,192,65,0,127,128,63,192 ;
  DEFB 31,128,15,0,10,128,18,64    ;
  DEFB 42,0,21,0,42,0,21,0         ;
  DEFB 32,0,32,0,32,0,32,48        ;
  DEFB 32,48,16,64,31,224,15,240   ;
  DEFB 7,224,3,192,2,160,4,144     ;
  DEFB 0,0,16,0,40,0,84,0          ;
  DEFB 170,0,81,0,33,0,1,12        ;
  DEFB 2,12,2,16,3,248,3,252       ;
  DEFB 1,248,0,240,0,168,1,36      ;
  DEFB 5,64,10,128,5,64,10,128     ;
  DEFB 0,64,0,64,0,64,0,67         ;
  DEFB 0,131,0,132,0,254,0,255     ;
  DEFB 0,126,0,60,0,42,0,73        ;
  DEFB 2,160,1,80,2,160,1,80       ;
  DEFB 2,0,2,0,2,0,194,0           ;
  DEFB 193,0,33,0,127,0,255,0      ;
  DEFB 126,0,60,0,84,0,146,0       ;
  DEFB 0,0,0,8,0,20,0,42           ;
  DEFB 0,85,0,138,0,132,48,128     ;
  DEFB 48,64,8,64,31,192,63,192    ;
  DEFB 31,128,15,0,21,0,36,128     ;
  DEFB 0,84,0,168,0,84,0,168       ;
  DEFB 0,4,0,4,0,4,12,4            ;
  DEFB 12,4,2,8,7,248,15,240       ;
  DEFB 7,224,3,192,5,64,9,32       ;
  DEFB 0,0,0,16,0,40,0,84          ;
  DEFB 0,170,0,82,0,33,3,1         ;
  DEFB 3,1,0,130,1,254,3,252       ;
  DEFB 1,248,0,240,1,80,2,72       ;

; The Warehouse (teleport: 56)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN16:
  DEFB 22,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,22,22,22      ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,6,0        ;
  DEFB 0,6,0,0,0,6,0,0         ;
  DEFB 6,0,0,0,0,0,6,0         ;
  DEFB 6,0,0,0,0,0,0,22        ;
  DEFB 22,4,4,68,68,68,68,68   ;
  DEFB 68,68,0,0,68,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,68   ;
  DEFB 0,68,68,0,0,4,4,22      ;
  DEFB 22,68,68,33,68,68,68,68 ;
  DEFB 68,68,0,0,68,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,22   ;
  DEFB 22,68,68,68,68,68,68,68 ;
  DEFB 68,68,0,0,68,68,68,0    ;
  DEFB 68,68,68,0,0,68,68,68   ;
  DEFB 68,68,33,0,0,68,68,22   ;
  DEFB 22,68,68,0,0,68,68,68   ;
  DEFB 68,68,0,0,68,68,32,32   ;
  DEFB 32,32,32,0,0,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,22   ;
  DEFB 22,0,68,0,0,68,68,68    ;
  DEFB 68,68,0,0,68,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,68   ;
  DEFB 68,68,68,0,0,68,68,22   ;
  DEFB 22,68,68,0,0,68,68,68   ;
  DEFB 68,68,0,0,68,68,68,68   ;
  DEFB 68,68,68,0,68,68,33,68  ;
  DEFB 68,68,68,0,0,68,68,22   ;
  DEFB 22,68,68,0,0,68,68,68   ;
  DEFB 68,33,0,0,68,68,68,68   ;
  DEFB 68,68,68,68,68,68,68,68 ;
  DEFB 68,68,0,0,0,68,68,22    ;
  DEFB 22,68,68,0,0,68,68,68   ;
  DEFB 68,68,0,0,68,68,68,68   ;
  DEFB 68,68,68,68,68,68,68,68 ;
  DEFB 68,68,68,0,0,68,68,22   ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,4,4,4,4,22        ;
  DEFB 22,4,4,4,4,4,4,4        ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,4,4,4,4         ;
  DEFB 4,4,4,4,4,4,4,22        ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "         The Warehouse          " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 4,255,255,219,110,197,64,0,0 ; Floor
  DEFB 68,255,170,85,170,85,170,85,170 ; Crumbling floor
  DEFB 22,255,153,187,255,255,153,187,255 ; Wall
  DEFB 32,240,102,240,102,0,0,0,0 ; Conveyor
  DEFB 6,68,40,148,81,53,214,88,16 ; Nasty 1
  DEFB 33,66,215,254,101,166,125,238,215 ; Nasty 2
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 48                 ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 3                  ; Animation frame (see FRAME)
  DEFB 1                  ; Direction and movement flags: facing left (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23649              ; Location in the attribute buffer at 23552: (3,1)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30734              ; Location in the screen buffer at 28672: (8,14)
  DEFB 5                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 35                 ; Item 1 at (5,24)
  DEFW 23736              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 36                 ; Item 2 at (7,15)
  DEFW 23791              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 37                 ; Item 3 at (9,1)
  DEFW 23841              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 38                 ; Item 4 at (10,19)
  DEFW 23891              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 35                 ; Item 5 at (11,26)
  DEFW 23930              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 76                 ; Attribute
  DEFB 255,255,128,1,191,253,160,5     ; Graphic data
  DEFB 165,165,165,165,165,165,165,165 ;
  DEFB 165,165,165,165,175,245,165,165 ;
  DEFB 165,165,165,165,165,165,255,255 ;
  DEFW 23613              ; Location in the attribute buffer at 23552: (1,29)
  DEFW 24637              ; Location in the screen buffer at 24576: (1,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 194                ; Horizontal guardian 1: y=13, initial x=5, 5<=x<=8,
  DEFW 23973              ; speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 165                ;
  DEFB 168                ;
  DEFB 5                  ; Horizontal guardian 2: y=13, initial x=12,
  DEFW 23980              ; 12<=x<=25, speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 172                ;
  DEFB 185                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 65                 ; Vertical guardian 1: x=3, initial y=64, 64<=y<102,
  DEFB 0                  ; initial y-increment=2
  DEFB 64                 ;
  DEFB 3                  ;
  DEFB 2                  ;
  DEFB 64                 ;
  DEFB 102                ;
  DEFB 6                  ; Vertical guardian 2: x=10, initial y=64, 3<=y<96,
  DEFB 1                  ; initial y-increment=-3
  DEFB 64                 ;
  DEFB 10                 ;
  DEFB 253                ;
  DEFB 3                  ;
  DEFB 96                 ;
  DEFB 71                 ; Vertical guardian 3: x=19, initial y=48, 0<=y<64,
  DEFB 2                  ; initial y-increment=1
  DEFB 48                 ;
  DEFB 19                 ;
  DEFB 1                  ;
  DEFB 0                  ;
  DEFB 64                 ;
  DEFB 67                 ; Vertical guardian 4: x=27, initial y=0, 4<=y<96,
  DEFB 3                  ; initial y-increment=4
  DEFB 0                  ;
  DEFB 27                 ;
  DEFB 4                  ;
  DEFB 4                  ;
  DEFB 96                 ;
  DEFB 255                ; Terminator
; The next 6 bytes are unused.
  DEFB 0,0,0,0,0,0        ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 85,85,255,255,255,255,8,16  ; Guardian graphic data
  DEFB 8,16,8,16,248,31,85,85      ;
  DEFB 255,255,255,255,8,16,8,16   ;
  DEFB 8,16,88,21,255,255,255,255  ;
  DEFB 0,0,85,85,255,255,255,255   ;
  DEFB 8,16,248,31,8,16,63,254     ;
  DEFB 56,30,8,16,95,245,255,255   ;
  DEFB 255,255,0,0,255,255,0,0     ;
  DEFB 0,0,0,0,255,255,85,85       ;
  DEFB 255,255,255,255,8,16,56,30  ;
  DEFB 63,254,8,16,248,31,95,245   ;
  DEFB 255,255,255,255,0,0,0,0     ;
  DEFB 0,0,85,85,255,255,248,31    ;
  DEFB 8,16,85,85,255,255,255,255  ;
  DEFB 120,29,248,31,248,31,8,16   ;
  DEFB 85,85,255,255,255,255,0,0   ;
  DEFB 126,0,153,0,255,0,219,0     ;
  DEFB 231,0,126,0,36,0,36,0       ;
  DEFB 36,0,66,0,66,0,66,0         ;
  DEFB 129,0,129,0,195,0,195,0     ;
  DEFB 0,0,31,128,38,64,63,192     ;
  DEFB 54,192,57,192,31,128,16,128 ;
  DEFB 32,64,32,64,64,32,64,32     ;
  DEFB 128,16,128,48,192,48,192,0  ;
  DEFB 0,0,0,0,0,0,7,224           ;
  DEFB 9,144,15,240,13,176,14,112  ;
  DEFB 7,224,8,16,16,8,32,4        ;
  DEFB 64,2,128,1,192,3,192,3      ;
  DEFB 0,0,1,248,2,100,3,252       ;
  DEFB 3,108,3,156,1,248,1,8       ;
  DEFB 2,4,2,4,4,2,4,2             ;
  DEFB 8,1,12,1,12,3,0,3           ;

; Amoebatrons' Revenge (teleport: 156)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN17:
  DEFB 22,0,0,0,0,0,0,0        ; Attributes
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,22,0,0,22       ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,66,66,0,0,66     ;
  DEFB 66,66,0,0,66,66,66,66   ;
  DEFB 66,66,66,66,0,0,66,66   ;
  DEFB 66,0,0,66,66,66,66,22   ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,66,66,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,66,66,66,66     ;
  DEFB 66,66,66,66,0,0,66,66   ;
  DEFB 66,0,0,66,66,0,0,22     ;
  DEFB 22,0,0,66,66,0,0,66     ;
  DEFB 66,66,0,0,0,0,0,0       ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,66,66,22      ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,66,66,0,0,66     ;
  DEFB 66,66,0,0,66,66,66,66   ;
  DEFB 66,66,66,66,0,0,66,66   ;
  DEFB 66,0,0,66,66,0,0,22     ;
  DEFB 22,66,66,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 22,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,22        ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "      Amoebatrons' Revenge      " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 66,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 22,255,129,129,255,255,129,129,255 ; Wall
  DEFB 4,240,102,240,102,0,153,255,0 ; Conveyor (unused)
  DEFB 68,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 3                  ; Animation frame (see FRAME)
  DEFB 1                  ; Direction and movement flags: facing left (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23997              ; Location in the attribute buffer at 23552: (13,29)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the (unused) conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30759              ; Location in the screen buffer at 28672: (9,7)
  DEFB 3                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 1                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (1,16)
  DEFW 23600              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 255,255,255,255,255 ; Item 2 (unused)
  DEFB 0,255,255,255,255  ; Item 3 (unused)
  DEFB 0,255,255,255,255  ; Item 4 (unused)
  DEFB 0,255,255,255,255  ; Item 5 (unused)
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 14                 ; Attribute
  DEFB 255,255,128,1,176,13,160,5  ; Graphic data
  DEFB 170,85,170,85,170,85,170,85 ;
  DEFB 170,85,170,85,170,85,170,85 ;
  DEFB 160,5,176,13,128,1,255,255  ;
  DEFW 23581              ; Location in the attribute buffer at 23552: (0,29)
  DEFW 24605              ; Location in the screen buffer at 24576: (0,29)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 128                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 196                ; Horizontal guardian 1: y=3, initial x=12,
  DEFW 23660              ; 12<=x<=18, speed=slow
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 108                ;
  DEFB 114                ;
  DEFB 133                ; Horizontal guardian 2: y=10, initial x=16,
  DEFW 23888              ; 12<=x<=17, speed=slow
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 76                 ;
  DEFB 81                 ;
  DEFB 67                 ; Horizontal guardian 3: y=6, initial x=16,
  DEFW 23760              ; 12<=x<=17, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 204                ;
  DEFB 209                ;
  DEFB 6                  ; Horizontal guardian 4: y=13, initial x=16,
  DEFW 23984              ; 12<=x<=18, speed=normal
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 172                ;
  DEFB 178                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 67                 ; Vertical guardian 1: x=5, initial y=8, 5<=y<104,
  DEFB 0                  ; initial y-increment=3
  DEFB 8                  ;
  DEFB 5                  ;
  DEFB 3                  ;
  DEFB 5                  ;
  DEFB 104                ;
  DEFB 4                  ; Vertical guardian 2: x=10, initial y=8, 5<=y<104,
  DEFB 1                  ; initial y-increment=2
  DEFB 8                  ;
  DEFB 10                 ;
  DEFB 2                  ;
  DEFB 5                  ;
  DEFB 104                ;
  DEFB 5                  ; Vertical guardian 3: x=20, initial y=8, 5<=y<104,
  DEFB 2                  ; initial y-increment=4
  DEFB 8                  ;
  DEFB 20                 ;
  DEFB 4                  ;
  DEFB 5                  ;
  DEFB 104                ;
  DEFB 6                  ; Vertical guardian 4: x=25, initial y=8, 5<=y<104,
  DEFB 3                  ; initial y-increment=1
  DEFB 8                  ;
  DEFB 25                 ;
  DEFB 1                  ;
  DEFB 5                  ;
  DEFB 104                ;
  DEFB 255                ; Terminator
; The next 6 bytes are unused.
  DEFB 0,0,0,0,0,0        ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 3,192,14,112,19,200,49,140    ; Guardian graphic data
  DEFB 57,156,95,250,141,178,132,164 ;
  DEFB 73,36,41,18,36,137,66,73      ;
  DEFB 130,82,4,144,8,136,0,64       ;
  DEFB 3,192,14,112,19,200,49,140    ;
  DEFB 57,156,95,250,77,177,133,17   ;
  DEFB 132,146,72,164,41,36,41,18    ;
  DEFB 68,137,2,72,2,80,4,0          ;
  DEFB 3,192,14,112,19,200,49,140    ;
  DEFB 57,156,95,250,77,177,68,145   ;
  DEFB 130,73,130,74,68,148,37,36    ;
  DEFB 41,34,8,144,4,72,0,64         ;
  DEFB 3,192,14,112,19,200,49,140    ;
  DEFB 57,156,95,250,77,178,41,18    ;
  DEFB 36,145,66,73,130,74,132,74    ;
  DEFB 72,145,9,32,9,0,0,128         ;
  DEFB 12,0,12,0,12,0,12,0           ;
  DEFB 12,0,12,0,12,0,12,0           ;
  DEFB 12,0,12,0,255,192,12,0        ;
  DEFB 97,128,210,192,179,64,97,128  ;
  DEFB 3,0,3,0,3,0,3,0               ;
  DEFB 3,0,3,0,3,0,3,0               ;
  DEFB 3,0,3,0,63,240,3,0            ;
  DEFB 24,96,36,208,60,208,24,96     ;
  DEFB 0,192,0,192,0,192,0,192       ;
  DEFB 0,192,0,192,0,192,0,192       ;
  DEFB 0,192,0,192,15,252,0,192      ;
  DEFB 6,24,11,52,13,44,6,24         ;
  DEFB 0,48,0,48,0,48,0,48           ;
  DEFB 0,48,0,48,0,48,0,48           ;
  DEFB 0,48,0,48,3,255,0,48          ;
  DEFB 1,134,2,77,3,205,1,134        ;

; Solar Power Generator (teleport: 256)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
CAVERN18:
  DEFB 22,22,22,36,36,36,36,36 ; Attributes
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,32,32,36,36,36 ;
  DEFB 36,32,32,32,32,32,32,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 32,32,32,32,32,32,32,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,32,32,32,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,32,32,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,32,32,32 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 32,32,32,32,32,32,32,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,32,32,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,32,32,32,32,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 32,32,32,32,32,32,32,22 ;
  DEFB 22,36,36,36,36,36,36,38 ;
  DEFB 38,38,38,36,36,36,32,32 ;
  DEFB 32,32,32,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,22,22,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,36 ;
  DEFB 36,36,36,36,36,36,36,22 ;
  DEFB 22,22,22,32,32,32,32,32 ;
  DEFB 32,32,32,32,32,32,32,32 ;
  DEFB 32,32,32,32,32,32,32,22 ;
  DEFB 32,32,32,32,32,32,32,22 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "     Solar Power Generator      " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 36,0,0,0,0,0,0,0,0 ; Background
  DEFB 32,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor (unused)
  DEFB 22,34,255,136,255,34,255,136,255 ; Wall
  DEFB 38,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 68,68,40,148,81,53,214,88,16 ; Nasty 1 (unused)
  DEFB 5,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 160                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 0                  ; Direction and movement flags: facing right (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23886              ; Location in the attribute buffer at 23552: (10,14)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 0                  ; Direction (left)
  DEFW 30855              ; Location in the screen buffer at 28672: (12,7)
  DEFB 4                  ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 3                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 35                 ; Item 1 at (1,30)
  DEFW 23614              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 36                 ; Item 2 at (5,1)
  DEFW 23713              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 37                 ; Item 3 at (12,30)
  DEFW 23966              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255,255,255,255,255 ; Item 4 (unused)
  DEFB 0,255,255,255,255  ; Item 5 (unused)
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 78                 ; Attribute
  DEFB 255,255,128,1,191,253,160,5   ; Graphic data
  DEFB 175,245,168,21,171,213,170,85 ;
  DEFB 170,85,171,213,168,21,175,245 ;
  DEFB 160,5,191,253,128,1,255,255   ;
  DEFW 23585              ; Location in the attribute buffer at 23552: (1,1)
  DEFW 24609              ; Location in the screen buffer at 24576: (1,1)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 240                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 38                 ; Horizontal guardian 1: y=3, initial x=24,
  DEFW 23672              ; 23<=x<=29, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 119                ;
  DEFB 125                ;
  DEFB 33                 ; Horizontal guardian 2: y=6, initial x=28,
  DEFW 23772              ; 22<=x<=29, speed=normal
  DEFB 96                 ;
  DEFB 0                  ;
  DEFB 214                ;
  DEFB 221                ;
  DEFB 162                ; Horizontal guardian 3: y=9, initial x=29,
  DEFW 23869              ; 23<=x<=29, speed=slow
  DEFB 104                ;
  DEFB 7                  ;
  DEFB 55                 ;
  DEFB 61                 ;
  DEFB 38                 ; Horizontal guardian 4: y=13, initial x=16,
  DEFW 23984              ; 13<=x<=29, speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 173                ;
  DEFB 189                ;
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 38                 ; Vertical guardian 1: x=5, initial y=64, 2<=y<102,
  DEFB 0                  ; initial y-increment=3
  DEFB 64                 ;
  DEFB 5                  ;
  DEFB 3                  ;
  DEFB 2                  ;
  DEFB 102                ;
  DEFB 34                 ; Vertical guardian 2: x=11, initial y=56, 48<=y<102,
  DEFB 1                  ; initial y-increment=-2
  DEFB 56                 ;
  DEFB 11                 ;
  DEFB 254                ;
  DEFB 48                 ;
  DEFB 102                ;
  DEFB 33                 ; Vertical guardian 3: x=16, initial y=80, 4<=y<80,
  DEFB 2                  ; initial y-increment=1
  DEFB 80                 ;
  DEFB 16                 ;
  DEFB 1                  ;
  DEFB 4                  ;
  DEFB 80                 ;
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 3,64,15,112,63,60,63,76       ; Guardian graphic data
  DEFB 95,102,95,118,159,127,0,127   ;
  DEFB 142,0,142,255,70,254,64,242   ;
  DEFB 32,4,48,12,12,48,2,192        ;
  DEFB 3,192,15,240,63,172,63,204    ;
  DEFB 95,198,71,182,153,191,158,127 ;
  DEFB 142,127,141,159,69,230,65,242 ;
  DEFB 32,4,48,12,12,48,3,192        ;
  DEFB 3,192,15,240,47,188,55,200    ;
  DEFB 91,230,93,230,158,223,158,63  ;
  DEFB 140,127,139,127,71,190,65,194 ;
  DEFB 0,4,48,4,12,48,3,192          ;
  DEFB 3,192,11,240,61,188,61,204    ;
  DEFB 93,230,94,244,158,227,158,31  ;
  DEFB 136,127,135,127,7,126,65,178  ;
  DEFB 32,4,48,12,12,16,3,192        ;
  DEFB 6,0,12,0,24,0,56,0            ;
  DEFB 116,0,202,128,133,192,3,192   ;
  DEFB 6,64,206,192,216,64,255,192   ;
  DEFB 226,0,200,128,213,64,8,128    ;
  DEFB 1,128,3,0,6,0,14,0            ;
  DEFB 29,0,50,160,33,112,0,240      ;
  DEFB 1,144,99,176,102,16,127,240   ;
  DEFB 120,128,98,32,101,80,2,32     ;
  DEFB 0,96,0,192,1,128,3,128        ;
  DEFB 7,64,12,168,8,92,0,60         ;
  DEFB 0,100,48,236,49,132,63,252    ;
  DEFB 62,32,48,136,49,84,0,136      ;
  DEFB 0,24,0,48,0,96,0,224          ;
  DEFB 1,208,3,42,2,23,0,15          ;
  DEFB 0,25,6,59,6,97,7,255          ;
  DEFB 7,136,6,34,6,85,0,34          ;

; The Final Barrier (teleport: 1256)
;
; Used by the routine at STARTGAME.
;
; The first 512 bytes are the attributes that define the layout of the cavern.
; The first 256 bytes here are also used by the routine at START when preparing
; the top third of the title screen.
CAVERN19:
  DEFB 44,34,34,34,34,34,44,40 ; Attributes
  DEFB 40,40,40,40,47,47,47,47 ;
  DEFB 47,40,40,40,40,40,46,50 ;
  DEFB 50,46,40,40,40,40,40,40 ;
  DEFB 44,34,34,34,34,34,44,40 ;
  DEFB 40,47,40,40,47,47,47,47 ;
  DEFB 47,40,40,40,40,40,58,56 ;
  DEFB 56,58,40,40,40,42,42,42 ;
  DEFB 44,34,34,22,34,44,46,46 ;
  DEFB 46,46,46,46,47,47,47,47 ;
  DEFB 47,46,43,46,43,46,58,56 ;
  DEFB 56,58,47,47,47,42,42,42 ;
  DEFB 40,44,44,22,44,46,46,46 ;
  DEFB 46,46,46,46,46,40,40,40 ;
  DEFB 44,44,44,44,44,44,58,58 ;
  DEFB 58,58,47,47,47,40,42,40 ;
  DEFB 40,47,40,22,40,46,46,46 ;
  DEFB 46,46,46,46,46,44,44,44 ;
  DEFB 38,38,38,38,38,38,38,38 ;
  DEFB 38,38,38,38,38,38,38,38 ;
  DEFB 40,44,44,22,44,46,46,46 ;
  DEFB 46,46,46,46,46,39,38,38 ;
  DEFB 38,38,38,0,0,38,0,0     ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 12,38,38,38,38,33,33,33 ;
  DEFB 14,14,33,33,33,39,38,38 ;
  DEFB 38,38,38,0,0,38,0,0     ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,38,38,38,38,38,38,38 ;
  DEFB 38,38,38,38,38,38,38,38 ;
  DEFB 38,38,38,0,0,38,0,0     ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,66,66,38      ;
  DEFB 38,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,5,5,5,5,5,5,5        ;
  DEFB 5,5,5,5,5,5,5,5         ;
  DEFB 5,5,5,5,5,5,5,0         ;
  DEFB 0,0,2,0,0,0,0,38        ;
  DEFB 38,0,0,0,0,0,0,0        ;
  DEFB 0,68,0,0,68,0,0,0       ;
  DEFB 0,68,0,0,0,68,0,0       ;
  DEFB 0,0,0,0,66,0,0,38       ;
  DEFB 38,66,66,0,0,0,0,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,0,0,0,0,66,66,0      ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,0,0,0,0,0,0,0        ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,0         ;
  DEFB 0,0,0,0,0,0,0,38        ;
  DEFB 38,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,66 ;
  DEFB 66,66,66,66,66,66,66,38 ;
; The next 32 bytes are copied to CAVERNNAME and specify the cavern name.
  DEFM "        The Final Barrier       " ; Cavern name
; The next 72 bytes are copied to BACKGROUND and contain the attributes and
; graphic data for the tiles used to build the cavern.
  DEFB 0,0,0,0,0,0,0,0,0  ; Background
  DEFB 66,255,255,219,110,197,64,0,0 ; Floor
  DEFB 2,255,219,165,36,82,32,8,0 ; Crumbling floor
  DEFB 38,34,255,136,255,34,255,136,255 ; Wall
  DEFB 5,240,102,240,102,0,153,255,0 ; Conveyor
  DEFB 68,16,16,214,56,214,56,84,146 ; Nasty 1
  DEFB 10,126,60,28,24,24,8,8,8 ; Nasty 2 (unused)
  DEFB 0,0,0,0,0,0,0,0,0  ; Extra (unused)
; The next seven bytes are copied to 32872-32878 and specify Miner Willy's
; initial location and appearance in the cavern.
  DEFB 208                ; Pixel y-coordinate * 2 (see PIXEL_Y)
  DEFB 0                  ; Animation frame (see FRAME)
  DEFB 1                  ; Direction and movement flags: facing left (see
                          ; DMFLAGS)
  DEFB 0                  ; Airborne status indicator (see AIRBORNE)
  DEFW 23995              ; Location in the attribute buffer at 23552: (13,27)
                          ; (see LOCATION)
  DEFB 0                  ; Jumping animation counter (see JUMPING)
; The next four bytes are copied to CONVDIR and specify the direction, location
; and length of the conveyor.
  DEFB 1                  ; Direction (right)
  DEFW 30785              ; Location in the screen buffer at 28672: (10,1)
  DEFB 22                 ; Length
; The next byte is copied to BORDER and specifies the border colour.
  DEFB 2                  ; Border colour
; The next byte is copied to ITEMATTR, but is not used.
  DEFB 0                  ; Unused
; The next 25 bytes are copied to ITEMS and specify the location and initial
; colour of the items in the cavern.
  DEFB 3                  ; Item 1 at (5,23)
  DEFW 23735              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 4                  ; Item 2 at (6,30)
  DEFW 23774              ;
  DEFB 96                 ;
  DEFB 255                ;
  DEFB 5                  ; Item 3 at (11,10)
  DEFW 23914              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 6                  ; Item 4 at (11,14)
  DEFW 23918              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 3                  ; Item 5 at (11,19)
  DEFW 23923              ;
  DEFB 104                ;
  DEFB 255                ;
  DEFB 255                ; Terminator
; The next 37 bytes are copied to PORTAL and define the portal graphic and its
; location.
  DEFB 30                 ; Attribute
  DEFB 0,0,7,224,24,24,35,196   ; Graphic data
  DEFB 68,34,72,18,72,18,72,18  ;
  DEFB 68,34,34,68,26,88,74,82  ;
  DEFB 122,94,66,66,126,126,0,0 ;
  DEFW 23731              ; Location in the attribute buffer at 23552: (5,19)
  DEFW 24755              ; Location in the screen buffer at 24576: (5,19)
; The next eight bytes are copied to ITEM and define the item graphic.
  DEFB 48,72,136,144,104,4,10,4 ; Item graphic data
; The next byte is copied to AIR and specifies the initial air supply in the
; cavern.
  DEFB 63                 ; Air
; The next byte is copied to CLOCK and initialises the game clock.
  DEFB 252                ; Game clock
; The next 28 bytes are copied to HGUARDS and define the horizontal guardians.
  DEFB 70                 ; Horizontal guardian 1: y=13, initial x=7, 7<=x<=22,
  DEFW 23975              ; speed=normal
  DEFB 104                ;
  DEFB 0                  ;
  DEFB 167                ;
  DEFB 182                ;
  DEFB 255,0,0,0,0,0,0    ; Horizontal guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Horizontal guardian 4 (unused)
  DEFB 255                ; Terminator
; The next two bytes are copied to EUGDIR and EUGHGT but are not used.
  DEFB 0,0                ; Unused
; The next 28 bytes are copied to VGUARDS and define the vertical guardians.
  DEFB 7                  ; Vertical guardian 1: x=24, initial y=48, 40<=y<103,
  DEFB 0                  ; initial y-increment=1
  DEFB 48                 ;
  DEFB 24                 ;
  DEFB 1                  ;
  DEFB 40                 ;
  DEFB 103                ;
  DEFB 255,0,0,0,0,0,0    ; Vertical guardian 2 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 3 (unused)
  DEFB 0,0,0,0,0,0,0      ; Vertical guardian 4 (unused)
; The next 7 bytes are unused.
  DEFB 0,0,0,0,0,0,0      ; Unused
; The next 256 bytes are copied to GGDATA and define the guardian graphics.
  DEFB 0,0,0,0,0,0,3,192             ; Guardian graphic data
  DEFB 12,48,16,8,32,4,64,2          ;
  DEFB 128,1,64,2,32,4,208,11        ;
  DEFB 44,52,75,210,18,72,2,64       ;
  DEFB 0,0,0,0,0,0,3,192             ;
  DEFB 12,48,16,8,32,4,64,2          ;
  DEFB 248,31,87,234,43,212,18,72    ;
  DEFB 12,48,3,192,0,0,0,0           ;
  DEFB 4,32,4,32,18,72,75,210        ;
  DEFB 44,52,147,201,167,229,70,98   ;
  DEFB 134,97,71,226,35,196,16,8     ;
  DEFB 12,48,3,192,0,0,0,0           ;
  DEFB 0,0,0,0,0,0,3,192             ;
  DEFB 12,48,18,72,42,84,95,250      ;
  DEFB 246,127,71,226,35,196,16,8    ;
  DEFB 12,48,3,192,0,0,0,0           ;
  DEFB 18,0,12,0,30,0,191,64         ;
  DEFB 115,128,115,128,191,64,94,128 ;
  DEFB 76,128,82,128,127,128,12,0    ;
  DEFB 97,128,146,192,178,64,97,128  ;
  DEFB 3,0,7,128,7,128,28,224        ;
  DEFB 59,112,59,112,28,224,23,160   ;
  DEFB 23,160,19,32,31,224,3,0       ;
  DEFB 24,96,36,144,52,176,24,96     ;
  DEFB 1,224,1,224,1,32,14,220       ;
  DEFB 13,236,13,236,14,220,5,40     ;
  DEFB 5,232,5,232,7,248,0,192       ;
  DEFB 6,24,13,36,9,52,6,24          ;
  DEFB 0,120,0,72,0,48,3,123         ;
  DEFB 2,253,2,253,3,123,1,50        ;
  DEFB 1,74,1,122,1,254,0,48         ;
  DEFB 1,134,2,205,2,73,1,134        ;

                END BEGIN
