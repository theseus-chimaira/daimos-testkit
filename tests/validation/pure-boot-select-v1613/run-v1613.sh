#!/bin/sh
# Execute actual KINIT SWAP selection source under C89 host fixtures.
# Mutation must fail at the absent AUXST1 selection assertion.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-kinit-v1613.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/modules/module_minit.c" \
    "$work/selection.c" "$work/mutant.c" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
begin = 'void\nproc_swap_minit_v481(void)\n{'
end = '\n/** Register a resident PI handler'
assert src.count(begin) == 1 and src.count(end) == 1
entry = src.split(begin, 1)[1].split(end, 1)[0]
unit = begin + entry
Path(sys.argv[2]).write_text(unit + '\n')
old = 'if (auxstore_boot_discover() != 0 ||\n'
new = 'if (auxstore_boot_discover() == 0 &&\n'
assert unit.count(old) == 1
Path(sys.argv[3]).write_text(unit.replace(old, new, 1) + '\n')
PY

for profile in '0 1' '0 0' '1 0'; do
    set -- $profile
    root=$1
    pure=$2
    cat "$here/test-native-v1613.c" "$work/selection.c" \
        "$here/test-main-v1613.c" >"$work/full.c"
    cc -std=c89 -pedantic -Wall -Wextra -Werror \
        -DD6FS_FS_ENABLED="$root" \
        -DDAIMOS_PURE_MRES_ENABLED="$pure" \
        "$work/full.c" -o "$work/guest"
    "$work/guest"
done

cat "$here/test-native-v1613.c" "$work/mutant.c" \
    "$here/test-main-v1613.c" >"$work/unsafe.c"
cc -std=c89 -pedantic -Wall -Wextra -Werror \
    -DD6FS_FS_ENABLED=0 -DDAIMOS_PURE_MRES_ENABLED=1 \
    "$work/unsafe.c" -o "$work/unsafe"
if "$work/unsafe" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1613: ignored absent-AUXST1 mutant was accepted' >&2
    exit 1
fi
grep -q '^FAIL KINIT v1613' "$work/mutant.log" || {
    cat "$work/mutant.log" >&2
    exit 1
}
echo 'PASS v1613: absent, zero and positive AUXST1; unsafe mutant rejected'
