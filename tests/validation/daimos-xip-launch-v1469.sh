#!/bin/sh
# Full PDP-6 KCC disk-root boot: privileged, pinned raw MEMFS XIP RUN/EXEC.
set -eu
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${TMPDIR:?set TMPDIR}"

tag=daimos-xip-launch-v1469
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="${XIP_V1469_WORK:-$TMPDIR/$tag-$$}"
obj="$work/obj"
build="$work/build"
mkdir -p "$obj"
trap 'if [ "${XIP_V1469_KEEP:-0}" != 1 ]; then rm -rf "$work"; else printf "XIP evidence: %s\n" "$work"; fi' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"

"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c89 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$obj/u.s"
"$das" -F -C -O "$obj/u.dobj" "$obj/u.s"
"$cc" -std=c89 -Os $incs -S "$self/$tag.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
    "$obj/crt0.dobj" "$obj/syscall.dobj" "$obj/u.dobj" \
    "$obj/test.dobj" "$libgcc"

# D6FS_EXTRA_ARGS is a command-line list, not a Makefile file dependency.
# A retained diagnostic workspace must always carry the freshly linked
# XIP probe, never a stale earlier DXR in its already-populated DSK media.
if [ -n "${XIP_V1469_WORK:-}" ]; then
    rm -f "$build/system/boot/pdp6/disk/dsk0.dsk" \
        "$build/system/boot/pdp6/disk/dsk1.dsk" \
        "$build/system/boot/pdp6/disk/dsk2.dsk" \
        "$build/system/boot/pdp6/disk/dsk3.dsk"
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/pty-run" \
    "$self/../../tools/pty-run-v1.c"
cat > "$work/probes.txt" <<'PROBES'
probe real-root-xip-run-exec
command /CONFIG/XIP1469.TEST; ECHO STATUS:$?
contains XIP-RUN-PASS
contains STATUS:0
not_contains XIP-FAIL-
end
probe orderly-halt
command HALT
terminal eof
end
PROBES

host_tools="${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin}"
# v1470: memory-specific full-profile XIP acceptance. MEMFS is not
# available on the lowmem profile, so 128K/192K/256K runs use the same
# full resident module selection and the physical core-size-specific image.
xip_boot_core_words=${XIP_V1470_BOOT_CORE_WORDS:-01000000}
xip_simh_cpu_kwords=${XIP_V1470_SIMH_CPU_KWORDS:-256}
PATH="$host_tools:$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    HOST_TOOLS="$host_tools" DAS_REPO="${DAS_REPO:-$DAIMOS_REPO/../das}" \
    KCC_REPO="${KCC_REPO:-$DAIMOS_REPO/../kcc}" \
    BOOT_PROFILE=full COMPILER=kcc \
    BOOT_CORE_WORDS="$xip_boot_core_words" \
    SIMH_CPU_KWORDS="$xip_simh_cpu_kwords" \
    BOOT=dsk ROOT=disk ROOTSET=1 \
    D6FS_EXTRA_ARGS="-f /CONFIG/XIP1469.TEST:$obj/test.dxr:555:dxr" \
    > "$work/image-build.log" 2>&1 || {
        tail -65 "$work/image-build.log" >&2
        printf 'XIP image build failure; evidence: %s\n' "$work" >&2
        exit 1
    }

"$self/../../tools/daimos-simh-harness-v6.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$work/pty-run" --login ROOT --probes "$work/probes.txt" \
    --work-dir "$work/run" --boot-timeout 60 --timeout 90

log="$work/run/simh.log"
# v1470: simulator configuration alone does not prove actual physical
# memory. Require the KINIT-detected installed size in the guest transcript
# as well as the live MEMFS mount and the full XIP lifecycle probe above.
if ! grep -Eq "^MEM[[:space:]]+$xip_simh_cpu_kwords K" "$log" ||
    ! grep -Eq '^MEMFS[[:space:]]+LOADED' "$log"; then
    echo "FAIL: guest did not detect ${xip_simh_cpu_kwords}K and load MEMFS" >&2
    tail -45 "$log" >&2
    exit 1
fi

printf '%s\n' 'PASS v1469: 3 serial + 3 queued XIP RUN/WAIT, malformed/nonroot/argc refusal, EXEC rollback and commit'
