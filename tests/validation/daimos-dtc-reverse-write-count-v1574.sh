#!/bin/sh
# v1574: actual production Type-136 reverse WRITE count/completion.
# The source-linked test exercises real PDP-6 tape writes and checks the
# entire physical reel. An unsafe one-instruction mutant must corrupt it.
# All disposable binaries and media are built outside the source tree.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtc-reverse-write-v1574.XXXXXX")
trap 'if [ "${V1574_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "v1574 evidence: $work"; fi' EXIT HUP INT TERM

driver="$DAIMOS_REPO/system/kernel/drivers/tape_io.s"
python3 - "$driver" "$work/unsafe-count-v1574.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
before = ('        movei 1,0200\n'
          '        skipn dtc_request_write\n'
          '        movem 1,storage_count\n'
          '        hrrzs storage_iowd\n')
after = ('        movei 1,0200\n'
         '        movem 1,storage_count\n'
         '        hrrzs storage_iowd\n')
assert source.count(before) == 1, 'v1574 reverse count source drift'
Path(sys.argv[2]).write_text(source.replace(before, after, 1))
print('PASS v1574: production reverse WRITE/READ count split matches source')
PY

for mode in control repeat reverse-fixture; do
    echo "v1574: production physical $mode"
    V1573_MODE="$mode" sh "$self/daimos-dtc-repeat-write-physical-v1573.sh" \
        > "$work/production-$mode.log" 2>&1 || {
        tail -55 "$work/production-$mode.log" >&2
        exit 1
    }
    grep -q '^PASS v1573: source-linked direct write/read' \
        "$work/production-$mode.log"
done

echo 'v1574: original direct reverse and forward-stream regressions'
sh "$self/daimos-dtc-reverse-online-v1.sh" > "$work/reverse.log" 2>&1
sh "$self/daimos-dtc-stream-online-v1.sh" > "$work/stream.log" 2>&1
grep -q 'PASS' "$work/reverse.log"
grep -q 'PASS' "$work/stream.log"

for mode in repeat reverse-fixture; do
    echo "v1574: unsafe count-reset mutant must damage the physical reel ($mode)"
    if V1573_MODE="$mode" V1574_DRIVER_OVERRIDE="$work/unsafe-count-v1574.s" \
        sh "$self/daimos-dtc-repeat-write-physical-v1573.sh" \
        > "$work/unsafe-$mode.log" 2>&1; then
        echo "FAIL v1574: unsafe $mode mutation was accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1573: Type-136 wrote unrelated physical blocks:' \
        "$work/unsafe-$mode.log" || {
        tail -55 "$work/unsafe-$mode.log" >&2
        echo "FAIL v1574: $mode mutant did not corrupt physical blocks" >&2
        exit 1
    }
    echo "PASS v1574: rejected executed unsafe $mode mutation"
done
echo 'PASS v1574: corrected Type-136 reverse count, exact reel isolation'
