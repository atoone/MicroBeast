cd ..
mkfs.cpm.exe -f memotech-type50 -b cpm\cpm22.bin cpm\microbeast.img

cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\pip.com 0:pip.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\stat.com 0:stat.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\kcalc.com 0:kcalc.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\sieve.com 0:sieve.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\mbasic_5_21.com 0:mbasic.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\zork1.com 0:zork1.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img cpmdisk\zork1.dat 0:zork1.dat

cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\upload.com 0:upload.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\download.com 0:download.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\write.com 0:write.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\restore.com 0:restore.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\setopts.com 0:setopts.com

cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\vload.com 0:vload.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\vpeek.com 0:vpeek.com
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\cushion.ch8 0:cushion.ch8
cpmcp.exe -f memotech-type50 cpm\microbeast.img utils\insigbyt.ch8 0:insigbyt.ch8

cpmls.exe -f memotech-type50 cpm\microbeast.img

cd cpm
