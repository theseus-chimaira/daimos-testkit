#!/bin/sh
# Read-only source images; all synthetic corruption and repair occurs on clones.
# This test exercises positive sole-ownership and negative cross-link cases.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO required}"
: "${D6FS_CLEAN_DISK:?D6FS_CLEAN_DISK must be the verified no-fault fixture}"
: "${TMPDIR:=$HOME/tmp}"
: "${D6FS_MEMBERS:=4}"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-orphan-ownership-20261012-v1.XXXXXXXX")
python3 - "$DAIMOS_REPO/tools/host/d6fsck.c" "$work/fixture.c" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
needle = ('        for (b = 0; b < s->freemap_blocks; ++b)\n'
          '                if (read_logical(s->freemap_start + b,\n')
assert source.count(needle) == 1, 'expected D6FS metadata traversal changed'
# Only test-only cloned images ever enter these special mutations. The rest
# of the tool remains the actual d6fsck parser and I/O geometry implementation.
fixture = '''        if (getenv("D6FS_TEST_ORPHAN_WITH_EXTENT")) {
                unsigned word;
                /* This fixture has a known entry for FCB 0451 at root slot 7. */
                for (word = 0U; word < DIRENT_WORDS; ++word)
                        if (write_file_word(s, fcbs, s->root,
                            7U * DIRENT_WORDS + word, 0U) != 0)
                                die("could not clear cloned directory entry");
                return 0;
        }
        if (getenv("D6FS_TEST_CROSSLINK")) {
                unsigned word, logical;
                uint64_t fcb_block[BLOCK_WORDS];
                /* Duplicate FCB 0451's extent into otherwise free FCB 0452. */
                logical = s->fcb_start + 298U / 8U;
                if (read_logical(logical, fcb_block) != 0)
                        die("could not read cloned FCB block");
                for (word = 0U; word < FCB_WORDS; ++word)
                        fcb_block[(298U % 8U) * FCB_WORDS + word] =
                            fcbs[(size_t)297U * FCB_WORDS + word];
                if (write_logical(logical, fcb_block) != 0)
                        die("could not write cloned FCB block");
                return 0;
        }
'''
Path(sys.argv[2]).write_text(source.replace(needle, fixture + needle, 1))
PY
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/fixture" "$work/fixture.c"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/d6fsck" "$DAIMOS_REPO/tools/host/d6fsck.c"
"$work/d6fsck" -n "$D6FS_MEMBERS" -d "$D6FS_CLEAN_DISK" > "$work/source-check.log" 2>&1
grep -F 'FCBs: clean' "$work/source-check.log" >/dev/null
# Current stable fixture: root directory slot 7 points to FCB 0451.
# A directory identity audit is a separate regression in daimos-testkit.
find "$D6FS_CLEAN_DISK" -maxdepth 1 -name 'dsk*.dsk' -type f -exec cksum '{}' ';' > "$work/source-before.cksum"
for kind in orphan crosslink; do
    disk="$work/$kind"
    mkdir -p "$disk"
    for f in "$D6FS_CLEAN_DISK"/dsk*.dsk; do
        test -f "$f"
        cp --reflink=auto "$f" "$disk/"
    done
    if test "$kind" = orphan; then
        D6FS_TEST_ORPHAN_WITH_EXTENT=1 "$work/fixture" -r -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-fixture.log" 2>&1
    else
        D6FS_TEST_CROSSLINK=1 "$work/fixture" -r -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-fixture.log" 2>&1
    fi
    if "$work/d6fsck" -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-before.log" 2>&1; then
        echo "FAIL: synthetic $kind corruption not detected" >&2; exit 1
    fi
    if test "$kind" = orphan; then
        grep -F 'unreachable FCB: 451' "$work/$kind-before.log" >/dev/null
        "$work/d6fsck" -r -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-repair.log" 2>&1
        grep -F 'reclaimed orphan FCB 451' "$work/$kind-repair.log" >/dev/null
        grep -F 'allocated leaked block:' "$work/$kind-repair.log" >/dev/null
        grep -F 'repair verification: clean' "$work/$kind-repair.log" >/dev/null
        "$work/d6fsck" -r -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-again.log" 2>&1
        if grep -E 'reclaimed orphan|deterministic repairs written|repaired superblock' "$work/$kind-again.log" >/dev/null; then
            echo 'FAIL: unique-orphan repair not idempotent' >&2; exit 1
        fi
        echo 'PASS: unique orphan extent reclaimed, allocation map repaired, clean and idempotent'
    else
        grep -F 'cross-linked block:' "$work/$kind-before.log" >/dev/null
        cksum "$disk"/*.dsk > "$work/$kind-before.cksum"
        status=0
        "$work/d6fsck" -r -n "$D6FS_MEMBERS" -d "$disk" > "$work/$kind-repair.log" 2>&1 || status=$?
        test "$status" -eq 1
        grep -F 'ambiguous corruption remains; no repairs written' "$work/$kind-repair.log" >/dev/null
        cksum "$disk"/*.dsk > "$work/$kind-after.cksum"
        cmp "$work/$kind-before.cksum" "$work/$kind-after.cksum"
        echo 'PASS: cross-linked orphan rejected; ambiguous disk untouched'
    fi
done
find "$D6FS_CLEAN_DISK" -maxdepth 1 -name 'dsk*.dsk' -type f -exec cksum '{}' ';' > "$work/source-after.cksum"
cmp "$work/source-before.cksum" "$work/source-after.cksum"
printf 'PASS: source image unchanged; ARTIFACTS=%s\n' "$work"
