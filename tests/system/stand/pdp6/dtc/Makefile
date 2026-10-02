PROJECT_ROOT ?= $(abspath $(DAIMOS_REPO))
BUILD ?= $(PROJECT_ROOT)/build/tests/system/stand/pdp6/dtc
STAT_INIT_BASE = 030000

include ../bin/stat.mk

BOOT_KIND = DTC
TEST_NAME = dtc-v4
STAGE1 = $(PROJECT_ROOT)/system/stand/pdp6/dtc/stage1.s
STAGE1_COMMON_DEPS = $(PROJECT_ROOT)/system/stand/pdp6/common/decompressor.inc
STAGE1_ENTRY = 060000
STAGE1_DXR = $(BUILD)/stage1-dtc-v4.dxr
STAGE1_TAPE = $(BUILD)/stage1-dtc-v4.pt
DTC_WORDS = $(BUILD)/dtc-v4.words
RAW_WORDS = $(BUILD)/dtc-v4.raw.words
COMP_WORDS = $(BUILD)/dtc-v4.d6lz.words
PAYLOAD_TAPE = $(BUILD)/payload-v4.dt
SIMH_INI = $(BUILD)/simh-v4.ini
SIMH_TEMPLATE = simh-v1.ini.in
SIMH_SED_EXTRA =

D6LZ ?= $(PDP10_PREFIX)/bin/d6lz

$(RAW_WORDS): $(STAT_WORDS) | $(BUILD)
	tail -n +3 $(STAT_WORDS) > $@

$(COMP_WORDS): $(RAW_WORDS) $(D6LZ) | $(BUILD)
	$(D6LZ) -t $< $@

$(DTC_WORDS): $(STAT_WORDS) $(COMP_WORDS) | $(BUILD)
	@cwords=`wc -l < $(COMP_WORDS) | tr -d ' '`; \
	{ head -n 2 $(STAT_WORDS); printf '%06o%06o\n' $$cwords 0; cat $(COMP_WORDS); } > $@

$(PAYLOAD_TAPE): $(DTC_WORDS) $(MKDT)
	$(MKDT) -t dtc -p $(DTC_WORDS) -o $@

include ../bin/boot-test.mk
