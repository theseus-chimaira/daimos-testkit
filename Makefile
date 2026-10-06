PDP10_PREFIX ?= /usr/local/cross
PDP10_TOOLS_BIN = $(PDP10_PREFIX)/bin
DAIMOS_REPO ?= ../DAIMOS
PDP10_TOOLS_REPO = ../pdp10-tools
BUILD_ROOT ?= $(CURDIR)/build
HOST_CC ?= cc
HOST_CFLAGS ?= -std=c99 -O2 -Wall -Wextra
HARNESS = tools/daimos-simh-harness-v4.sh
PTY_RUN_SRC = tools/pty-run-v1.c
PTY_RUN = $(BUILD_ROOT)/tools/pty-run-v1
TCP_RUN_SRC = tools/tcp-run-v1.c
TCP_RUN = $(BUILD_ROOT)/tools/tcp-run-v1
PROBES = probes/daimos-runtime-probes-v3.txt
DSH_PROBES = probes/daimos-dsh-conformance-v1.txt
PROBE_CHECK = tests/validation/check-probe-format-v1.sh
COVERAGE = tests/validation/check-command-coverage-v1.sh
REPORT_MD = reports/daimos-runtime-probes-v3.md
KERNEL_BUILD = $(BUILD_ROOT)/tests/system/kernel
KERNEL_SMOKE_BUILD = $(BUILD_ROOT)/tests/system/kernel-smoke
KERNEL_DOS = $(KERNEL_BUILD)/boot.ini
KERNEL_HOST_CHECK = $(KERNEL_BUILD)/host-check-v1
DTFS_RUN = tests/system/dtfs-native-v1/run.sh

.PHONY: check-prefix check coverage image inventory runtime runtime-build regression dtfs-runtime d6fs-mres dtfs-mres mm-core target target-memfs-pdp6 target-memfs-fifo-pdp6 \
	target-file-pdp6 target-file-walk-pdp6 target-module-runtime-pdp6 target-d6lz-pdp6 target-wordtoken-pdp6 kernel-runtime stand-runtime d6fs-hdd-runtime d6fs-hdd-multi d6fs-recovery simulator-test test-daimos-stage1-kinit-entry test-daimos-kinit-sixbit-lifetime test-daimos-kcc-pdp6-codegen test-daimos-monitorfs-devices-online test-daimos-wcnsls-raw test-daimos-apr-user-protection test-daimos-apr-injected-fault test-daimos-apr-aap test-daimos-badmap-map test-daimos-badmap-root test-daimos-d6fs-context-dispatch test-daimos-d6fs-multimount test-daimos-d6fs-direct-backing-drm test-daimos-bcache-multisource test-daimos-bcache-allocation test-daimos-d6fs-remount test-daimos-d6fs-super-recovery test-daimos-vfs-storage-reservation test-daimos-logstore-v1 test-daimos-mtc516-online test-daimos-dsk270-online test-daimos-dsk270-elevator test-daimos-drm236-online test-daimos-drm236-minit test-daimos-drm236-capacity test-daimos-drm-stage1-boot test-daimos-dsk-root-discovery test-daimos-dtc-online test-daimos-dtc-stream-online test-daimos-tsfs-image-online test-daimos-tsfs-scan test-daimos-tsfs-multiextent test-daimos-tsfs-d6lz test-daimos-tsfs-dir test-daimos-tsfs-mount test-daimos-dtc-reverse-online test-daimos-low-memory-boot test-daimos-scheduler-multiproc test-daimos-scheduler-realtime test-daimos-scheduler-rt-revoke test-daimos-rt-required test-daimos-process-lifecycle test-daimos-process-id-lifetime test-daimos-process-hierarchy test-daimos-domain test-daimos-monitorfs-process-decimal test-daimos-process-events test-daimos-process-tty test-daimos-tty-session-state test-daimos-tty-routing test-daimos-dpy-interrupt-policy test-daimos-tty-s6rec test-daimos-tty-s6rec-input test-daimos-pt-wordio test-daimos-card-wordio test-daimos-lpt-s6rec test-daimos-exec-abi test-daimos-exec-replace test-daimos-exec-child-session test-daimos-userspace-bootstrap test-daimos-userspace-multitty test-daimos-make-boot-multitty test-daimos-login-password test-daimos-init-once test-daimos-session-teardown test-daimos-job-pipeline test-daimos-user-kuuo-isolation test-daimos-no-kernel-uuo test-daimos-trap-frequency test-daimos-proc-uarea-layout test-daimos-credentials test-daimos-credentials-fs test-daimos-proc-stack-watermark test-daimos-idle-stack-watermark test-daimos-pipe-wordfifo test-daimos-pipe-anon test-daimos-pipe-fifo test-daimos-swap-wait test-daimos-swap-stress test-daimos-d6fs-fcb-validate test-daimos-vfs-stat-frame test-daimos-pre-dsh-fs-closure test-daimos-dtfs-chain-walk test-daimos-dtfs-resize test-daimos-kfmt-u18 test-daimos-permanent-size test-daimos-p10fold-build test-host-d6lz-exec test-daimos-d6lz-native-exec test-pdp10-tools test-pdp10-tools-mkd6fs-encoding clean
	test-daimos-pi-restore test-daimos-tsfs-boot-eight
.PHONY: test-daimos-boot-source-matrix test-daimos-root-class-matrix test-daimos-auto-root-priority test-daimos-boot-root-cross-matrix test-daimos-root-login-lifecycle test-daimos-monitorfs-live-state test-daimos-monitorfs-storage-accounting test-daimos-dsh-conformance test-daimos-dsh-foreground test-daimos-native-tools regression regression-status regression-restart test-daimos-sleep test-daimos-multiuser-kernel-auth test-daimos-multiuser-auth-runtime


test-pdp10-tools-mkd6fs-encoding:
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_TOOLS_REPO="$$(cd "$(PDP10_TOOLS_REPO)" && pwd -P)" TMPDIR="$(TMPDIR)" \
		tests/tools/pdp10-tools/mkd6fs-encoding-v1-test.sh

check-prefix:
	@test -n "$(PDP10_PREFIX)" || { echo "PDP10_PREFIX must be set" >&2; exit 2; }

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

test-daimos-dsh-conformance: check-prefix $(PTY_RUN) image
	@$(PROBE_CHECK) $(DSH_PROBES)
	@env -u MAKEFLAGS -u MFLAGS PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' $(HARNESS) \
		--daimos-repo '$(DAIMOS_REPO)' --dofile '$(abspath $(KERNEL_DOS))' \
		--pty-run '$(abspath $(PTY_RUN))' --login ROOT --probes '$(DSH_PROBES)'

test-daimos-dsh-foreground: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-dsh-foreground-v1.sh

test-daimos-native-tools: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		tests/validation/daimos-native-tools-v1.sh

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
		tests/system/d6fs-hdd-v2/run-multimember-v1.sh

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
		'$(DAIMOS_REPO)/system/kernel/mm/mm_boot.c' \
		'$(DAIMOS_REPO)/system/kernel/modules/module_runtime.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc_boot.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/vm_pdp6.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/vm_pdp6_swap.c' \
		'$(DAIMOS_REPO)/system/kernel/proc/proc_swap_boot.c'
	'$(BUILD_ROOT)/tests/system/mm-v1/test'


target: mm-core target-backstore-pdp6 target-monitorfs-wordio-pdp6 target-memfs-pdp6 target-memfs-fifo-pdp6 target-file-pdp6 target-file-walk-pdp6 target-module-runtime-pdp6 target-stage1-d6lz-pdp6 target-wordtoken-pdp6 target-kcc-indexed-byteptr-pdp6 test-daimos-d6fs-fcb-validate test-daimos-vfs-stat-frame test-daimos-pre-dsh-fs-closure test-daimos-dtfs-chain-walk test-daimos-dtfs-resize test-daimos-kfmt-u18 test-daimos-pi-restore

target-backstore-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-backstore-pdp6-v1/run.sh

target-monitorfs-wordio-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-monitorfs-wordio-pdp6-v1/run.sh

target-memfs-pdp6:
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' tests/target/daimos-memfs-pdp6-v1/run.sh

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
	@MAKE='$(MAKE)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh

regression-status: check-prefix
	@MAKE='$(MAKE)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh --status

regression-restart: check-prefix
	@MAKE='$(MAKE)' PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		tests/validation/daimos-regression-resume-v1.sh --restart


# DAIMOS-specific validation tests migrated from pdp10-testkit.




test-daimos-pipe-wordfifo: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		tests/validation/daimos-pipe-wordfifo-v2.sh

test-daimos-pipe-anon: test-daimos-pipe-wordfifo



test-daimos-swap-wait: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@test -n "$(DAIMOS_TOOLS_REPO)" || { echo "DAIMOS_TOOLS_REPO must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		DAIMOS_TOOLS_REPO="$$(cd "$(DAIMOS_TOOLS_REPO)" && pwd -P)" \
		tests/validation/daimos-swap-wait-v1.sh

test-daimos-swap-stress: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@test -n "$(DAIMOS_TOOLS_REPO)" || { echo "DAIMOS_TOOLS_REPO must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		DAIMOS_TOOLS_REPO="$$(cd "$(DAIMOS_TOOLS_REPO)" && pwd -P)" \
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
	@PATH="$(PDP10_TOOLS_BIN):$$PATH" PDP10_PREFIX="$(PDP10_PREFIX)" \
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
		tests/validation/daimos-tsfs-dir-v2.sh


test-daimos-tsfs-mount: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@test -n "$(DAIMOS_TOOLS_REPO)" || { echo "DAIMOS_TOOLS_REPO must be set" >&2; exit 2; }
	@test -n "$(DAS_REPO)" || { echo "DAS_REPO must be set" >&2; exit 2; }
	@test -n "$(TMPDIR)" || { echo "TMPDIR must be set" >&2; exit 2; }
	@PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$(TMPDIR)" \
		DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
		DAIMOS_TOOLS_REPO="$$(cd "$(DAIMOS_TOOLS_REPO)" && pwd -P)" \
		DAS_REPO="$$(cd "$(DAS_REPO)" && pwd -P)" \
		tests/validation/daimos-tsfs-mount-v1.sh


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
