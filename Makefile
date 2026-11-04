.PHONY: test-dxr2-st2-v1070 test-kcc-excluded-long-directive-v1070
test-dxr2-st2-v1070:
	@DAS_REPO='$(DAS_REPO)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/dxr2-st2-v1070.sh

test-kcc-excluded-long-directive-v1070:
	@KCC_CC='$(KCC_CC)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/kcc-excluded-long-directive-v1070.sh

.PHONY: test-daimos-kcore-swap-input-deps-v1063
test-daimos-kcore-swap-input-deps-v1063:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    sh tests/validation/daimos-kcore-swap-input-deps-v1063.sh

.PHONY: test-daimos-make-lazy-depth-v1054
test-daimos-make-lazy-depth-v1054: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    DAIMOS_MAKE_BOOT_INI='$(DAIMOS_MAKE_BOOT_INI)' \
	    PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-make-lazy-depth-v1054.sh

.PHONY: test-daimos-simh-console-pc-v1048
test-daimos-simh-console-pc-v1048: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-simh-console-pc-v115.sh

.PHONY: test-daimos-gcc-packed-heading-v1043
test-daimos-gcc-packed-heading-v1043: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/target/daimos-gcc-help-heading-v154/run.sh

.PHONY: test-daimos-dsh-image-provenance-v1043
test-daimos-dsh-image-provenance-v1043:
	@TMPDIR='$(TMPDIR)' sh tests/validation/check-dsh-image-provenance-v1043.sh

.PHONY: test-daimos-simh-ptr-tsfs-evidence-v1042
test-daimos-simh-ptr-tsfs-evidence-v1042: check-prefix
	@test -n '$(PTR_TSFS_BUILD)' && test -n '$(PTR_TSFS_LOG)' || { \
	    echo 'Set PTR_TSFS_BUILD and PTR_TSFS_LOG from a completed real SIMH PTR/TSFS boot' >&2; exit 2; }
	@PATH='$(PDP10_PREFIX)/bin':$$PATH python3 \
	    tests/validation/daimos-simh-ptr-tsfs-evidence-v1042.py \
	    --repo '$(abspath $(DAIMOS_REPO))' \
	    --build '$(abspath $(PTR_TSFS_BUILD))' --log '$(abspath $(PTR_TSFS_LOG))'

.PHONY: test-daimos-vfs-parent-ac3-v1037
test-daimos-vfs-parent-ac3-v1037: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-vfs-parent-ac3-v1037.sh

.PHONY: test-daimos-monitorfs-compiler-v1033
test-daimos-monitorfs-compiler-v1033: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-monitorfs-compiler-v1033.sh

.PHONY: test-daimos-mm-descriptor-capacity-v1030
test-daimos-mm-descriptor-capacity-v1030: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    sh tests/native-kernel/mm/capacity-v125/run-v125.sh

.PHONY: test-simh-pdp6-go-pc-v155
test-simh-pdp6-go-pc-v155: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/check-simh-pdp6-go-pc-v155.sh

.PHONY: test-daimos-dsh-uppercase-literals-v1016
test-daimos-dsh-uppercase-literals-v1016:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    sh tests/host/daimos-dsh-literal-contract-v1016.sh

.PHONY: test-daimos-tsfs-auxstore-swap-v494
test-daimos-tsfs-auxstore-swap-v494: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    DAS_REPO='$(abspath $(DAS_REPO))' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-tsfs-auxstore-swap-v494.sh

.PHONY: test-daimos-tsfs-auxstore-positive-v493
test-daimos-tsfs-auxstore-positive-v493: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-tsfs-auxstore-positive-v493.sh

.PHONY: test-daimos-auxstore-choice-v492
test-daimos-auxstore-choice-v492:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
	    sh tests/validation/daimos-auxstore-choice-v492.sh

.PHONY: test-daimos-tsfs-swapless-minit-v490
test-daimos-tsfs-swapless-minit-v490: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-tsfs-swapless-minit-v490.sh

.PHONY: test-daimos-file-rename-native-v457
test-daimos-file-rename-native-v457: check-prefix
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-file-rename-native-v457.sh

.PHONY: test-daimos-vfs-rename-native-v455
test-daimos-vfs-rename-native-v455: check-prefix
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-vfs-rename-native-v455.sh

PDP10_PREFIX ?= /usr/local/cross
COMPILER ?= kcc
ifeq ($(filter $(COMPILER),gcc kcc),)
$(error COMPILER must be gcc or kcc (got '$(COMPILER)'))
endif
export COMPILER
PDP10_TOOLS_BIN = $(PDP10_PREFIX)/bin
DAIMOS_REPO ?= ../DAIMOS
DAS_REPO ?= ../das
AAP_PDP6_REPO ?= ../pdp6
SIMH_PDP6 ?= $(PDP10_PREFIX)/bin/pdp6
SIMS_REPO ?= ../sims
PDP10_TOOLS_REPO = $(DAIMOS_REPO)/tools/host
# Use PDP10_TOOLS_REPO=... to test an independently maintained source tree
# rather than the default in-tree DAIMOS host utilities.
.PHONY: test-d6fsck-source-owner-width-v1040
test-d6fsck-source-owner-width-v1040: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	    PDP10_TOOLS_REPO='$(abspath $(PDP10_TOOLS_REPO))' \
	    sh tests/validation/check-d6fsck-fcb-owners-v1040.sh

# Termux workspaces may contain binaries copied from a Linux host.  Keep
# Android host helpers in an architecture-specific directory so Make cannot
# mistake a foreign ELF executable for an up-to-date local test helper.
ifeq ($(shell uname -o 2>/dev/null),Android)
BUILD_ROOT ?= $(CURDIR)/build/$(COMPILER)-android-$(shell uname -m)
else
BUILD_ROOT ?= $(CURDIR)/build/$(COMPILER)
endif
HOST_CC ?= cc
HOST_CFLAGS ?= -std=c99 -O2 -Wall -Wextra
HARNESS = tools/daimos-simh-harness-v4.sh
PTY_RUN_SRC = tools/pty-run-v1.c
PTY_RUN = $(BUILD_ROOT)/tools/pty-run-v1
TCP_RUN_SRC = tools/tcp-run-v1.c
TCP_RUN = $(BUILD_ROOT)/tools/tcp-run-v1
PROBES = probes/daimos-runtime-probes-v590.txt
DSH_PROBES = probes/daimos-dsh-conformance-v1.txt
PROBE_CHECK = tests/validation/check-probe-format-v1.sh
COVERAGE = tests/validation/check-command-coverage-v1.sh
REPORT_MD = reports/daimos-runtime-probes-v3.md
KERNEL_BUILD = $(BUILD_ROOT)/tests/system/kernel
KERNEL_SMOKE_BUILD = $(BUILD_ROOT)/tests/system/kernel-smoke
KERNEL_DOS = $(KERNEL_BUILD)/boot.ini
KERNEL_HOST_CHECK = $(KERNEL_BUILD)/host-check-v1
DTFS_RUN = tests/system/dtfs-native-v1/run.sh

.PHONY: check-prefix check coverage image inventory runtime runtime-build regression dtfs-runtime d6fs-mres dtfs-mres mm-core target target-memfs-pdp6 target-memfs-fifo-pdp6 target-swap-pure-text-pdp6 \
	target-file-pdp6 target-file-walk-pdp6 target-module-runtime-pdp6 target-d6lz-pdp6 target-wordtoken-pdp6 kernel-runtime stand-runtime d6fs-hdd-runtime d6fs-hdd-multi d6fs-recovery simulator-test test-daimos-stage1-kinit-entry test-daimos-kinit-sixbit-lifetime test-daimos-kcc-pdp6-codegen test-daimos-monitorfs-devices-online test-daimos-wcnsls-raw test-daimos-apr-user-protection test-daimos-apr-injected-fault test-daimos-apr-aap test-daimos-badmap-map test-daimos-badmap-root test-daimos-d6fs-context-dispatch test-daimos-d6fs-multimount test-daimos-d6set1-scratch test-daimos-d6fs-direct-backing-drm test-daimos-bcache-multisource test-daimos-bcache-allocation test-daimos-d6fs-remount test-daimos-d6fs-super-recovery test-daimos-vfs-storage-reservation test-daimos-logstore-v1 test-daimos-mtc516-online test-daimos-dsk270-online test-daimos-dsk270-elevator test-daimos-drm236-online test-daimos-drm236-minit test-daimos-drm236-capacity test-daimos-drm-stage1-boot test-daimos-dsk-root-discovery test-daimos-dtc-online test-daimos-dtc-stream-online test-daimos-tsfs-image-online test-daimos-tsfs-scan test-daimos-tsfs-multiextent test-daimos-tsfs-d6lz test-daimos-tsfs-dir test-daimos-tsfs-mount test-daimos-dtc-reverse-online test-daimos-low-memory-boot test-daimos-scheduler-multiproc test-daimos-scheduler-realtime test-daimos-scheduler-rt-revoke test-daimos-rt-required test-daimos-process-lifecycle test-daimos-process-id-lifetime test-daimos-process-hierarchy test-daimos-domain test-daimos-monitorfs-process-decimal test-daimos-process-events test-daimos-process-tty test-daimos-tty-session-state test-daimos-tty-routing test-daimos-dpy-interrupt-policy test-daimos-tty-s6rec test-daimos-tty-s6rec-input test-daimos-pt-wordio test-daimos-card-wordio test-daimos-lpt-s6rec test-daimos-exec-abi test-daimos-exec-replace test-daimos-exec-child-session test-daimos-userspace-bootstrap test-daimos-userspace-multitty test-daimos-make-boot-multitty test-daimos-login-password test-daimos-init-once test-daimos-session-teardown test-daimos-job-pipeline test-daimos-user-kuuo-isolation test-daimos-no-kernel-uuo test-daimos-trap-frequency test-daimos-proc-uarea-layout test-daimos-credentials test-daimos-credentials-fs test-daimos-proc-stack-watermark test-daimos-idle-stack-watermark test-daimos-pipe-wordfifo test-daimos-pipe-anon test-daimos-pipe-fifo test-daimos-swap-wait test-daimos-swap-stress test-daimos-d6fs-fcb-validate test-daimos-vfs-stat-frame test-daimos-pre-dsh-fs-closure test-daimos-dtfs-chain-walk test-daimos-dtfs-resize test-daimos-kfmt-u18 test-daimos-permanent-size test-daimos-p10fold-build test-host-d6lz-exec test-daimos-d6lz-native-exec test-pdp10-tools test-pdp10-tools-mkd6fs-encoding clean
	test-daimos-pi-restore test-daimos-tsfs-boot-eight test-daimos-tsfs-aap-64k-boot
.PHONY: test-daimos-boot-source-matrix test-daimos-root-class-matrix test-daimos-auto-root-priority test-daimos-boot-root-cross-matrix test-daimos-root-login-lifecycle test-daimos-monitorfs-live-state test-daimos-monitorfs-storage-accounting test-daimos-dsh-conformance test-daimos-dsh-pipeline test-daimos-dsh-source test-daimos-dsh-argument-frames test-daimos-dsh-foreground test-daimos-native-tools test-daimos-img2dpic test-type340-timing regression regression-status regression-restart test-daimos-sleep test-daimos-multiuser-kernel-auth test-daimos-multiuser-auth-runtime
.PHONY: test-daimos-compiler-selection-20261012-v1
.PHONY: test-daimos-p10fold-io-skip-20261012-v1
.PHONY: test-daimos-file-directmount-20261026-v417
test-daimos-file-directmount-20261026-v417: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-file-directmount-20261026-v417.sh
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-pipe-directmount-20261026-v417.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' sh tests/validation/daimos-file-cutover-guard-20261026-v416.sh
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-vfs-umask-20261026-v417.sh
test-daimos-p10fold-io-skip-20261012-v1: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-p10fold-io-skip-20261012-v1.sh

test-daimos-compiler-selection-20261012-v1: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' COMPILER='$(COMPILER)' \
	    sh tests/validation/daimos-compiler-selection-20261012-v1.sh


test-pdp10-tools-mkd6fs-encoding:
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" TMPDIR="$(TMPDIR)" \
		tests/tools/pdp10-tools/mkd6fs-encoding-v1-test.sh

check-prefix:
	@test -n "$(PDP10_PREFIX)" || { echo "PDP10_PREFIX must be set" >&2; exit 2; }

.PHONY: test-daimos-dlink-xip-v218
test-daimos-dlink-xip-v218: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		HOST_CC='$(HOST_CC)' sh tests/host/dlink-xip-v218.sh

$(PTY_RUN): $(PTY_RUN_SRC)
	mkdir -p '$(dir $@)'
	$(HOST_CC) $(HOST_CFLAGS) -o '$@' '$<'

$(TCP_RUN): $(TCP_RUN_SRC)
	mkdir -p '$(dir $@)'
	$(HOST_CC) $(HOST_CFLAGS) -o '$@' '$<'

check: $(PTY_RUN)
	sh -n $(HARNESS) $(PROBE_CHECK) $(COVERAGE)
	$(PROBE_CHECK) $(PROBES)
	$(MAKE) coverage

coverage:
	$(COVERAGE) --daimos-repo '$(DAIMOS_REPO)' --probes '$(PROBES)' \
		--script 'tests/validation/daimos-dtc-online-v1.sh' \
		--script 'tests/validation/daimos-tsfs-mount-v1.sh' \
		--script 'tests/validation/daimos-low-memory-boot-v2.sh' \
		--script 'tests/validation/daimos-dpy-native-refresh-smoke-v1.sh'

image:
	$(MAKE) -C '$(abspath $(DAIMOS_REPO))/system/boot/pdp6' image \
		BUILD='$(abspath $(KERNEL_BUILD))' PDP10_PREFIX='$(PDP10_PREFIX)'

inventory: check
	env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT

runtime: check
	mkdir -p reports
	env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT --probes '$(PROBES)' \
		--markdown-report '$(REPORT_MD)'

runtime-build: image runtime
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' tests/validation/daimos-monitorfs-cty-stats-v589.sh

test-daimos-dsh-conformance: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) $(DSH_PROBES)
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT --probes '$(DSH_PROBES)'

test-daimos-dsh-pipeline: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) probes/daimos-dsh-pipeline-regression-20261010-v1.txt
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT \
		--probes probes/daimos-dsh-pipeline-regression-20261010-v1.txt

.PHONY: test-daimos-dsh-pipeline-failed-launch-reap-v1019
test-daimos-dsh-pipeline-failed-launch-reap-v1019: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) probes/daimos-dsh-pipeline-failed-launch-reap-v1019.txt
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT --isolate-media \
		--probes probes/daimos-dsh-pipeline-failed-launch-reap-v1019.txt \
		--markdown-report '$(abspath $(BUILD_ROOT))/reports/dsh-pipeline-reap-v1019.md'

.PHONY: test-daimos-simh-isolate-media-v1
test-daimos-simh-isolate-media-v1:
	@TMPDIR='$(TMPDIR)' sh tests/validation/daimos-simh-isolate-media-20261021-v1.sh

test-daimos-dsh-source: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) probes/daimos-dsh-source-nested-regression-20261010-v1.txt
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT \
		--probes probes/daimos-dsh-source-nested-regression-20261010-v1.txt

test-daimos-dsh-argument-frames: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) probes/daimos-dsh-argument-frames-20261010-v1.txt
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT \
		--probes probes/daimos-dsh-argument-frames-20261010-v1.txt

test-daimos-dsh-variable-heap-20261012-v1: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) probes/daimos-dsh-variable-heap-20261012-v1.txt
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT \
		--probes probes/daimos-dsh-variable-heap-20261012-v1.txt

test-daimos-dsh-resource-contract:
	@DAIMOS_REPO="$(abspath $(DAIMOS_REPO))" tests/validation/daimos-dsh-resource-contract-20261010-v1.sh

test-daimos-dsh-foreground: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-dsh-foreground-v1.sh

test-daimos-native-tools: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-native-tools-v1.sh

test-daimos-img2dpic:
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-img2dpic-v1.sh

test-type340-timing:
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' SIMS_REPO='$(abspath $(SIMS_REPO))' \
		tests/validation/type340-timing-v1.sh

$(KERNEL_HOST_CHECK):
	$(MAKE) -C tests/system/kernel '$(abspath $(KERNEL_HOST_CHECK))' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD='$(abspath $(KERNEL_BUILD))' \
		PDP10_PREFIX='$(PDP10_PREFIX)'

dtfs-runtime: check image $(KERNEL_HOST_CHECK)
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		KERNEL_DOS='$(abspath $(KERNEL_DOS))' PTY_RUN='$(abspath $(PTY_RUN))' \
		HOST_CHECK='$(abspath $(KERNEL_HOST_CHECK))' $(DTFS_RUN)

dtfs-mres:
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		tests/system/dtfs-mres-v3/run.sh

d6fs-hdd-runtime: $(PTY_RUN)
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		PTY_RUN='$(abspath $(PTY_RUN))' tests/system/d6fs-hdd-v2/run.sh

d6fs-hdd-multi: $(PTY_RUN) $(TCP_RUN)
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/system/d6fs-hdd-v2/run-multimember-v582.sh

d6fs-recovery: $(PTY_RUN) $(TCP_RUN)
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/system/d6fs-hdd-v2/run-recovery-v1.sh

d6fs-mres:
	TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		tests/system/d6fs-mres-v1/run.sh


mm-core:
	mkdir -p '$(BUILD_ROOT)/tests/system/mm-v1'
	$(HOST_CC) -std=c99 -O2 -Wall -Wextra -Werror \
		-I'$(PDP10_PREFIX)/include' \
		-I'$(DAIMOS_REPO)/system/kernel' \
		-I'$(DAIMOS_REPO)/system/kernel/core' \
		-I'$(DAIMOS_REPO)/system/kernel/drivers' \
		-I'$(DAIMOS_REPO)/system/kernel/fs' \
		-I'$(DAIMOS_REPO)/system/kernel/mm' \
		-I'$(DAIMOS_REPO)/system/kernel/modules' \
		-I'$(DAIMOS_REPO)/system/kernel/proc' \
		-I'$(DAIMOS_REPO)/system/kernel/storage' \
		-o '$(BUILD_ROOT)/tests/system/mm-v1/test' \
		tests/system/mm-v1/test.c '$(DAIMOS_REPO)/system/kernel/mm/mm.c' \
		tests/system/mm-v1/vm_host_v656.c \
		'$(DAIMOS_REPO)/system/kernel/mm/mm_boot.c' \
		'$(DAIMOS_REPO)/system/kernel/modules/module_runtime.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc_boot.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc_storage_map_v28.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/vm_pdp6_swap.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc_swap_boot.c'
	'$(BUILD_ROOT)/tests/system/mm-v1/test'


target: mm-core target-backstore-pdp6 target-monitorfs-wordio-pdp6 target-memfs-pdp6 target-memfs-fifo-pdp6 target-file-pdp6 target-file-walk-pdp6 target-module-runtime-pdp6 target-swap-pure-text-pdp6 target-stage1-d6lz-pdp6 target-wordtoken-pdp6 target-kcc-indexed-byteptr-pdp6 test-daimos-compiler-selection-20261012-v1 test-daimos-p10fold-io-skip-20261012-v1 test-daimos-d6fs-fcb-validate test-daimos-vfs-stat-frame test-daimos-pre-dsh-fs-closure test-daimos-dtfs-chain-walk test-daimos-dtfs-resize test-daimos-kfmt-u18 test-daimos-pi-restore

# Every direct PDP-6 target sweep also checks optimized 9-bit character
# accesses when a stack-local array crosses a 36-bit word boundary.
target: test-pdp10-gcc-char-word-boundary-v45

.PHONY: test-pdp10-gcc-char-word-boundary-v45
test-pdp10-gcc-char-word-boundary-v45: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
		sh tests/validation/pdp10-gcc-char-word-boundary-v45.sh

target-swap-pure-text-pdp6: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/target/daimos-swap-pure-text-pdp6-v1/run.sh

target-backstore-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-backstore-pdp6-v1/run.sh

target-monitorfs-wordio-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-monitorfs-wordio-pdp6-v1/run.sh

target-memfs-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-memfs-pdp6-v1/run.sh

.PHONY: target-memfs-xip-aap-v202
target-memfs-xip-aap-v202: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		AAP_PDP6_REPO='$(abspath $(AAP_PDP6_REPO))' \
		sh tests/target/daimos-memfs-pdp6-v1/run-aap-v202.sh

.PHONY: target-memfs-xip-user-apr-v209
target-memfs-xip-user-apr-v209: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		AAP_PDP6_REPO='$(abspath $(AAP_PDP6_REPO))' \
		sh tests/target/daimos-memfs-pdp6-v1/run-user-apr-v209.sh

.PHONY: target-memfs-xip-user-lifecycle-v216
target-memfs-xip-user-lifecycle-v216: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		AAP_PDP6_REPO='$(abspath $(AAP_PDP6_REPO))' \
		sh tests/target/daimos-memfs-pdp6-v1/run-user-lifecycle-v216.sh

target-memfs-fifo-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-memfs-fifo-pdp6-v1/run.sh

target-file-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-file-pdp6-v1/run.sh

target-file-walk-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-file-walk-pdp6-v1/run.sh

target-module-runtime-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-module-runtime-pdp6-v1/run.sh

target-d6lz-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-d6lz-pdp6-v1/run.sh

target-wordtoken-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-wordtoken-pdp6-v1/run.sh

target-kcc-indexed-byteptr-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		tests/target/daimos-kcc-sixarg-char-pdp6-v1/run.sh

target-stage1-d6lz-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-stage1-d6lz-pdp6-v1/run.sh

test-daimos-stage1-size:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/validation/daimos-stage1-size-v1.sh

test-daimos-boot-source-matrix: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-boot-source-matrix-v1.sh

test-daimos-root-class-matrix: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-root-class-matrix-v1.sh

test-daimos-auto-root-priority: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-auto-root-priority-v1.sh

test-daimos-boot-root-cross-matrix: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-boot-root-cross-matrix-v1.sh

test-daimos-root-login-lifecycle: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-root-login-lifecycle-v1.sh

test-daimos-monitorfs-live-state: check-prefix $(PTY_RUN) $(TCP_RUN)
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PTY_RUN='$(abspath $(PTY_RUN))' TCP_RUN='$(abspath $(TCP_RUN))' \
		tests/validation/daimos-monitorfs-live-state-v1.sh

test-daimos-monitorfs-storage-accounting: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-monitorfs-storage-accounting-v1.sh

kernel-runtime:
	$(MAKE) -C tests/system/kernel test \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD='$(abspath $(KERNEL_SMOKE_BUILD))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)'

stand-runtime:
	$(MAKE) -C tests/system/stand test \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)'

simulator-test: check target d6fs-mres dtfs-mres test-daimos-permanent-size test-daimos-pipe-wordfifo test-daimos-pipe-fifo kernel-runtime stand-runtime runtime-build dtfs-runtime

# Complete DAIMOS patch-acceptance gate.  The matrix runner remains strictly
# serial because many rows share simulator media and build directories.  PASS
# rows are checkpointed independently together with the source fingerprints
# they actually tested, so a fix can resume at the failed row without hiding
# that earlier PASS rows came from an older revision.
regression: check-prefix
	@MAKE='$(MAKE)' COMPILER='$(COMPILER)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh

regression-status: check-prefix
	@MAKE='$(MAKE)' COMPILER='$(COMPILER)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh --status

regression-restart: check-prefix
	@MAKE='$(MAKE)' COMPILER='$(COMPILER)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh --restart


# DAIMOS-specific validation tests migrated from pdp10-testkit.




test-daimos-pipe-wordfifo: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-pipe-wordfifo-v2.sh

test-daimos-pipe-anon: test-daimos-pipe-wordfifo
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	 DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 tests/validation/daimos-pipe-anon-regression-v902.sh



test-daimos-swap-wait: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		tests/validation/daimos-swap-wait-v1.sh

test-daimos-swap-stress: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		tests/validation/daimos-swap-stress-v1.sh

test-daimos-pipe-fifo: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-pipe-fifo-v2.sh


test-daimos-dsk-root-discovery: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dsk-root-discovery-v1.sh

test-daimos-drm-stage1-boot: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-drm-stage1-boot-v1.sh

test-daimos-drm236-capacity:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-drm236-capacity-v1.sh

test-daimos-p10fold-build: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/validation/daimos-p10fold-build-v1.sh

test-daimos-sleep: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/validation/daimos-sleep-v1.sh

test-daimos-proc-timer-frontier: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-proc-timer-frontier-v1.sh

test-daimos-multiuser-kernel-auth:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-multiuser-kernel-auth-v1.sh

test-daimos-multiuser-auth-runtime: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/validation/daimos-multiuser-auth-runtime-v1.sh

test-daimos-permanent-size: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-permanent-size-v1.sh

.PHONY: test-daimos-kcore-end-boundary-v484
test-daimos-kcore-end-boundary-v484: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-kcore-end-boundary-v484.sh

.PHONY: test-daimos-root-tapefs-selection
test-daimos-root-tapefs-selection: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
	    tests/validation/daimos-root-tapefs-selection-20261012-v1.sh

test-daimos-dtfs-unlink: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-unlink-v1.sh

test-daimos-dtfs-create: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-create-v1.sh

test-daimos-dtfs-dirfields: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-dirfields-v1.sh

test-daimos-dtfs-rename: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-rename-v1.sh

test-daimos-dtfs-resize: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-resize-v1.sh


test-daimos-kfmt-u18: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-kfmt-u18-v1.sh

test-daimos-pi-restore: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-pi-restore-v1.sh

test-daimos-dtfs-chain-walk: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-chain-walk-v1.sh

test-daimos-d6fs-fcb-validate: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-fcb-validate-v2.sh

test-daimos-pre-dsh-fs-closure:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-pre-dsh-fs-closure-v1.sh

test-daimos-vfs-stat-frame: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-vfs-stat-frame-v1.sh

test-daimos-low-memory-boot: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-low-memory-boot-v2.sh

test-daimos-scheduler-rt-revoke: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-scheduler-rt-revoke-v1.sh

test-daimos-rt-required: check-prefix
	PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(DAIMOS_REPO)' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-rt-required-v1.sh

.PHONY: test-daimos-exec-rt-owner
test-daimos-exec-rt-owner: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' DAIMOS_EXEC_OBSERVE_SECONDS='$(DAIMOS_EXEC_OBSERVE_SECONDS)' \
		sh tests/validation/daimos-exec-rt-owner-v191.sh

.PHONY: test-daimos-exec-commit-rollback
test-daimos-exec-commit-rollback: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-exec-commit-rollback-v200.sh

.PHONY: test-daimos-exec-create-oom
test-daimos-exec-create-oom: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-exec-create-oom-v205.sh

.PHONY: test-daimos-exec-pressure
test-daimos-exec-pressure: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-exec-pressure-v201.sh


test-daimos-scheduler-realtime: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-scheduler-realtime-v1.sh

test-daimos-scheduler-multiproc: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-scheduler-multiproc-v1.sh

test-daimos-process-lifecycle: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-process-lifecycle-v1.sh

.PHONY: test-daimos-run-late-rollback
test-daimos-run-late-rollback: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-run-late-rollback-v197.sh

.PHONY: test-daimos-run-vm-oom
test-daimos-run-vm-oom: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-run-vm-oom-v198.sh

.PHONY: test-daimos-run-create-oom
test-daimos-run-create-oom: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-run-create-oom-v199.sh

test-daimos-process-id-lifetime: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-process-id-lifetime-v1.sh

test-daimos-process-hierarchy: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-process-hierarchy-v1.sh

test-daimos-domain: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-domain-v1.sh

test-daimos-monitorfs-process-decimal: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-monitorfs-process-decimal-v1.sh

test-daimos-process-events: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-process-events-v1.sh

test-daimos-process-tty: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-process-tty-v1.sh


test-daimos-tty-s6rec: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tty-s6rec-v1.sh

test-daimos-tty-s6rec-input: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tty-s6rec-input-v1.sh

test-daimos-pt-wordio: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-pt-wordio-v1.sh

test-daimos-card-wordio: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-card-wordio-v1.sh

test-daimos-lpt-s6rec: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-lpt-s6rec-v1.sh

test-daimos-tty-routing: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-tty-routing-v1.sh

test-daimos-dpy-interrupt-policy: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-dpy-interrupt-policy-v1.sh

test-daimos-dpy-native-blocks: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dpy-native-blocks-v1.sh

test-daimos-dpy-native-refresh: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dpy-native-refresh-smoke-v1.sh

test-daimos-exec-abi: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-exec-abi-v1.sh

test-daimos-exec-replace: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-exec-replace-v1.sh

test-daimos-exec-child-session: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-exec-child-session-v1.sh

test-daimos-init-once: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-init-once-v1.sh

test-daimos-login-password: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-login-password-v1.sh

test-daimos-userspace-bootstrap: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-userspace-bootstrap-v1.sh

test-host-d6lz-exec: check-prefix
	@test -n "$(PDP10_TOOLS_REPO)" || { echo "PDP10_TOOLS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" \
	 PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	 tests/validation/host-d6lz-exec-v1.sh


test-daimos-d6lz-native-exec: check-prefix
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	 tests/validation/daimos-d6lz-native-exec-v1.sh


test-daimos-userspace-multitty: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-userspace-multitty-v1.sh

test-daimos-make-boot-multitty: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-make-boot-multitty-v1.sh

test-daimos-tty-session-state: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tty-session-state-v1.sh

test-daimos-session-teardown: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-session-teardown-v1.sh

test-daimos-job-pipeline: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-job-pipeline-v1.sh

test-daimos-user-kuuo-isolation: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-user-kuuo-isolation-v1.sh

test-daimos-no-kernel-uuo:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-no-kernel-uuo-v1.sh

test-daimos-trap-frequency: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-trap-frequency-v1.sh

test-daimos-credentials:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-credentials-v1.sh

test-daimos-credentials-fs:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" tests/validation/daimos-credentials-fs-v1.sh

test-daimos-proc-uarea-layout:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/validation/daimos-proc-uarea-layout-v1.sh


test-daimos-proc-stack-watermark: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-proc-stack-watermark-v1.sh

# Measure the permanent runtime idle/exit stack independently of late KINIT.
test-daimos-idle-stack-watermark: check-prefix
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' tests/validation/daimos-idle-stack-watermark-v1.sh

test-daimos-stage1-kinit-entry: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-stage1-kinit-entry-v1.sh

test-daimos-kinit-sixbit-lifetime: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" TMPDIR="$(TMPDIR)" \
	    tests/validation/daimos-kinit-sixbit-lifetime-v1.sh

test-daimos-kcc-pdp6-codegen: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
	    DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    tests/validation/daimos-kcc-pdp6-codegen-v1.sh

test-daimos-monitorfs-devices-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-monitorfs-devices-online-v1.sh

test-daimos-apr-user-protection: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-apr-user-protection-v1.sh

test-daimos-apr-injected-fault: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-apr-injected-fault-v1.sh

test-daimos-apr-aap: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(AAP_PDP6_REPO)" || { echo "AAP_PDP6_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		AAP_PDP6_REPO="$$(cd "$(AAP_PDP6_REPO)" && pwd -P)" \
		tests/validation/daimos-apr-aap-v1.sh

test-daimos-badmap-map: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-badmap-map-v1.sh

test-daimos-badmap-root: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-badmap-root-v1.sh

test-daimos-d6fs-context-dispatch: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-context-dispatch-v1.sh

test-daimos-d6fs-multimount: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-multimount-v1.sh

test-daimos-d6set1-scratch: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAS_REPO="$(DAS_REPO)" DAIMOS_TOOLS_REPO="$(DAIMOS_TOOLS_REPO)" \
		KCC_REPO="$(KCC_REPO)" tests/validation/daimos-d6set1-scratch-v1.sh

test-daimos-d6fs-direct-backing-drm: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-direct-backing-drm-v1.sh

test-daimos-bcache-multisource: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-bcache-multisource-v1.sh

test-daimos-bcache-allocation: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-bcache-allocation-v1.sh


test-daimos-d6fs-remount: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-remount-v1.sh

test-daimos-d6fs-super-recovery:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-d6fs-super-recovery-v1.sh

test-daimos-vfs-storage-reservation: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-vfs-storage-reservation-v1.sh

test-daimos-logstore-v1: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-logstore-v1.sh

test-daimos-mtc516-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-mtc516-online-v1.sh

test-daimos-dsk270-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dsk270-online-v1.sh

test-daimos-dsk270-elevator: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dsk270-elevator-v1.sh

test-daimos-drm236-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" SIMH_PDP6="$(SIMH_PDP6)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-drm236-online-v1.sh

test-daimos-drm236-minit: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-drm236-minit-v1.sh

test-daimos-dtc-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtc-online-v1.sh


test-daimos-dtc-stream-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtc-stream-online-v1.sh

test-daimos-tsfs-image-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(PDP10_TOOLS_REPO)" || { echo "PDP10_TOOLS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-image-online-v1.sh

.PHONY: test-daimos-tsfs-root-no-d6fs
test-daimos-tsfs-root-no-d6fs: check-prefix
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-tsfs-root-no-d6fs-v1.sh

.PHONY: test-daimos-tsfs-root-no-pictures
test-daimos-tsfs-root-no-pictures: check-prefix
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		sh tests/validation/daimos-tsfs-root-no-pictures-v1.sh

test-daimos-tsfs-scan:
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" TMPDIR="$(TMPDIR)" \
		tests/validation/daimos-tsfs-scan-v2.sh

test-daimos-tsfs-boot-eight: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-boot-eight-v1.sh

test-daimos-tsfs-aap-64k-boot: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(AAP_PDP6_REPO)" || { echo "AAP_PDP6_REPO must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		AAP_PDP6_REPO="$$(cd "$(AAP_PDP6_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-aap-64k-boot-v1.sh

test-daimos-tsfs-multiextent: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-multiextent-v1.sh


test-daimos-tsfs-d6lz: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-d6lz-v1.sh



test-daimos-tsfs-dir: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(PDP10_TOOLS_REPO)" || { echo "PDP10_TOOLS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-root-directory-v577.sh


test-daimos-tsfs-mount: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtfs-tape-root-mount-v578.sh


test-daimos-dtc-reverse-online: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
		TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-dtc-reverse-online-v1.sh



test-pdp10-tools: check-prefix
	@test -f '$(PDP10_TOOLS_REPO)/Makefile' || { echo 'invalid PDP10_TOOLS_REPO: $(PDP10_TOOLS_REPO)' >&2; exit 1; }
	@test -n '$(TMPDIR)' || { echo 'TMPDIR must be set' >&2; exit 2; }
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
		PDP10_TOOLS_REPO="$$(cd '$(PDP10_TOOLS_REPO)' && pwd -P)" \
		tests/tools/pdp10-tools/run.sh

clean:
	$(MAKE) -C tests/system/kernel clean DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD='$(abspath $(KERNEL_BUILD))'
	$(MAKE) -C tests/system/stand clean DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' BUILD_ROOT='$(abspath $(BUILD_ROOT))'
	rm -rf build reports/*.md stand-test-report.txt

.PHONY: test-daimos-kcc-foldtrna-conditional-20261008-v1
test-daimos-kcc-foldtrna-conditional-20261008-v1: check-prefix
	DAIMOS_REPO='${DAIMOS_REPO}' PDP10_PREFIX='${PDP10_PREFIX}' TMPDIR='${TMPDIR}' sh tests/validation/daimos-kcc-foldtrna-conditional-20261008-v1.sh

# Deliberately opt-in: full PDP-6 KCC source compilation can take many minutes.
# Preserve all build artifacts, simulator output and the harness report.
.PHONY: test-daimos-kcc-manual-rebuild-20261008-v1
test-daimos-kcc-manual-rebuild-20261008-v1:
	@DAIMOS_REPO="$(abspath $(DAIMOS_REPO))" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" KCC_REPO="$${KCC_REPO:-$$HOME/git/kcc}" \
	 DAS_REPO="$${DAS_REPO:-$$HOME/git/das}" \
	 DAIMOS_TOOLS_REPO="$${DAIMOS_TOOLS_REPO:-$$HOME/git/daimos-tools}" \
	 KCC_TIMEOUT="$${KCC_TIMEOUT:-900}" \
	 sh tests/validation/daimos-kcc-manual-rebuild-20261008-v1.sh

# Opt-in fresh-image KCC source-build regression. Never reuse test disk images.
.PHONY: test-daimos-kcc-make-all-fresh-20261008-v1
test-daimos-kcc-make-all-fresh-20261008-v1:
	@DAIMOS_REPO="$(abspath $(DAIMOS_REPO))" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" KCC_REPO="$${KCC_REPO:-$$HOME/git/kcc}" \
	 DAS_REPO="$${DAS_REPO:-$$HOME/git/das}" \
	 DAIMOS_TOOLS_REPO="$${DAIMOS_TOOLS_REPO:-$$HOME/git/daimos-tools}" \
	 sh tests/validation/daimos-kcc-make-all-fresh-20261008-v1.sh

.PHONY: test-daimos-libc-memcpy-20261008-v1
test-daimos-libc-memcpy-20261008-v1:
	@mkdir -p "$${TMPDIR:-$$HOME/tmp}"
	$(HOST_CC) -std=c99 -O2 -fno-builtin -Wall -Wextra -Werror \
	 -o "$${TMPDIR:-$$HOME/tmp}/daimos-libc-memcpy-20261008-v1" \
	 tests/host/daimos-libc-memcpy-20261008-v1.c \
	 "$(abspath $(DAIMOS_REPO))/userland/libc/string.c"
	"$${TMPDIR:-$$HOME/tmp}/daimos-libc-memcpy-20261008-v1"

.PHONY: test-daimos-brk-double-mm-rollback-v1074
test-daimos-brk-double-mm-rollback-v1074: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-brk-double-mm-rollback-v1074.sh

.PHONY: test-daimos-oom-requester-live-v1075
test-daimos-oom-requester-live-v1075: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-requester-live-v1075.sh

.PHONY: test-daimos-oom-requester-disabled-v1075
test-daimos-oom-requester-disabled-v1075: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1075_TEST_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-requester-live-v1075.sh

.PHONY: test-daimos-oom-brk-negatives-v1110
.PHONY: test-daimos-oom-pid-reuse-v1120
.PHONY: test-daimos-oom-pid-reuse-enabled-v1120
test-daimos-oom-pid-reuse-v1120: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-pid-reuse-v1120.sh

test-daimos-oom-pid-reuse-enabled-v1120: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1120_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-pid-reuse-v1120.sh

.PHONY: test-daimos-oom-failed-run-v1112
test-daimos-oom-failed-run-v1112: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-failed-run-v1112.sh

.PHONY: test-daimos-oom-failed-run-enabled-v1112
test-daimos-oom-failed-run-enabled-v1112: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1112_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-failed-run-v1112.sh

.PHONY: test-daimos-mm-exhaustion-class-v1111
.PHONY: test-daimos-oom-brk-real-mm-v1113
.PHONY: test-daimos-oom-mm-slots-v1114
.PHONY: test-daimos-oom-mm-fragment-v1115
.PHONY: test-daimos-oom-run-cause-v1116
test-daimos-oom-run-cause-v1116: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-run-cause-v1116.sh

.PHONY: test-daimos-oom-run-cause-enabled-v1116
test-daimos-oom-run-cause-enabled-v1116: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1116_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-run-cause-v1116.sh

test-daimos-oom-mm-fragment-v1115: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-mm-fragment-v1115.sh

.PHONY: test-daimos-oom-mm-fragment-enabled-v1115
test-daimos-oom-mm-fragment-enabled-v1115: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1115_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-mm-fragment-v1115.sh

test-daimos-oom-mm-slots-v1114: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-mm-slots-v1114.sh

.PHONY: test-daimos-oom-mm-slots-enabled-v1114
test-daimos-oom-mm-slots-enabled-v1114: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1114_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-mm-slots-v1114.sh

test-daimos-oom-brk-real-mm-v1113: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-brk-real-mm-v1113.sh

test-daimos-mm-exhaustion-class-v1111: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-mm-exhaustion-class-v1111.sh

test-daimos-oom-brk-negatives-v1110: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-brk-negatives-v1110.sh

.PHONY: test-daimos-oom-brk-negatives-enabled-v1110
test-daimos-oom-brk-negatives-enabled-v1110: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1110_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-brk-negatives-v1110.sh

.PHONY: test-daimos-oom-requester-provider-mm-v1077
test-daimos-oom-requester-provider-mm-v1077: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-requester-provider-mm-v1077.sh

.PHONY: test-daimos-provider-lock-contract-v325
.PHONY: test-daimos-provider-fatal-contention-v1078
.PHONY: test-daimos-provider-inflight-owner-v1088
.PHONY: test-daimos-provider-pending-fatal-v1090
test-daimos-provider-pending-fatal-v1090: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-provider-pending-fatal-v1090.sh

.PHONY: test-daimos-provider-pending-live-v1091
test-daimos-provider-pending-live-v1091: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-provider-pending-live-v1091.sh

.PHONY: test-daimos-provider-quarantine-v1092
.PHONY: test-daimos-tty-mm-error-stage-v1093
test-daimos-tty-mm-error-stage-v1093: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-tty-mm-error-stage-v1093.sh

test-daimos-provider-quarantine-v1092: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-provider-quarantine-v1092.py

.PHONY: test-daimos-xip-release-stage-v1094
test-daimos-xip-release-stage-v1094: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-xip-release-stage-v1094.sh

.PHONY: test-daimos-p0d-release-matrix-v1096
.PHONY: test-daimos-xip-vm-retry-v1109
test-daimos-xip-vm-retry-v1109: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-xip-vm-retry-v1109.sh

.PHONY: test-daimos-xip-physical-retry-v1108
test-daimos-xip-physical-retry-v1108: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-xip-physical-retry-v1108.sh

.PHONY: test-daimos-reaper-sidl-runq-v1107
test-daimos-reaper-sidl-runq-v1107: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-reaper-sidl-runq-v1107.sh

.PHONY: test-daimos-session-hup-swap-v1107
test-daimos-session-hup-swap-v1107: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-swap-v1107.sh

.PHONY: test-daimos-oom-multistage-v1103
.PHONY: test-daimos-oom-wait-churn-v1117
.PHONY: test-daimos-oom-physical-mixed-v1118
test-daimos-oom-physical-mixed-v1118: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-physical-mixed-v1118.sh

test-daimos-oom-wait-churn-v1117: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-wait-churn-v1117.sh

.PHONY: test-daimos-oom-physical-vm-v1106
test-daimos-oom-physical-vm-v1106: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-physical-vm-v1106.sh

.PHONY: test-daimos-session-hup-pipe-mm-v1104
.PHONY: test-daimos-session-hup-dpy-mm-v1105
.PHONY: test-daimos-session-hup-pipe-dpy-v1119
test-daimos-session-hup-pipe-dpy-v1119: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-pipe-dpy-v1119.sh

test-daimos-session-hup-dpy-mm-v1105: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-dpy-mm-v1105.sh

test-daimos-session-hup-pipe-mm-v1104: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-pipe-mm-v1104.sh

test-daimos-oom-multistage-v1103: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-multistage-v1103.sh

.PHONY: test-daimos-fatal-mm-wrong-owner-v1101
.PHONY: test-daimos-reaper-backoff-v1102
test-daimos-reaper-backoff-v1102: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-reaper-backoff-v1102.sh

test-daimos-fatal-mm-wrong-owner-v1101: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-mm-wrong-owner-v1101.sh

.PHONY: test-daimos-pipe-typed-close-v1099
.PHONY: test-daimos-dpy-typed-replace-v1100
test-daimos-dpy-typed-replace-v1100: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-dpy-typed-replace-v1100.sh

test-daimos-pipe-typed-close-v1099: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-pipe-typed-close-v1099.sh

.PHONY: test-daimos-uarea-typed-release-v1097
.PHONY: test-daimos-prevm-retry-clock-v1098
test-daimos-prevm-retry-clock-v1098: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-prevm-retry-clock-v1098.sh

test-daimos-uarea-typed-release-v1097: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-uarea-typed-release-v1097.sh

test-daimos-p0d-release-matrix-v1096: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-p0d-release-matrix-v1096.sh

.PHONY: test-daimos-provider-permanent-v891
test-daimos-provider-permanent-v891: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-file-persistent-v891.sh

.PHONY: test-daimos-provider-invalid-v914
test-daimos-provider-invalid-v914: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-file-invalid-v914.sh

.PHONY: test-daimos-provider-revival-v953
test-daimos-provider-revival-v953: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-provider-revival-v953.sh

test-daimos-provider-inflight-owner-v1088: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-provider-inflight-owner-v1088.sh

.PHONY: test-daimos-tape-data-watchdog-v1089
test-daimos-tape-data-watchdog-v1089: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-tape-data-watchdog-v1089.sh

.PHONY: test-daimos-drm236-watchdog-v1079
test-daimos-drm236-watchdog-v1079: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-drm236-watchdog-binding-v1079.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-drm236-runtime-watchdog-v1079.sh

.PHONY: test-daimos-drm236-queue-full-v1080
test-daimos-drm236-queue-full-v1080: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-drm236-queue-full-v1080.sh

.PHONY: test-daimos-tty-finalize-gate-v1081
test-daimos-tty-finalize-gate-v1081: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-tty-finalize-gate-v1081.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-tty-prevm-finalize-v1081.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-tty-session-release-v967.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-tty-session-actual-mm-v968.sh

.PHONY: test-daimos-newsession-tty-rollback-v1082
test-daimos-newsession-tty-rollback-v1082: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-newsession-tty-rollback-v1082.sh
	@DAIMOS_V1082_NEGATIVE=1 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-newsession-tty-rollback-v1082.sh

.PHONY: test-daimos-fatal-release-scope-v1083
test-daimos-fatal-release-scope-v1083: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-fatal-release-scope-v1083.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-pipe-close-v870.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-dpy-actual-mm-v904.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-dpy-double-free-v912.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-vm-detach-order-v957.sh

.PHONY: test-daimos-fifo-open-abort-mm-v1084
test-daimos-fifo-open-abort-mm-v1084: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-fifo-open-abort-mm-v1084.sh
	@DAIMOS_V1084_NEGATIVE=1 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-fifo-open-abort-mm-v1084.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-fatal-release-scope-v1083.py

.PHONY: test-daimos-discard-tty-prevm-v1085
test-daimos-discard-tty-prevm-v1085: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-discard-tty-prevm-v1085.sh
	@DAIMOS_V1085_NEGATIVE=1 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-discard-tty-prevm-v1085.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-run-discard-reaper-v892.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-run-prevm-discard-v894.sh

.PHONY: test-daimos-slot0-pi6-v1086
test-daimos-slot0-pi6-v1086: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-slot0-pi6-contract-v1086.py
	@for mode in exit gateway xip idle self tty swap; do \
	 if DAIMOS_V1086_NEGATIVE=$$mode DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-slot0-pi6-contract-v1086.py >/dev/null 2>&1; then \
	 echo "v1086: unsafe mutation $$mode unexpectedly passed" >&2; exit 1; fi; \
	 echo "v1086: $$mode mutation rejected PASS"; done
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-slot0-memfs-pi6-v1086.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-slot0-exit-premark-v1086.sh
	@DAIMOS_V1086_NEGATIVE=1 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-slot0-exit-premark-v1086.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-slot0-finish-hup-v1086.sh

.PHONY: test-daimos-oom-transitive-release-v1087
test-daimos-oom-transitive-release-v1087: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-transitive-release-v1087.py
	@for mode in file hup foreign vfs sync pipe tty vm owner discard dpystop; do \
	 if DAIMOS_V1087_NEGATIVE=$$mode DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-transitive-release-v1087.py >/dev/null 2>&1; then \
	 echo "v1087: unsafe transitive mutation $$mode unexpectedly passed" >&2; exit 1; fi; \
	 echo "v1087: $$mode mutation rejected PASS"; done
	@for test in \
	 daimos-pipe-close-v870 \
	 daimos-dpy-actual-mm-v904 \
	 daimos-dpy-double-free-v912 \
	 daimos-vm-detach-order-v957 \
	 daimos-session-hup-pending-v905 \
	 daimos-session-hup-repeated-failure-v922 \
	 daimos-fatal-owner-hup-retry-v995 \
	 daimos-provider-fatal-contention-v1078 \
	 daimos-tty-prevm-finalize-v1081 \
	 daimos-discard-tty-prevm-v1085; do \
	 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/$$test.sh || exit 1; done

test-daimos-provider-fatal-contention-v1078: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-provider-fatal-contention-v1078.sh

test-daimos-provider-lock-contract-v325:
	@python3 tests/validation/daimos-provider-lock-contract-v325.py \
	    "$(abspath $(DAIMOS_REPO))/system/kernel/fs/fs_mres.s"

.PHONY: test-daimos-provider-lock-native-v326
test-daimos-provider-lock-native-v326:
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR="$${TMPDIR:-$$HOME/tmp}" sh tests/validation/daimos-provider-lock-native-v326.sh

.PHONY: test-daimos-provider-lock-native-v327
test-daimos-provider-lock-native-v327:
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR="$${TMPDIR:-$$HOME/tmp}" sh tests/validation/daimos-provider-lock-native-v327.sh

.PHONY: test-daimos-monitorfs-mres-device-v341
test-daimos-monitorfs-mres-device-v341: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-monitorfs-mres-device-v341.sh

.PHONY: test-daimos-monitorfs-mres-proc-basic-v343
test-daimos-monitorfs-mres-proc-basic-v343: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-monitorfs-mres-proc-basic-v343.sh

.PHONY: test-daimos-monitorfs-mres-domains-v344
test-daimos-monitorfs-mres-domains-v344: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-monitorfs-mres-domains-v344.sh

.PHONY: test-daimos-monitorfs-mres-domains-v346
test-daimos-monitorfs-mres-domains-v346: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-monitorfs-mres-domains-v346.sh

.PHONY: test-daimos-procinfo-current-v350
test-daimos-procinfo-current-v350: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-procinfo-current-v350.sh

.PHONY: test-daimos-procinfo-zombie-v354
test-daimos-procinfo-zombie-v354: check-prefix
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
	 TMPDIR="$(TMPDIR)" DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	 sh tests/validation/daimos-procinfo-zombie-v354.sh
