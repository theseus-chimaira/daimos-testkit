# K17 processor and hardware read-in probes v1963

Use a fresh 64K KCC LOWMEM hybrid TSFS PDP-6 image as in the v1961
README. These probes do not claim a complete KA10 kernel boot.

    python3 -B probe-v1963.py "$DAIMOS_REPO" "$PDP10_PREFIX" "$TMPDIR/apr-v1963"
    python3 -B readin-v1963.py BUILD "$PDP10_PREFIX" "$TMPDIR/readin-v1963"

The APR fixture extracts actual resident activation and translation
instructions, checks the aligned descriptor expression at first-user
entry, and verifies native register readbacks on PDP-6, KA10 ONESEG
and KA10 TWOSEG. The latter must have no usable high segment.
The paper tape test compares the counted stream against the independent
SIMH relocation stream, rejects missing final JRST and wrapping geometry,
and boots the unchanged DTC Stage1 on KA10 to the KINIT breakpoint.
The KINIT image is still PDP-6-specific and must not be executed on KA10.
