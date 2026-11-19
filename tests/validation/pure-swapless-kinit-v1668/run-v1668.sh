#!/bin/sh
# Real source C89 root-only KINIT selector, second AUXSTORE MINIT,
# compiled Make policy and deliberately unsafe selected-source mutants.
set -eu
: "${DAIMOS_REPO:?DAIMOS worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1668-source.XXXXXX")
trap 'echo "v1668 source evidence: $work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/modules/module_minit.c" \
    "$kit/tests/validation/pure-boot-select-v1613/test-native-v1613.c" \
    "$here/test-main-v1668.c" "$work" <<'PY'
from pathlib import Path
import sys

src=Path(sys.argv[1]).read_text(encoding='ascii')
fixture=Path(sys.argv[2]).read_text(encoding='ascii')
tests=Path(sys.argv[3]).read_text(encoding='ascii')
work=Path(sys.argv[4])
begin='void\nproc_swap_minit_v481(void)\n{'
end='\n/** Register a resident PI handler'
aux='void\nauxstore_minit(void)\n{'
end_aux='\n/** @brief Install runtime logstore'
prefix_end='/* Forward declaration for the extracted second AUXSTORE MINIT.'
if src.count(begin)!=1 or src.count(end)!=1 or \
    src.count(aux)!=1 or src.count(end_aux)!=1 or \
    tests.count(prefix_end)!=1:
    raise SystemExit('v1668 selector/AUXSTORE source extraction drift')
selector=begin+src.split(begin,1)[1].split(end,1)[0]+'\n'
auxstore=aux+src.split(aux,1)[1].split(end_aux,1)[0]+'\n'
pre,post=tests.split(prefix_end,1)
post=prefix_end+post


def write(name,selector_code=selector,aux_code=auxstore):
    (work/name).write_text(fixture+'\n'+pre+selector_code+
        aux_code+'\n'+post,encoding='ascii')


write('original.c')
bad=('        minit_fatal(name);\n        return;\n'
     '#endif\n        auxstore_post_minits();')
if selector.count(bad)!=1:
    raise SystemExit('v1668 exact positive BACKSTORE fail marker drift')
write('unsafe-positive.c',selector.replace(bad,
    '        return;\n#endif\n        auxstore_post_minits();',1))
bad_aux='if (auxstore_backstore_blocks != 0UL) {'
if auxstore.count(bad_aux)!=1:
    raise SystemExit('v1668 second discovery fail marker drift')
write('unsafe-rediscovery.c',aux_code=auxstore.replace(bad_aux,
    'if (0) {',1))
PY

for version in original unsafe-positive unsafe-rediscovery; do
    cc -std=c89 -pedantic -Wall -Wextra -Werror \
        -Wno-unused-function \
        -DD6FS_FS_ENABLED=0 -DKINIT_TAPE_BOOT=1 \
        -DDAIMOS_PURE_MRES_ENABLED=1 \
        -DDAIMOS_SWAPLESS_ONLY_V1668=1 \
        "$work/$version.c" -o "$work/$version"
done
"$work/original" > "$work/original.log"
echo 'v1668: real source C89 selector and AUXSTORE rediscovery PASS'
for mutant in unsafe-positive unsafe-rediscovery; do
    if "$work/$mutant" > "$work/$mutant.log" 2>&1; then
        echo "FAIL v1668: $mutant survived expected rejection" >&2
        exit 1
    fi
    grep -q '^FAIL v1668:' "$work/$mutant.log" || {
        cat "$work/$mutant.log" >&2; exit 1;
    }
    echo "v1668: executed $mutant rejected"
done

rootmake="$DAIMOS_REPO/system/boot/pdp6"
for options in 'tape 1 1 only' 'tape 1 0 both' \
    'auto 1 0 both' 'disk 1 0 disk' 'drum 1 0 disk' \
    'tape 1 1 only-bitmap'; do
    set -- $options
    root=$1
    pure=$2
    strict=$3
    expect=$4
    bitmap=0
    if [ "$expect" = only-bitmap ]; then
        bitmap=1
        expect=only
    fi
    image=$(make -s -C "$rootmake" ROOT="$root" \
        DAIMOS_PURE_MRES_ENABLED="$pure" \
        DAIMOS_SWAPLESS_ONLY_V1668="$strict" DAIMOS_PBM_V1667="$bitmap" \
        --eval='print-v1668: ; @printf "%s\n" "$(MRES_PACKAGE_OBJS)"' \
        print-v1668)
    case "$image" in
        *purev1612-mres.dobj*) pure_found=1 ;;
        *) pure_found=0 ;;
    esac
    if [ "$expect" = disk ]; then
        if [ "$pure_found" -ne 0 ]; then
            echo 'FAIL v1668: disk/drum-only build included PURE' >&2
            exit 1
        fi
        expect=both
    elif [ "$pure_found" -ne 1 ]; then
        echo 'FAIL v1668: PURE candidate missing' >&2
        exit 1
    fi
    case "$image" in
        *swapv481-mres.dobj*) found=both ;;
        *) found=only ;;
    esac
    if [ "$found" != "$expect" ]; then
        echo "FAIL v1668: ROOT=$root strict=$strict found=$found" >&2
        exit 1
    fi
    echo "v1668: ROOT=$root strict=$strict bitmap=$bitmap $found PASS"
done

for options in 'auto 1 1' 'disk 1 1' 'drum 1 1' \
    'tape 0 1' 'tape 1 2'; do
    set -- $options
    if make -s -C "$rootmake" ROOT="$1" \
        DAIMOS_PURE_MRES_ENABLED="$2" \
        DAIMOS_SWAPLESS_ONLY_V1668="$3" \
        --eval='print-v1668: ; @printf "%s\n" "$(MRES_PACKAGE_OBJS)"' \
        print-v1668 > "$work/rejected-$1-$2-$3.log" 2>&1; then
        echo "FAIL v1668: invalid ROOT=$1 PURE=$2 strict=$3 allowed" >&2
        exit 1
    fi
    grep -q 'DAIMOS_SWAPLESS_ONLY_V1668' \
        "$work/rejected-$1-$2-$3.log" || exit 1
    echo "v1668: invalid ROOT=$1 PURE=$2 strict=$3 rejected"
done

# A general build must retain v1665 source-linked behavior.
sh "$kit/tests/validation/pure-boot-select-v1665/run-v1665.sh" \
    > "$work/v1665-regression.log" 2>&1 || {
    tail -60 "$work/v1665-regression.log" >&2; exit 1;
}
echo 'v1668: normal v1665/v1613 selector baseline PASS'
