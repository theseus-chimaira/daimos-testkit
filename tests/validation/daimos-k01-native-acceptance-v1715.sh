#!/bin/sh
# Reproducible source-linked PDP-6 K01 MM owner/refusal acceptance matrix.
# Native tests are necessary but never replace full physical guest gates.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k01-native-acceptance-v1715.XXXXXX")
echo "K01 v1715: native evidence=$work"
git -C "$DAIMOS_REPO" rev-parse HEAD > "$work/daimos-revision"
git -C "$self/../.." rev-parse HEAD > "$work/testkit-revision"

# Covers source-level typed refusal, mutation publication, swap owner
# transition, VM rollback, transient providers, and active compaction.
# All entries are standalone source-linked PDP-6 tests, not physical guests.
cases='
daimos-k01-mm-refusal-v1678
daimos-k01-pressure-chain-v1678
daimos-k01-verify-unpin-v1680
daimos-k01-swap-pin-v1681
daimos-k01-swap-owner-v1682
daimos-k01-swap-free-v1683
daimos-k01-grow-registers-v1684
daimos-k01-restore-unpin-v1685
daimos-k01-restore-owner-v1686
daimos-k01-relocate-owner-v1687
daimos-k01-relocate-rollback-v1688
daimos-k01-relocate-capacity-v1689
daimos-k01-relocate-publication-v1690
daimos-k01-pure-restore-v1691
daimos-k01-relocate-slot-v1692
daimos-k01-relocate-length-v1693
daimos-k01-relocate-pin-race-v1745
daimos-k01-vm-sleep-wake-v1745
daimos-k01-vm-retire-v1695
daimos-k01-brk-reclaim-v1696
daimos-k01-mm-free-pi-v1697
daimos-k01-mm-pin-pi-v1698
daimos-k01-pinned-mutate-pi-v1699
daimos-k01-verify-pi-v1700
daimos-k01-uarea-probe-pi-v1701
daimos-k01-alloc-publish-pi-v1742
daimos-k01-recovery-injection-v1704
daimos-k01-swap-restore-injection-v1705
daimos-k01-exec-launch-free-v1706
daimos-k01-temp-owner-free-v1707
daimos-k01-compact-current-v1710
daimos-k01-is-pinned-pi-v1711
daimos-k01-f07-term-stack-v1712
daimos-pipe-close-v870
'
count=0
for name in $cases; do
    if [ ! -f "$self/$name.sh" ]; then
        echo "FAIL missing native case $name" | tee -a "$work/results"
        exit 1
    fi
    printf 'K01 v1715: native %s ...\n' "$name"
    if sh "$self/$name.sh" > "$work/$name.log" 2>&1; then
        printf 'PASS %s\n' "$name" >> "$work/results"
        count=$((count + 1))
    else
        printf 'FAIL %s\n' "$name" >> "$work/results"
        tail -65 "$work/$name.log" >&2
        echo "K01 v1715: FAILED; evidence=$work" >&2
        exit 1
    fi
done
echo "K01 v1715: all $count native PDP-6 acceptance cases PASS"
echo 'K01 v1715: physical fault-injection and full F07 gates NOT included'
echo "K01 v1715: evidence=$work"
