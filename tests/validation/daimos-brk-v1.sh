#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-brk-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
obj="$work/obj"
pty="$work/pty-run"
probes="$work/probes.txt"
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$obj"

kcc="$PDP10_PREFIX/bin/kcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/userland/libc -I$DAIMOS_REPO/userland/exec"
incs="$incs -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$PDP10_PREFIX/include"

"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall-helpers.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
"$das" -F -C -O "$obj/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
for src in stdlib string; do
        (cd "$DAIMOS_REPO/userland/libc" && \
                "$kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs -S \
                "$src.c" -o "$obj/$src.s")
        "$das" -F -C -O "$obj/$src.dobj" "$obj/$src.s"
done
"$das" -F -C -O "$obj/memcpy.dobj" "$DAIMOS_REPO/userland/libc/memcpy.s"
"$das" -F -C -O "$obj/memmove.dobj" "$DAIMOS_REPO/userland/libc/memmove.s"
"$kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs -S "$self/$tag.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
"$dlink" --daimos-uuo-relax -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
        "$obj/crt0.dobj" "$obj/syscall-helpers.dobj" "$obj/syscall.dobj" \
        "$obj/stdlib.dobj" "$obj/string.dobj" "$obj/memcpy.dobj" \
        "$obj/memmove.dobj" "$obj/test.dobj"

cc_host=${HOST_CC:-cc}
"$cc_host" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$self/../../tools/pty-run-v1.c"
cat >"$probes" <<'EOF'
probe brk-runtime-growth
command /CONFIG/BRK.TEST; ECHO STATUS:$?
contains BRK-PASS
contains STATUS:0
end
EOF

extra_make=
test -n "${DAS_REPO-}" && extra_make="$extra_make DAS_REPO=$DAS_REPO"
test -n "${DAIMOS_TOOLS_REPO-}" && extra_make="$extra_make DAIMOS_TOOLS_REPO=$DAIMOS_TOOLS_REPO"
test -n "${KCC_REPO-}" && extra_make="$extra_make KCC_REPO=$KCC_REPO"

# shellcheck disable=SC2086
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
        D6FS_EXTRA_ARGS="-f /CONFIG/BRK.TEST:$obj/test.dxr:555:dxr" \
        $extra_make >/dev/null

"$self/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" \
        --pty-run "$pty" --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (brk/sbrk growth, heap data, and shrink)"
