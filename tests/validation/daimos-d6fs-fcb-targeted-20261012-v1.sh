#!/bin/sh
# Repeatable live PDP-6 staged-growth data-write failure acceptance.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-d6fs-fcb-targeted-20261012-v1.XXXXXXXX")
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
repo="$DAIMOS_REPO"
incs="-I$repo/system/kernel/boot -I$repo/system/kernel/core -I$repo/system/kernel/drivers -I$repo/system/kernel/fs -I$repo/system/kernel/mm -I$repo/system/kernel/modules -I$repo/system/kernel/proc -I$repo/system/kernel/storage -I$repo/userland/libc"
"$das" -F -C -O "$work/crt0.dobj" "$repo/userland/libc/crt0.s"
"$das" -F -C -O "$work/syscall.dobj" "$repo/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$repo/userland/libc/u.c" -o "$work/u.s"
"$das" -F -C -O "$work/u.dobj" "$work/u.s"
"$cc" -std=c99 -Os $incs -S "$self/daimos-d6fs-fcb-ambiguous-20261012-v1.c" -o "$work/test.s"
"$das" -F -C -O "$work/test.dobj" "$work/test.s"
"$PDP10_PREFIX/bin/dlink" -b 020 -o "$work/test.dxr" -M "$work/test.map" \
 "$work/crt0.dobj" "$work/syscall.dobj" "$work/u.dobj" "$work/test.dobj" "$($cc -print-libgcc-file-name)"
python3 - "$work/seed.bin" <<'SEED'
import sys
open(sys.argv[1],'wb').write((0o123456701234).to_bytes(8,'little'))
SEED
FAULT_AFTER_WRITE_START=479 FAULT_AFTER_WRITE_END=479 \
 D6FS_EXTRA_ARGS="-f /CONFIG/FAULT.TEST:$work/test.dxr:555:dxr -f /CONFIG/FCBSEED:$work/seed.bin:666:binwords" \
 "$self/daimos-d6fs-fault-link-20261012-v1.sh" > "$work/build-result.txt"
image=$(sed -n 's/^INJECTED_IMAGE=//p' "$work/build-result.txt")
injected=$(sed -n 's/^INJECTED_WORK=//p' "$work/build-result.txt")
test -f "$image"
cat > "$work/probes.txt" <<'PROBES'
probe ambiguous-fcb-return-and-committed-file
command /CONFIG/FAULT.TEST
contains FCBAMBIG-COMMITTED-PASS
not_contains FCBAMBIG-COMMIT-CONTENT-FAIL
not_contains FCBAMBIG-NO-ERROR
end
probe orderly-halt
command HALT
terminal eof
end
PROBES
"$self/../../tools/daimos-simh-harness-v6.sh" \
 --daimos-repo "$repo" --dofile "$image" \
 --pty-run "${PTY_RUN:-$TMPDIR/dsh-history-runtime-20261011-v2/pty-run}" \
 --login ROOT --probes "$work/probes.txt" --work-dir "$work/simh" \
 --boot-timeout 120 --timeout 20
host_tools="${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin}"
"$host_tools/d6fsck" -n 4 -d "$injected/image/system/boot/pdp6/disk"
printf 'daimos-d6fs-fcb-ambiguous-20261012-v1: PASS; artifacts in %s\n' "$work"
