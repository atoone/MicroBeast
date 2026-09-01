#
# MicroBeast firmware build (Linux/macOS replacement for build.bat)
#
# Requires: tasm 3.2.x, globber, python3, and a CP/M disk image at cpm/microbeast.img
#
# Usage:
#   make                 build everything into build/
#   make flash           build only the combined flash image
#   make clean           remove intermediates (listings, object files)
#   make VERSION=1.9     build a differently-versioned flash image
#

# ---------------------------------------------------------------- configuration

TASM        ?= $(HOME)/.local/bin/tasm
TASMTABS    ?= $(HOME)/.local/share/tasm
GLOBBER     ?= $(HOME)/.local/bin/globber
PYTHON      ?= python3

# Firmware version, and the physical page the .bin/.img are loaded at when
# transferring them to MicroBeast over Y-Modem (see build/README.md). Both
# appear in the output file names.
#
# Note that build/flash.glob names firmware_p25.bin literally, so changing
# PAGE means editing that script too.
VERSION     ?= 1.8
PAGE        ?= 25

export TASMTABS

TASMFLAGS   := -t80

BUILD       := build
VERSION_TAG := $(subst .,_,$(VERSION))

# ---------------------------------------------------------------------- sources

# Shared between the BIOS, the monitor and the firmware.
COMMON_SRC  := common_data.asm ports.asm keyboard.inc uart.asm flash.asm \
               $(wildcard micro/*.asm) $(wildcard nano/*.asm)

BIOS_SRC    := $(wildcard beastos/*.asm) beastos/beastos.inc $(COMMON_SRC)

MONITOR_SRC := $(wildcard monitor/*.asm) \
               beastos/beastos.inc beastos/system_vars.asm $(COMMON_SRC)

FIRMWARE_SRC := firmware.asm firmware_vars.asm boot_seq.asm memory_test.asm \
                rtc_options.asm beastos/beastos.inc beastos/display.asm \
                beastos/font.asm $(COMMON_SRC)

# ---------------------------------------------------------------------- outputs

FIRMWARE_BIN := $(BUILD)/firmware_p$(PAGE).bin
FLASH_BIN    := $(BUILD)/flash_v$(VERSION).bin
BIOS_INC     := $(BUILD)/bios.inc
NANO_INC     := $(BUILD)/nano_patch.inc
MONITOR_INC  := $(BUILD)/monitor.inc

ARTEFACTS := $(FLASH_BIN) \
             $(BUILD)/bios_$(VERSION_TAG).inc \
             $(BUILD)/bootdisk_p$(PAGE).img

.PHONY: all flash clean help

all: $(ARTEFACTS)

flash: $(FLASH_BIN)

# ------------------------------------------------------------------ BeastOS BIOS

beastos/bios.obj: $(BIOS_SRC) | $(BUILD)
	cd beastos && $(TASM) $(TASMFLAGS) bios.asm bios.obj ../$(BUILD)/bios.lst

$(BIOS_INC): beastos/bios.obj
	$(PYTHON) hex2inc.py $< $@

# The Nanobeast BIOS is the same source assembled with NANO_BIOS defined; only
# the part that differs from the MicroBeast build is shipped, as a patch.
#
# nano.asm carries its own ".DEFINE NANO_BIOS"; the -d flag is needed as well
# before .IFNDEF will see it. The "=1" matters: with a bare "-dNANO_BIOS" the
# redefinition makes tasm free a pointer it does not own, which glibc catches
# and aborts on (build.bat gets away with it on Windows).
beastos/nano.obj: $(BIOS_SRC) | $(BUILD)
	cd beastos && $(TASM) $(TASMFLAGS) -dNANO_BIOS=1 nano.asm nano.obj ../$(BUILD)/nano.lst

beastos/nano_patch.obj: beastos/bios.obj beastos/nano.obj
	$(PYTHON) split_diff.py $^ $@

$(NANO_INC): beastos/nano_patch.obj
	$(PYTHON) hex2inc.py $< $@

# ---------------------------------------------------------------------- monitor

monitor/monitor.obj: $(MONITOR_SRC) | $(BUILD)
	cd monitor && $(TASM) $(TASMFLAGS) monitor.asm monitor.obj ../$(BUILD)/monitor.lst

$(MONITOR_INC): monitor/monitor.obj
	$(PYTHON) hex2inc.py $< $@

# --------------------------------------------------------------------- firmware

$(FIRMWARE_BIN): $(FIRMWARE_SRC) $(BIOS_INC) $(NANO_INC) $(MONITOR_INC) | $(BUILD)
	$(TASM) $(TASMFLAGS) -b -dFIRMWARE=1 firmware.asm $@ $(BUILD)/firmware.lst

# Flash image: firmware padded to 64K, then the CP/M disk appended. The layout
# lives in build/flash.glob; globber runs from build/ because that script's
# paths are relative to it.
$(FLASH_BIN): $(FIRMWARE_BIN) cpm/microbeast.img $(BUILD)/flash.glob
	cd $(BUILD) && $(GLOBBER) flash.glob $(notdir $@)

# ------------------------------------------------------------- shipped copies

$(BUILD)/bios_$(VERSION_TAG).inc: beastos/beastos.inc | $(BUILD)
	cp $< $@

$(BUILD)/bootdisk_p$(PAGE).img: cpm/microbeast.img | $(BUILD)
	cp $< $@

$(BUILD):
	mkdir -p $@

# ------------------------------------------------------------------------ misc

clean:
	rm -f beastos/*.obj monitor/*.obj *.obj \
	      beastos/*.lst monitor/*.lst *.lst \
	      $(BUILD)/*.lst $(BIOS_INC) $(NANO_INC)

help:
	@echo "Targets: all (default), flash, clean"
	@echo "Variables: VERSION=$(VERSION) PAGE=$(PAGE)"
	@echo "           TASM=$(TASM) TASMTABS=$(TASMTABS) GLOBBER=$(GLOBBER)"
