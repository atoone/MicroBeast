;
; Font definition
;
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

INVALID_CHAR_BITMASK    .EQU 04861h

font
                    .dw     0000h
                    .dw     4900h   ; !
                    .dw     0202h   ; "
                    .dw     12ceh   ; #
                    .dw     12edh   ; $
                    .dw     2de4h   ; %
                    .dw     0b59h   ; &
                    .dw     0200h   ; '
                    .dw     0c00h   ; (
                    .dw     2100h   ; )
                    .dw     3fc0h   ; *
                    .dw     12c0h   ; +
                    .dw     2000h   ; ,
                    .dw     00c0h   ; -
                    .dw     4000h   ; .
                    .dw     2400h   ; /

                    .dw     243fh   ; 0
                    .dw     0406h   ; 1
                    .dw     00dbh   ; 2
                    .dw     008fh   ; 3
                    .dw     00e6h   ; 4
                    .dw     0869h   ; 5
                    .dw     00fdh   ; 6
                    .dw     1401h   ; 7
                    .dw     00ffh   ; 8
                    .dw     00efh   ; 9
                    .dw     0040h   ; :
                    .dw     2200h   ; ;
                    .dw     0c40h   ; <
                    .dw     00c8h   ; = 
                    .dw     2180h   ; >
                    .dw     5083h   ; ?

                    .dw     02bbh   ; @
                    .dw     00f7h   ; A
                    .dw     128fh   ; B
                    .dw     0039h   ; C
                    .dw     120fh   ; D
                    .dw     0079h   ; E
                    .dw     0071h   ; F
                    .dw     00bdh   ; G
                    .dw     00f6h   ; H
                    .dw     1209h   ; I
                    .dw     001eh   ; J
                    .dw     0c70h   ; K
                    .dw     0038h   ; L
                    .dw     0536h   ; M
                    .dw     0936h   ; N
                    .dw     003fh   ; O

                    .dw     00f3h   ; P
                    .dw     083fh   ; Q
                    .dw     08f3h   ; R
                    .dw     00edh   ; S
                    .dw     1201h   ; T
                    .dw     003eh   ; U
                    .dw     2430h   ; V
                    .dw     2836h   ; W
                    .dw     2d00h   ; X
                    .dw     00eeh   ; Y
                    .dw     2409h   ; Z
                    .dw     0039h   ; [
                    .dw     0900h   ; \
                    .dw     000fh   ; ]
                    .dw     2800h   ; ^
                    .dw     0008h   ; _

                    .dw     0100h   ; `
                    .dw     208ch   ; a
                    .dw     0878h   ; b
                    .dw     00d8h   ; c
                    .dw     208eh   ; d 
                    .dw     2058h   ; e 
                    .dw     14c0h   ; f
                    .dw     048eh   ; g
                    .dw     1070h   ; h
                    .dw     1000h   ; i
                    .dw     2210h   ; j
                    .dw     1e00h   ; k
                    .dw     1200h   ; l
                    .dw     10d4h   ; m
                    .dw     1050h   ; n
                    .dw     00dch   ; o

                    .dw     0170h   ; p
                    .dw     0486h   ; q
                    .dw     0050h   ; r
                    .dw     0888h   ; s
                    .dw     0078h   ; t
                    .dw     001ch   ; u
                    .dw     2010h   ; v
                    .dw     2814h   ; w
                    .dw     2d00h   ; x
                    .dw     028eh   ; y
                    .dw     2048h   ; z
                    .dw     2149h   ; {
                    .dw     1200h   ; |
                    .dw     0c89h   ; }
                    .dw     24c0h   ; ~
                    .dw     0000h   ; 