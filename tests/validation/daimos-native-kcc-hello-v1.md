# DAIMOS native KCC Hello world smoke test v1

`daimos-native-kcc-hello-v1.sh` is an opt-in, isolated native compiler
smoke test. It stages this small C program into the DAIMOS boot image:

```c
extern int puts(const char *);
int main(void)
{
    return puts("Hello, world!") < 0;
}
```

The test boots DAIMOS, runs the installed native KCC driver with `-S`,
requires `STATUS:0`, and checks that the assembly file exists. It does
not link the program, execute it, or verify terminal output; those are
separate acceptance stages. A successful run demonstrates the KCPP,
KPARSE, KGEN and KOPT native compile path for this small input only.

Use `DAIMOS_REPO`, `KCC_REPO`, `DAS_REPO`, `DAIMOS_TOOLS_REPO`,
`PDP10_PREFIX`, and `TMPDIR` as for the existing native compile test.
For diagnosis, set `KEEP_WORK=1` to preserve build and SIMH logs.
Run with a ten-minute external timeout initially:

```
timeout 600 sh tests/validation/daimos-native-kcc-hello-v1.sh
```

The full self-hosting `CC.C` build failure (`gaddress: bad Sclass 0`)
is deferred as a compiler bug, not considered a Hello world regression.
The test is deliberately not included in the default regression matrix.

## Initial execution result (2026-11-19)

Executed the Hello-world source against the actual native KCC guest
with an outer 600-second limit and `KEEP_WORK=1`. The boot-image build
completed and the guest invoked KCC. The last captured output was
`KCC: KCC000005`; no `STATUS:0` or assembly-file oracle was reached.
The external timeout returned exit 124 and the harness reported
`SIMH exited before expected terminal` on forced termination. This
is **INCOMPLETE (timeout)**, not a compiler pass and not proof of a
specific compiler failure. Evidence is retained in
`$TMPDIR/daimos-native-kcc-hello-v1-29860/` (`run/results.tsv`,
`run/output.1`, and `build.log`).

The earlier even smaller `int main(void) { return 0; }` test had the
same final visible `KCC: KCC000005` before its 600-second timeout.
The shared symptom suggests a native KCC pipeline/progress problem,
but the precise cause remains unverified. No compiler source was
modified; self-hosting compiler defect repair remains deferred.
