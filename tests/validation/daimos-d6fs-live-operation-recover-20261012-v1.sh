#!/bin/sh
# Real PDP-6 append interrupted inside test-only post-write HALT, followed by
# offline recovery and fresh PDP-6 boot from disposable four-member media.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-d6fs-live-operation-recover-20261012-v1.XXXXXXXX")
"$self/daimos-d6fs-live-operation-cut-20261012-v1.sh" > "$work/build-result.txt"
image=$(sed -n 's/^CUT_IMAGE=//p' "$work/build-result.txt")
disk=$(sed -n 's/^CUT_DISK=//p' "$work/build-result.txt")
test -f "$image" && test -d "$disk"
pty_run=${PTY_RUN:-$TMPDIR/dsh-history-runtime-20261011-v2/pty-run}
test -x "$pty_run"
# HALT inside the backing-write callback after the selected data block is
# written. Neither the test program nor the shell gets to perform clean exit.
cat > "$work/cut.probes" <<'PROBES'
probe interrupt-in-real-append
command /CONFIG/FAULT.TEST
terminal eof
contains OPERATION-CUT-START
contains HALT instruction
contains (HALT
not_contains OPERATION-CUT-NOT-TRIGGERED
end
PROBES
"$self/../../tools/daimos-simh-harness-v6.sh" --daimos-repo "$DAIMOS_REPO" \
    --dofile "$image" --pty-run "$pty_run" --login ROOT \
    --probes "$work/cut.probes" --work-dir "$work/cut-simh" \
    --boot-timeout 120 --timeout 25
# This check is intentionally expected to fail: the interrupted writable
# mount must leave the selected superblock DIRTY.
fsck="$work/d6fsck"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    "$DAIMOS_REPO/tools/host/d6fsck.c" -o "$fsck"
if "$fsck" -n 4 -d "$disk" > "$work/dirty.log" 2>&1; then
    echo 'FAIL: interrupted filesystem was not dirty' >&2; exit 1
fi
grep -F 'selected superblock DIRTY' "$work/dirty.log" >/dev/null
mkdir -p "$work/recovered-disk"
for f in "$disk"/dsk*.dsk; do
    test -f "$f"
    cp --reflink=auto "$f" "$work/recovered-disk/"
done
find "$disk" -maxdepth 1 -name 'dsk*.dsk' -type f -exec cksum '{}' ';' > "$work/source-before.cksum"
"$fsck" -r -n 4 -d "$work/recovered-disk" > "$work/repair.log" 2>&1
grep -F 'repair verification: clean' "$work/repair.log" >/dev/null
"$fsck" -n 4 -d "$work/recovered-disk" > "$work/check.log" 2>&1
grep -F 'FCBs: clean' "$work/check.log" >/dev/null
# Replace precisely the four DSK member attachments. The SIMH kernel image
# remains the same; the second boot must not execute the faulting append.
python3 - "$image" "$disk" "$work/recovered-disk" "$work/reboot.ini" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
old,new=sys.argv[2:4]
assert source.count(old + '/dsk')==4, 'unexpected DSK member attachments'
Path(sys.argv[4]).write_text(source.replace(old + '/dsk', new + '/dsk'))
PY
cat > "$work/reboot.probes" <<'PROBES'
probe verify-original-content-and-eof
command /CONFIG/VERIFY.TEST
contains CUT-OLD-EOF-AND-DATA-PASS
not_contains CUT-OLD-FILE-CORRUPT
end
probe verify-stat-size
command STAT /CONFIG/FCBSEED
contains WORDS 1 MODE
not_contains WORDS 2 MODE
end
probe orderly-second-halt
command HALT
terminal eof
end
PROBES
"$self/../../tools/daimos-simh-harness-v6.sh" --daimos-repo "$DAIMOS_REPO" \
    --dofile "$work/reboot.ini" --pty-run "$pty_run" --login ROOT \
    --probes "$work/reboot.probes" --work-dir "$work/reboot-simh" \
    --boot-timeout 120 --timeout 25
find "$disk" -maxdepth 1 -name 'dsk*.dsk' -type f -exec cksum '{}' ';' > "$work/source-after.cksum"
cmp "$work/source-before.cksum" "$work/source-after.cksum"
printf 'PASS: interrupted PDP-6 append; offline clone recovery; fresh SIMH boot; original EOF/data; source unchanged\n'
printf 'ARTIFACTS=%s\n' "$work"
