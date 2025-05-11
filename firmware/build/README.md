# Updating Firmware

To update the firmware on MicroBeast, you have two options from the Monitor:

1. Transfer the file `flash_v1.x.bin` which updates both the BIOS, CP/M AND the CP/M disk image. To transfer over
the serial connection, go to `Y-Modem -> Physical Address` in the Monitor menu, and enter `25` for the page 
number, then `0000` for the offset (i.e. load it to RAM above the current BIOS).

In your PC terminal program, send the file as normal.

Once you've transferred the file, select `Write to flash` and when it asks for a page number type `00` - i.e. write the file from the start of Flash memory.

2. OR: Use the files `firmware_p25.bin` and `bootdisk_p25.img` which update the BIOS and CP/M boot disk respectively.
If you are upgrading to version 1.6, you **must** upgrade both.

To do this, go to `Y-Modem -> Address from file` in the Monitor menu and transfer `firmware_p25.bin` - you should 
then be able to choose `Update firmware` to write the new version to flash. Then repeat `Y-Modem -> Address from file` and 
transfer `firmware_p25.bin` - this time select `Write Flash` and enter a page number of `04` to write the boot disk
to the correct location in the Flash ROM.

With either option, you should get a `Done` message, and can then reboot MicroBeast

Note that firmware files have a name and firmware version in the first 32 bytes or so of the file, so you 
can always check which version you've got by looking at the `.bin` files with a hex viewer on your PC.
