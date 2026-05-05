cd beastos
tasm -t80 bios.asm
@if %errorlevel% neq 0 (
    cd ..
    exit /b %errorlevel%
    )
@python ..\hex2inc.py bios.obj ..\build\bios.inc

tasm -t80 -dNANO_BIOS nano.asm
@if %errorlevel% neq 0 (
    cd ..
    exit /b %errorlevel%
    )
@python ..\split_diff.py bios.obj nano.obj nano_patch.obj
@python ..\hex2inc.py nano_patch.obj ..\build\nano_patch.inc

cd ..\monitor
tasm -t80 monitor.asm
@if %errorlevel% neq 0 (
    cd ..
    exit /b %errorlevel%
    )
@python ..\hex2inc.py monitor.obj ..\build\monitor.inc

cd ..
tasm -t80 -b -dFIRMWARE firmware.asm build\firmware_p25.bin
@if %errorlevel% neq 0 (
    exit /b %errorlevel%
    )
@cd build
globber flash.glob flash_v1.8.bin
@cd ..

@ECHO off
copy beastos\beastos.inc build\bios_1_8.inc
copy cpm\microbeast.img build\bootdisk_p25.img
copy firmware.lst build\firmware.lst
copy monitor\monitor.lst build\monitor.lst
copy beastos\bios.lst build\bios.lst
