#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
tag=daimos-exec-abi-v1
sh="$DAIMOS_REPO/system/kernel/proc/syscall.h"
sd="$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s"
dh="$DAIMOS_REPO/userland/libc/dsys.h"
ss="$DAIMOS_REPO/userland/libc/syscall.s"
ex="$DAIMOS_REPO/system/kernel/proc/exec.c"

# EXEC is an extension of UUO 077 so the already-full monitor UUO bank does not
# grow another ABI.  Successful EXEC must reset the saved user context in the
# existing u-area rather than returning to the caller's old image.
grep -q '#define SYS_EXT_EXEC[[:space:]]*022U' "$sh" || {
        echo "$tag: SYS_EXT_EXEC ABI missing" >&2; exit 1;
}
grep -q 'int dsys_exec(struct sys_exec_v1 \*args);' "$dh" || {
        echo "$tag: dsys_exec declaration missing" >&2; exit 1;
}
grep -q '^dsys_exec:' "$ss" || {
        echo "$tag: dsys_exec veneer missing" >&2; exit 1;
}
grep -q 'native_sys_exec,,pclk_time36' "$sd" || {
        echo "$tag: EXEC not dispatched by UUO 077" >&2; exit 1;
}
grep -q 'exec_replace_current' "$ex" || {
        echo "$tag: current-image replacement implementation missing" >&2; exit 1;
}

printf '%s\n' "$tag: PASS (EXEC ABI and current-image replacement plumbing)"
