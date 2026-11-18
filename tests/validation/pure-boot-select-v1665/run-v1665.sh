#!/bin/sh
# Source-linked C89 KINIT memory-backend selection + real Make policies.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-boot-policy-v1665.XXXXXX")
trap 'echo "v1665 boot-policy evidence: $work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/modules/module_table.s" \
    "$DAIMOS_REPO/system/kernel/modules/module_minit.c" \
    "$work/selection.c" "$work/unsafe-root.c" <<'PY'
from pathlib import Path
import sys

table=Path(sys.argv[1]).read_text(encoding='ascii')
src=Path(sys.argv[2]).read_text(encoding='ascii')


def valid_order(t):
    drivers = ('.word dtc_minit,,tape_mres_package',
               '.word dsk_minit,,dsk_mres_package')
    root = '.word root_select_minit,,0'
    swap = '.word proc_swap_minit_v481,,proc_swap_mres_package_v481'
    aux = '.word auxstore_minit,,0'
    if any(t.count(x)!=1 for x in (*drivers,root,swap,aux)):
        return False
    return all(t.index(d) < t.index(root) for d in drivers) and (
        t.index(root) < t.index(swap) < t.index(aux))


if not valid_order(table):
    raise SystemExit('FAIL v1665: root/driver/swap/aux MINIT ordering')
root='.word root_select_minit,,0'
swap='.word proc_swap_minit_v481,,proc_swap_mres_package_v481'
unsafe=table.replace(root,'TEMP-V1665',1).replace(swap,root,1)
unsafe=unsafe.replace('TEMP-V1665',swap,1)
if valid_order(unsafe):
    raise SystemExit('FAIL v1665: swapped root/SWAP order mutant accepted')
print('v1665: original module-table root-before-swap ordering PASS')
print('v1665: executed inverse MINIT order mutation rejected')

begin='void\nproc_swap_minit_v481(void)\n{'
end='\n/** Register a resident PI handler'
if src.count(begin)!=1 or src.count(end)!=1:
    raise SystemExit('v1665 source-linked SWAP MINIT extraction drift')
part=begin+src.split(begin,1)[1].split(end,1)[0]
Path(sys.argv[3]).write_text(part+'\n',encoding='ascii')
old='if (root == KINIT_ROOT_DTC) {'
if part.count(old)!=1:
    raise SystemExit('v1665 wrong-root selection mutation anchor drift')
Path(sys.argv[4]).write_text(part.replace(old,
    'if (root != KINIT_ROOT_DTC) {',1)+'\n',encoding='ascii')
PY

cat "$kit/tests/validation/pure-boot-select-v1613/test-native-v1613.c" \
    "$work/selection.c" "$here/test-main-v1665.c" > "$work/full.c"
cat "$kit/tests/validation/pure-boot-select-v1613/test-native-v1613.c" \
    "$work/unsafe-root.c" "$here/test-main-v1665.c" > "$work/unsafe.c"

for profile in '1 1 1' '0 1 1' '1 0 1' \
    '1 1 0' '0 1 0' '1 0 0'; do
    set -- $profile
    d6=$1
    tape=$2
    pure=$3
    name="d6${d6}-tape${tape}-pure${pure}"
    cc -std=c89 -pedantic -Wall -Wextra -Werror \
        -DD6FS_FS_ENABLED="$d6" -DKINIT_TAPE_BOOT="$tape" \
        -DDAIMOS_PURE_MRES_ENABLED="$pure" \
        "$work/full.c" -o "$work/$name"
    "$work/$name" > "$work/$name.log"
    echo "v1665: C89 original MINIT source $name PASS"
done

cc -std=c89 -pedantic -Wall -Wextra -Werror \
    -DD6FS_FS_ENABLED=1 -DKINIT_TAPE_BOOT=1 \
    -DDAIMOS_PURE_MRES_ENABLED=1 \
    "$work/unsafe.c" -o "$work/unsafe"
if "$work/unsafe" > "$work/unsafe-root.log" 2>&1; then
    echo 'FAIL v1665: wrong-root PURE selection mutant accepted' >&2
    exit 1
fi
grep -q '^FAIL v1665' "$work/unsafe-root.log" || {
    cat "$work/unsafe-root.log" >&2
    exit 1
}
echo 'v1665: executed wrong-root selection mutant rejected'

# Evaluate the ACTUAL top-level PDP-6 Makefile for each profile;
# this observes linked candidate packages, not just source strings.
for profile in 'auto 1 yes' 'tape 1 yes' 'disk 1 no' \
    'drum 1 no' 'auto 0 no' 'tape 0 no'; do
    set -- $profile
    root=$1
    pure=$2
    expected=$3
    output=$(make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
        ROOT="$root" DAIMOS_PURE_MRES_ENABLED="$pure" \
        --eval='print-v1665: ; @printf "%s\n" "$(MRES_PACKAGE_OBJS)"' \
        print-v1665)
    case "$output" in
        *purev1612-mres.dobj*) actual=yes ;;
        *) actual=no ;;
    esac
    if [ "$actual" != "$expected" ]; then
        echo "FAIL v1665: ROOT=$root PURE=$pure MRES candidates=$actual" >&2
        exit 1
    fi
    case "$output" in
        *swapv481-mres.dobj*) : ;;
        *) echo 'FAIL v1665: legacy SWAP MRES missing' >&2; exit 1 ;;
    esac
    echo "v1665: Make ROOT=$root PURE=$pure candidate=$actual PASS"
done

# The original v1613 source-linked selector and unsafe AUX discovery
# mutant remain a regression for both dedicated media-root profiles.
sh "$kit/tests/validation/pure-boot-select-v1613/run-v1613.sh" \
    > "$work/v1613-baseline.log" 2>&1
echo 'v1665: original v1613 KINIT selection baseline PASS'
