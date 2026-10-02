PROJECT_ROOT ?= $(abspath $(DAIMOS_REPO))
BUILD ?= $(PROJECT_ROOT)/build/tests/system/stand/pdp6/ptr
STAT_INIT_BASE = 030000

include ../bin/stat.mk

BOOT_KIND = PTR
TEST_NAME = ptr-two-tape-v2
STAGE1 = $(PROJECT_ROOT)/system/stand/pdp6/ptr/stage1.s
STAGE1_COMMON_DEPS = $(PROJECT_ROOT)/system/stand/pdp6/common/decompressor.inc \
	$(PROJECT_ROOT)/system/stand/pdp6/common/sixbit-fixed.inc
STAGE1_ENTRY = 060000
STAGE1_DXR = $(BUILD)/stage1-ptr-two-tape-v2.dxr
STAGE1_TAPE = $(BUILD)/stage1-ptr-two-tape-v2.pt

RAW_WORDS = $(BUILD)/payload-v2.raw.words
COMP_WORDS = $(BUILD)/payload-v2.d6lz.words

TAPE1_WORDS = $(BUILD)/tape1-v2.words
TAPE2_WORDS = $(BUILD)/tape2-v2.words
TAPE1 = $(BUILD)/tape1-v2.pt
TAPE2 = $(BUILD)/tape2-v2.pt
SIMH_INI = $(BUILD)/simh-v2.ini
SIMH_TEMPLATE = simh-v1.ini.in

.DEFAULT_GOAL := build

.PHONY: build image test clean

$(STAGE1_DXR): $(STAGE1) | $(BUILD)
	$(DAS) -k -o $@ $<

$(STAGE1_TAPE): $(STAGE1_DXR)
	$(DXRCONVERT) --pdp6-readin -b $(STAGE1_ENTRY) $< $@

D6LZ ?= $(PDP10_PREFIX)/bin/d6lz

$(RAW_WORDS): $(STAT_WORDS) | $(BUILD)
	tail -n +3 $< > $@

$(COMP_WORDS): $(RAW_WORDS) $(D6LZ) | $(BUILD)
	$(D6LZ) -t $< $@

$(TAPE1_WORDS) $(TAPE2_WORDS) &: $(STAT_WORDS) $(COMP_WORDS) | $(BUILD)
	@set -eu; \
	cwords=`wc -l < $(COMP_WORDS) | tr -d ' '`; \
	first=$$(( (cwords + 1) / 2 )); second=$$(( cwords - first )); \
	test $$first -gt 0; test $$second -gt 0; \
	{ printf '%012o\n' $$((first + 3)); head -n 2 $(STAT_WORDS); \
	  printf '%06o%06o\n' $$cwords 0; head -n $$first $(COMP_WORDS); } > $(TAPE1_WORDS); \
	{ printf '%012o\n' $$second; tail -n +$$((first + 1)) $(COMP_WORDS); } > $(TAPE2_WORDS)

$(TAPE1): $(TAPE1_WORDS) $(WORDS2PT)
	$(WORDS2PT) -t ptr -p $< -o $@

$(TAPE2): $(TAPE2_WORDS) $(WORDS2PT)
	$(WORDS2PT) -t ptr -p $< -o $@

$(SIMH_INI): $(SIMH_TEMPLATE) $(STAGE1_TAPE) $(TAPE1) $(TAPE2) | $(BUILD)
	sed -e 's|@SIMH_LOG@|$(BUILD)/$(TEST_NAME).simh.log|g' \
	    -e 's|@STAGE1_TAPE@|$(STAGE1_TAPE)|g' \
	    -e 's|@TAPE1@|$(TAPE1)|g' \
	    -e 's|@TAPE2@|$(TAPE2)|g' \
	    -e 's|@STAGE1_ENTRY@|$(STAGE1_ENTRY)|g' \
	    $(SIMH_TEMPLATE) > $@

image: $(STAGE1_TAPE) $(TAPE1) $(TAPE2) $(SIMH_INI)
build: image

test: image
	@log="$(BUILD)/$(TEST_NAME).log"; \
	simhlog="$(BUILD)/$(TEST_NAME).simh.log"; \
	echo "$(BOOT_KIND) $(TEST_NAME)"; \
	start=$$(date +%s); \
	timeout -k 2s $(TIMEOUT) $(SIMH_PDP6) $(SIMH_INI) < /dev/null > "$$log" 2>&1; \
	rc=$$?; reason=; \
	if test "$$rc" -ne 0; then reason="SIMH exit $$rc"; fi; \
	if test -z "$$reason" && ! grep -F "TAPE2" "$$log" >/dev/null; then reason="missing TAPE2"; fi; \
	if test -z "$$reason" && ! grep -F "BOOTLOADER OK" "$$log" >/dev/null; then reason="missing BOOTLOADER OK"; fi; \
	if test -z "$$reason" && ! grep -F "TEST  DONE" "$$log" >/dev/null; then reason="missing TEST DONE"; fi; \
	end=$$(date +%s); elapsed=$$((end - start)); \
	if test -n "$$reason"; then \
	  test -z "$$TEST_REPORT_DETAIL" || printf '%-6s %-4s %-18s %7ss  %s; log=%s\n' FAIL $(BOOT_KIND) $(TEST_NAME) "$$elapsed" "$$reason" "$$log" >> "$$TEST_REPORT_DETAIL"; \
	  echo "$(BOOT_KIND) $(TEST_NAME) failed: $$reason"; cat "$$log"; test ! -f "$$simhlog" || cat "$$simhlog"; exit 1; \
	fi; \
	test -z "$$TEST_REPORT_DETAIL" || printf '%-6s %-4s %-18s %7ss  two-tape handoff verified\n' PASS $(BOOT_KIND) $(TEST_NAME) "$$elapsed" >> "$$TEST_REPORT_DETAIL"

clean:
	rm -rf $(BUILD)

.DELETE_ON_ERROR:
