#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-native-tools-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
obj="$work/obj"
pty="$work/pty-run"
probes="$work/probes.txt"

cleanup()
{
        if [ -n "${KEEP_WORK:-}" ]; then
                echo "$tag: preserved work tree: $work" >&2
        else
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$obj"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"

cpp="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core"
cpp="$cpp -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs"
cpp="$cpp -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules"
cpp="$cpp -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage"
cpp="$cpp -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"

# KCC does not accept an arbitrary path as a module name, so compile the tiny
# test from its source directory and direct only the generated assembly into
# the versioned temporary work tree.
( cd "$(dirname "$0")" && \
  "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $cpp \
        -S daimos-native-tools-v1.c -o "$obj/main.s" )
"$PDP10_PREFIX/bin/das" -F -C -O "$obj/main.dobj" "$obj/main.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$obj/crt0.dobj" \
        "$DAIMOS_REPO/userland/libc/crt0.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$obj/syscall.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$obj/syscall-helpers.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
( cd "$DAIMOS_REPO/userland" && \
  "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $cpp \
        -S libc/u.c -o "$obj/u.s" )
"$PDP10_PREFIX/bin/das" -F -C -O "$obj/u.dobj" "$obj/u.s"

cat >"$probes" <<'EOF'
probe du-recursive
setup MKDIR /CONFIG/DUD
setup ECHO ONE > /CONFIG/DUD/A
command DU /CONFIG/DUD
contains /CONFIG/DUD/A
contains /CONFIG/DUD
end

probe du-cleanup
command RM /CONFIG/DUD/A; RMDIR /CONFIG/DUD
end

probe native-objdump
command OBJDUMP -H /CONFIG/MAIN.DOBJ
contains TEXT
contains SYMBOLS
end

probe native-darc
command DARC -O /CONFIG/U.DARC /CONFIG/SYSCALL.DOBJ /CONFIG/SYSH.DOBJ /CONFIG/U.DOBJ
end

probe native-dlink
command DLINK -O /CONFIG/NATIVE.DXR -B 020 /CONFIG/CRT0.DOBJ /CONFIG/MAIN.DOBJ /CONFIG/U.DARC
end

probe native-linked-exec
setup CHMOD 755 /CONFIG/NATIVE.DXR
command /CONFIG/NATIVE.DXR
line ^NATIVE LINK OK$
end
EOF

extra="-f /CONFIG/CRT0.DOBJ:$obj/crt0.dobj:644:binwords"
extra="$extra -f /CONFIG/SYSCALL.DOBJ:$obj/syscall.dobj:644:binwords"
extra="$extra -f /CONFIG/SYSH.DOBJ:$obj/syscall-helpers.dobj:644:binwords"
extra="$extra -f /CONFIG/MAIN.DOBJ:$obj/main.dobj:644:binwords"
extra="$extra -f /CONFIG/U.DOBJ:$obj/u.dobj:644:binwords"

PATH="$PDP10_PREFIX/bin:$PATH" \
        "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" USERLAND_BUILD_ROOT="$build" \
        PDP10_PREFIX="$PDP10_PREFIX" D6FS_EXTRA_ARGS="$extra" >/dev/null

"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" \
        --pty-run "$pty" --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

echo "$tag: PASS (native DARC/DLINK/OBJDUMP link+exec; DU recursive walk)"
