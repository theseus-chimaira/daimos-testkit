#!/bin/sh
# Two-boot DTFS persistence test, with TSFS as root and DTC3 as data media.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${DAIMOS_TSFS_ROOT_BOOT_INI:?supply a verified BOOT=dtc ROOT=tape boot.ini}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
kit=$(CDPATH= cd -- "$self/../.." && pwd -P)
work="$TMPDIR/daimos-dtfs-taperoot-persist-v185-$$"
mkdir -p "$work"
trap 'if [ "${DAIMOS_DTFS_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
boot=$DAIMOS_TSFS_ROOT_BOOT_INI
# Preserve the root media; only the test DTC3 image is copied and modified.
media=$(awk '$1=="attach" && $3=="dtc3" {print $4; exit}' "$boot")
test -n "$media" && test -f "$media"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
  -o "$work/mkdtfs-v185" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v185" -o "$work/dtc3.tap"
cc -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty-run" "$kit/tools/pty-run-v1.c"
for phase in a; do
    sed "s|^attach -q dtc3 .*|attach -q dtc3 $work/dtc3.tap|" "$boot" > "$work/boot-$phase.ini"
    "$kit/tools/daimos-simh-harness-v4.sh" \
      --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot-$phase.ini" \
      --simh "${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}" \
      --pty-run "$work/pty-run" --login ROOT \
      --probes "$kit/probes/daimos-dtfs-taperoot-probe-v185.txt" \
      --work-dir "$work/run-$phase" --boot-timeout 360 --timeout 55 \
      --markdown-report "$work/report-$phase.md"
done
echo 'daimos-dtfs-taperoot-probe-v185: PASS (direct DTFSPROBE and FSCK.DTFS)'
