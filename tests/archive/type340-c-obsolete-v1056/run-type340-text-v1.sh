#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
DAIMOS_REPO=${DAIMOS_REPO:-../DAIMOS}
CC=${CC:-cc}
work="$TMPDIR/pdp10-testkit-type340-text-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$CC" -std=c99 -Wall -Wextra -Werror \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    tests/validation/pdp10-migrated-v1/type340-text-v1.c -o "$work/type340-text-v1"
"$work/type340-text-v1"

grep -Eq '^#define[[:space:]]+DPY_TEXT_ROW_WORDS[[:space:]]+14U$' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_text.c" || {
        echo 'type340-text-v1: logical row is not 14 packed SIXBIT words' >&2
        exit 1
}

# The large text/cache store must remain an MM allocation, never fixed MRES
# BSS.  This is also the permanent-size accounting contract.
grep -q 'MM_TYPE_KERNEL_DYNAMIC' "$DAIMOS_REPO/system/kernel/drivers/dpy_text.c"
grep -Eq "dpy\)[[:space:]]+echo 'dpy_io dpy_text'" \
    "$DAIMOS_REPO/system/boot/pdp6/image/report-permanent.sh" || {
        echo 'type340-text-v1: permanent-size omits resident dpy_text code' >&2
        exit 1
}
if grep -Eq '\.block[[:space:]]+(03726|2006)' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"; then
        echo 'type340-text-v1: display text buffer leaked into MRES BSS' >&2
        exit 1
fi
grep -Eq '^[[:space:]]*datao[[:space:]]+0130,1' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" || {
        echo 'type340-text-v1: retained refresh has no Type-344 DATAO path' >&2
        exit 1
}
if grep -Eq '^[[:space:]]*blko[[:space:]]+0130' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"; then
        echo 'type340-text-v1: Type-344 refresh incorrectly uses BLKO' >&2
        exit 1
fi
awk '
    /^dpy_refresh_banner:/ { in_banner=1 }
    in_banner && /^dpy_refresh_start_send:/ { exit }
    in_banner { print }
' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" |
    grep -Eq 'movei[[:space:]]+1,DPY_TEXT_ROWS' || {
        echo 'type340-text-v1: banner/text transition sentinel missing' >&2
        exit 1
}
awk '
    /^dpy_pi_handler:/ { in_handler=1 }
    /^dpy_clock_handler:/ { exit }
    in_handler { print }
' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" > "$work/dpy-handler.s"
grep -Eq '^dpy_pi_refresh_complete:' "$work/dpy-handler.s" || {
        echo 'type340-text-v1: retained frame has no completion state' >&2
        exit 1
}
awk '
    /^dpy_pi_refresh_complete:/ { in_done=1 }
    in_done { print }
' "$work/dpy-handler.s" |
    grep -Eq 'setzm[[:space:]]+dpy_pending' || {
        echo 'type340-text-v1: frame completion does not release DPY ownership' >&2
        exit 1
}
if awk '
    /^dpy_pi_handler:/ { in_handler=1 }
    /^dpy_pi_refresh_complete:/ { exit }
    in_handler { print }
' "$work/dpy-handler.s" |
    grep -Eq 'setzm[[:space:]]+dpy_pending'; then
        echo 'type340-text-v1: DPY ownership released between frame words' >&2
        exit 1
fi
for label in proc_sched_pi_resched proc_sched_timer_done; do
    awk -v label="$label" '
        $0 ~ "^" label ":" { in_path=1 }
        in_path && /^[_A-Za-z][_A-Za-z0-9]*:/ && $0 !~ "^" label ":" { exit }
        in_path { print }
    ' "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" |
        grep -Eq 'trne[[:space:]]+1,000400' || {
            echo "type340-text-v1: $label can switch while PI7 is held" >&2
            exit 1
    }
done
grep -Eq '^clk_pi_post_handler:' \
    "$DAIMOS_REPO/system/kernel/drivers/clk_io.s" || {
        echo 'type340-text-v1: CLK post-service hook missing' >&2
        exit 1
}
grep -q 'clk_pi_post_handler_addr' \
    "$DAIMOS_REPO/system/kernel/modules/module_minit.c" || {
        echo 'type340-text-v1: DPY does not patch the CLK post-service hook' >&2
        exit 1
}
if grep -q 'module_pi_replace(CLK_NATIVE_PI_LEVEL' \
    "$DAIMOS_REPO/system/kernel/modules/module_minit.c"; then
        echo 'type340-text-v1: DPY still replaces the live PI6 handler' >&2
        exit 1
fi
for label in proc_sched_pi_resched proc_sched_tick_idle_check; do
    sed -n "/^$label:/,/^proc_/p" \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" |
        grep -q 'hrrz[[:space:]]\+1,pdp10_pi_level6' || {
            echo "type340-text-v1: $label does not inspect saved PI6 PC" >&2
            exit 1
    }
    sed -n "/^$label:/,/^proc_/p" \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" |
        grep -q 'caige[[:space:]]\+1,proc_idle_loop' || {
            echo "type340-text-v1: $label does not reject pre-idle slot-0 PC" >&2
            exit 1
    }
    sed -n "/^$label:/,/^proc_/p" \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" |
        grep -q 'cail[[:space:]]\+1,proc_idle_loop_end' || {
            echo "type340-text-v1: $label does not reject post-idle slot-0 PC" >&2
            exit 1
    }
done
awk '
    /^dpy_clock_handler:/ { in_hook=1 }
    /^dpy_refresh_start:/ { exit }
    in_hook { print }
' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" |
    grep -Eq 'pushj[[:space:]]+017' && {
        echo 'type340-text-v1: DPY PI6 post-hook uses AC17/PUSHJ' >&2
        exit 1
}
for stub in dtc_minit mtc_minit dsk_minit; do
    grep -Eq "^$stub:" "$DAIMOS_REPO/system/kernel/modules/module_io.s" || {
        echo "type340-text-v1: live $stub missing from module_io.s" >&2
        exit 1
    }
    if grep -Eq "^$stub:" "$DAIMOS_REPO/system/kernel/modules/module_table.s"; then
        echo "type340-text-v1: $stub remains in reclaimed MINIT-table prefix" >&2
        exit 1
    fi
done
grep -Eq '^#define[[:space:]]+MONITORFS_DEV_TTYDPY0[[:space:]]+19U$' \
    "$DAIMOS_REPO/system/kernel/fs/monitorfs.h" || {
        echo 'type340-text-v1: TTYDPY0 MonitorFS id missing' >&2
        exit 1
}
grep -Eq '^tty_ttydpy_getchar:' \
    "$DAIMOS_REPO/system/kernel/drivers/tty_io.s" || {
        echo 'type340-text-v1: TTYDPY0 CTY input wrapper missing' >&2
        exit 1
}
grep -Eq '^tty_ttydpy_putchar:' \
    "$DAIMOS_REPO/system/kernel/drivers/tty_io.s" || {
        echo 'type340-text-v1: TTYDPY0 DPY output wrapper missing' >&2
        exit 1
}
grep -Eq '^dpy_write_words:' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" || {
        echo 'type340-text-v1: raw DPY word writer missing' >&2
        exit 1
}
awk '
    /^dpy_write_words:/ { in_raw=1 }
    /^dpy_write_words_zero:/ { print; exit }
    in_raw { print }
' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" |
    grep -Eq 'cono[[:space:]]+0130,000107' || {
        echo 'type340-text-v1: raw DPY frame does not reset Type 340' >&2
        exit 1
}
grep -q 'dpy_raw_hold' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" || {
        echo 'type340-text-v1: raw DPY lease missing' >&2
        exit 1
}
grep -q '020002000010.*DPY0' \
    "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" || {
        echo 'type340-text-v1: /DEV/DPY0 WRITE_WORDS dispatch missing' >&2
        exit 1
}
grep -q 'CMD_PROGRAM_DPYVIEW' "$DAIMOS_REPO/userland/exec/cmd.h" || {
        echo 'type340-text-v1: DPYVIEW userspace command missing' >&2
        exit 1
}
grep -q 'dsys_write_words(dpy, dpyview_words, used)' \
    "$DAIMOS_REPO/userland/exec/commands.c" || {
        echo 'type340-text-v1: DPYVIEW does not use /DEV/DPY0 word writes' >&2
        exit 1
}
grep -q '\[020002000023\].*TTYDPY0' \
    "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" || {
        echo 'type340-text-v1: TTYDPY0 is not recognized as controlling TTY0' >&2
        exit 1
}
grep -q 'MFSDEV_PUBLISH(MONITORFS_DEV_TTYDPY0, "TTYDPY")' \
    "$DAIMOS_REPO/system/kernel/modules/module_minit.c" || {
        echo 'type340-text-v1: TTYDPY0 namespace publication missing' >&2
        exit 1
}
if awk '
    /^dpy_putchar:/ { in_putchar=1 }
    in_putchar && /^dpy_text_setup_words:/ { exit }
    in_putchar { print }
' "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" |
    grep -Eq 'datao[[:space:]]+0130'; then
        echo 'type340-text-v1: terminal putchar performs DPY DATAO' >&2
        exit 1
fi

printf '%s\n' 'type340-text-v1: permanent-buffer policy PASS'
printf '%s\n' 'type340-text-v1: DATAO refresh policy PASS'
printf '%s\n' 'type340-text-v1: banner/text transition policy PASS'
printf '%s\n' 'type340-text-v1: frame-ownership policy PASS'
printf '%s\n' 'type340-text-v1: nested-PI scheduler policy PASS'
printf '%s\n' 'type340-text-v1: bootstrap slot-0 scheduler policy PASS'
printf '%s\n' 'type340-text-v1: stackless PI6 hook policy PASS'
printf '%s\n' 'type340-text-v1: MINIT stub lifetime policy PASS'
printf '%s\n' 'type340-text-v1: TTYDPY0 composite endpoint policy PASS'
printf '%s\n' 'type340-text-v1: userspace raw DPY viewer policy PASS'
