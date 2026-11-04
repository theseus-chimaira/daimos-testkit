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

printf 'v1075: booting patched disposable guest; production unchanged\n'
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s 90s stdbuf -o0 -e0 \
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
if [ "$bad_run" = 1 ]; then prefix=R; fi
if [ "$negatives" = 1 ]; then prefix=${prefix}IL; fi
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
        *"<${prefix}KWP"*'HALT'*) : ;;
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
        *"<${prefix}DNWP"*'HALT'*) : ;;
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
    echo "v1112: invalid child RUN rejected; PID and MM unchanged, requester/witness survive (OOM enabled=$enable) PASS"
fi
