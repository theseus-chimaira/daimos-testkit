# DAIMOS GCC stdio console integration (2026-11-20, v1)

The two DAIMOS-specific tests are owned by this repository.
Generic GCC standard-library buffer-formatting tests belong
in pdp10-testkit.

* daimos-gcc-stdio-console-abi-v1.c/.sh: test GCC-compiled
  printf, vprintf, putchar and puts against a recording
  dsys_writechar implementation. Validate the native GCC varargs
  ABI, archive extraction, output, return counts, and failure
  handling. This test uses a bare-metal PDP10 testkit crt0.
  It is NOT proof that the monitor WRITECHAR syscall works.
* daimos-gcc-stdio-console-guest-v1.c/.sh: link the real DAIMOS
  syscall veneer and both GCC archives, install the resulting
  program in a boot image, and verify the actual console transcript
  and process status through the DAIMOS PTY harness.

The OS-specific archive is libp10stdio-daimos-v1.a and contains
real dsys_writechar calls. The independent portable formatter
is libp10stdio-v2.a; it has no DAIMOS syscall dependency.

## Observed result and open gate

The recording-sink test passes on PDP-6, KA10, KI10 and KS10
under GCC O0 and O2. A separate production-linker check resolves
the expected symbols from both installed GCC archives. These are
DAIMOS backend ABI checks, not real monitor I/O executions.

The first full-guest attempt reached INIT V1 and LOGIN but halted
in boot/root critical I/O before the test program ran. There
is NO accepted real-console PASS yet. The boot error remains
an explicit prerequisite and was not hidden or worked around.

## Opt-in execution

    make test-daimos-gcc-stdio-console-abi-v1
    make test-daimos-gcc-stdio-console-guest-v1

Set PDP10_PREFIX and DAIMOS_REPO as for other DAIMOS tests.
The recording-sink suite also uses the sibling pdp10-testkit
support/crt0-upstream-v1.s fixture; override PDP10_TESTKIT_REPO
if needed. Neither test is included in automatic check or
regression sweeps.

The historical 25-suite NATIVE-TOOLCHAIN-TESTS-v1.tsv registry
remains unchanged. These new tests have separate explicit
Makefile targets, with the real guest acceptance status unresolved.
