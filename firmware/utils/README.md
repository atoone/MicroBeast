
## MicroBeast Disk Management

Use `RESTORE.COM` to fetch a CP\M disk image from Flash (Page `010h`) to RAM disk, "loading" the disk for use.

Use `WRITE.COM` to write the current RAM disk to Flash, "saving" it for later use.

## VideoBeast Support

Use `VPEEK.COM` to read and write VideoBeast memory and registers (requires VideoBeast expansion)

Use `VLOAD.COM` to load files into VideoBeast memory.

As an example, two fonts are included on the bootdisk, `INISGBYT.CH8` and `CUSHION.CH8`. Load them in place of the
standard font (which is at address `8100h`) by typing: `VLOAD CUSHION.CH8 x8100`

### Fonts

The included fonts are from DamienG - website here: https://damieng.com/typography/zx-origins/

## File Transfer

Use these utilities to send and receive CP/M files over a serial console. They turn a file into a block of hexadecimal text
that can be copied and pasted in most PC terminal software.

`DOWNLOAD.COM` is by Grant Searle - website here: http://searle.hostei.com/grant/index.html

`UPLOAD.COM` is by Peacock Media - https://blog.peacockmedia.software/2022/01/uploadcom-for-z80-cpm-usage.html

Online file converter for DOWLOAD.COM here: https://rc2014.co.uk/filepackage/

