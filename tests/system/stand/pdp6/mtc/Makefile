PROJECT_ROOT ?= $(abspath $(DAIMOS_REPO))
BUILD ?= $(PROJECT_ROOT)/build/tests/system/stand/pdp6/mtc
STAT_INIT_BASE = 030000

include ../bin/stat.mk

BOOT_KIND = MTC
TEST_NAME = mtc-v5
STAGE1 = $(PROJECT_ROOT)/system/stand/pdp6/mtc/stage1.s
STAGE1_COMMON_DEPS = $(PROJECT_ROOT)/system/stand/pdp6/common/decompressor.inc
STAGE1_ENTRY = 060000
STAGE1_DXR = $(BUILD)/stage1-mtc-v5.dxr
STAGE1_TAPE = $(BUILD)/stage1-mtc-v5.pt
RAW_PAYLOAD_WORDS = $(BUILD)/payload-v5.raw.words
COMP_PAYLOAD_WORDS = $(BUILD)/payload-v5.d6lz.words
MTC_WORDS = $(BUILD)/mtc-v5.words
PAYLOAD_TAPE = $(BUILD)/payload-v5.tap
SIMH_INI = $(BUILD)/simh-v5.ini
SIMH_TEMPLATE = simh-v1.ini.in
SIMH_SED_EXTRA =

$(RAW_PAYLOAD_WORDS): $(STAT_WORDS) | $(BUILD)
	tail -n +3 $< > $@
	test `wc -l < $@` -eq $$(( $(STAT_INIT_WORDS) ))

D6LZ ?= $(PDP10_PREFIX)/bin/d6lz

$(COMP_PAYLOAD_WORDS): $(RAW_PAYLOAD_WORDS) $(D6LZ) | $(BUILD)
	$(D6LZ) -t $< $@

$(MTC_WORDS): $(STAT_WORDS) $(COMP_PAYLOAD_WORDS) | $(BUILD)
	@cwords=`wc -l < $(COMP_PAYLOAD_WORDS) | tr -d ' '`; \
	{ head -n 2 $(STAT_WORDS); printf '%06o%06o\n' $$cwords 0; cat $(COMP_PAYLOAD_WORDS); } > $@

$(PAYLOAD_TAPE): $(MTC_WORDS) $(MKTAP)
	$(MKTAP) -t mtc -p $(MTC_WORDS) -o $@

include ../bin/boot-test.mk
