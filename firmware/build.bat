cd beastos
tasm -t80 monitor.asm
python ..\hex2inc.py monitor.obj
move monitor.inc ..\build\.
cd ..
tasm -t80 -b firmware.asm build\firmware_p24.bin
cd build
globber flash.glob flash_v1.6.bin
cd ..
copy beastos\bios.inc build\.
