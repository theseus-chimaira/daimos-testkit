TESTKIT_ROOT := $(abspath ../../..)
DAIMOS_REPO ?= ../DAIMOS
PROJECT_ROOT := $(abspath $(DAIMOS_REPO))
BUILD ?= $(TESTKIT_ROOT)/build/tests/system/kernel
PDP10_PREFIX ?= $(HOME)/cross
SIMH_PDP6 ?= $(PDP10_PREFIX)/bin/pdp6
D6FS_SPARE_BLOCKS ?= 0
HOST_CC ?= cc
HOST_CFLAGS ?= -std=c99 -O2 -Wall -Wextra
STDBUF ?= stdbuf
WATCH_OUTPUT := $(TESTKIT_ROOT)/tools/watch-output.sh
BOOT_DIR := $(PROJECT_ROOT)/system/boot/pdp6
SIMH_INI := $(BUILD)/boot.ini
SIMH_LOG := $(BUILD)/boot.simh.log
LOG := $(BUILD)/kinit-v1.log
HOST_CHECK := $(BUILD)/host-check-v1

.DEFAULT_GOAL := image
.PHONY: image minboot test clean

# Keep the testkit synchronized with the production disk-boot recipe.  The
# DAIMOS boot Makefile owns the kernel source manifest and MRES packaging;
# duplicating that list here made the testkit break whenever kernel files were
# renamed, split, or moved between KCORE and MRES.
image:
	$(MAKE) -C '$(BOOT_DIR)' image \
		BUILD='$(abspath $(BUILD))' BUILD_ROOT='$(abspath $(BUILD))/daimos-build' \
		PDP10_PREFIX='$(PDP10_PREFIX)' D6FS_SPARE_BLOCKS='$(D6FS_SPARE_BLOCKS)'

$(HOST_CHECK): host-check-v1.c | $(BUILD)
	$(HOST_CC) $(HOST_CFLAGS) -o '$@' '$<'

$(BUILD):
	mkdir -p '$@'

minboot: image
	$(SIMH_PDP6) '$(SIMH_INI)'

# A boot banner on CTY cannot prove that LOGIN/DSH reached the DCS0
# terminal. Exercise the real device and require two external commands.
test:
	@DAIMOS_REPO='$(PROJECT_ROOT)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		TMPDIR='$(TMPDIR)' BUILD='$(abspath $(BUILD))' \
		COMPILER='$(COMPILER)' SIMH_PDP6='$(SIMH_PDP6)' \
		HOST_CC='$(HOST_CC)' D6FS_SPARE_BLOCKS='$(D6FS_SPARE_BLOCKS)' \
		sh '$(CURDIR)/daimos-kernel-boot-dcs-v121.sh'

clean:
	$(MAKE) -C '$(BOOT_DIR)' clean BUILD='$(abspath $(BUILD))' \
		BUILD_ROOT='$(abspath $(BUILD))/daimos-build' PDP10_PREFIX='$(PDP10_PREFIX)' || true
	rm -rf '$(BUILD)'
