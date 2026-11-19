# v1620: physical RAW PURE MM commit, unpin and scheduler wake

Status: native 48K PDP-6, genuine opt-in PURE DXR2 on TSFS/no-AUX.
No production code, process state, MM format or KCORE words changed.

All runners use the preserved v1618 full TSFS build directory via
PURE_BRK_BUILD_V1615. The historical version of that environment
variable is reused for compatibility with the source-mapped v1615
physical replay; it points at the ORIGINAL, unmodified v1618 image.
The replay clones each DTC media member and removes AUX attachments.

## Original source and physical module identity

The replay reads the actual linked pure-mres-v1612.map and decoded
pure-mres-v1612.dxr. Offset 002563 is the original v1384 release
instruction MOVEI 0,1; offset 002565 is original commit MOVEI 0,2.
The previously physically verified PURE MRES base 032027 yields:

    034612  mm_pure_release_prefix_v1384
    034614  mm_pure_commit_prefix_v1384

After the final 020000 BRK pressure request marker, stop-v1620.sh
registers both original CPU breakpoints and continues the PDP-6.
The real machine hits COMMIT 034614. At entry, slot 0 is current,
the scheduler requests slot 2, and the original call ACs are:

    AC1  116000   original physical APR base
    AC2  000002   owner slot
    AC3  001000   immutable PURE prefix words
    AC4  010000   complete process APR words

MM extent index 13 (physical descriptor word 024307) contains
000014000002: PACKED_PROCESS, pin 1, owner 2. The extent spans
116000..126000. The other three sleeping RAW owners (5, 4, 3)
still own their unpinned 007000-word suffixes.

## Original, unmodified MM writes

follow-v1620.sh stops at COMMIT, then watches two actual writes
to memory word 024307. These are source-authentic PDP-6 write
breakpoints (-W), not separate static snapshots:

    COMMIT entry       000014000002   PACKED,   one pin
    PC 034765          000011000002   PROCESS,  one pin
    PC 002467          000001000002   PROCESS, zero pins

The original commit therefore executes, preserves the physical
APR position and releases the pin. This does not create a second
copy of the mutable suffix.

## Source-authentic scheduler publication

schedule-v1620.sh follows both MM writes and then watches the
original scheduler cursor 024235 and current-slot word 024233.
The real CPU records:

    PC 032477  proc_sched_cursor = 001002  (READY_ONCE | slot 2)
    PC 016770  proc_current_slot = 000002

The owner remains unpinned PROCESS at both scheduler stops.
This establishes the chain from completed VFS prefix loader
through MM retype and unpin to scheduler one-shot publication
and selection. It does not, merely from this breakpoint,
establish return to user mode, successful PIPE/WAIT/EXIT,
immutable backing lifetime, or positive net RAM benefit.

## Read-only audits and deliberate unsafe mutations

run-audit-v1620.sh checks the exact linked PURE DXR instructions,
the live commit ACs, slot ownership and the pre-commit physical
extent layout. It rejects deliberate mutations changing the
commit owner or removing the pre-commit pin.

run-follow-audit-v1620.sh checks the three actual MM states,
optionally also the READY_ONCE and current-slot writes. It
rejects a forged MM trace in which the final pin remains set.
With scheduler mode selected it additionally rejects both a
wrong READY_ONCE cursor and a wrong current-slot publication.

Example with previously preserved physical trace files:

    PURE_BRK_BUILD_V1615=/path/to/48k/build \
    PURE_COMMIT_TRACE_V1620=/path/to/commit/trace.clean \
        sh run-audit-v1620.sh

    PURE_FOLLOW_TRACE_V1620=/path/to/follow/trace.clean \
    PURE_FOLLOW_MODE_V1620=mm sh run-follow-audit-v1620.sh

    PURE_FOLLOW_TRACE_V1620=/path/to/schedule/trace.clean \
    PURE_FOLLOW_MODE_V1620=scheduler sh run-follow-audit-v1620.sh

No production kernel/PURE MRES code was changed. The optional
DAIMOS_PURE_MRES_ENABLED build flag stays zero by default.
The next physical acceptance gate is a real process user-mode
resume, successful PIPE/WAIT/EXIT, source lifetime and exact
physical peak/net RAM measurements on a fitting pressure case.
