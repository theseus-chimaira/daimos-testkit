# KCC GCCABI outgoing stack argument lifetime v1407

The v1406 native DAS refactor exposed a KCC code-generation defect:
when a five-argument call used `hash(name)` for a register argument,
the direct GCC ABI path pushed the fifth outgoing argument between
spills of incoming register values.  Restoring those older spills
reduced SP below the outgoing argument before `PUSHJ`.  The callee
then read stale stack memory as its fifth argument.

The v1407 compiler fix reserves the complete outgoing stack-argument
area once, before any argument evaluation can spill registers.  Each
stack-only argument is stored into its reserved slot at a displacement
recomputed after expression evaluation.  Call temporaries may then
be spilled/unspilled without consuming an outgoing argument.  No
additional stack words or heap allocations are introduced.

The C89 test includes five- and six-argument arithmetic calls, plus
the exact pointer/unsigned-long/void-call shape which triggered the
native DAS bug.  Both historical and corrected host KCC builds
compile the fixture to relocatable DOBJ1.  Host DLINK links them
with identical accepted CRT0/syscall inputs.  Both resulting DXRs
are executed under the same PDP-6 SIMH guest with cloned media:
the historical KCC image exits with status 5 (corrupted fifth
argument), while the corrected image exits with status 7.

The runner builds the v1407 host KCC from the supplied staged source
and a full grouped D6FS image.  It does not modify installed tools:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
DAIMOS_REPO=/path/to/DAIMOS \
KCC_REPO=/path/to/kcc-v1407 \
sh tests/validation/kcc-gccabi-stack-nested-v1407/run-v1407.sh
```

The v1410 extension additionally compiles the corrected fixture with
KCC's actual `-n` no-optimization switch, links a third DXR, and executes it in the same isolated PDP-6
guest.  All three checks must pass: old optimized KCC exits 5, corrected
optimized KCC exits 7, and corrected non-optimized KCC exits 7.

This is compiler correctness acceptance for the proven reproducer.
The separate v1401 native KCC phase suite and v1402 native DAS
compatibility suite must also pass when built using the corrected
host compiler.  Native DOBJ1 output remains a separate unfinished
assembler stage.  KCORE size-only optimization is deferred to the
final KCORE development stage.
