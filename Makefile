.PHONY: test-d6codec-lowcore-map-v1821
test-d6codec-lowcore-map-v1821:
	@python3 tests/validation/d6codec-v1459-integration/lowcore-map-v1821.py \
	 --build '$(abspath $(DAIMOS_REPO))/build'

.PHONY: test-native-manual-coverage-v1820
test-native-manual-coverage-v1820: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' \
	 python3 tests/validation/daimos-native-manual-coverage-v1820.py

.PHONY: test-bcache-low-placement-v1819
test-bcache-low-placement-v1819: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 sh tests/diagnostics/bcache-low-v1819/run-v1819.sh

.PHONY: test-dtfs-write-abi-v1818
test-dtfs-write-abi-v1818: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 sh tests/validation/daimos-dtfs-write-preserve-v1818.sh

.PHONY: test-d6codec-host-reference-v1824
test-d6codec-host-reference-v1824:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 DAIMOS_BUILD_DXR_DIR='$(abspath $(DAIMOS_REPO))/build/system/boot/pdp6' \
	 TMPDIR='$(TMPDIR)' HOST_CC='$(HOST_CC)' \
	 sh tests/validation/d6codec-host-reference-v1824/run-v1824.sh

.PHONY: test-kcore-pure-bitmap-probe-v1659
.PHONY: test-pure-stop-foreign-negatives-v1815
test-pure-stop-foreign-negatives-v1815:
	@V1815_EVIDENCE_ROOT="$${V1815_EVIDENCE_ROOT:?set preserved v1682 evidence}" \
	 TMPDIR="$(TMPDIR)" \
	 sh tests/validation/pure-stop-foreign-v1682/replay-negatives-v1815.sh

.PHONY: test-cat-make-consolidation-v1814
test-cat-make-consolidation-v1814: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 HOST_CC='$(HOST_CC)' \
	 sh tests/host/cat-make-consolidation-v1814/run-host-v1814.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 sh tests/host/cat-make-consolidation-v1814/run-native-frame-v1814.sh

.PHONY: test-toolchain-extern-expiry-v1812
.PHONY: test-toolchain-extern-expiry-simh-v1812
test-toolchain-extern-expiry-v1812: check-prefix
	@TOOL_SRC_DIR='$(abspath $(PDP10_TOOLS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 HOST_CC='$(HOST_CC)' \
	 sh tests/host/toolchain-extern-expiry-v1812/run-v1812.sh

test-toolchain-extern-expiry-simh-v1812: check-prefix
	@TOOL_SRC_DIR='$(abspath $(PDP10_TOOLS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
	 HOST_CC='$(HOST_CC)' \
	 sh tests/host/toolchain-extern-expiry-v1812/real-simh-v1812.sh

test-kcore-pure-bitmap-probe-v1659: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/pure-bitmap-probe-v1659/run-v1659.sh

.PHONY: test-kcore-pure-mm-owner-v1658
test-kcore-pure-mm-owner-v1658: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/pure-mm-owner-v1658/run-v1658.sh

.PHONY: test-daimos-swap-physical-final-v1349-preflight
test-daimos-swap-physical-final-v1349-preflight: check-prefix
	@python3 tests/validation/daimos-f07-swapstack-schema-v1349.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1349_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-physical-final-v1349.sh

.PHONY: test-daimos-swap-spinner-witness-v1348-preflight
test-daimos-swap-spinner-witness-v1348-preflight: check-prefix
	@python3 tests/validation/daimos-f07-spinner-progress-gate-v1348-selftest.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1348_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-spinner-witness-v1348.sh

.PHONY: test-daimos-swap-postflight-schema-v1347
test-daimos-swap-postflight-schema-v1347:
	@python3 tests/validation/daimos-swap-no-partner-physical-v1303.py --self-test
	@python3 tests/validation/daimos-swap-postflight-schema-v1347.py

.PHONY: test-daimos-swap-reclaim-refusal-v1346
test-daimos-swap-reclaim-refusal-v1346:
	@python3 tests/validation/daimos-swap-no-partner-physical-v1303.py --self-test
	@python3 tests/validation/daimos-swap-reclaim-refusal-v1346.py

.PHONY: test-daimos-swap-slot0-evidence-v1345
test-daimos-swap-slot0-evidence-v1345:
	@: "$${V1345_TRACE_LOG:?set V1345_TRACE_LOG to source-linked v1344 simh-sampler.log}"
	@python3 tests/validation/daimos-swap-slot0-recovery-evidence-v1345.py \
	 "$$V1345_TRACE_LOG"

.PHONY: test-daimos-swap-slot0-io-v1344-preflight
test-daimos-swap-slot0-io-v1344-preflight: check-prefix
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1344-selftest.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1344_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-slot0-io-trace-v1344.sh

.PHONY: test-daimos-f07-independent-provider-release-v1343
test-daimos-f07-independent-provider-release-v1343:
	@python3 tests/validation/daimos-f07-independent-provider-release-v1343-selftest.py

.PHONY: test-daimos-swap-stall-waits-v1341
test-daimos-swap-stall-waits-v1341:
	@python3 tests/validation/daimos-swap-stall-waits-v1341-selftest.py

.PHONY: test-daimos-simh-swap-live-sampler-v1342
test-daimos-simh-swap-live-sampler-v1342:
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1342-selftest.py

.PHONY: test-daimos-swap-timer-frontier-v1340-preflight
test-daimos-swap-timer-frontier-v1340-preflight: check-prefix
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1340-selftest.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1340_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-independent-trace-v1340.sh

.PHONY: test-daimos-swap-independent-trace-v1338-preflight
test-daimos-swap-independent-trace-v1338-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1338_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-independent-trace-v1338.sh

.PHONY: test-daimos-swap-live-pressure-v1336
test-daimos-swap-live-pressure-v1336:
	@python3 tests/validation/daimos-swap-live-pressure-v1336.py --self-test
	@if [ -f "$${TMPDIR:-$$HOME/tmp}/daimos-swap-early-owner-pressure-v1335-evidence-r1/guest/addresses" ]; then \
	 python3 tests/validation/daimos-swap-live-pressure-v1336.py \
	 "$${TMPDIR:-$$HOME/tmp}/daimos-swap-early-owner-pressure-v1335-evidence-r1/guest/addresses" \
	 "$${TMPDIR:-$$HOME/tmp}/daimos-swap-early-owner-pressure-v1335-evidence-r1/guest/simh.out.raw-v1306.log"; \
	 fi

.PHONY: test-daimos-swap-independent-release-v1336-preflight
test-daimos-swap-independent-release-v1336-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1336_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-independent-release-v1336.sh

.PHONY: test-daimos-swap-physical-pinned-v1329-preflight
test-daimos-swap-physical-pinned-v1329-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1329_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1329.sh

.PHONY: test-daimos-swap-resident-pins-v1326-preflight
test-daimos-swap-resident-pins-v1326-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1326_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1326.sh

.PHONY: test-daimos-simh-swap-live-sampler-v1326
test-daimos-simh-swap-live-sampler-v1326: check-prefix
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1326-selftest.py

.PHONY: test-daimos-swap-owner-postmortem-v1325
test-daimos-swap-owner-postmortem-v1325: check-prefix
	@: "$${V1325_ADDRESSES:?set full-guest address manifest}"
	@: "$${V1325_SIMH_OUT:?set completed guest transcript}"
	@python3 tests/validation/daimos-swap-owner-admission-postmortem-v1325.py \
	 "$${V1325_ADDRESSES}" "$${V1325_SIMH_OUT}"

.PHONY: test-daimos-simh-swap-live-sampler-v1324
test-daimos-simh-swap-live-sampler-v1324: check-prefix
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1324-selftest.py

.PHONY: test-daimos-swap-physical-owner-v1323-preflight
test-daimos-swap-physical-owner-v1323-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1323_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1323.sh

.PHONY: test-daimos-swap-physical-owner-v1322-preflight
test-daimos-swap-physical-owner-v1322-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1322_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1322.sh

.PHONY: test-daimos-swap-physical-owner-v1321-preflight
test-daimos-swap-physical-owner-v1321-preflight: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1321_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1321.sh

.PHONY: test-daimos-swap-in-device-gateway-v1319
test-daimos-swap-in-device-gateway-v1319: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-in-device-gateway-v1319.sh

.PHONY: test-daimos-swap-in-real-transaction-v1316
test-daimos-swap-in-real-transaction-v1316: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-in-real-transaction-v1316.sh

.PHONY: test-daimos-swap-real-mm-no-partner-v1313
test-daimos-swap-real-mm-no-partner-v1313: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-real-mm-no-partner-v1313.sh

.PHONY: test-daimos-swap-postflight-replay-v1311
test-daimos-swap-postflight-replay-v1311: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 V1311_GUEST_DIR="$${V1311_GUEST_DIR:?set V1311_GUEST_DIR to an existing complete 256K guest}" \
	 sh tests/validation/daimos-swap-postflight-replay-v1311.sh

.PHONY: test-daimos-simh-swap-live-sampler-v1306
test-daimos-simh-swap-live-sampler-v1306:
	@python3 tests/validation/daimos-simh-swap-live-sampler-v1306-selftest.py

.PHONY: test-daimos-swap-no-partner-v1304-preflight
test-daimos-swap-no-partner-v1304-preflight:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1304_PREPARE_ONLY=1 \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1304.sh

.PHONY: test-daimos-swap-no-partner-physical-v1303
test-daimos-swap-no-partner-physical-v1303:
	@python3 tests/validation/daimos-swap-no-partner-physical-v1303.py \
	 --self-test

.PHONY: test-daimos-swap-no-partner-fullguest-v1304
test-daimos-swap-no-partner-fullguest-v1304: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-no-partner-fullguest-v1304.sh

.PHONY: test-daimos-swap-no-partner-v1301
test-daimos-swap-no-partner-v1301: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-no-partner-v1301.sh

.PHONY: test-daimos-swap-no-partner-contract-v1300
test-daimos-swap-no-partner-contract-v1300:
	@python3 tests/validation/daimos-swap-no-partner-contract-v1300.py \
	 '$(abspath $(DAIMOS_REPO))'

.PHONY: test-daimos-mm-swap-result-contract-v756
test-daimos-mm-swap-result-contract-v756: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-mm-swap-result-contract-v756.sh

.PHONY: test-daimos-f07-combined-v1206 test-daimos-f07-combined-disabled-v1206
test-daimos-f07-combined-v1206: check-prefix
	@test -n '$(V1206_EVIDENCE_DIR)' || { \
	 echo 'v1206: specify fresh V1206_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1206_OOM_ENABLED=1 \
	 V1206_EVIDENCE_DIR='$(V1206_EVIDENCE_DIR)' \
	 sh tests/validation/daimos-f07-combined-v1206.sh

test-daimos-f07-combined-disabled-v1206: check-prefix
	@test -n '$(V1206_EVIDENCE_DIR)' || { \
	 echo 'v1206: specify fresh V1206_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1206_OOM_ENABLED=0 \
	 V1206_EVIDENCE_DIR='$(V1206_EVIDENCE_DIR)' \
	 sh tests/validation/daimos-f07-combined-v1206.sh

.PHONY: test-daimos-f07-real-proc-v1205 test-daimos-f07-real-proc-disabled-v1205
test-daimos-f07-real-proc-v1205: check-prefix
	@test -n '$(V1205_EVIDENCE_DIR)' || { \
	 echo 'v1205: specify fresh V1205_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1205_OOM_ENABLED=1 \
	 V1205_EVIDENCE_DIR='$(V1205_EVIDENCE_DIR)' \
	 sh tests/validation/daimos-f07-real-proc-v1205.sh

test-daimos-f07-real-proc-disabled-v1205: check-prefix
	@test -n '$(V1205_EVIDENCE_DIR)' || { \
	 echo 'v1205: specify fresh V1205_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1205_OOM_ENABLED=0 \
	 V1205_EVIDENCE_DIR='$(V1205_EVIDENCE_DIR)' \
	 sh tests/validation/daimos-f07-real-proc-v1205.sh

.PHONY: test-daimos-f07-mm-high-v1204 test-daimos-f07-mm-high-disabled-v1204
test-daimos-f07-mm-high-v1204: check-prefix
	@test -n '$(V1204_EVIDENCE_DIR)' || { \
	 echo 'v1204: specify a fresh V1204_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 V1204_EVIDENCE_DIR='$(V1204_EVIDENCE_DIR)' V1204_OOM_ENABLED=1 \
	 sh tests/validation/daimos-f07-mm-high-v1204.sh

test-daimos-f07-mm-high-disabled-v1204: check-prefix
	@test -n '$(V1204_EVIDENCE_DIR)' || { \
	 echo 'v1204: specify a fresh V1204_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 V1204_EVIDENCE_DIR='$(V1204_EVIDENCE_DIR)' V1204_OOM_ENABLED=0 \
	 sh tests/validation/daimos-f07-mm-high-v1204.sh

.PHONY: test-daimos-f07-mm-peak-v1203 test-daimos-f07-mm-peak-disabled-v1203
test-daimos-f07-mm-peak-v1203: check-prefix
	@test -n '$(V1203_EVIDENCE_DIR)' || { \
	 echo 'v1203: specify a fresh V1203_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 V1203_EVIDENCE_DIR='$(V1203_EVIDENCE_DIR)' V1203_OOM_ENABLED=1 \
	 sh tests/validation/daimos-f07-mm-peak-v1203.sh

test-daimos-f07-mm-peak-disabled-v1203: check-prefix
	@test -n '$(V1203_EVIDENCE_DIR)' || { \
	 echo 'v1203: specify a fresh V1203_EVIDENCE_DIR' >&2; exit 2; }
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 V1203_EVIDENCE_DIR='$(V1203_EVIDENCE_DIR)' V1203_OOM_ENABLED=0 \
	 sh tests/validation/daimos-f07-mm-peak-v1203.sh

.PHONY: test-daimos-d6fs-explicit-zero-layout-v1192
test-daimos-d6fs-explicit-zero-layout-v1192:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-d6fs-explicit-zero-layout-v1192.sh

.PHONY: test-daimos-oom-build-diagnostics-v1190
test-daimos-oom-build-diagnostics-v1190:
	@test -n '$(V1190_ARM_ARCHIVE)' && test -n '$(V1190_LINUX_ARCHIVE)' || \
	 { echo 'v1190: provide Android and Linux archives' >&2; exit 2; }
	@python3 tests/validation/daimos-oom-build-diagnostics-v1190.py \
	 '$(V1190_ARM_ARCHIVE)' '$(V1190_LINUX_ARCHIVE)'

.PHONY: test-daimos-mres-residency-inventory-v1176
test-daimos-mres-residency-inventory-v1176:
	@test -n '$(V1176_ARCHIVE)' || \
	 { echo 'v1176: specify V1176_ARCHIVE' >&2; exit 2; }
	@python3 tests/validation/daimos-mres-residency-inventory-v1176.py \
	 '$(V1176_ARCHIVE)'

.PHONY: test-daimos-oom-residency-v1174
test-daimos-oom-residency-v1174: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-residency-v1174.sh

.PHONY: test-daimos-oom-cross-platform-v1163
test-daimos-oom-cross-platform-v1163:
	@test -n '$(V1163_ARM_ARCHIVE)' && test -n '$(V1163_LINUX_ARCHIVE)' || \
	 { echo 'v1163: specify both V1163_ARM_ARCHIVE and V1163_LINUX_ARCHIVE' >&2; exit 2; }
	@python3 tests/validation/daimos-oom-cross-platform-v1163.py \
	 '$(V1163_ARM_ARCHIVE)' '$(V1163_LINUX_ARCHIVE)'

.PHONY: test-daimos-oom-release-media-v1160
test-daimos-oom-release-media-v1160: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-release-media-v1160.sh

.PHONY: test-daimos-oom-protected-v1159 test-daimos-oom-protected-disabled-v1159
test-daimos-oom-protected-v1159: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" sh tests/validation/daimos-oom-protected-v1159.sh
test-daimos-oom-protected-disabled-v1159: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1159_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-protected-v1159.sh

.PHONY: test-daimos-oom-run-parent-v1158 test-daimos-oom-run-parent-disabled-v1158
test-daimos-oom-run-parent-v1158: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" sh tests/validation/daimos-oom-run-parent-v1158.sh
test-daimos-oom-run-parent-disabled-v1158: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1158_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-run-parent-v1158.sh

.PHONY: test-daimos-fatal-exec-provider-v1157
test-daimos-fatal-exec-provider-v1157: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-provider-v1157.sh

.PHONY: test-daimos-oom-exact-once-matrix-v1146
test-daimos-oom-exact-once-matrix-v1146: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-exact-once-matrix-v1146.sh

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
.PHONY: test-daimos-file-directmount-20261026-v417
test-daimos-file-directmount-20261026-v417: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-file-directmount-20261026-v417.sh
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-pipe-directmount-20261026-v417.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' sh tests/validation/daimos-file-cutover-guard-20261026-v416.sh
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	    TMPDIR='$(TMPDIR)' sh tests/validation/daimos-vfs-umask-20261026-v417.sh
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


target: mm-core target-backstore-pdp6 target-monitorfs-wordio-pdp6 target-memfs-pdp6 target-memfs-fifo-pdp6 target-file-pdp6 target-file-walk-pdp6 target-module-runtime-pdp6 target-swap-pure-text-pdp6 target-stage1-d6lz-pdp6 target-wordtoken-pdp6 test-daimos-compiler-selection-20261012-v1 test-daimos-d6fs-fcb-validate test-daimos-vfs-stat-frame test-daimos-pre-dsh-fs-closure test-daimos-dtfs-chain-walk test-daimos-dtfs-resize test-daimos-kfmt-u18 test-daimos-pi-restore

# Compiler and assembler code-generation regressions are owned by
# ../pdp10-testkit, never by this DAIMOS OS target sweep.

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

.PHONY: target-d6fs-free-fcb-pdp6-v1
target-d6fs-free-fcb-pdp6-v1: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/target/daimos-d6fs-free-fcb-pdp6-v1/run.sh

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

.PHONY: test-daimos-f07-software-timer-v1252
test-daimos-f07-software-timer-v1252: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/validation/daimos-f07-software-timer-v1252.sh

.PHONY: test-daimos-sched-resident-tie-v1256
test-daimos-sched-resident-tie-v1256: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/validation/daimos-sched-resident-tie-v1256.sh

.PHONY: test-daimos-mm-arena-feasibility-v1260
test-daimos-mm-arena-feasibility-v1260: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/validation/daimos-mm-arena-feasibility-v1260.sh

.PHONY: test-daimos-mm-brk-impossible-v1260
test-daimos-mm-brk-impossible-v1260: check-prefix
	@TMPDIR='$(TMPDIR)' PDP10_PREFIX='$(PDP10_PREFIX)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/validation/daimos-mm-brk-impossible-v1260.sh

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

.PHONY: test-daimos-stack-watermark-bounds-v1239
test-daimos-stack-watermark-bounds-v1239: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-stack-watermark-bounds-v1239.sh

.PHONY: test-daimos-uarea-canary-boundary-v1243
test-daimos-uarea-canary-boundary-v1243: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-uarea-canary-boundary-v1243.sh

.PHONY: test-daimos-swap-exchange-backing-v1241
test-daimos-swap-exchange-backing-v1241: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		TMPDIR='$(TMPDIR)' sh tests/validation/daimos-swap-exchange-backing-v1241.sh

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

.PHONY: test-daimos-kcc-pdp6-codegen
test-daimos-kcc-pdp6-codegen: check-prefix
	@test -n "$(DAIMOS_REPO)" || { echo "DAIMOS_REPO must be set" >&2; exit 2; }
	@DAIMOS_REPO="$$(cd "$(DAIMOS_REPO)" && pwd -P)" \
	    PDP10_PREFIX="$(PDP10_PREFIX)" TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	    sh tests/validation/daimos-kinit-pdp6-stack-codegen-v1.sh

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

.PHONY: test-daimos-drm236-pi-registers-v1247
test-daimos-drm236-pi-registers-v1247: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
		DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		sh tests/validation/daimos-drm236-pi-registers-v1247.sh

.PHONY: test-daimos-f07-pi-map-probe-v1249
test-daimos-f07-pi-map-probe-v1249:
	@python3 tests/validation/daimos-f07-pi-map-probe-test-v1249.py

.PHONY: test-daimos-f07-slot0-wait-probe-v1250
test-daimos-f07-slot0-wait-probe-v1250:
	@python3 tests/validation/daimos-f07-slot0-wait-report-test-v1250.py

.PHONY: test-daimos-f07-dispatch-tally-v1253
test-daimos-f07-dispatch-tally-v1253: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
		python3 tests/validation/daimos-f07-dispatch-tally-test-v1253.py \
		'$(abspath $(DAIMOS_REPO))'
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' TMPDIR='$(TMPDIR)' \
		sh tests/validation/daimos-f07-dispatch-native-v1253.sh

.PHONY: test-daimos-f07-provider-snapshot-v1254
test-daimos-f07-provider-snapshot-v1254:
	@python3 tests/validation/daimos-f07-provider-report-test-v1254.py

.PHONY: test-daimos-f07-provider-order-v1259
test-daimos-f07-provider-order-v1259:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' TMPDIR='$(TMPDIR)' \
		python3 tests/validation/daimos-f07-provider-order-test-v1259.py

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

.PHONY: test-daimos-oom-provider-held-v1150
test-daimos-oom-provider-held-v1150: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1150_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-provider-held-v1150.sh

.PHONY: test-daimos-oom-provider-held-disabled-v1150
test-daimos-oom-provider-held-disabled-v1150: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1150_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-provider-held-v1150.sh

.PHONY: test-daimos-oom-endurance-v1151
test-daimos-oom-endurance-v1151: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1151_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-endurance-v1151.sh

.PHONY: test-daimos-oom-endurance-disabled-v1151
test-daimos-oom-endurance-disabled-v1151: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1151_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-endurance-v1151.sh

.PHONY: test-daimos-oom-brk-negatives-v1110
.PHONY: test-daimos-oom-pid-reuse-v1120
.PHONY: test-daimos-vm-none-idempotent-v1129
.PHONY: test-daimos-run-pgrp-new-v1130
test-daimos-run-pgrp-new-v1130: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-run-pgrp-new-v1130.sh

.PHONY: test-daimos-fatal-exec-discard-diag-v1131
test-daimos-fatal-exec-discard-diag-v1131: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-discard-diag-v1131.sh

.PHONY: test-daimos-fatal-exec-layout-diag-v1132
test-daimos-fatal-exec-layout-diag-v1132: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-layout-diag-v1132.sh

.PHONY: test-daimos-fatal-exec-run-boundary-v1133
test-daimos-fatal-exec-run-boundary-v1133: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-run-boundary-v1133.sh

.PHONY: test-daimos-fatal-exec-text-placement-v1134
.PHONY: test-daimos-fatal-exec-return-state-v1135
.PHONY: test-daimos-fatal-exec-return-break-v1136
.PHONY: test-daimos-fatal-exec-sequential-return-v1137
.PHONY: test-daimos-fatal-exec-discard-breaks-v1138
.PHONY: test-daimos-fatal-exec-release-breaks-v1139
.PHONY: test-daimos-oom-pipe-dpy-vm-provider-v1144
test-daimos-oom-pipe-dpy-vm-provider-v1144: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-pipe-dpy-vm-provider-v1144.sh

.PHONY: test-daimos-oom-pi6-spinners-v1153
test-daimos-oom-pi6-spinners-v1153: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-pi6-spinners-v1153.sh

.PHONY: test-daimos-oom-disk-pi6-v1154
test-daimos-oom-disk-pi6-v1154: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-disk-pi6-v1154.sh

.PHONY: test-daimos-fold-plan-fields-v1277
test-daimos-fold-plan-fields-v1277: check-prefix
	@PDP10_PREFIX='$(PDP10_PREFIX)' \
	 P10FOLD="$${P10FOLD:-$(PDP10_PREFIX)/bin/p10fold}" \
	 DLINK="$${DLINK:-$(PDP10_PREFIX)/bin/dlink}" \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fold-plan-fields-v1277.sh

.PHONY: test-daimos-fatal-exec-physical-uarea-v1142
test-daimos-fatal-exec-physical-uarea-v1142: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-physical-uarea-v1142.sh

test-daimos-fatal-exec-release-breaks-v1139: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-release-breaks-v1139.sh

test-daimos-fatal-exec-discard-breaks-v1138: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-discard-breaks-v1138.sh

test-daimos-fatal-exec-sequential-return-v1137: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-sequential-return-v1137.sh

test-daimos-fatal-exec-return-break-v1136: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-return-break-v1136.sh

# The following explicit OS tests were formerly misplaced among compiler
# and assembler tests.  The host checks are safe and bounded.  Boot/media
# and guest-native DAS checks remain operator-selected, never part of the
# ordinary compiler sweep in pdp10-testkit.
PDP10_TESTKIT_REPO ?= $(abspath ../pdp10-testkit)

.PHONY: test-daimos-native-toolchain-list-v1 test-daimos-native-toolchain-run-v1 test-daimos-native-toolchain-verify-v2
test-daimos-native-toolchain-list-v1:
	@python3 tools/run-native-toolchain-v1.py list
test-daimos-native-toolchain-run-v1:
	@test -n "$(TEST_ID)" || { echo "TEST_ID is required" >&2; exit 2; }
	@python3 tools/run-native-toolchain-v1.py run "$(TEST_ID)"
test-daimos-native-toolchain-verify-v2:
	@python3 tools/test-native-toolchain-dispatch-v2.py

.PHONY: test-testkit-scope-v1 test-daimos-migrated-os-host-v1
test-testkit-scope-v1:
	@PDP10_TESTKIT_REPO='$(PDP10_TESTKIT_REPO)' \
	 python3 '$(PDP10_TESTKIT_REPO)/tools/test-testkit-boundary-v1.py'

test-daimos-migrated-os-host-v1:
	@set -e; for test in \
	 test-aap-kernel-coverage-v1.py \
	 test-aap-daimos-asm-coverage-v1.py \
	 test-pdp6-boot-failure-v1.py \
	 test-pdp6-kernel-boot-profile-v1.py \
	 test-pdp6-root-media-v1.py \
	 test-pdp6-root-snapshot-v1.py \
	 test-pdp6-linked-profile-v1.py \
	 test-pdp6-fresh-media-profile-v1.py; do \
	  PDP10_TESTKIT_REPO='$(PDP10_TESTKIT_REPO)' python3 "tests/validation/$$test"; \
	 done

.PHONY: test-daimos-rm-recursive-os-20261117-v1
test-daimos-rm-recursive-os-20261117-v1:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 sh tests/host/daimos-rm-recursive-os-20261117-v1.sh

.PHONY: test-daimos-aap-stage1-v1 test-daimos-aap-stage1-trace-v1
.PHONY: test-daimos-aap-alt-stage1-media-v1 test-daimos-aap-ptr-handoff-v1
.PHONY: test-daimos-simh-ptr-tsfs-boot-v1 test-daimos-native-das-guest-v1
test-daimos-aap-stage1-v1:
	@sh tests/validation/test-aap-daimos-stage1-v1.sh
test-daimos-aap-stage1-trace-v1:
	@sh tests/validation/test-aap-daimos-stage1-trace-v1.sh
test-daimos-aap-alt-stage1-media-v1:
	@sh tests/validation/test-aap-alt-stage1-media-v1.sh
test-daimos-aap-ptr-handoff-v1:
	@python3 tests/validation/test-aap-ptr-handoff-v1.py
test-daimos-simh-ptr-tsfs-boot-v1:
	@sh tests/validation/test-simh-ptr-tsfs-boot-v1.sh
test-daimos-native-das-guest-v1:
	@PDP10_PREFIX='$(PDP10_PREFIX)' DAS_ROOT='$(DAS_REPO)' \
	 DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 NATIVE_BUILD_DIR='$(NATIVE_BUILD_DIR)' TMPDIR='$${TMPDIR:-$$HOME/tmp}' \
	 sh tests/validation/das-native-guest-v1/run-das-native-daimos.sh

test-daimos-fatal-exec-return-state-v1135: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-return-state-v1135.sh

test-daimos-fatal-exec-text-placement-v1134: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-exec-text-placement-v1134.sh

test-daimos-vm-none-idempotent-v1129: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-vm-none-idempotent-v1129.sh

.PHONY: test-daimos-oom-scope-v1123
test-daimos-oom-scope-v1123: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-scope-v1123.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-readiness-v1123.py --audit

.PHONY: check-daimos-oom-ready-v1123
check-daimos-oom-ready-v1123: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-scope-v1123.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 python3 tests/validation/daimos-oom-readiness-v1123.py --require-ready

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

.PHONY: test-daimos-pipe-fatal-wait-v1261
test-daimos-pipe-fatal-wait-v1261: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-pipe-fatal-wait-v1261.sh

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
.PHONY: test-daimos-tty-vm-uarea-v1124
.PHONY: test-daimos-tty-pi6-owner-v1147
test-daimos-tty-pi6-owner-v1147: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-tty-pi6-owner-v1147.sh

.PHONY: test-daimos-tty-pending-hup-pi6-v1148
test-daimos-tty-pending-hup-pi6-v1148: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-tty-pending-hup-pi6-v1148.sh

.PHONY: test-daimos-oom-unbounded-owner-v1149
test-daimos-oom-unbounded-owner-v1149: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 python3 tests/validation/daimos-oom-unbounded-owner-v1149.py
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-close-backoff-v885.sh
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-reaper-backoff-v1102.sh

.PHONY: test-daimos-oom-groups-sessions-v1155
test-daimos-oom-groups-sessions-v1155: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-groups-sessions-v1155.sh

.PHONY: test-daimos-oom-backstore-capacity-v1156
test-daimos-oom-backstore-capacity-v1156: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-backstore-capacity-v1156.sh

.PHONY: test-daimos-oom-disk-full-v1156
test-daimos-oom-disk-full-v1156: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1156_OOM_ENABLED=0 \
	 sh tests/validation/daimos-oom-disk-full-v1156.sh

.PHONY: test-daimos-oom-disk-full-enabled-v1156
test-daimos-oom-disk-full-enabled-v1156: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" V1156_OOM_ENABLED=1 \
	 sh tests/validation/daimos-oom-disk-full-v1156.sh

.PHONY: test-daimos-oom-error-matrix-v1156
test-daimos-oom-error-matrix-v1156: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-oom-error-matrix-v1156.sh

test-daimos-tty-vm-uarea-v1124: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-tty-vm-uarea-v1124.sh

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
.PHONY: test-daimos-session-hup-dpy-swap-v1121
.PHONY: test-daimos-session-hup-pipe-swap-v1122
test-daimos-session-hup-pipe-swap-v1122: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-pipe-swap-v1122.sh

test-daimos-session-hup-dpy-swap-v1121: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-session-hup-dpy-swap-v1121.sh

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
.PHONY: test-daimos-fatal-mm-provider-v1125
test-daimos-fatal-mm-provider-v1125: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-fatal-mm-provider-v1125.sh

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

.PHONY: test-daimos-f07-requester-stage-v1259
test-daimos-f07-requester-stage-v1259:
	@TMPDIR='$(TMPDIR)' python3 tests/validation/daimos-f07-requester-stage-test-v1259.py

.PHONY: test-daimos-pure-ram-rollback-v1395
test-daimos-pure-ram-rollback-v1395: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/pure-ram-rollback-v1395/run-v1395.sh

.PHONY: test-daimos-xip-restricted-policy-v1394
test-daimos-xip-restricted-policy-v1394: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/xip-restricted-policy-v1394/run-v1394.sh

.PHONY: test-daimos-backstore-free-ownership-v1393
test-daimos-backstore-free-ownership-v1393: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-backstore-free-ownership-v1393.sh

.PHONY: test-daimos-swap-in-checked-release-v1405
test-daimos-swap-in-checked-release-v1405: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 TMPDIR="$${TMPDIR:-$$HOME/tmp}" \
	 sh tests/validation/daimos-swap-in-checked-release-v1405.sh

.PHONY: test-daimos-d6codec-release-selection-v1464
test-daimos-d6codec-release-selection-v1464:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
	 sh tests/validation/d6codec-release-selection-v1464.sh

# v1673: opt-in source-matched 48K PDP-6 RAW PURE reclamation.
# Keep out of the default regression matrix until physical acceptance.
.PHONY: test-pure-runtime-reclaim-v1673
test-pure-runtime-reclaim-v1673:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' \
		sh tests/validation/pure-runtime-reclaim-v1673/run-physical-v1673.sh

# v1674: opt-in physical 48K RAW PURE MM write-watch high-water.
.PHONY: test-pure-runtime-highwater-v1674
test-pure-runtime-highwater-v1674:
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' \
		PDP10_PREFIX='$(PDP10_PREFIX)' \
		sh tests/validation/pure-runtime-highwater-v1674/run-physical-v1674.sh

# v1674: lightweight native MM write-replay invariant test.
.PHONY: test-pure-runtime-highwater-native-v1674
test-pure-runtime-highwater-native-v1674:
	@python3 tests/validation/pure-runtime-highwater-v1674/test-replay-v1674.py

# DAIMOS WRITECHAR integration (explicit opt-in; never in default sweeps).
# The first test records calls; only the second boots a real OS guest.
.PHONY: test-daimos-gcc-stdio-console-abi-v1
test-daimos-gcc-stdio-console-abi-v1: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-gcc-stdio-console-abi-v1.sh

.PHONY: test-daimos-gcc-stdio-console-guest-v1
test-daimos-gcc-stdio-console-guest-v1: check-prefix
	@DAIMOS_REPO='$(abspath $(DAIMOS_REPO))' PDP10_PREFIX='$(PDP10_PREFIX)' \
	 sh tests/validation/daimos-gcc-stdio-console-guest-v1.sh

# v1677: opt-in native PDP-6 two-owner PURE fault preflight (not physical PI6).
.PHONY: test-pure-pi6-fault-native-v1677
test-pure-pi6-fault-native-v1677:
	@DAIMOS_REPO="$${DAIMOS_REPO:?original DAIMOS source required}" \
	 sh tests/validation/pure-pi6-fault-pressure-v1677/run-v1677.sh

# v1678: native original PDP-6 MM precommit pin/rebase rejection and retry.
.PHONY: test-pure-mm-precommit-native-v1678
test-pure-mm-precommit-native-v1678:
	@DAIMOS_REPO="$${DAIMOS_REPO:?original PURE source checkout required}" \
	 sh tests/validation/pure-mm-precommit-v1678/run-v1678.sh

# v1679: native PDP-6 repeat-MM-refusal owner and bystander safety.
.PHONY: test-pure-mm-persistent-native-v1679
test-pure-mm-persistent-native-v1679:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source required}" \
	 sh tests/validation/pure-mm-persistent-v1679/run-v1679.sh

# v1680: native PDP-6 terminal pinned-owner retry, isolation and mutation.
.PHONY: test-pure-terminal-pin-native-v1680
test-pure-terminal-pin-native-v1680:
	@DAIMOS_REPO="$${DAIMOS_REPO:?source-matched DAIMOS tree required}" \
	 sh tests/validation/pure-terminal-pin-v1680/run-v1680.sh

# v1680: native original PDP-6 idle FINALIZE+PREVM repeated refusal.
.PHONY: test-pure-prevm-finalizer-native-v1680
test-pure-prevm-finalizer-native-v1680:
	@DAIMOS_REPO="$${DAIMOS_REPO:?source-matched DAIMOS tree required}" \
	 sh tests/validation/pure-prevm-finalizer-v1680/run-v1680.sh

# v1681: original PDP-6 MM pin/unpin + VM/PURE terminal + FINALIZE/PREVM.
.PHONY: test-pure-terminal-finalizer-native-v1681
test-pure-terminal-finalizer-native-v1681:
	@DAIMOS_REPO="$${DAIMOS_REPO:?original DAIMOS source required}" \
	 sh tests/validation/pure-terminal-finalizer-v1681/run-v1681.sh

# v1684: native C89 two-source PURE ownership under original FULL + VFS.
.PHONY: test-pure-multiowner-source-native-v1684
test-pure-multiowner-source-native-v1684:
	@DAIMOS_REPO="$${DAIMOS_REPO:?source-matched DAIMOS required}" \
	 sh tests/validation/pure-multiowner-source-v1684/run-v1684.sh

# v1804: opt-in combined K03/K04/RAW PURE source acceptance gate.
# K04 witness replay is read-only; this does not boot an integrated guest.
.PHONY: test-pure-integration-native-v1804
test-pure-integration-native-v1804:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1804 DAIMOS integration checkout required}" \
	 sh tests/validation/pure-integration-v1804/run-v1804.sh

# v1807: opt-in RAW PURE + K04 native integration matrix.
# No synthetic physical or 48K/64K acceptance is inferred.
.PHONY: test-pure-integration-native-v1807
test-pure-integration-native-v1807: \
 test-pure-pi6-fault-native-v1677 \
 test-pure-mm-precommit-native-v1678 \
 test-pure-mm-persistent-native-v1679 \
 test-pure-terminal-pin-native-v1680 \
 test-pure-prevm-finalizer-native-v1680 \
 test-pure-terminal-finalizer-native-v1681 \
 test-pure-multiowner-source-native-v1684 \
 test-pure-runtime-highwater-native-v1674 \
 test-pure-integration-native-v1804
	@echo 'PASS v1807: native RAW PURE/K04 integration matrix (physical acceptance separate)'

# v1808: committed-state READY_ONCE after a lost PURE restore reply.
.PHONY: test-pure-k05-restore-reply-native-v1808
test-pure-k05-restore-reply-native-v1808:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS v1808 K05 source checkout required}" \
	 sh tests/validation/pure-restore-reply-v1808/run-v1808.sh

.PHONY: test-pure-integration-native-v1808
test-pure-integration-native-v1808: test-pure-integration-native-v1807 \
 test-pure-k05-restore-reply-native-v1808
	@echo 'PASS v1808: v1807 native suite plus K05 restore lost-success regression'

# K05: MM source-free result ambiguity during bounded FULL restore.
.PHONY: test-pure-k05-source-free-native-v1839
test-pure-k05-source-free-native-v1839:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS K05 source checkout required}" \
	 sh tests/validation/pure-full-free-reply-v1839/run-v1839.sh

.PHONY: test-pure-integration-native-v1839
test-pure-integration-native-v1839: test-pure-integration-native-v1808 \
 test-pure-k05-source-free-native-v1839
	@echo 'PASS v1839: integrated RAW PURE native suite and K05 source-free reply'

# K05: both original FULL MM owners must be exactly singly pinned at
# PI-atomic commit; persistent allocation failures may retry safely.
.PHONY: test-pure-k05-pinned-commit-native-v1855
test-pure-k05-pinned-commit-native-v1855:
	@DAIMOS_REPO="$${DAIMOS_REPO:?current DAIMOS K05 source required}" \
	 sh tests/validation/pure-k05-pinned-commit-v1855/run-v1855.sh

# K05: physical 48K original FULL, debugger-injected exact MM target
# pin2, original -5 quarantine and real PCLK with owner preservation.
.PHONY: test-pure-k05-physical-overpin-v1890
test-pure-k05-physical-overpin-v1890:
	@V1890_BUILD="$${V1890_BUILD:?source-built v1855 48K image required}" \
	 V1890_PROBE="$${V1890_PROBE:?original installed MRES probe required}" \
	 V1890_PRIOR="$${V1890_PRIOR:?accepted v1848 physical FULL required}" \
	 sh tests/validation/pure-k05-physical-overpin-v1890/run-v1890.sh

.PHONY: test-pure-k05-physical-overpin-audit-v1890
test-pure-k05-physical-overpin-audit-v1890:
	@V1890_BUILD="$${V1890_BUILD:?source-built v1855 48K image required}" \
	 V1890_WORK="$${V1890_WORK:?actual v1890 physical trace required}" \
	 sh tests/validation/pure-k05-physical-overpin-v1890/audit-v1890.sh

# K05: source-linked 48K physical process TRANSITION flag and peer
# owner/scheduler descriptors after target pin2 FULL refusal and PCLK.
.PHONY: test-pure-k05-process-quarantine-v1891
test-pure-k05-process-quarantine-v1891:
	@V1891_BUILD="$${V1891_BUILD:?source-built v1855 48K image required}" \
	 V1891_PROBE="$${V1891_PROBE:?actual MRES probe required}" \
	 V1891_PRIOR="$${V1891_PRIOR:?accepted v1848 owner stage required}" \
	 V1891_V1890="$${V1891_V1890:?accepted v1890 original trace required}" \
	 sh tests/validation/pure-k05-physical-overpin-v1890/run-process-v1891.sh

.PHONY: test-pure-k05-process-quarantine-audit-v1891
test-pure-k05-process-quarantine-audit-v1891:
	@V1891_BUILD="$${V1891_BUILD:?source-built v1855 48K image required}" \
	 V1891_WORK="$${V1891_WORK:?completed physical process-table trace required}" \
	 sh tests/validation/pure-k05-physical-overpin-v1890/audit-process-v1891.sh

# K05: retain the identical original 48K KCORE/PURE/pressure path,
# with a test-only already-resident parent user heartbeat after fault.
.PHONY: test-pure-k05-resident-peer-build-v1892
test-pure-k05-resident-peer-build-v1892:
	@DAIMOS_REPO="$${DAIMOS_REPO:?source-matched DAIMOS checkout required}" \
	 sh tests/validation/pure-k05-resident-peer-v1892/build-v1892.sh

.PHONY: test-pure-k05-resident-peer-physical-v1892
test-pure-k05-resident-peer-physical-v1892:
	@V1892_BUILD="$${V1892_BUILD:?original 48K resident-parent build required}" \
	 V1892_PROBE="$${V1892_PROBE:?fresh installed MRES probe required}" \
	 V1892_PRIOR="$${V1892_PRIOR:?accepted v1848 pinned FULL required}" \
	 V1892_V1890="$${V1892_V1890:?accepted v1890 physical source trace required}" \
	 sh tests/validation/pure-k05-resident-peer-v1892/run-v1892.sh

.PHONY: test-pure-k05-resident-peer-audit-v1892
test-pure-k05-resident-peer-audit-v1892:
	@V1892_BUILD="$${V1892_BUILD:?original 48K resident-parent build required}" \
	 V1892_WORK="$${V1892_WORK:?actual original physical HB evidence required}" \
	 sh tests/validation/pure-k05-resident-peer-v1892/audit-v1892.sh

# K05: original PDP6 MM successfully deletes PACKED source, then
# simulator corrupts ONLY AC1 return into -5. The v1839 reconciliation
# must recognize the sole exact PROCESS owner and finish normal WAIT.
.PHONY: test-pure-k05-source-free-reply-physical-v1893
test-pure-k05-source-free-reply-physical-v1893:
	@V1893_BUILD="$${V1893_BUILD:?original source-built v1855 48K image required}" \
	 V1893_PROBE="$${V1893_PROBE:?actual original MRES JRST probe required}" \
	 sh tests/validation/pure-k05-source-free-reply-physical-v1893/run-v1893.sh

.PHONY: test-pure-k05-source-free-reply-audit-v1893
test-pure-k05-source-free-reply-audit-v1893:
	@V1893_BUILD="$${V1893_BUILD:?original source-built v1855 48K image required}" \
	 V1893_WORK="$${V1893_WORK:?original physical failed free-reply evidence required}" \
	 sh tests/validation/pure-k05-source-free-reply-physical-v1893/audit-v1893.sh

# K05: physically pin PACKED source AT the actual original mm_free
# invocation, prove the real allocator refuses -5, then release only
# the temporary owner pin so the exact-zero-pin pair can safely roll
# back the provisional PROCESS target before original child retry.
.PHONY: test-pure-k05-real-free-refusal-physical-v1894
test-pure-k05-real-free-refusal-physical-v1894:
	@V1894_BUILD="$${V1894_BUILD:?original v1855 source-built 48K guest required}" \
	 V1894_PROBE="$${V1894_PROBE:?original physical installed PURE probe required}" \
	 V1894_PRIOR="$${V1894_PRIOR:?accepted source-linked v1893 physical evidence required}" \
	 sh tests/validation/pure-k05-real-free-refusal-v1894/run-v1894.sh

.PHONY: test-pure-k05-real-free-refusal-audit-v1894
test-pure-k05-real-free-refusal-audit-v1894:
	@V1894_BUILD="$${V1894_BUILD:?original v1855 source-built 48K guest required}" \
	 V1894_WORK="$${V1894_WORK:?original physical refused source-free evidence required}" \
	 sh tests/validation/pure-k05-real-free-refusal-v1894/audit-v1894.sh

# K05: genuine original fixed KCORE PACKED-source free refusal under
# a persistently held external source pin. Exact unchanged MM owners,
# process quarantine, and TWO new autonomous resident parent HBs.
.PHONY: test-pure-k05-persistent-source-pin-physical-v1895
test-pure-k05-persistent-source-pin-physical-v1895:
	@V1895_BUILD="$${V1895_BUILD:?original 48K resident parent-HB source build required}" \
	 V1895_PROBE="$${V1895_PROBE:?installed original PURE MRES probe required}" \
	 V1895_PRIOR="$${V1895_PRIOR:?accepted original real v1894 source free refusal required}" \
	 sh tests/validation/pure-k05-persistent-source-pin-v1895/run-v1895.sh

.PHONY: test-pure-k05-persistent-source-pin-audit-v1895
test-pure-k05-persistent-source-pin-audit-v1895:
	@V1895_BUILD="$${V1895_BUILD:?original 48K resident parent-HB source build required}" \
	 V1895_WORK="$${V1895_WORK:?original real v1895 physical evidence required}" \
	 sh tests/validation/pure-k05-persistent-source-pin-v1895/audit-v1895.sh

# K05: two original native PDP-6 MM -5 replies, the second inside
# the actual failure rollback mm_free(PROCESS). Keep source pin0 and
# target pin1 live, TRANSITION quarantined, while resident parent
# executes two new real user heartbeats and original PCLK advances.
.PHONY: test-pure-k05-target-free-refusal-physical-v1896
test-pure-k05-target-free-refusal-physical-v1896:
	@V1896_BUILD="$${V1896_BUILD:?original 48K source-built resident parent required}" \
	 V1896_PROBE="$${V1896_PROBE:?installed original PURE MRES probe required}" \
	 V1896_PRIOR="$${V1896_PRIOR:?accepted original v1894 real-source-free evidence required}" \
	 sh tests/validation/pure-k05-target-free-refusal-v1896/run-v1896.sh

.PHONY: test-pure-k05-target-free-refusal-audit-v1896
test-pure-k05-target-free-refusal-audit-v1896:
	@V1896_BUILD="$${V1896_BUILD:?original 48K source-built resident parent required}" \
	 V1896_WORK="$${V1896_WORK:?original real v1896 failed target-free evidence required}" \
	 sh tests/validation/pure-k05-target-free-refusal-v1896/audit-v1896.sh

# K05: original native target cleanup free ACTUALLY succeeds, then
# only its returned AC1 is forged to -5. Prove the sole unpinned
# PACKED source survives and five original children retry/WAIT/HALT.
.PHONY: test-pure-k05-target-free-lost-reply-physical-v1897
test-pure-k05-target-free-lost-reply-physical-v1897:
	@V1897_BUILD="$${V1897_BUILD:?original v1855 five-child 48K source build required}" \
	 V1897_PROBE="$${V1897_PROBE:?installed original PURE MRES probe required}" \
	 V1897_PRIOR="$${V1897_PRIOR:?original v1894 source-free refusal physical evidence required}" \
	 sh tests/validation/pure-k05-target-free-lost-reply-v1897/run-v1897.sh

.PHONY: test-pure-k05-target-free-lost-reply-audit-v1897
test-pure-k05-target-free-lost-reply-audit-v1897:
	@V1897_BUILD="$${V1897_BUILD:?original v1855 five-child 48K source build required}" \
	 V1897_WORK="$${V1897_WORK:?original physical lost target-free reply evidence required}" \
	 sh tests/validation/pure-k05-target-free-lost-reply-v1897/audit-v1897.sh

# K05: original target unpin first commit and fail_target retry
# both ACTUALLY fail MM_ERR_INVAL=-4 after test-only zero pin.
# Prove no speculative RAW/target free, TRANSITION VM0 and real
# unrelated resident parent HB progress with advancing PDP6 PCLK.
.PHONY: test-pure-k05-target-unpin-refusal-physical-v1898
test-pure-k05-target-unpin-refusal-physical-v1898:
	@V1898_BUILD="$${V1898_BUILD:?original 48K resident parent source build required}" \
	 V1898_PROBE="$${V1898_PROBE:?installed original PURE MRES probe required}" \
	 V1898_PRIOR="$${V1898_PRIOR:?accepted v1897 original physical owner evidence required}" \
	 sh tests/validation/pure-k05-target-unpin-refusal-v1898/run-v1898.sh

.PHONY: test-pure-k05-target-unpin-refusal-audit-v1898
test-pure-k05-target-unpin-refusal-audit-v1898:
	@V1898_BUILD="$${V1898_BUILD:?original 48K resident parent source build required}" \
	 V1898_WORK="$${V1898_WORK:?original real v1898 MM unpin refusal required}" \
	 sh tests/validation/pure-k05-target-unpin-refusal-v1898/audit-v1898.sh

# K05: original SOURCE native mm_unpin physically refuses -4 when
# a test-only zero-source-pin is introduced at the real call.
# The original target rollback must succeed, retaining PACKED
# source and five child retry/typed EXIT-WAIT/parent HALT.
.PHONY: test-pure-k05-source-unpin-refusal-physical-v1899
test-pure-k05-source-unpin-refusal-physical-v1899:
	@V1899_BUILD="$${V1899_BUILD:?original source-built 48K five-child guest required}" \
	 V1899_PROBE="$${V1899_PROBE:?original installed PURE MRES probe required}" \
	 V1899_PRIOR="$${V1899_PRIOR:?accepted original v1897 physical MM evidence required}" \
	 sh tests/validation/pure-k05-source-unpin-refusal-v1899/run-v1899.sh

.PHONY: test-pure-k05-source-unpin-refusal-audit-v1899
test-pure-k05-source-unpin-refusal-audit-v1899:
	@V1899_BUILD="$${V1899_BUILD:?original source-built 48K five-child guest required}" \
	 V1899_WORK="$${V1899_WORK:?original physical source-unpin refusal trace required}" \
	 sh tests/validation/pure-k05-source-unpin-refusal-v1899/audit-v1899.sh

# Historical v1900 only (superseded by v1920 exact terminal identity).
# K05 v1900: SOURCE-LINKED original PDP-6 terminal code must release
# an EXACT unpinned RAW PACKED source plus one complete provisional
# PROCESS target left by a failed FULL, without releasing anyone else.
# Real native checks include 4 executed unsafe assembler mutants.
.PHONY: test-pure-k05-terminal-dual-owner-native-v1900
test-pure-k05-terminal-dual-owner-native-v1900:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-k05-terminal-dual-owner-v1900/run-native-v1900.sh

# Unlike the fixture MM return variants above, this also links and
# EXECUTES the ORIGINAL PDP-6 allocator, idle FINALIZE+PREVM and
# post-VM retry machinery with the precise two-owner RAW+target pair.
.PHONY: test-pure-k05-terminal-dual-owner-finalizer-native-v1900
test-pure-k05-terminal-dual-owner-finalizer-native-v1900:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-k05-terminal-dual-owner-v1900/run-finalizer-v1900.sh

# Separate current-source 48K real PDP-6 PURE integration smoke with
# unchanged KCORE and TEST-ONLY five-child resident parent markers.
# This does NOT claim actual foreign termination of a quarantined slot.
.PHONY: test-pure-k05-terminal-dual-owner-physical-v1900
test-pure-k05-terminal-dual-owner-physical-v1900:
	@V1900_BUILD="$${V1900_BUILD:?source-built corrected PURE 48K guest required}" \
	 V1900_PROBE="$${V1900_PROBE:?actual original installed PURE JRST probe required}" \
	 V1900_PRIOR="$${V1900_PRIOR:?accepted original v1895 pinned physical MM trace required}" \
	 sh tests/validation/pure-k05-terminal-dual-owner-v1900/run-physical-v1900.sh

.PHONY: test-pure-k05-terminal-dual-owner-physical-audit-v1900
test-pure-k05-terminal-dual-owner-physical-audit-v1900:
	@V1900_BUILD="$${V1900_BUILD:?source-built v1900 PURE 48K guest required}" \
	 V1900_PHYSICAL_WORK="$${V1900_PHYSICAL_WORK:?actual original PDP6 physical trace required}" \
	 sh tests/validation/pure-k05-terminal-dual-owner-v1900/audit-physical-v1900.sh

# K05 v1901: original full 48K PDP6 native parent EVENT_TERM(3) on an
# actually quarantined dual-owner child with an outstanding private
# executive continuation. The simulator sets only a TEST-ONLY parent
# user-APR gate AFTER the original MM -5 failure has been witnessed.
# Do not weaken event TRANSITION or remote private-stack safety guards.
.PHONY: test-pure-k05-transition-term-build-v1901
test-pure-k05-transition-term-build-v1901:
	@DAIMOS_REPO="$${DAIMOS_REPO:?original DAIMOS checkout required}" \
	 sh tests/validation/pure-k05-transition-term-v1901/build-source-v1901.sh

.PHONY: test-pure-k05-transition-term-physical-v1901
test-pure-k05-transition-term-physical-v1901:
	@V1901_BUILD="$${V1901_BUILD:?real original 48K parent TERM guest required}" \
	 V1901_PROBE="$${V1901_PROBE:?actual original PURE MRES base probe required}" \
	 V1901_PRIOR="$${V1901_PRIOR:?original v1895 true MM owner fault evidence required}" \
	 V1901_V1900="$${V1901_V1900:?accepted original v1900 physical snapshot required}" \
	 sh tests/validation/pure-k05-transition-term-v1901/run-physical-v1901.sh

.PHONY: test-pure-k05-transition-term-audit-v1901
test-pure-k05-transition-term-audit-v1901:
	@V1901_BUILD="$${V1901_BUILD:?real original 48K parent TERM guest required}" \
	 V1901_WORK="$${V1901_WORK:?completed original 48K native user TERM transcript required}" \
	 sh tests/validation/pure-k05-transition-term-v1901/audit-physical-v1901.sh

# v1902: original PDP-6 KCC PURE exact two-owner idle reconciliation.
# This target is a native component test, NOT physical full-system acceptance.
.PHONY: test-pure-k05-reconcile-native-v1902
test-pure-k05-reconcile-native-v1902:
	@DAIMOS_REPO="$${DAIMOS_REPO:?original DAIMOS checkout required}" \
	 sh tests/validation/pure-k05-reconcile-v1902/run-native-v1902.sh

.PHONY: test-pure-k05-reconcile-physical-v1902
test-pure-k05-reconcile-physical-v1902:
	@V1902_BUILD="$${V1902_BUILD:?original source-built 48K image required}" \
	 V1902_PROBE="$${V1902_PROBE:?installed source-built PURE base trace required}" \
	 sh tests/validation/pure-k05-reconcile-v1902/run-physical-v1902.sh

.PHONY: test-pure-k05-reconcile-audit-v1902
test-pure-k05-reconcile-audit-v1902:
	@V1902_BUILD="$${V1902_BUILD:?original source-built 48K image required}" \
	 V1902_PHYSICAL_WORK="$${V1902_PHYSICAL_WORK:?completed original PDP6 physical trace required}" \
	 sh tests/validation/pure-k05-reconcile-v1902/audit-physical-v1902.sh

# Stronger source-linked native MM target-free/slot0/CTX-PC proof.
.PHONY: test-pure-k05-reconcile-commit-physical-v1902
test-pure-k05-reconcile-commit-physical-v1902:
	@V1902_BUILD="$${V1902_BUILD:?original source-built 48K image required}" \
	 V1902_PROBE="$${V1902_PROBE:?installed source-built PURE base trace required}" \
	 sh tests/validation/pure-k05-reconcile-v1902/run-physical-commit-v1902.sh

.PHONY: test-pure-k05-reconcile-commit-audit-v1902
test-pure-k05-reconcile-commit-audit-v1902:
	@V1902_BUILD="$${V1902_BUILD:?original source-built 48K image required}" \
	 V1902_COMMIT_WORK="$${V1902_COMMIT_WORK:?completed original native target-free trace required}" \
	 sh tests/validation/pure-k05-reconcile-v1902/audit-physical-commit-v1902.sh

# v1903: original native FULL retry commit and parent five-child typed WAIT.
# The separate read-only mutation audit never changes production images.
.PHONY: test-pure-k05-full-commit-physical-v1903
test-pure-k05-full-commit-physical-v1903:
	@V1903_BUILD="$${V1903_BUILD:?source-built 48K PDP6 guest required}" \
	 V1903_PROBE="$${V1903_PROBE:?source-built PURE JRST probe required}" \
	 sh tests/validation/pure-k05-full-commit-v1903/run-physical-v1903.sh

.PHONY: test-pure-k05-full-commit-audit-v1903
test-pure-k05-full-commit-audit-v1903:
	@python3 tests/validation/pure-k05-full-commit-v1903/verify-physical-v1903.py \
	 . "$${V1903_BUILD:?source-built 48K PDP6 guest required}" \
	 "$${V1903_PHYSICAL_WORK:?completed original 48K physical trace required}"
	@python3 tests/validation/pure-k05-full-commit-v1903/negative-physical-v1903.py \
	 tests/validation/pure-k05-full-commit-v1903/verify-physical-v1903.py \
	 . "$${V1903_BUILD:?source-built 48K PDP6 guest required}" \
	 "$${V1903_PHYSICAL_WORK:?completed original 48K physical trace required}"

# v1904: test the original v1902 idle rollback against a pinned target.
# This also requires the full v1903 end-to-end typed WAIT/HALT proof.
.PHONY: test-pure-k05-target-pin-physical-v1904
test-pure-k05-target-pin-physical-v1904:
	@V1904_BUILD="$${V1904_BUILD:?48K source-built v1903 guest required}" \
	 V1904_PROBE="$${V1904_PROBE:?source-linked PURE base probe required}" \
	 sh tests/validation/pure-k05-target-pin-idle-v1904/run-physical-v1904.sh

.PHONY: test-pure-k05-target-pin-audit-v1904
test-pure-k05-target-pin-audit-v1904:
	@python3 tests/validation/pure-k05-target-pin-idle-v1904/verify-physical-v1904.py \
	 . "$${V1904_BUILD:?48K source-built v1903 guest required}" \
	 "$${V1904_PHYSICAL_WORK:?completed persistent target pin trace required}"
	@python3 tests/validation/pure-k05-target-pin-idle-v1904/negative-physical-v1904.py \
	 . "$${V1904_BUILD:?48K source-built v1903 guest required}" \
	 "$${V1904_PHYSICAL_WORK:?completed persistent target pin trace required}"

# v1905: historical unescrowed PURE genuinely unlocks an orphaned
# foreign-claimed target. This is a regression REPRO, not an acceptance.
.PHONY: test-pure-k05-foreign-repro-physical-v1905
test-pure-k05-foreign-repro-physical-v1905:
	@V1905_BUILD="$${V1905_BUILD:?original unescrowed 48K guest required}" \
	 V1905_PROBE="$${V1905_PROBE:?original PURE base probe required}" \
	 sh tests/validation/pure-k05-foreign-target-v1905/run-physical-v1905.sh

# v1906: escrow original FULL target in existing u-area word 067, then
# prove fail-closed foreign owner and operator-repaired FULL/WAIT/HALT.
.PHONY: test-pure-k05-foreign-native-v1906
test-pure-k05-foreign-native-v1906:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1906 DAIMOS source checkout required}" \
	 sh tests/validation/pure-k05-foreign-target-v1906/run-native-v1906.sh

.PHONY: test-pure-k05-foreign-physical-v1906
test-pure-k05-foreign-physical-v1906:
	@V1906_BUILD="$${V1906_BUILD:?source-built fixed PURE 48K guest required}" \
	 V1906_PROBE="$${V1906_PROBE:?v1906 original PURE base probe required}" \
	 sh tests/validation/pure-k05-foreign-target-v1906/run-physical-v1906.sh

.PHONY: test-pure-k05-foreign-audit-v1906
test-pure-k05-foreign-audit-v1906:
	@python3 tests/validation/pure-k05-foreign-target-v1906/verify-physical-v1906.py \
	 . "$${V1906_BUILD:?source-built fixed PURE 48K guest required}" \
	 "$${V1906_PHYSICAL_WORK:?completed original foreign owner physical required}"
	@python3 tests/validation/pure-k05-foreign-target-v1906/negative-physical-v1906.py \
	 . "$${V1906_BUILD:?source-built fixed PURE 48K guest required}" \
	 "$${V1906_PHYSICAL_WORK:?completed original foreign owner physical required}"

# v1907: one real user TERM under the escrowed foreign FULL owner,
# then original repaired rollback and typed WAIT/HALT. Four new
# targeted mutants suffice; v1906's 16 owner mutants already PASS.
.PHONY: test-pure-k05-foreign-term-build-v1907
test-pure-k05-foreign-term-build-v1907:
	@DAIMOS_REPO="$${DAIMOS_REPO:?current DAIMOS source checkout required}" \
	 sh tests/validation/pure-k05-foreign-term-v1907/build-source-v1907.sh

.PHONY: test-pure-k05-foreign-term-physical-v1907
test-pure-k05-foreign-term-physical-v1907:
	@V1907_BUILD="$${V1907_BUILD:?source-built v1907 48K guest required}" \
	 V1907_PROBE="$${V1907_PROBE:?v1907 original PURE base probe required}" \
	 sh tests/validation/pure-k05-foreign-term-v1907/run-physical-v1907.sh

.PHONY: test-pure-k05-foreign-term-audit-v1907
test-pure-k05-foreign-term-audit-v1907:
	@python3 tests/validation/pure-k05-foreign-term-v1907/verify-physical-v1907.py \
	 . "$${V1907_BUILD:?source-built v1907 48K guest required}" \
	 "$${V1907_WORK:?completed original TERM physical trace required}"
	@python3 tests/validation/pure-k05-foreign-term-v1907/negative-physical-v1907.py \
	 . "$${V1907_BUILD:?source-built v1907 48K guest required}" \
	 "$${V1907_WORK:?completed original TERM physical trace required}"

# v1908: bounded original full-system observation of a held foreign
# target WITHOUT operator repair or fabricated native EXIT/HALT.
.PHONY: test-pure-k05-long-owner-physical-v1908
test-pure-k05-long-owner-physical-v1908:
	@V1908_BUILD="$${V1908_BUILD:?source-built v1907 48K guest required}" \
	 V1908_PROBE="$${V1908_PROBE:?source-linked installed PURE probe required}" \
	 sh tests/validation/pure-k05-permanent-owner-v1908/run-physical-v1908.sh

.PHONY: test-pure-k05-long-owner-audit-v1908
test-pure-k05-long-owner-audit-v1908:
	@python3 tests/validation/pure-k05-permanent-owner-v1908/verify-physical-v1908.py \
	 . "$${V1908_BUILD:?source-built v1907 48K guest required}" \
	 "$${V1908_WORK:?completed original held-owner physical evidence required}"
	@python3 tests/validation/pure-k05-permanent-owner-v1908/negative-physical-v1908.py \
	 . "$${V1908_BUILD:?source-built v1907 48K guest required}" \
	 "$${V1908_WORK:?completed original held-owner physical evidence required}"

# v1909: authentic original PI6 PCLK entry while the foreign FULL
# owner remains quarantined; reuse v1908's complete held-owner audit.
.PHONY: test-pure-k05-held-pi6-physical-v1909
test-pure-k05-held-pi6-physical-v1909:
	@DAIMOS_REPO="$${DAIMOS_REPO:?current DAIMOS checkout required}" \
	 V1909_BUILD="$${V1909_BUILD:?original 48K guest required}" \
	 V1909_PROBE="$${V1909_PROBE:?original PURE base probe required}" \
	 sh tests/validation/pure-k05-held-pi6-v1909/run-physical-v1909.sh

.PHONY: test-pure-k05-held-pi6-audit-v1909
test-pure-k05-held-pi6-audit-v1909:
	@python3 tests/validation/pure-k05-held-pi6-v1909/verify-physical-v1909.py \
	 . "$${V1909_BUILD:?original 48K guest required}" \
	 "$${V1909_WORK:?completed original PI6 physical trace required}"
	@python3 tests/validation/pure-k05-held-pi6-v1909/negative-physical-v1909.py \
	 . "$${V1909_BUILD:?original 48K guest required}" \
	 "$${V1909_WORK:?completed original PI6 physical trace required}"

# v1910: real user parent EXIT while the original failed-FULL child
# target is foreign-owned, with exact source-built TSFS and KCORE/PURE.
.PHONY: test-pure-k05-parent-exit-build-v1910
test-pure-k05-parent-exit-build-v1910:
	@DAIMOS_REPO="$${DAIMOS_REPO:?current DAIMOS checkout required}" \
	 sh tests/validation/pure-k05-parent-exit-v1910/build-source-v1910.sh

.PHONY: test-pure-k05-parent-exit-physical-v1910
test-pure-k05-parent-exit-physical-v1910:
	@V1910_BUILD="$${V1910_BUILD:?source-built v1910 48K guest required}" \
	 V1910_PROBE="$${V1910_PROBE:?source-linked PURE base probe required}" \
	 sh tests/validation/pure-k05-parent-exit-v1910/run-physical-v1910.sh

.PHONY: test-pure-k05-parent-exit-audit-v1910
test-pure-k05-parent-exit-audit-v1910:
	@python3 tests/validation/pure-k05-parent-exit-v1910/verify-physical-v1910.py \
	 . "$${V1910_BUILD:?source-built v1910 48K guest required}" \
	 "$${V1910_WORK:?completed original parent EXIT physical trace required}"
	@python3 tests/validation/pure-k05-parent-exit-v1910/negative-physical-v1910.py \
	 . "$${V1910_BUILD:?source-built v1910 48K guest required}" \
	 "$${V1910_WORK:?completed original parent EXIT physical trace required}"

# v1911: the three remaining genuine orphan children EXIT, leaving
# the unrepaired foreign FULL child as the last live user.
.PHONY: test-pure-k05-last-orphan-physical-v1911
test-pure-k05-last-orphan-physical-v1911:
	@V1911_BUILD="$${V1911_BUILD:?v1910 original 48K guest required}" \
	 V1911_PROBE="$${V1911_PROBE:?original PURE base probe required}" \
	 sh tests/validation/pure-k05-last-orphan-v1911/run-physical-v1911.sh

.PHONY: test-pure-k05-last-orphan-audit-v1911
test-pure-k05-last-orphan-audit-v1911:
	@python3 tests/validation/pure-k05-last-orphan-v1911/verify-physical-v1911.py \
	 . "$${V1911_BUILD:?original v1910 48K guest required}" \
	 "$${V1911_WORK:?completed last-orphan physical evidence required}"
	@python3 tests/validation/pure-k05-last-orphan-v1911/negative-physical-v1911.py \
	 . "$${V1911_BUILD:?original v1910 48K guest required}" \
	 "$${V1911_WORK:?completed last-orphan physical evidence required}"

# v1912: only after the last quarantined orphan remains, restore
# the test-corrupted MM owner and observe original recovery/true HALT.
.PHONY: test-pure-k05-terminal-reconcile-physical-v1912
test-pure-k05-terminal-reconcile-physical-v1912:
	@V1912_BUILD="$${V1912_BUILD:?original v1910 48K guest required}" \
	 V1912_PROBE="$${V1912_PROBE:?original PURE base probe required}" \
	 sh tests/validation/pure-k05-terminal-reconcile-v1912/run-physical-v1912.sh

.PHONY: test-pure-k05-terminal-reconcile-audit-v1912
test-pure-k05-terminal-reconcile-audit-v1912:
	@python3 tests/validation/pure-k05-terminal-reconcile-v1912/verify-physical-v1912.py \
	 . "$${V1912_BUILD:?original v1910 48K guest required}" \
	 "$${V1912_WORK:?completed actual last-user HALT trace required}"
	@python3 tests/validation/pure-k05-terminal-reconcile-v1912/negative-physical-v1912.py \
	 . "$${V1912_BUILD:?original v1910 48K guest required}" \
	 "$${V1912_WORK:?completed actual last-user HALT trace required}"

# v1913: no repair ever arrives; slot0 must preserve the sole live
# foreign-owned orphan through another twelve clock-governed retries.
.PHONY: test-pure-k05-permanent-orphan-physical-v1913
test-pure-k05-permanent-orphan-physical-v1913:
	@V1913_BUILD="$${V1913_BUILD:?original v1910 48K guest required}" \
	 V1913_PROBE="$${V1913_PROBE:?original PURE physical base probe required}" \
	 sh tests/validation/pure-k05-permanent-orphan-v1913/run-physical-v1913.sh

.PHONY: test-pure-k05-permanent-orphan-audit-v1913
test-pure-k05-permanent-orphan-audit-v1913:
	@python3 tests/validation/pure-k05-permanent-orphan-v1913/verify-physical-v1913.py \
	 . "$${V1913_BUILD:?original v1910 48K guest required}" \
	 "$${V1913_WORK:?completed permanent orphan physical trace required}"
	@python3 tests/validation/pure-k05-permanent-orphan-v1913/negative-physical-v1913.py \
	 . "$${V1913_BUILD:?original v1910 48K guest required}" \
	 "$${V1913_WORK:?completed permanent orphan physical trace required}"

# v1914: test-only synchronized clock/epoch leap followed by real
# original PCLK PI6 increments across the 17-bit retry timer wrap.
.PHONY: test-pure-k05-clock-wrap-physical-v1914
test-pure-k05-clock-wrap-physical-v1914:
	@V1914_BUILD="$${V1914_BUILD:?original v1910 48K guest required}" \
	 V1914_PROBE="$${V1914_PROBE:?original PURE physical base probe required}" \
	 sh tests/validation/pure-k05-clock-wrap-v1914/run-physical-v1914.sh

.PHONY: test-pure-k05-clock-wrap-audit-v1914
test-pure-k05-clock-wrap-audit-v1914:
	@python3 tests/validation/pure-k05-clock-wrap-v1914/verify-physical-v1914.py \
	 . "$${V1914_BUILD:?original v1910 48K guest required}" \
	 "$${V1914_WORK:?completed native wrap physical trace required}"
	@python3 tests/validation/pure-k05-clock-wrap-v1914/negative-physical-v1914.py \
	 . "$${V1914_BUILD:?original v1910 48K guest required}" \
	 "$${V1914_WORK:?completed native wrap physical trace required}"

# v1915: a test-only parent USER BRK capacity request under an
# unrepaired foreign FULL target; requester-only original OOM must
# leave quarantined child authoritative MM owners unchanged.
.PHONY: test-pure-k05-orphan-oom-build-v1915
test-pure-k05-orphan-oom-build-v1915:
	@DAIMOS_REPO="$${DAIMOS_REPO:?current DAIMOS checkout required}" \
	 sh tests/validation/pure-k05-orphan-oom-v1915/build-source-v1915.sh

.PHONY: test-pure-k05-orphan-oom-physical-v1915
test-pure-k05-orphan-oom-physical-v1915:
	@V1915_BUILD="$${V1915_BUILD:?original source-built v1915 48K guest required}" \
	 V1915_PROBE="$${V1915_PROBE:?source-matched PURE base probe required}" \
	 sh tests/validation/pure-k05-orphan-oom-v1915/run-physical-v1915.sh

.PHONY: test-pure-k05-orphan-oom-audit-v1915
test-pure-k05-orphan-oom-audit-v1915:
	@python3 tests/validation/pure-k05-orphan-oom-v1915/verify-physical-v1915.py \
	 . "$${V1915_BUILD:?original source-built v1915 48K guest required}" \
	 "$${V1915_WORK:?completed native requester OOM physical trace required}"
	@python3 tests/validation/pure-k05-orphan-oom-v1915/negative-physical-v1915.py \
	 . "$${V1915_BUILD:?original source-built v1915 48K guest required}" \
	 "$${V1915_WORK:?completed native requester OOM physical trace required}"

.PHONY: test-pure-integration-native-v1855
test-pure-integration-native-v1855: test-pure-integration-native-v1839 \
 test-pure-k05-pinned-commit-native-v1855
	@echo 'PASS v1855: complete RAW PURE native matrix plus exact pinned FULL commit'

# K05: current-source physical secondary backing loss and FULL rollback.
.PHONY: test-pure-k05-secondary-physical-v1845
test-pure-k05-secondary-physical-v1845:
	@V1845_BUILD="$${V1845_BUILD:?source-built v1845 guest required}" \
	 sh tests/validation/pure-k05-secondary-physical-v1845/run-physical-v1845.sh

.PHONY: test-pure-k05-secondary-audit-v1845
test-pure-k05-secondary-audit-v1845:
	@V1845_BUILD="$${V1845_BUILD:?source-built v1845 guest required}" \
	 V1845_WORK="$${V1845_WORK:?real physical trace required}" \
	 sh tests/validation/pure-k05-secondary-physical-v1845/audit-v1845.sh

# K05: physical PCLK PI6 with a retained PACKED owner after FULL failure.
.PHONY: test-pure-k05-postfault-pi6-v1847
test-pure-k05-postfault-pi6-v1847:
	@V1847_BUILD="$${V1847_BUILD:?current v1845 48K image required}" \
	 V1847_PROBE="$${V1847_PROBE:?actual current-source MRES probe required}" \
	 sh tests/validation/pure-k05-postfault-pi6-v1847/run-v1847.sh

.PHONY: test-pure-k05-postfault-pi6-audit-v1847
test-pure-k05-postfault-pi6-audit-v1847:
	@V1847_BUILD="$${V1847_BUILD:?current v1845 48K image required}" \
	 V1847_WORK="$${V1847_WORK:?real physical evidence required}" \
	 sh tests/validation/pure-k05-postfault-pi6-v1847/audit-v1847.sh

# K05: real PCLK PI6 must interrupt FULL while BOTH original MM pins live.
.PHONY: test-pure-k05-midfull-pi6-v1848
test-pure-k05-midfull-pi6-v1848:
	@V1848_BUILD="$${V1848_BUILD:?source-built 48K FULL image required}" \
	 V1848_PROBE="$${V1848_PROBE:?physical MRES JRST probe required}" \
	 sh tests/validation/pure-k05-midfull-pi6-v1848/run-v1848.sh

.PHONY: test-pure-k05-midfull-pi6-audit-v1848
test-pure-k05-midfull-pi6-audit-v1848:
	@V1848_BUILD="$${V1848_BUILD:?source-built 48K FULL image required}" \
	 V1848_WORK="$${V1848_WORK:?completed physical FULL PI6 trace required}" \
	 sh tests/validation/pure-k05-midfull-pi6-v1848/audit-v1848.sh

# Optional mode3 shares v1612 readiness, but is NOT production-accepted.
.PHONY: test-pure-k05-mode3-compat-native-v1808
test-pure-k05-mode3-compat-native-v1808:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS v1808 integration source required}" \
	 sh tests/validation/pure-mres-bitmap-v1667/run-service-v1667.sh

# v1805: physical default-OFF PDP-6 disk-root smoke (requires built image).
.PHONY: test-pure-integration-dsk-smoke-v1805
test-pure-integration-dsk-smoke-v1805:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1804 DAIMOS integration checkout required}" \
	 sh tests/validation/pure-integration-v1805/run-dsk-smoke-v1805.sh

# v1807: opt-in 64K TSFS PURE boot for the reconciled K01-K04 source map.
.PHONY: test-pure-integration-tsfs64-v1807
test-pure-integration-tsfs64-v1807:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1804 DAIMOS integration checkout required}" \
	 V1665_MAP_MODE_V1807=integration \
	 sh tests/validation/pure-boot-select-v1665/run-physical-v1665.sh

# v1807: full opt-in paired physical 48K PURE reclaim/restore regression.
# The integrated source has a different verified permanent RAM baseline;
# preserve the v1673 historical default and all MM mutation rejections.
.PHONY: test-pure-integration-pressure48-v1807
test-pure-integration-pressure48-v1807:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1804 DAIMOS integration checkout required}" \
	 V1673_SOURCE_PROFILE_V1807=integration KEEP_TEST=1 \
	 sh tests/validation/pure-runtime-reclaim-v1673/run-physical-v1673.sh

# v1807: verify retained independent GENERAL/STRICT physical A/B/C evidence.
.PHONY: test-pure-integration-verify48-v1807
test-pure-integration-verify48-v1807:
	@DAIMOS_REPO="$${DAIMOS_REPO:?v1804 DAIMOS integration checkout required}" \
	 sh tests/validation/pure-integration-v1807/check-physical-pair-v1807.sh \
	 "$${V1807_PHYSICAL_EVIDENCE_DIR:?set independent guest evidence directory}"

# K06 current terminal owner and integrated PREVM escrow gates.
.PHONY: test-pure-terminal-identity-v1920 test-pure-terminal-finalizer-v1920
test-pure-terminal-identity-v1920:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-terminal-identity-v1920/run-v1920.sh

test-pure-terminal-finalizer-v1920:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-terminal-identity-v1920/run-finalizer-v1920.sh

.PHONY: test-pure-mm-geometry-v1921
test-pure-mm-geometry-v1921:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-mm-geometry-v1921/run-v1921.sh

.PHONY: test-pure-mm-arena-v1922
test-pure-mm-arena-v1922:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-mm-arena-v1922/run-v1922.sh

.PHONY: test-pure-backing-identity-v1923
test-pure-backing-identity-v1923:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-backing-identity-v1923/run-v1923.sh

.PHONY: test-pure-provider-identity-v1924
test-pure-provider-identity-v1924:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-provider-identity-v1924/run-v1924.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-provider-identity-v1924/run-run-v1924.sh

.PHONY: test-pure-dtfs-media-v1925
test-pure-dtfs-media-v1925:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-dtfs-media-v1925/run-physical-v1925.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-dtfs-media-v1925/run-bridge-v1925.sh

.PHONY: test-pure-drop-availability-v1926
test-pure-drop-availability-v1926:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-drop-availability-v1926/run-v1926.sh

.PHONY: test-pure-d6fs-media-v1927
test-pure-d6fs-media-v1927:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-native-v1927.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-format-v1927.sh

.PHONY: test-pure-tsfs-media-v1928
test-pure-tsfs-media-v1928:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-tsfs-media-v1928/run-v1928.sh

.PHONY: test-pure-d6fs-loss-v1929
test-pure-d6fs-loss-v1929:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-native-v1927.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-drop-availability-v1926/run-v1926.sh

.PHONY: test-pure-d6fs-retry-v1930
test-pure-d6fs-retry-v1930:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-native-v1927.sh

.PHONY: test-pure-d6fs-unmount-v1931
test-pure-d6fs-unmount-v1931:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-native-v1927.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/daimos-dtfs-quiesce-v1562.sh

.PHONY: test-pure-mutation-lease-v1932
test-pure-mutation-lease-v1932:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-mutation-lease-v1932/run-v1932.sh

.PHONY: test-pure-load-reservation-v1933
test-pure-load-reservation-v1933:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-load-reservation-v1933/run-v1933.sh

.PHONY: test-pure-exec-handover-v1934
test-pure-exec-handover-v1934:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-exec-handover-v1934/run-v1934.sh

.PHONY: test-pure-lowmem-exec-v1935
test-pure-lowmem-exec-v1935:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-lowmem-exec-v1935/run-v1935.sh

.PHONY: test-pure-namespace-epoch-v1936
test-pure-namespace-epoch-v1936:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-namespace-epoch-v1936/run-v1936.sh

.PHONY: test-pure-stack-lifetime-v1937
test-pure-stack-lifetime-v1937:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-stack-lifetime-v1937/run-v1937.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/daimos-uarea-ownership-v956.sh

.PHONY: test-pure-memfs-mutation-v1938
test-pure-memfs-mutation-v1938:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-memfs-mutation-v1938/run-v1938.sh

.PHONY: test-pure-d6fs-discard-v1939
test-pure-d6fs-discard-v1939:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-d6fs-media-v1927/run-native-v1927.sh
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/daimos-dtfs-admin-owner-v1531.sh

.PHONY: test-pure-k07-native-v1940 test-pure-k07-physical-v1940
test-pure-k07-native-v1940:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-k07-accept-v1940/run-native-v1940.sh
test-pure-k07-physical-v1940:
	@DAIMOS_REPO="$${DAIMOS_REPO:?DAIMOS source checkout required}" \
	 sh tests/validation/pure-k07-accept-v1940/run-physical-v1940.sh

.PHONY: test-pure-k07-full-v1941 test-pure-k07-full-oracle-v1941
test-pure-k07-full-v1941:
	@sh tests/validation/pure-k07-full-v1941/run-v1941.sh
test-pure-k07-full-oracle-v1941:
	@python3 tests/validation/pure-k07-full-v1941/test-verifier-v1941.py

.PHONY: test-pure-k07-race-v1943
test-pure-k07-race-v1943:
	@sh tests/validation/pure-k07-race-v1943/run-v1943.sh
