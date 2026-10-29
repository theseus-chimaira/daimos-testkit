#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work=$(mktemp -d "$TMPDIR/daimos-logstore-native-v706.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
python3 - "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s" "$work/logic.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s[s.index('logstore_read:\n'):s.index('        .bss\nlogstore_mres_state:')]
head='.text\n'+''.join('.globl '+x+'\n' for x in ('logstore_read','logstore_write','logstore_backend_read_call','logstore_direct_read_call','logstore_backend_write_jump','logstore_mres_state','kret_neg1'))
tail='kret_neg1:\n seto 1,\n popj 17,\n.bss\nlogstore_mres_state: .block 7\n'
Path(sys.argv[2]).write_text(head+s+tail)
PY
cat > "$work/test.s" <<'EOF'
.text
.globl main
.globl __test_exit
main:
    movei 0,0200
    movem 0,logstore_mres_state+1
    movei 0,010
    movem 0,logstore_mres_state
    movei 0,provider
    hrrm 0,logstore_backend_read_call
    hrrm 0,logstore_direct_read_call
    hrrm 0,logstore_backend_write_jump
    setzm logstore_mres_state+4
    movei 1,2
    movei 2,01234
    pushj 17,logstore_read
    caie 1,1
    jrst fail
    movei 1,2
    movei 2,01234
    pushj 17,logstore_write
    caie 1,1
    jrst fail
    movei 0,0100010
    movem 0,logstore_mres_state+4
    movei 1,2
    movei 2,01234
    pushj 17,logstore_read
    caie 1,1
    jrst fail
    movei 1,2
    movei 2,01234
    pushj 17,logstore_write
    caie 1,1
    jrst fail
    setz 1,
    popj 17,
provider:
    movei 1,1
    popj 17,
fail:
    movei 1,2
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 20000 --timeout 15 --workdir "$work/run" \
 --name daimos-logstore-native-v706 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/logic.s" "$work/test.s" \
 > "$work/log" 2>&1 || { cat "$work/log"; exit 1; }
echo 'v706: native PDP-6 LOGSTORE multi/direct read/write PASS'
