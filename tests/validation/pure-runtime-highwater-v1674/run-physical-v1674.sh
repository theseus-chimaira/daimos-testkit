#!/bin/sh
# v1674: physical 48K RAW PURE original-MM write-watch high-water.
# Reuse v1673 source-build/CTY verification with a deterministic pipe
# fixture. No KCORE or production guest modifications.
set -eu
: "${DAIMOS_REPO:?set source-matched DAIMOS development worktree}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1674-physical-highwater.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1674 original physical MM high-water evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
# Reuse the proven v1673 source build and three CTY barriers with the
# v1674 pipe-controlled PID1/child fixtures. Watchpoints are armed at A;
# KINIT is not sampled or slowed. Physical debugger write stops can be
# much slower than the ordinary guest: this timeout is host wall time,
# not a child's synthetic sleep or a kernel scheduling deadline.
V1673_TIMEOUT=${V1673_TIMEOUT:-3600}
V1673_TIMEOUT="$V1673_TIMEOUT" \
V1673_WORK_DIR="$work" \
V1673_GUEST_C="$here/proc-pressure-v1674.c" \
V1673_CHILD_ASM="$here/pipe-child-v1674.s" \
V1673_CTY_DRIVER="$here/host-cty-v1674.py" \
KEEP_TEST=1 sh "$here/../pure-runtime-reclaim-v1673/run-physical-v1673.sh"
fixture=${V1673_FIXTURE_BUILD:-$work/fixture}
for variant in general strict; do
    if [ -n "${V1674_ONLY_VARIANT:-}" ] && \
        [ "$variant" != "$V1674_ONLY_VARIANT" ]; then
        continue
    fi
    case "$variant" in
        general) build=${V1673_GENERAL_BUILD:-$work/general-build} ;;
        strict) build=${V1673_STRICT_BUILD:-$work/strict-build} ;;
    esac
    test -s "$build/kcore.map"
    python3 "$here/trace-v1674.py" \
        "$fixture/v1673-test-init.map" "$build/kcore.map" \
        "$work/$variant-48-console.clean" \
        "$work/$variant-48-report.json" \
        "$work/$variant-48-highwater.json" || {
        keep=1
        echo "FAIL v1674: incomplete $variant MM watchpoint replay" >&2
        exit 1
    }
done
if [ -n "${V1674_ONLY_VARIANT:-}" ]; then
    variant=$V1674_ONLY_VARIANT
    case "$variant" in
        general) build=${V1673_GENERAL_BUILD:-$work/general-build} ;;
        strict) build=${V1673_STRICT_BUILD:-$work/strict-build} ;;
    esac
    sh "$here/run-negative-v1674.sh" \
        "$work/$variant-48-console.clean" "$fixture/v1673-test-init.map" \
        "$build/kcore.map" "$work/$variant-48-report.json" \
        "$work/$variant-48-highwater.json" || { keep=1;exit 1; }
    echo 'PASS v1674: selected one-profile diagnostic write-watch replay'
    echo 'NOT ACCEPTED: paired general/strict comparison not executed'
    exit 0
fi
python3 "$here/compare-v1674.py" \
    "$work/general-48-highwater.json" \
    "$work/strict-48-highwater.json" || { keep=1;exit 1; }
variant=${V1674_ONLY_VARIANT:-strict}
case "$variant" in
    general) build=${V1673_GENERAL_BUILD:-$work/general-build} ;;
    strict) build=${V1673_STRICT_BUILD:-$work/strict-build} ;;
esac
sh "$here/run-negative-v1674.sh" \
    "$work/$variant-48-console.clean" "$fixture/v1673-test-init.map" \
    "$build/kcore.map" "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json" || { keep=1;exit 1; }
echo 'PASS v1674: both original physical 48K write-watch traces accepted'
