;
; Register the NANO_BIOS macro
;
; Note - there's an apparent bug in TASM that requires this is used *as well as* the
; matching command line parameter -dFIRMWARE to force the macro to be recognised
; by .IFDEF or .IFNDEF directives.
;
; To get round this, we wrap bios.asm with this file so that we can do conditional
; assembly. No, I'm not happy about it either.
;

.DEFINE NANO_BIOS
                .INCLUDE bios.asm