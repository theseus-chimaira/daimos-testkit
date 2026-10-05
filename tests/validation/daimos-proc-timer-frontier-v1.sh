#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-proc-timer-frontier-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
src="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"

cat > "$work/timer.s" <<'ASM'
        .equ PROC_WORDS,3
        .equ PROC_STATE_LH_MASK,0700000
        .equ PROC_STATE_RUN,0200000
        .equ PROC_WAIT_LH_MASK,060000
        .equ PROC_CPU_SLEEP_LH_MASK,017700
        .equ PROC_TIMER_ACTIVE_LH,0400000
        .equ PROC_TIMER_DUE_LH,0200000
        .equ PROC_TIMER_TAG_RH,0400000
        .equ PROC_TIMER_CLOCK_MASK,0377777

        .text
ASM

# Exercise the production bodies themselves, not a reimplementation.
awk '/^proc_runq_add:$/ {copy=1} /^proc_runq_remove:$/ {copy=0} copy {print}' \
    "$src" >> "$work/timer.s"
awk '/^proc_timer_service:$/ {copy=1} /^proc_idle_loop:$/ {copy=0} copy {print}' \
    "$src" >> "$work/timer.s"

cat >> "$work/timer.s" <<'ASM'
        .text
        .globl main
main:
        movei   1,proc_desc
        movem   1,proc_table

        ; Normal case: frontier 0100 serviced at clock 0102.  Slots 1 and 3
        ; are due; slot 1 wakes, stopped slot 3 only loses its timer wait, and
        ; slot 2 at 0110 becomes the next frontier.
        movei   1,4
        movem   1,proc_high_slot
        setzm   proc_runq_head
        move    1,[0200000,,0100]
        movem   1,proc_timer_next
        movei   1,0102
        movem   1,proc_timer_clock
        move    1,[0320000,,0400100]
        movem   1,proc_desc+5
        move    1,[0320000,,0400110]
        movem   1,proc_desc+010
        move    1,[0620000,,0400101]
        movem   1,proc_desc+013
        pushj   17,proc_timer_service

        move    1,proc_desc+5
        camn    1,[0200000,,0]
        jrst    timer_n1
        movei   1,1
        popj    17,
timer_n1:
        move    1,proc_desc+010
        camn    1,[0320000,,0400110]
        jrst    timer_n2
        movei   1,2
        popj    17,
timer_n2:
        move    1,proc_desc+013
        camn    1,[0600000,,0]
        jrst    timer_n3
        movei   1,3
        popj    17,
timer_n3:
        move    1,proc_timer_next
        camn    1,[0400000,,0110]
        jrst    timer_n4
        movei   1,4
        popj    17,
timer_n4:
        move    1,proc_runq_head
        caie    1,1
        jrst    timer_fail5

        ; Wrap case: frontier 0377776 and clock 1 means three elapsed ticks.
        ; Deadlines 0377777, 0 and 1 are due; deadline 2 remains future.
        movei   1,5
        movem   1,proc_high_slot
        setzm   proc_runq_head
        move    1,[0200000,,0377776]
        movem   1,proc_timer_next
        movei   1,1
        movem   1,proc_timer_clock
        move    1,[0320000,,0777777]
        movem   1,proc_desc+5
        move    1,[0320000,,0400000]
        movem   1,proc_desc+010
        move    1,[0620000,,0400001]
        movem   1,proc_desc+013
        move    1,[0320000,,0400002]
        movem   1,proc_desc+016
        pushj   17,proc_timer_service

        move    1,proc_desc+5
        camn    1,[0200000,,0]
        jrst    timer_w1
        movei   1,6
        popj    17,
timer_w1:
        move    1,proc_desc+010
        camn    1,[0200000,,1]
        jrst    timer_w2
        movei   1,7
        popj    17,
timer_w2:
        move    1,proc_desc+013
        camn    1,[0600000,,0]
        jrst    timer_w3
        movei   1,010
        popj    17,
timer_w3:
        move    1,proc_desc+016
        camn    1,[0320000,,0400002]
        jrst    timer_w4
        movei   1,011
        popj    17,
timer_w4:
        move    1,proc_timer_next
        camn    1,[0400000,,2]
        jrst    timer_w5
        movei   1,012
        popj    17,
timer_w5:
        move    1,proc_runq_head
        caie    1,2
        jrst    timer_fail13
        setz    1,
        popj    17,

timer_fail5:
        movei   1,5
        popj    17,
timer_fail13:
        movei   1,013
        popj    17,

        .bss
        .globl __test_exit
__test_exit:
        .block 1
proc_table:
        .block 1
proc_high_slot:
        .block 1
proc_runq_head:
        .block 1
proc_timer_clock:
        .block 1
proc_timer_next:
        .block 1
proc_desc:
        .block 017
ASM

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 1000000 --timeout 20 \
    --workdir "$work/run" --name daimos-proc-timer-frontier-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/timer.s" >/dev/null

printf '%s\n' 'proc-timer-frontier: PASS (due/future, STOP, wraparound, runq chaining)'
