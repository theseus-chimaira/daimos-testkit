#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$PDP10_TOOLS_REPO" && pwd)
work=$TMPDIR/daimos-pdp10-tools-regression-v1-$$
trap 'rm -rf "$work"' 0 1 2 3 15
mkdir -p "$work/tests"

${MAKE:-make} -C "$repo" all

for f in mkbootbanner mkinitfs0 mkdsk mkd6fs d6fsck packfs d6bad logstore d6swap mktsfs tsfscheck; do
        ln -s "$repo/$f" "$work/$f"
done
ln -s "$repo/d6fsck.c" "$work/d6fsck.c"

for f in mkbootbanner-v1-test.sh mkinitfs0-test.sh mkinitfs0-dxr-v1-test.sh \
        mkdsk-member-sectors-v1-test.sh mkd6fs-dir-v1-test.sh \
        d6fsck-v1-test.sh d6fsck-repair-v2-test.sh d6fsck-recovery-v3-test.sh d6fsck-mutation-recovery-v1-test.sh d6fsck-extent-integrity-v1-test.sh d6-maintenance-v2-test.sh \
        tsfs-empty-v1-test.sh; do
        cp "$here/$f" "$work/tests/$f"
done
chmod 755 "$work/tests"/*.sh

(
        cd "$work"
        ./tests/mkbootbanner-v1-test.sh
        ./tests/mkinitfs0-test.sh
        ./tests/mkinitfs0-dxr-v1-test.sh
        ./tests/mkdsk-member-sectors-v1-test.sh
        ./tests/mkd6fs-dir-v1-test.sh
        ./tests/d6fsck-v1-test.sh
        ./tests/d6fsck-repair-v2-test.sh
        ./tests/d6fsck-recovery-v3-test.sh
        ./tests/d6fsck-mutation-recovery-v1-test.sh
        ./tests/d6fsck-extent-integrity-v1-test.sh
        ./tests/d6-maintenance-v2-test.sh
        ./tests/tsfs-empty-v1-test.sh
)

echo 'DAIMOS pdp10-tools regressions: PASS'
