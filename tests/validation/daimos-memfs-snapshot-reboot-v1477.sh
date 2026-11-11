#!/bin/sh
# Full-profile persistent MEMFS: fresh PDP-6 process and RAM on each
# boot, same untouched DSK and AUXSTORE DR images between HALT/restart.
# Never rebuild between boots. Failure-injection will be a later gate.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
size=${XIP_V1477_SIZE:-128}
case "$size" in
    128) core=0400000 ;;
    192) core=0600000 ;;
    256) core=01000000 ;;
    *) echo "v1477: unsupported physical RAM size $size" >&2; exit 2 ;;
esac
work="${XIP_V1477_WORK:-$TMPDIR/daimos-memfs-snapshot-v1477-$size}"
mkdir -p "$work"
trap 'if [ "${XIP_V1477_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1477 evidence: $work"; fi' EXIT HUP INT TERM
printf '# DAIMOS FSTAB V1 - V1477 SNAPSHOT TEST\nMEMFS:/TEMP:4096:PERSIST\n' > "$work/fstab-v1477.txt"

# The first boot must start with freshly formatted AUXSTORE backing.
# Reusing a previous diagnostic workspace's DR0 would make the second
# boot's persistent state ambiguous and can hide snapshot mount defects.
rm -rf "$work/guest/build/system/boot/pdp6/drum"
XIP_V1469_WORK="$work/guest" XIP_V1469_KEEP=1 \
XIP_V1477_TEST_CFLAGS="-DXIP_SNAPSHOT_V1477=1 ${XIP_V1478_TEST_CFLAGS:-}" \
XIP_V1477_FSTAB_TEXT="$work/fstab-v1477.txt" \
XIP_V1477_IMAGE_ONLY=1 \
XIP_V1470_BOOT_CORE_WORDS="$core" XIP_V1470_SIMH_CPU_KWORDS="$size" \
    sh "$self/daimos-xip-launch-v1469.sh"

boot="$work/guest/build/system/boot/pdp6"
"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/auxstore-v1477.inspect"
for n in 1 2; do
    case "$n" in
        1) marker=XIP-SNAPSHOT-WRITTEN ;;
        2) marker=XIP-SNAPSHOT-RESTORED ;;
    esac
    cat > "$work/boot-$n.probes" <<EOF
probe memfs-persistent-boot-$n
command /CONFIG/XIP1469.TEST; ECHO STATUS:\$?
contains $marker
contains STATUS:0
not_contains XIP-FAIL-
not_contains INIT: MOUNTALL FAILED
end
probe orderly-halt-$n
command HALT
terminal eof
end
EOF
    if [ "${XIP_V1478_FAULT_MODE:-0}" = 1 ]; then
        sed -i "/^contains $marker$/a contains XIP-SNAPSHOT-HALT-REFUSED" \
            "$work/boot-$n.probes"
    fi
    printf '=== v1477 physical %sK, cold boot %s: %s ===\n' "$size" "$n" "$marker"
    "$self/../../tools/daimos-simh-harness-v6.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$boot/boot.ini" \
        --pty-run "$work/guest/pty-run" --login ROOT \
        --probes "$work/boot-$n.probes" \
        --work-dir "$work/boot-$n" --boot-timeout 60 --timeout 90
    log="$work/boot-$n/simh.log"
    grep -Eq "^MEM[[:space:]]+$size K" "$log"
    grep -Eq '^MEMFS[[:space:]]+LOADED' "$log"
    grep -Fq "$marker" "$log"
    if grep -Fq 'INIT: MOUNTALL FAILED' "$log"; then
        echo "v1477: persistent MEMFS failed to mount on cold boot $n" >&2
        exit 1
    fi
    grep -q '^STATUS:0' "$log"
    # v1484: a raw-MRES LOGSTORE ABI mismatch once DMA-wrote KCORE text
    # into DR0 block zero during INIT/LOGIN, corrupting AUXSTORE discovery
    # on the next boot despite a valid snapshot near the end of the drum.
    # Refuse the guest immediately if any boot changed the raw descriptor.
    "$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
        > "$work/auxstore-after-boot-$n.inspect" || {
        echo "v1484: AUXSTORE drum descriptor was damaged by guest boot $n" >&2
        exit 1
    }
    cmp -s "$work/auxstore-v1477.inspect" \
        "$work/auxstore-after-boot-$n.inspect" || {
        echo "v1484: AUXSTORE partition geometry changed at boot $n" >&2
        exit 1
    }
done
echo 'PASS v1477: committed MEMFS snapshot survived a completely new PDP-6 boot'
