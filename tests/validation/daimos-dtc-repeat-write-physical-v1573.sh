#!/bin/sh
# v1573: direct real PDP-6 Type-136 driver write->write with NO DTFS.
# Prove the complete DECtape image, not just data returned by a read.
# All assembly links exact production tape_io.s and storage_router.s.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1573_MODE:-repeat}
case "$mode" in
    control|repeat|strict-direction|reverse-immediate|reverse-drain|reverse-armfirst|reverse-prime|write-only|reverse-fixture|reverse-fixture-fixed|reverse-fixture-drain|reverse-fixture-armfirst|reverse-fixture-prime) ;;
    *) echo "v1573: invalid mode $mode" >&2; exit 2 ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-dtc-repeat-write-v1573.XXXXXX")
trap 'if [ "${V1573_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "v1573 direct evidence: $work"; fi' EXIT HUP INT TERM

source="$self/daimos-dtc-stream-online-v1.s"
case "$mode" in
    reverse-fixture|reverse-fixture-fixed|reverse-fixture-drain)
        source="$self/daimos-dtc-reverse-online-v1.s" ;;
esac
python3 - "$source" "$work/direct-v1573.s" "$mode" <<'PY'
from pathlib import Path
import sys

original = Path(sys.argv[1]).read_text()
if sys.argv[3] in ('control', 'reverse-fixture', 'reverse-fixture-fixed', 'reverse-fixture-drain', 'reverse-fixture-armfirst', 'reverse-fixture-prime'):
    Path(sys.argv[2]).write_text(original)
    raise SystemExit(0)
if sys.argv[3] == 'write-only':
    marker = ('write_ok:\n'
              '        ; Read the same two-block ascending run.  This deliberately starts\n')
    assert original.count(marker) == 1
    replacement = ('write_ok:\n'
                   '        ; v1573: HALT immediately after first counted write.\n'
                   '        setz 1,\n'
                   '        popj 017,\n'
                   '        ; Read the same two-block ascending run.  This deliberately starts\n')
    Path(sys.argv[2]).write_text(original.replace(marker, replacement, 1))
    raise SystemExit(0)
old = ('write_ok:\n'
       '        ; Read the same two-block ascending run.  This deliberately starts\n')
assert original.count(old) == 1
insert = (
    'write_ok:\n'
    '        ; v1573: exact physical adjacent write WITHOUT intervening read.\n'
    '        ; First 0200/0201 write completed, now overwrite 0200.\n'
    '        setz 1,\n'
    '        movei 2,0200\n'
    '        movei 3,write_buf\n'
    '        pushj 017,dtc_write_block\n'
    '        jumpe 1,repeat_ok_v1573\n'
    '        movei 1,4\n'
    '        popj 017,\n'
    'repeat_ok_v1573:\n'
    '        ; Read the same two-block ascending run.  This deliberately starts\n')
Path(sys.argv[2]).write_text(original.replace(old, insert, 1))
PY

# A completed transfer is already PAST its block's DATA. If the next
# request targets that block, forward search must NOT be chosen. Test
# this minimal one-instruction driver correction without patching DAIMOS.
driver="${V1574_DRIVER_OVERRIDE:-$DAIMOS_REPO/system/kernel/drivers/tape_io.s}"
if [ "$mode" = strict-direction ]; then
    driver="$work/tape-io-strict-v1573.s"
    python3 - "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$driver" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
before = ('        soj 6,\n'
          '        sub 6,2\n'
          '        jumple 6,dtc_search_begin\n')
after = ('        soj 6,\n'
         '        sub 6,2\n'
         '        jumpl 6,dtc_search_begin\n')
assert text.count(before) == 1, 'driver direction anchor drift'
Path(sys.argv[2]).write_text(text.replace(before, after, 1))
PY
    echo 'v1573: one-instruction strict direction check in disposable driver'
fi
if [ "$mode" = reverse-immediate ] || [ "$mode" = reverse-fixture-fixed ]; then
    driver="$work/tape-io-reverse-immediate-v1573.s"
    python3 - "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$driver" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        hrrzs storage_iowd\n'
       '        jrst tape_dct_count_done\n'
       'tape_dct_reverse_more:\n')
new = ('        hrrzs storage_iowd\n'
       '        ; v1573 DISPOSABLE: check reverse last-word completion.\n'
       '        skipn dtc_request_write\n'
       '        jrst tape_dct_count_done\n'
       '        jrst tape_dct_done_keep_dtc\n'
       'tape_dct_reverse_more:\n')
assert source.count(old) == 1
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY
    echo 'v1573: disposable reverse last-word early completion probe'
fi
if [ "$mode" = reverse-drain ] || [ "$mode" = reverse-fixture-drain ] ||
    [ "$mode" = reverse-armfirst ] || [ "$mode" = reverse-fixture-armfirst ] ||
    [ "$mode" = reverse-prime ] || [ "$mode" = reverse-fixture-prime ]; then
    driver="$work/tape-io-reverse-drain-v1573.s"
    python3 - "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$driver" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        movei 1,0200\n'
       '        movem 1,storage_count\n'
       '        hrrzs storage_iowd\n'
       '        jrst tape_dct_count_done\n'
       'tape_dct_reverse_more:\n')
new = ('        ; v1573 TEST ONLY: the reverse write needs two DCT flush\n'
       '        ; ACKs. Keep zero count so the next PI3 enters the\n'
       '        ; patched ACK selector, not another memory DATAO.\n'
       '        skipn dtc_request_write\n'
       '        jrst tape_dct_reverse_read_end_v1573\n'
       '        setzm storage_count\n'
       '        jrst tape_dct_reverse_end_v1573\n'
       'tape_dct_reverse_read_end_v1573:\n'
       '        movei 1,0200\n'
       '        movem 1,storage_count\n'
       'tape_dct_reverse_end_v1573:\n'
       '        hrrzs storage_iowd\n'
       '        jrst tape_dct_count_done\n'
       'tape_dct_reverse_more:\n')
assert source.count(old) == 1
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY
    if [ "$mode" = reverse-armfirst ] || [ "$mode" = reverse-fixture-armfirst ]; then
        python3 - "$driver" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = ('        cono 0210,0(1)\n'
       '        cono 0200,003443\n'
       '        jrst pdp10_pi_dispatch_done\n')
new = ('        ; v1573 TEST ONLY: request DCT output before WRITE mode.\n'
       '        cono 0200,003443\n'
       '        cono 0210,0(1)\n'
       '        jrst pdp10_pi_dispatch_done\n')
assert text.count(old) == 1
path.write_text(text.replace(old, new, 1))
PY
        echo 'v1573: extra isolated DCT-before-DTC reverse WRITE probe'
    fi
    echo 'v1573: disposable reverse DCT two-ACK drain probe'
fi
if [ "$mode" = reverse-prime ] || [ "$mode" = reverse-fixture-prime ]; then
    python3 - "$driver" <<'PY'
from pathlib import Path
import sys

path=Path(sys.argv[1]); text=path.read_text()
old=('        iori 1,0220705\n'
     '        ior 1,dtc_request_reverse\n'
     '        cono 0210,0(1)\n'
     '        cono 0200,003443\n'
     '        jrst pdp10_pi_dispatch_done\n')
new=('        iori 1,0220705\n'
     '        ior 1,dtc_request_reverse\n'
     '        skipn dtc_request_reverse\n'
     '        jrst dtc_write_forward_v1573\n'
     '        ; v1573 TEST ONLY: prime the reverse DCT output before\n'
     '        ; switching Type-551 to physical WRITE mode.\n'
     '        cono 0200,003443\n'
     '        hrrz 2,storage_iowd\n'
     '        move 1,(2)\n'
     '        datao 0200,1\n'
     '        sos storage_iowd\n'
     '        sos storage_count\n'
     '        move 1,dtc_request_unit\n'
     '        lsh 1,3\n'
     '        iori 1,0220705\n'
     '        ior 1,dtc_request_reverse\n'
     '        cono 0210,0(1)\n'
     '        jrst pdp10_pi_dispatch_done\n'
     'dtc_write_forward_v1573:\n'
     '        cono 0210,0(1)\n'
     '        cono 0200,003443\n'
     '        jrst pdp10_pi_dispatch_done\n')
assert text.count(old)==1
path.write_text(text.replace(old,new,1))
PY
    echo 'v1573: disposable initial reverse DCT DATAO priming probe'
fi

if [ "${V1573_COUNTERS:-0}" = 1 ]; then
    # Diagnostic counters live ONLY in this testkit copy of tape_io.s.
    # They prove whether the real PI3 handler sends DATAO while the
    # tape motor is in physical reverse WRITE, independent of the
    # simulator's block-level success/failure return code.
    if [ "$driver" = "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" ]; then
        driver="$work/tape-io-counters-v1573.s"
        cp "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" "$driver"
    fi
    python3 - "$driver" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]); text = path.read_text()
tags = {
    'tape_dct_data_handler:': 'v1573_data_pis',
    'tape_dct_reverse_word:': 'v1573_reverse_pis',
    'tape_dct_dtc_write_arm:': 'v1573_write_arms',
    'tape_dct_dtc_write_ack1:': 'v1573_ack1',
    'tape_dct_dtc_write_ack2:': 'v1573_ack2',
    'dtc_search_pi_found:': 'v1573_search_found',
}
for label, counter in tags.items():
    assert text.count(label+'\n') == 1, label
    text = text.replace(label+'\n', label+'\n        aos '+counter+'\n', 1)
text += ('\n        .bss\n' + ''.join(
    '        .globl '+name+'\n'+name+': .block 1\n' for name in tags.values()))
path.write_text(text)
PY
fi

"$PDP10_PREFIX/bin/mkdtfs" -o "$work/tape-v1573.tap"
cp "$work/tape-v1573.tap" "$work/before-v1573.tap"
cat > "$work/physical-v1573.ini" <<EOF
set DCT enabled
set DTC enabled
set DTC0 enabled
set DTC DCT=4
attach -q DTC0 $work/tape-v1573.tap
EOF
if [ "${V1573_DEBUG:-0}" = 1 ]; then
    dtc_debug_flags=CONO
    if [ "${V1573_DEBUG_DETAIL:-0}" = 1 ]; then
        dtc_debug_flags=DETAIL
    fi
    cat >> "$work/physical-v1573.ini" <<EOF
set debug $work/type136-v1573.log
set DTC debug=$dtc_debug_flags
set DCT debug=${V1573_DCT_DEBUG:-CONO}
EOF
fi
echo "v1573: real PDP-6 direct Type-136 physical $mode test"
if ! "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 80 \
    --workdir "$work/run" --name dtc-repeat-v1573 \
    --ini "$work/physical-v1573.ini" --expect __test_exit=0 \
    ${V1573_COUNTERS:+--examine v1573_data_pis --examine v1573_reverse_pis --examine v1573_write_arms --examine v1573_ack1 --examine v1573_ack2 --examine v1573_search_found} \
    "$self/daimos-test-crt0-v1.s" "$work/direct-v1573.s" \
    "$driver" \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
    "$self/daimos-dtc-stream-online-stubs-v1.s" \
    > "$work/guest.log" 2>&1; then
    tail -65 "$work/guest.log" >&2
    exit 1
fi
python3 - "$work/before-v1573.tap" "$work/tape-v1573.tap" "$mode" <<'PY'
from pathlib import Path
import struct
import sys

before, after = [Path(p).read_bytes() for p in sys.argv[1:3]]
assert len(before) == len(after) == 0o1102 * 1024
modified = {i // 1024 for i, pair in enumerate(zip(before, after))
            if pair[0] != pair[1]}
unexpected = sorted(modified - {0o200, 0o201})
print('v1573 direct physical changed blocks:',
      [oct(block) for block in sorted(modified)])
negative = sys.argv[3] in ('repeat', 'reverse-fixture', 'strict-direction') and (
    __import__('os').environ.get('V1573_EXPECT_NEGATIVE') == '1')
assert 0 not in modified, 'stamped physical RBN0 changed'
for block in (0o200, 0o201):
    offset = block * 1024
    hi, lo = struct.unpack_from('<II', after, offset)
    expected = 1 if block == 0o200 else 129
    if sys.argv[3] in ('reverse-fixture', 'reverse-fixture-fixed', 'reverse-fixture-drain', 'reverse-fixture-armfirst', 'reverse-fixture-prime'):
        expected = 0o1001 if block == 0o200 else 0o401
    assert hi == 0 and lo == expected, (
        'wrong DATA block', block, hi, lo, expected)
if negative:
    assert unexpected, 'known unsafe reverse-write completion escaped oracle'
    print('PASS v1573 NEGATIVE: caught %d unrelated physical block writes' %
          len(unexpected))
else:
    if unexpected:
        print('FAIL v1573: Type-136 wrote unrelated physical blocks:',
              [oct(block) for block in unexpected])
        raise SystemExit(1)
    print('PASS v1573: source-linked direct write/read affects exact requested blocks')
PY
