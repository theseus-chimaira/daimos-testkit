#!/bin/sh
# Validate random host-created native DTFS identities and original C probe.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-dtfs-volume-id-v1520.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1520" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1520" -o "$work/first-v1520.dta"
"$work/mkdtfs-v1520" -o "$work/second-v1520.dta"

python3 - "$work/first-v1520.dta" "$work/second-v1520.dta" <<'PY'
from pathlib import Path
import sys

MASK = 0o777777777777
MARKER = 0o446466575421
BLOCK_WORDS = 0o200
TOTAL_WORDS = 0o1102 * BLOCK_WORDS

def word_at(data, index):
    pos = index * 8
    high = int.from_bytes(data[pos:pos+4], 'little')
    low = int.from_bytes(data[pos+4:pos+8], 'little')
    assert high <= 0o777777 and low <= 0o777777
    return (high << 18) | low

identities = []
for path in sys.argv[1:]:
    data = Path(path).read_bytes()
    assert len(data) == TOTAL_WORDS * 8
    words = [word_at(data, i) for i in range(BLOCK_WORDS)]
    assert words[0] == MARKER
    assert 0 < words[1] <= MASK and 0 < words[2] <= MASK
    assert words[3] == (~(words[0] ^ words[1] ^ words[2])) & MASK
    assert words[4:] == [0] * (BLOCK_WORDS-4)
    assert word_at(data, 0o144 * BLOCK_WORDS + 0o177) == 0o446446632021
    assert word_at(data, 0o144 * BLOCK_WORDS) >> 31 == 0o36
    identities.append((words[1], words[2]))
    print('PASS v1520: checked host native record and unchanged directory:',
          Path(path).name)
assert identities[0] != identities[1], 'two formatted volumes share identity'
print('PASS v1520: two independently formatted tapes have distinct identities')
PY

${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -I "$DAIMOS_REPO/userland/libc" \
    -I "$DAIMOS_REPO/userland/dtfs" \
    -I "$DAIMOS_REPO/system/kernel/proc" \
    -I "$DAIMOS_REPO/system/kernel/fs" \
    -I "$DAIMOS_REPO/system/kernel/core" \
    -I "$DAIMOS_REPO/system/kernel/storage" \
    -I "$DAIMOS_REPO/tools/host" \
    -o "$work/dtfs-probe-v1520" \
    "$self/daimos-dtfs-volume-id-v1520-host.c" \
    "$DAIMOS_REPO/userland/dtfs/dtfs_probe.c"
"$work/dtfs-probe-v1520"

# The native target MKFS command has no reliable 72-bit randomness source.
# It MUST clear the reserved identity header before replacing a stamped
# filesystem's directory, rather than accidentally inheriting its ID.
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -Wno-unused-function \
    -DDAIMOS_CMD_PROGRAM=CMD_PROGRAM_MKFS_DTFS \
    -DDAIMOS_CMD_TOKEN=MKFS_DTFS \
    -I "$DAIMOS_REPO/userland/exec" \
    -I "$DAIMOS_REPO/userland/libc" \
    -I "$DAIMOS_REPO/system/kernel/proc" \
    -I "$DAIMOS_REPO/system/kernel/fs" \
    -I "$DAIMOS_REPO/system/kernel/core" \
    -I "$DAIMOS_REPO/system/kernel/storage" \
    -I "$DAIMOS_REPO/tools/host" \
    -o "$work/mkfs-target-v1520" \
    "$self/daimos-dtfs-mkfs-identity-clear-v1520.c" \
    "$DAIMOS_REPO/userland/exec/commands.c"
"$work/mkfs-target-v1520"

# Execute actual PDP-6 DTFS mount source and the real BCACHE invalidation
# leaf against both stamped and legacy RBN0.  The VFS publisher and raw
# hardware jump are the only test-controlled boundaries.
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(x) for x in sys.argv[1:])
dtfs = (repo / 'system/kernel/fs/dtfs_runtime.s').read_text()
mount = dtfs[dtfs.index('dtfs_mount_unit:\n'):
             dtfs.index('dtfs_lookup:\n')]
restore = dtfs[dtfs.index('dtfs_restore4:\n'):
               dtfs.index('; Compact vnode predicates.',
                          dtfs.index('dtfs_restore4:\n'))]
cache = (repo / 'system/kernel/storage/bcache_pdp6.s').read_text()
invalidate = cache[cache.index('bcache_invalidate_all:\n'):
                   cache.index('; void bcache_workspace_invalidate')]
head = ('.text\n.set DTFS_ENABLE_TENEX,0\n'
        '.set DTFS_ENABLE_ITS,0\n.set DTFS_ENABLE_FOREIGN,0\n'
        '.globl dtfs_mount_unit\n.globl bcache_invalidate_all\n')
source = head + restore + mount + invalidate
required = ('movei   2,0144', 'setz    2,',
            'dtfs_mount_identity_nonzero_loop_v1520:',
            'dtfs_mount_identity_padding_loop_v1520:',
            'move    2,tsfs_file_shape_base',
            'move    2,tsfs_extent_media_base',
            'sub     17,kconst_3_3')
for anchor in required:
    assert anchor in mount, 'v1520 production source drift: ' + anchor
(out / 'native-source-v1520.s').write_text(source)
mutants = (
    ('ignore-checksum',
     'came    1,fs_block_workspace+3', 'came    1,1'),
    ('ignore-padding',
     'skipn   (1)', 'skipn   [0]'),
    ('accept-any-nonempty',
     'jumpe   3,dtfs_mount_identity_valid_v1520',
     'jrst    dtfs_mount_identity_valid_v1520'),
    ('skip-high-ID-publication',
     'move    1,-2(17)               ; high half of volume identifier',
     'setz    1,                      ; high half of volume identifier'),
    ('skip-low-ID-publication',
     'move    1,-1(17)               ; low half',
     'setz    1,                      ; low half'))
for name, old, new in mutants:
    assert source.count(old) == 1, 'ambiguous source mutation ' + name
    (out / ('mutant-'+name+'-v1520.s')).write_text(
        source.replace(old, new, 1))
PY

run_native() {
    label=$1
    program=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 600000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-id-$label-v1520" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-volume-id-native-v1520.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_v2_mount_exclusive_v1557.s" \
        "$program" > "$work/$label.log" 2>&1
}

run_native baseline "$work/native-source-v1520.s" || {
    echo 'FAIL v1520: native admission/identity baseline' >&2
    tail -55 "$work/baseline.log" >&2
    exit 1
}
echo 'PASS v1520: native PDP-6 mounted 72-bit ID and rejected malformed media'
for name in ignore-checksum ignore-padding accept-any-nonempty \
    skip-high-ID-publication skip-low-ID-publication; do
    if run_native "$name" "$work/mutant-$name-v1520.s"; then
        echo "FAIL v1520: unsafe $name accepted" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$name.log" || {
        echo "FAIL v1520: $name did not execute native oracle" >&2
        tail -26 "$work/$name.log" >&2
        exit 1
    }
    echo "PASS v1520: rejected native $name mutation"
done
