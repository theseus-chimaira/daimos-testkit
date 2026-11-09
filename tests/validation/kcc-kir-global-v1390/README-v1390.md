# KCC native multi-function KIR1 acceptance gate v1390

This is a **strict regression**, not a successful compiler test at the
v1373 baseline.  It requires zero exit status for all five compiler stages
and exact guest `CMP` equality between native and hosted assembly for the
multi-function C89 fixture.  An existing v1378 inspection printed the exit
status but only looked for the status *label*, so it incorrectly reported
five PASS cases when KCC returned 1 and both KGEN invocations returned 126.

The accepted v1373 boot, complete 237-file D6FS image, compiler executables,
and host reference must already exist in `$TMPDIR/kcc-native-refresh-v1373`.
The v1373 driver regression remains an independent 9/9 PASS baseline.

Run from the daimos-testkit root:

    DAIMOS_REPO=/path/to/staged/DAIMOS \
      PDP10_PREFIX="$HOME/cross" \
      sh tests/validation/kcc-kir-global-v1390/run-v1390.sh

The script retains all logs and isolated mutable disk copies under
`$TMPDIR/kcc-kir-global-v1390`. It refuses to overwrite previous evidence
and never installs a native compiler or modifies the production root.

Expected result against v1373: FAIL.  The multi-function compiler reports
`gaddress: bad Sclass 0` and exits 1, while standalone optimized and `-N`
KGEN may UUO and exit 126.  A zero exit alone is insufficient: the native
output must also match the host reference word-for-word.  Only a real fix
that passes all these gates can turn v1390 green.

The preceding v1383-v1388 isolated probes showed that identifier `first`
was reconstructed as class 17 with flags 010003 and later changed to class
0 at the same symbol pointer.  Adding diagnostic calls altered the failure
and permitted one successful compiler exit, but the generated assembly
still differed from the host at word 69.  Those traces are diagnostic only.
