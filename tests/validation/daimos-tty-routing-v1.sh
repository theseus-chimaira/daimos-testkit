#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
tag=daimos-tty-routing-v1
th="$DAIMOS_REPO/system/kernel/drivers/tty.h"
ti="$DAIMOS_REPO/system/kernel/drivers/tty_io.s"
pm="$DAIMOS_REPO/system/kernel/modules/module_minit.c"
ph="$DAIMOS_REPO/system/kernel/proc/proc.h"
ps="$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s"

# Generic terminal input must exist beside generic output.  The syscall layer
# obtains the attached logical TTY from process state and hands it to the TTY
# dispatcher; it must not retain a CTY-only input tail call.
grep -q 'int tty_getchar(unsigned int tty);' "$th" || {
        echo "$tag: tty_getchar API missing" >&2; exit 1;
}
grep -q '^tty_getchar:' "$ti" || {
        echo "$tag: tty_getchar dispatcher missing" >&2; exit 1;
}
for sym in tty_cty_getchar_address tty_dcs_getchar_address tty_ge_getchar_address; do
        grep -q "$sym" "$ti" || {
                echo "$tag: missing $sym" >&2; exit 1;
        }
done
grep -q 'proc_tty_input(unsigned int tty, unsigned int ch)' "$ph" || {
        echo "$tag: proc_tty_input is not logical-TTY aware" >&2; exit 1;
}
grep -q 'TTY_X_GETCHAR' "$pm" || {
        echo "$tag: MINIT does not export generic TTY input" >&2; exit 1;
}
grep -q 'storage_patch_jump(&native_sys_getchar_call' "$pm" || {
        echo "$tag: generic input is not bound into the syscall path" >&2; exit 1;
}
grep -q 'pushj[[:space:]]*17,proc_tty_output' "$ps" || {
        echo "$tag: output fallback is not controlling-TTY aware" >&2; exit 1;
}

printf '%s\n' "$tag: PASS (logical CTY/DCS/GE input and controlling-TTY output routing)"
