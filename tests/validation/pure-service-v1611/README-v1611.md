# P1-E PDP-6 experimental PURE service v1611

From daimos-testkit root:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-service-v1611/run-v1611.sh

The independent KCC KINIT package-selector regression is:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-service-v1611/boot-mode-v1611.sh

It rebuilds the same KINIT directory in default-OFF,
experimental-ON and default-OFF configurations. The
current v1612 PURE package must appear only in the middle
build, and fixed KCORE bytes must remain identical throughout.
The independent historical v1611 C-policy native test
continues to use the unchanged v1611 source file.

This links the original KCC PDP-6 v1381 zero-copy DROP,
v1384 prefix transaction, v1391 bounded FULL transaction,
the actual MM rebase/claim/commit assembly and two-bit
storage-mode ASM with the proposed v1611 MRES C policy.
The fixture supplies only controlled source loader and
MM compaction responses; it does not replace process,
storage-mode, MM transaction or PI-state publication.

Positive coverage: an excluded inactive SLEEP job
loses only its PURE prefix, leaving exact writable
suffix words and authoritative MM owner; slot-0
RUN restoration succeeds using either the original
prefix or the FULL fallback. No DISK payload is involved.

Negative coverage: a still-advertised BACKSTORE or
missing executable mount refuses DROP; missing mount
and refused FULL loader preserve the complete
unrestored PACKED owner, without READY_ONCE or fatal
TERM. A non-slot-0 RUN restore is separately covered
by the v1610 prefix/FULL tests.

An additional source mutation removes the final
RESIDENT/TRANSITION/VM verification before READY_ONCE.
The actual PDP-6 guest rejects this unsafe shortcut
after refused loading, rather than merely checking
the source text.

The opt-in module is NOT active by default:

    DAIMOS_PURE_MRES_ENABLED=0

Explicit experimental KINIT build uses
`DAIMOS_PURE_MRES_ENABLED=1`. Native test passing
does not replace physical no-AUX PDP-6 boot,
immutable source lifetime, full PI6/EXEC/WAIT/EXIT
acceptance or installed RAM/peak-memory measurements.
The historical v1611 KCC module costs 2275 words and GCC
1864 words. The current v1612 module costs 2196 KCC and
1758 GCC words. Both must be offset by real reclaimed
PURE memory before enabling the feature by default.
