cd beastos
tasm -t80 monitor.asm
tasm -t80 bios.asm
python ..\hex2inc.py monitor.obj
move monitor.inc ..\build\.
python ..\hex2inc.py bios.obj
move bios.inc ..\build\.
cd ..
tasm -t80 -b firmware.asm build\firmware_p25.bin
cd build
globber flash.glob flash_v1.8.bin
cd ..

copy beastos\beastos.inc build\bios_1_8.inc
copy cpm\microbeast.img build\bootdisk_p25.img
copy firmware.lst build\firmware.lst
copy beastos\monitor.lst build\monitor.lst
copy beastos\bios.lst build\bios.lst
