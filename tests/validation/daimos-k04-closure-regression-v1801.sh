#!/bin/sh
# K04 v1801: bounded closeout regression; no writable guest media.
# Existing real PDP-6 evidence is verified without rebuilding images.
# C89 guests and physical fixtures remain in their versioned tests.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
PATH="${PDP10_PREFIX:-$HOME/cross}/bin:$PATH"
export PATH
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

for version in 1787 1793 1794 1795 1796 1797 1798 1799 1800 1800b; do
    case "$version" in
    1787) name=clock-wrap ;;
    1793) name=sidl-prevm ;;
    1794) name=prevm-sidl ;;
    1795) name=permanent-pin ;;
    1796) name=file-fatal ;;
    1797) name=dying-parent ;;
    1798) name=multimember-hup ;;
    1799) name=vmnone-discard ;;
    1800) name=late-child ;;
    1800b) name=ineligible-init ;;
    esac
    python3 "$self/daimos-k04-$name-verify-v$version.py" --self-test
done

# v1800-A and B are the latest complementary parent/INIT physical
# ownership experiments. Their immutable source-linked witnesses
# and D6FS are checked again, not merely trusted from the reports.
for case_name in a b; do
    case "$case_name" in
    a)
        work="$TMPDIR/daimos-k04-v1800a-r2-late-child-physical"
        verify="$self/daimos-k04-late-child-verify-v1800.py"
        map="$work/build/system/boot/pdp6/k04-v1800-witnesses.txt"
        ;;
    b)
        work="$TMPDIR/daimos-k04-v1800b-ineligible-init-physical"
        verify="$self/daimos-k04-ineligible-init-verify-v1800b.py"
        map="$work/build/system/boot/pdp6/k04-v1800b-witnesses.txt"
        ;;
    esac
    if test -e "$work"; then
        test -f "$map" && test -f "$work/simh.out" || {
            echo "K04 v1801 incomplete physical evidence: $work" >&2
            exit 1
        }
        python3 "$verify" "$map" "$work/simh.out" \
            "$work/build/system/boot/pdp6/disk"
    else
        echo "K04 v1801 physical evidence unavailable: $work" >&2
        exit 1
    fi
done
echo 'K04 v1801 closeout regression PASS (read-only)'
