# v1621: actual restored user code and fitting-BRK negative control

Status: physical PDP-6 TSFS/no-AUX experiment. The original
P1-E PURE MRES remains opt-in and all production kernel code
is unchanged.

## Actual slot-2 return to user code

continue-v1621.sh replays the original 48K TSFS pressure guest.
It inherits the source-linked v1620 probes of:

* v1384 MM commit at original physical PC 034614;
* physical PACKED pin1 -> PROCESS pin1 -> PROCESS pin0 writes;
* READY_ONCE|2 publication at PC 032477;
* fixed KCORE current-slot 2 publication at PC 016770.

It then clears the last write watchpoint and executes two
bounded real PDP-6 CPU intervals. The physical console
prints a standalone lowercase w AFTER slot 2 was selected
and BEFORE the first CPU interval expires. This is the
unique user C marker in the original booted pressure INIT:
the child returns from dsys_read_words, verifies BOTH
mutable private-data sentinel words and prints w, then
calls dsys_exit with status 057 octal.

run-user-audit-v1621.sh checks the original v1620 physical
MM/scheduler transitions, reads the preserved source
compiled into the guest and the exact /SYSTEM/INIT image
named by the TSFS root manifest, verifies purity=PURE,
and requires the user marker strictly after the slot-2
selection and before the first resumed CPU interval ends.
It rejects test-only mutations that remove the marker
or substitute an unrelated source file.

    PURE_BRK_BUILD_V1615=/path/to/physical/48k/build \
        sh continue-v1621.sh

    PURE_BRK_BUILD_V1615=/path/to/physical/48k/build \
    PURE_USER_TRACE_V1621=/path/to/physical/trace.clean \
    PURE_GUEST_SOURCE_V1621=/path/to/user/init-v1614.c \
    PURE_GUEST_IMAGE_V1621=/path/to/user/init.dxr \
        sh run-user-audit-v1621.sh

An actual child user-mode execution marker is observed,
but this does not by itself prove parent WAIT or all
children's successful exit status.

## Smaller BRK is NOT automatically RAW pressure

fitting-pressure-v1621.sh generates a private source
variant of the original v1614 PIPE/WAIT pressure test.
The only default source change is its final BRK target
from 022000 to 016000 octal words. Optionally set
PURE_FIT_CHILDREN_V1621=6 to test whether six
simultaneous children can reach sleeping state.

The original four-child 48K test was executed against
a newly built TSFS/no-AUX guest. BRK 010000 -> 016000
succeeded, but process_words grew by exactly 006000
octal words (052450 -> 060450). The original guest
correctly printed !R and refused to credit this as
RAW reclaim; the four blocked children printed w
only after the parent failure path released the PIPE.
The native test therefore exits NONZERO. This is a
negative control, not an accepted complete scenario.

The separately rebuilt six-child 48K no-AUX guest
printed five successful child 'a' markers and then
!c before ever reaching its BRK marker. The
original source uses the same !c failure for either
an invalid RUN pid or a spawned child that does
not reach PROC_SLEEP within the bounded polling
loop. The evidence does NOT distinguish the two
causes, and does not establish an MM or compiler
bug. This six-child fixture also fails as a
pressure-acceptance case. Its exact early refusal
is accepted by the negative-control auditor.

    DAIMOS_REPO=/path/to/DAIMOS \
        sh fitting-pressure-v1621.sh

For the preserved four- or six-child trace:

    PURE_FIT_SOURCE_V1621=/path/to/user/init-v1614.c \
    PURE_FIT_TRACE_V1621=/path/to/console.clean \
        sh run-fit-audit-v1621.sh

For four children, the source-linked negative-control
auditor requires the real 48K console, exact BRK and
process-word counters, original !R refusal and four
child exit markers. It rejects an altered physical
process-growth number. For six children, it requires
the first five successful child markers followed
by the original !c and absence of a BRK attempt;
it rejects a mutated refusal marker.

The physical peak/net memory gate is NOT accepted. At
least four simultaneous omitted 001000-word PURE
prefixes are needed just to exceed the original
1758-decimal-word resident GCC PURE MRES cost:
4 * 512 - 1758 = 290 decimal words before other costs.
Do not infer savings from logical MEMINFO fields alone.

All source code, test scripts and diagnostics remain in
daimos-testkit. No change to default PURE OFF, fixed
KCORE, MRES image, process MM or kernel scheduler.
