#!/bin/sh
# Disposable PDP-6 full-system physical OOM test: kill ONLY the requester.
# Production OOM BRK remains default-off. No production source is edited.
# Set V1075_TEST_OOM_ENABLED=0 for the full-guest negative control.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
enable=${V1075_TEST_OOM_ENABLED:-1}
negatives=${V1110_TEST_NEGATIVES:-0}
bad_run=${V1112_TEST_FAILED_RUN:-0}
mm_slots=${V1114_TEST_MM_SLOTS:-0}
mm_fragment=${V1115_TEST_MM_FRAGMENT:-0}
run_cause=${V1116_TEST_RUN_CAUSE:-0}
pid_reuse=${V1120_TEST_PID_REUSE:-0}
held_provider=${V1150_TEST_HELD_PROVIDER:-0}
endurance=${V1151_TEST_ENDURANCE:-0}
case "$enable" in
    0|1) ;;
    *) echo 'v1075: invalid V1075_TEST_OOM_ENABLED' >&2; exit 2 ;;
esac
case "$negatives" in
    0|1) ;;
    *) echo 'v1110: invalid negative-control mode' >&2; exit 2 ;;
esac
case "$bad_run" in
    0|1) ;;
    *) echo 'v1112: invalid failed-RUN mode' >&2; exit 2 ;;
esac
case "$mm_slots" in
    0|1) ;;
    *) echo 'v1114: invalid MM descriptor mode' >&2; exit 2 ;;
esac
case "$mm_fragment" in
    0|1) ;;
    *) echo 'v1115: invalid MM fragmentation mode' >&2; exit 2 ;;
esac
case "$run_cause" in
    0|1) ;;
    *) echo 'v1116: invalid RUN cause mode' >&2; exit 2 ;;
esac
case "$pid_reuse" in
    0|1) ;;
    *) echo 'v1120: invalid PID-reuse mode' >&2; exit 2 ;;
esac
case "$held_provider" in
    0|1) ;;
    *) echo 'v1150: invalid provider mode' >&2; exit 2 ;;
esac
case "$endurance" in
    0|1) ;;
    *) echo 'v1151: invalid endurance mode' >&2; exit 2 ;;
esac
if [ "$endurance" = 1 ] && { [ "$pid_reuse" != 1 ] ||
    [ "$held_provider" != 0 ] || [ "$negatives" != 0 ] ||
    [ "$bad_run" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ]; }; then
    echo 'v1151: endurance needs PID reuse without other fault modes' >&2
    exit 2
fi
if [ "$held_provider" = 1 ] && { [ "$negatives" != 0 ] ||
    [ "$bad_run" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ] ||
    [ "$pid_reuse" != 0 ]; }; then
    echo 'v1150: provider guest has a separate fault matrix' >&2
    exit 2
fi
if [ "$run_cause" = 1 ] && [ "$mm_slots" != 1 ]; then
    echo 'v1116: RUN cause requires MM descriptor pressure' >&2
    exit 2
fi
if [ "$mm_slots" = 1 ] && [ "$mm_fragment" = 1 ]; then
    echo 'v1115: only one MM fault mode per disposable kernel' >&2
    exit 2
fi
work=$(mktemp -d "$TMPDIR/daimos-oom-requester-live-v1075.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1075 work: $work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" "$enable" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
original = '.equ    PROC_OOM_BRK_ENABLED_V1000,0'
assert s.count(original) == 1, 'OOM option changed; audit before enabling test'
if sys.argv[2] == '1':
    p.write_text(s.replace(original,
                           '.equ    PROC_OOM_BRK_ENABLED_V1000,1', 1))
PY
if [ "$held_provider" = 1 ]; then
    python3 "$self/daimos-oom-provider-held-v1150.py" \
        "$work/source/system/kernel" "$enable"
fi
if [ "$endurance" = 1 ]; then
    python3 "$self/daimos-oom-endurance-v1151.py" \
        "$work/source/system/kernel"
fi
if [ "$mm_slots" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" \
        "$self/daimos-oom-mm-slots-v1114.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
snippet = Path(sys.argv[2]).read_text()
before, after = snippet.split('; Definitions appended after the original syscall assembly file.', 1)
source = p.read_text()
anchor = 'native_sys_brk:\n'
assert source.count(anchor) == 1, 'v1114: syscall entry changed'
p.write_text(source.replace(anchor, anchor + before, 1) + '\n' + after)
PY
fi
if [ "$run_cause" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/vm_pdp6.s" \
        "$work/source/system/kernel/proc/proc_run.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
run = Path(sys.argv[2])
s = p.read_text()
anchor = ('        pushj   17,mm_alloc_aligned\n'
          '        sub     17,kconst_2_2\n'
          '        jumpn   1,vm_space_create_fail\n')
assert s.count(anchor) == 1, 'v1116: VM create allocator contract changed'
header = '        .globl  vm_space_create\n'
assert s.count(header) == 1
s = s.replace(header, header + '        .globl  v1116_last_vm_cause\n', 1)
s = s.replace(anchor, anchor.replace('        jumpn',
            '        movem   1,v1116_last_vm_cause\n        jumpn'), 1)
p.write_text(s)

# RUN allocates the child u-area only after successful VM construction.
# Capture that later production MM result before it becomes generic -1.
s = run.read_text()
header = '        .globl  mm_alloc_aligned\n'
anchor = ('        pushj   17,mm_alloc_aligned\n'
          '        move    014,-2(17)\n'
          '        sub     17,kconst_3_3\n'
          '        jumpn   1,proc_run_mm_bad\n')
assert s.count(header) == 1 and s.count(anchor) == 1
s = s.replace(header, header + '        .globl  v1116_last_run_cause\n', 1)
s = s.replace(anchor, anchor.replace('        jumpn',
            '        movem   1,v1116_last_run_cause\n        jumpn'), 1)
run.write_text(s)
PY
fi
if [ "$mm_fragment" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" \
        "$work/source/system/kernel/mm/mm_pdp6.s" \
        "$self/daimos-oom-mm-fragment-v1115.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
mm = Path(sys.argv[2])
snippet = Path(sys.argv[3]).read_text()
before, after = snippet.split(
    '; Immediately after the production VM BRK call, before policy checking:', 1)
note, definitions = after.split(
    '; Definitions appended after the original syscall assembly file.', 1)
assert 'movem   2,v1115_last_cause' in note
source = p.read_text()
entry = 'native_sys_brk:\n'
call = '        pushj   17,vm_space_brk_current\n'
assert source.count(entry) == 1 and source.count(call) == 1
source = source.replace(entry, entry + before, 1)
source = source.replace(call, call +
                        '        movem   2,v1115_last_cause\n', 1)
p.write_text(source + '\n' + definitions)
# mm_find_fit is deliberately private in production. Export it only
# in this disposable test copy to observe genuine fragmented gaps.
mm_source = mm.read_text()
mm_anchor = '        .globl  mm_alloc_aligned_noreclaim\n'
assert mm_source.count(mm_anchor) == 1
mm.write_text(mm_source.replace(mm_anchor,
                               mm_anchor + '        .globl  mm_find_fit\n', 1))
PY
fi

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -F -C -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=
for sub in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$sub"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os -DV1075_TEST_OOM_ENABLED="$enable" \
    -DV1110_TEST_NEGATIVES="$negatives" \
    -DV1112_TEST_FAILED_RUN="$bad_run" \
    -DV1114_TEST_MM_SLOTS="$mm_slots" \
    -DV1115_TEST_MM_FRAGMENT="$mm_fragment" \
    -DV1116_TEST_RUN_CAUSE="$run_cause" \
    -DV1120_TEST_PID_REUSE="$pid_reuse" \
    -DV1150_TEST_HELD_PROVIDER="$held_provider" \
    -DV1151_TEST_ENDURANCE="$endurance" \
    $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-oom-requester-live-v1075.c" -o "$work/user/init.s"
"$das" -F -C -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"

build="$work/build/system/boot/pdp6"
port=$((30000 + ($$ % 10000)))
printf 'v1075: building disposable PDP-6 physical-OOM guest (enabled=%s)\n' "$enable"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    KERNEL_DIR="$work/source/system/kernel" PROC_BOOT_USERS=1 \
    BOOT_PROFILE=full BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 \
    SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$((port + 10000))" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        exit 1
    }
sed -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' "$build/boot.ini" \
    > "$build/boot.v1075.tmp"
mv "$build/boot.v1075.tmp" "$build/boot.ini"

if [ "$held_provider" = 1 ]; then
    : > "$work/addresses"
    for name in armed holder_enter holder_lease holder_return release \
                predispatch fatal_busy ordinary_wait spinner real_oom \
                lease_at_oom error; do
        sym="daimos_test_${name}_v1150"
        addr=$(awk -v sym="$sym" '$1 == sym {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1150: missing $sym" >&2; exit 1; }
        printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
    sed -i '/^exit$/d' "$build/boot.ini"
    while read -r name addr; do
        printf 'examine %s\n' "$addr" >> "$build/boot.ini"
    done < "$work/addresses"
    printf 'exit\n' >> "$build/boot.ini"
fi

printf 'v1075: booting patched disposable guest; production unchanged\n'
guest_timeout=90s
if [ "$endurance" = 1 ]; then guest_timeout=360s; fi
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s "$guest_timeout" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -65 "$work/simh.out" >&2
    echo "v1075: SIMH exit $rc" >&2
    exit 1
fi
text=$(tr -d '\r\n' < "$work/simh.out")
prefix=
if [ "$mm_fragment" = 1 ]; then prefix=F; fi
if [ "$mm_slots" = 1 ]; then prefix=M; fi
if [ "$run_cause" = 1 ]; then prefix=${prefix}C; fi
if [ "$bad_run" = 1 ]; then prefix=${prefix}R; fi
if [ "$negatives" = 1 ]; then prefix=${prefix}IL; fi
tail_marker=P
if [ "$pid_reuse" = 1 ]; then tail_marker=QP; fi
if [ "$endurance" = 1 ]; then
    tail_marker=EQP
    if [ "$enable" = 0 ]; then
        # Every one of 32 physical-OOM requesters returns normally and
        # prints D in the production-disabled guest. Do not skip or
        # wildcard those bytes: missing/extra completions must fail.
        returned=$(printf '%032d' 0 | tr 0 D)
        tail_marker=${returned}${tail_marker}
    fi
fi
if [ "$negatives" = 1 ]; then
    case "$text" in
        *"<$prefix"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1110: invalid/address-limit BRK child did not return' >&2
           exit 1 ;;
    esac
fi
if [ "$enable" = 1 ]; then
    case "$text" in
        *"<${prefix}KW${tail_marker}"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1075: missing requester-reclaimed / witness-survived markers' >&2
           exit 1 ;;
    esac
    case "$text" in
        *'!'*) tail -70 "$work/simh.out" >&2
               echo 'v1075: guest assertion failed' >&2; exit 1 ;;
    esac
    echo 'v1075: physical OOM kills requester only; blocked witness runs; MM accounting recovers PASS'
else
    case "$text" in
        *"<${prefix}DNW${tail_marker}"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1075: default-off negative control failed' >&2
           exit 1 ;;
    esac
    echo 'v1075: default-off guest returns -1 rather than terminating requester PASS'
fi
if [ "$negatives" = 1 ]; then
    echo "v1110: invalid-floor and address-limit BRK return -1, preserve BRK and process MM (OOM enabled=$enable) PASS"
fi
if [ "$bad_run" = 1 ]; then
    echo "v1112: invalid child RUN rejected; no retained child slot or process-MM words, requester/witness survive (OOM enabled=$enable) PASS"
fi
if [ "$mm_slots" = 1 ]; then
    echo "v1114: real MM descriptor capacity filled, child RUN refused, original MM released (OOM enabled=$enable) PASS"
fi
if [ "$mm_fragment" = 1 ]; then
    echo "v1115: real physical MM fragmentation, BRK -1 with cause -2, no fatal requester, exact cleanup (OOM enabled=$enable) PASS"
fi
if [ "$run_cause" = 1 ]; then
    echo "v1116: real descriptor-saturated RUN returned -1 with original VM/MM cause -3, no retained child (OOM enabled=$enable) PASS"
fi
if [ "$pid_reuse" = 1 ]; then
    if [ "$endurance" = 1 ]; then
        echo "v1151: 32 additional true physical OOM/reclaim + successful RUN/BRK cycles, 256 PID reuse lifetimes, 512 stale requests and >=1024 actual PI6 ticks with stable MM/slot/backing PASS (OOM enabled=$enable)"
    else
        echo "v1120: 24 numeric PID reuse cycles, alternating exit statuses, stale WAIT/TERM rejection and exact MM/slot cleanup (OOM enabled=$enable) PASS"
    fi
fi
if [ "$held_provider" = 1 ]; then
    python3 - "$work/addresses" "$work/simh.out" "$enable" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    matches = re.findall(r'(?m)^\s*0*' + re.escape(addr.lstrip('0')) +
                         r'\s*:\s*([0-7]+)', text)
    if not matches:
        raise SystemExit('v1150: missing counter ' + name)
    seen[name] = int(matches[-1], 8)

one = ('holder_enter', 'holder_return', 'real_oom')
if any(seen[name] != 1 for name in one) or \
        seen['armed'] != (1 << 36) - 1 or \
        seen['release'] != (1 << 36) - 1:
    raise SystemExit('v1150: incorrect owner/oom counters ' + repr(seen))
if seen['holder_lease'] != (7 << 18) or \
        seen['lease_at_oom'] != (7 << 18) or \
        seen['predispatch'] < 1 or seen['spinner'] < 5 or \
        seen['error'] != 0:
    raise SystemExit('v1150: lease/waiter/spinner/OOM stage invalid: '
                     + repr(seen))
if sys.argv[3] == '1':
    if seen['fatal_busy'] < 2:
        raise SystemExit('v1150: OOM FILE close never retried: '+repr(seen))
elif seen['ordinary_wait'] < 1:
    raise SystemExit('v1150: disabled-OOM FILE close never waited: '
                     +repr(seen))
print('v1150: physical OOM under held in-flight FS lease and real '
      'pre-dispatch waiter, exact owner retry/release, independent '
      'spinner and MM accounting PASS:', seen)
PY
fi
