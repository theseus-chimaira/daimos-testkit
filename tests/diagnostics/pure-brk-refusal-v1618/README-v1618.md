# v1618: 120-second DECtape search and physical timer progression

The 45-second Type-551 RBN-search timeout is too short
when tape reversal or rewind takes a full minute.
The production driver now allows 120 seconds (016040
octal ticks at 60 Hz), including a full minute of headroom.
The Type-516 rewind/spacing timeout remains 15 minutes.
The successful RBN match does not wait for this timeout.

The accepted historical v1617 Type-551 image had 45-second
reset operands at linked offsets 000343 and 000405.
The v1618 linked image changes only those two instruction
operands to 120 seconds, with the original MRES image,
BSS and relocation counts unchanged. The source-authentic
validation script is:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/daimos-dtc-search-timeout-v1618.sh

The timed 48K physical PDP-6 replay clones the TSFS
tapes, omits AUXST1 disk/drum attachments, and stops
in the original Type-551 wait only after the final
pressure request marker. Then it removes the CPU
breakpoint and executes bounded simulated time:

    PURE_BRK_BUILD_V1615=/path/to/v1618/build \
        sh tests/diagnostics/pure-brk-refusal-v1618/tape-timer-v1618.sh

This name reuses the earlier replay's build-directory
environment variable; it can point at the v1618
new-image build. The new run-timer-audit-v1618.sh
tests actual physical clock/mark progress against
the linked 120-second image and rejects a test-only
obsolete 45-second countdown mutation.

The physical experiment is an I/O-timer diagnostic,
not an assertion that a process successfully completed
PURE-prefix restoration. The remaining gates are
bounded tape RBN/data transfer, exact VFS prefix commit
or rollback, slot-0 READY_ONCE, PIPE/WAIT/EXIT, and
positive net/peak physical RAM measurements.
