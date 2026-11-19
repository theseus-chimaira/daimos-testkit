# Native KGEN graph record stack-lifetime regression v1401

This test covers both compiler bugs that prevented full multi-function
KIR1/KPCODE2 use after the v1373 nested-argument ABI correction:

1. The host KCC compiler's loop-induction pointer was invalid across
   function calls.  That bug was fixed in KCC `ccgen1.c` in v1395.
2. Native KGEN nested two 512-word KIR record buffers on its bounded
   PDP-6 startup stack.  The v1401 KIR reader reuses the caller's record
   buffer and copies only the small graph header before reading records.
   This avoids overlapping stack frames without allocating heap memory.

The baseline v1373 and complete grouped v1371 test environments must
exist under `$TMPDIR` (default `$HOME/tmp`).  Run the v1373 validation
first if the baseline is missing.  Then, from daimos-testkit:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
DAIMOS_REPO=/path/to/DAIMOS \
KCC_REPO=/path/to/kcc-v1401 \
sh tests/validation/kcc-kgen-stack-lifetime-v1401/run-v1401.sh
```

The runner builds the staged host KCC and all five native phases from
source and places them in a freshly created `$TMPDIR/kcc-kgen-stack-lifetime-v1401`
tree.  The 237-file grouped D6FS test root is independently built and
checked CLEAN.  Source checkouts, installed native compiler binaries,
and production boot media are not modified by this runner.

The 16 native PDP-6 checks demand actual zero exit status for minimal
and multi-function KCPP, KPARSE, KGEN, KGEN -N, and KOPT, plus exact
host/native packed-assembly comparisons for optimized KGEN replay and
integrated KCC.  A guest UUO, internal error or missing output is a
test failure, not merely a captured diagnostic transcript.

The passing v1401 regression does **not** establish the remaining full
native KCC-to-canonical-SIXBIT-to-DAS/DLINK/RUN acceptance.  Native
self-hosting and production compiler replacement remain gated on those
end-to-end tests and wider source coverage.
