# Updating Firmware

To update the firmware on MicroBeast, you have two options from the Monitor:

1. Use the file `firmware_p24.bin` which just updates the BIOS and CP/M, but NOT the CP/M disk image.
To use this, go to `Y-Modem -> Address from file` and transfer the file - you should then be able to choose
`Update firmware` to write the new version to flash.

1. Use the file `flash_v1.x.bin` which updates both the BIOS, CP/M AND the CP/M disk image. To use this, go
to `Y-Modem -> Physical Address`, and enter `24` for the page number, then `0000` for the offset (i.e. load
it to RAM above the current BIOS). Once you've transferred the file, select `Write to flash` and when it asks
for a page number type `00` - i.e. write the file from the start of Flash memory.

With either option, you should get a `Done` message, and can then reboot MicroBeast

Note that firmware files have a name and firmware version in the first 32 bytes or so of the file, so you 
can always check which version you've got by looking at the `.bin` files with a hex viewer on your PC.
