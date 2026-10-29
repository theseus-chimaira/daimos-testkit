#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work=$(mktemp -d "$TMPDIR/daimos-file-direct-native-v708.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
python3 - "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" "$work/calls.s" <<'PY'
from pathlib import Path
import re
import sys
s=Path(sys.argv[1]).read_text()
out='.text\n.globl kret_neg1\n'
for kind,op in [('tty','write_s6rec'),('tty','read_s6rec'),('lpt','write_s6rec'),('wcnsls','read_words'),('wcnsls','write_words'),('ttydpy','putchar'),('ttydpy','getchar')]:
    name=f'{kind}_{op}_call'
    assert re.search(r'^'+name+r':\n\s*pushj\s+17,kret_neg1',s,re.M)
    out+=f'.globl {name}\n{name}:\n pushj 17,kret_neg1\n popj 17,\n'
out+='kret_neg1:\n seto 1,\n popj 17,\n'
Path(sys.argv[2]).write_text(out)
PY
cat > "$work/probe.s" <<'EOF'
.text
.globl main
.globl __test_exit
main:
    movei 1,3
    pushj 17,tty_write_s6rec_call
    jumpl 1,missing_ok
    jrst fail
missing_ok:
    movei 0,service
    hrrm 0,tty_write_s6rec_call
    hrrm 0,tty_read_s6rec_call
    hrrm 0,lpt_write_s6rec_call
    hrrm 0,wcnsls_read_words_call
    hrrm 0,wcnsls_write_words_call
    hrrm 0,ttydpy_putchar_call
    hrrm 0,ttydpy_getchar_call
    pushj 17,tty_write_s6rec_call
    caie 1,7
    jrst fail
    pushj 17,tty_read_s6rec_call
    caie 1,7
    jrst fail
    pushj 17,lpt_write_s6rec_call
    caie 1,7
    jrst fail
    pushj 17,wcnsls_read_words_call
    caie 1,7
    jrst fail
    pushj 17,wcnsls_write_words_call
    caie 1,7
    jrst fail
    pushj 17,ttydpy_putchar_call
    caie 1,7
    jrst fail
    pushj 17,ttydpy_getchar_call
    caie 1,7
    jrst fail
    setz 1,
    popj 17,
service:
    movei 1,7
    popj 17,
fail:
    movei 1,1
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 20000 --timeout 15 --workdir "$work/run" \
  --name daimos-file-direct-native-v708 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$work/calls.s" "$work/probe.s" \
  > "$work/test.log" 2>&1 || { cat "$work/test.log"; exit 1; }
echo 'v708: native PDP-6 absent and patched call-site behavior PASS'
