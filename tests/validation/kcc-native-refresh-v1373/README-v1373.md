# v1373: PDP-6 KCC nested-call register-argument lifetime

Run from `daimos-testkit` with the staged KCC and DAIMOS worktrees:

```
DAIMOS_REPO=/path/to/staged/DAIMOS \
KCC_REPO=/path/to/staged/kcc \
sh tests/validation/kcc-native-refresh-v1373/run-v1373.sh
```

The default repeats the previously accepted full v1371 grouped KCORE
and 237-file distribution cold boot. For an already verified local
v1371 workspace only, set `V1373_REUSE_VERIFIED_V1371=1`. All builds,
media and generated source remain under `$TMPDIR/kcc-native-refresh-v1373`.
The normal KCC bootstrap, production kernel and D6LZ36 images are
never overwritten or installed.

## Root cause and code fix

The native KGEN initially wrote invalid KPCODE2 pseudo-instructions:
`P_CVALUE` (opcode 1) and `P_DFMP` (opcode 15), rather than a simple
`P_MOVEI` return constant. The actual first corruption was upstream
of serialization, at the `newcode()` call itself. An instrumented
native build showed `V1373_NEW type=22 op=1 reg=1` and
`V1373_NEW type=6 op=15 reg=15`, matching the bad records.

In the original host compiler's generated assembly for `code1()`:

    MOVE 1,2
    PUSHJ 17,VRTOREAL
    MOVE 2,1
    JRST CODR1

The first incoming parameter, the pseudo-opcode in AC1, was destroyed
by evaluating `vrtoreal(vr)` in the second argument of `codr1()`.
The third parameter could also be destroyed by the nested call.
This is a general GCC-ABI caller-argument lifetime bug, not an
incorrect `code1()` source declaration or KPCODE reader bug.

The fix in KCC `ccgen2.c:gccabi_direct_reg_args()` snapshots
register-bound incoming arguments into tracked VREGs **before**
evaluating any side-effecting argument. The ordinary nested-call
spill/reload machinery now preserves them. Calls without such
side effects retain their direct zero-copy register fast path.
It changes neither the kernel ABI nor the installed userspace ABI.

The test explicitly compiles KCC's actual `cccode.c` and requires
the return from `vrtoreal` to restore AC1 before `codr1`. It builds
the complete current host KCC from the staged source, not from the
possibly stale installed toolchain; it then cross-compiles the
complete native KCC/KCPP/KPARSE/KGEN/KOPT closure using that host.

## Native PDP-6 tests

Five source-matched compiler DXRs are substituted into the full
grouped D6FS root, without modifying the original Makefile or
the other 237 standard files. The new root passes `d6fsck` CLEAN.
The nine PDP-6 SIMH guest acceptance probes are:

- Native KCC compiles a minimal `return 012345` C89 function.
- Guest `CMP` checks the **exact 36-bit packed ASCII7** output against
  the independently generated host compiler reference.
- Direct native KCPP parses the source into KPT4.
- Direct native KPARSE produces KIR1.
- Direct native KGEN generates the KPCODE2 stream.
- Native HEXDUMP verifies the KPCODE2 stream header.
- Native KOPT decodes it and emits packed assembler output.
- Guest CMP checks KGEN/KOPT replay word-for-word against host KCC.
- A separate host-compiled, linked, uncompressed C89 executable with
  a nested call in the middle argument returns zero after validating
  all three received arguments under actual PDP-6 execution.

All nine probes PASS, including the actual semantic ABI execution.
The native compiler images have no new static BSS versus the earlier
current-source native bootstrap; no permanent KCORE/DAS growth.

## Separate unresolved compiler failures

`abi-nested-call-v1373.c` also provides a larger native multi-function
source fixture. Its host compiler DXR executes correctly, but native
KCC still fails to compile the multi-function source at KGEN with
`gaddress: bad Sclass 0` for a global identifier while reconstructing
the split-phase KIR1 graph. The test file `probes-open-kir-v1373.txt`
reproduces this error independently; **it is not counted as passing
native compilation**. Native KGEN invoked directly with `-N` also
crashes with a UUO and exit status 126. Neither defect was resolved
by the register-lifetime correction, and both are outstanding
high-priority compiler correctness items before full self-hosting.

Do not install this KCC bootstrap over production KCC until these
separate failure paths and wider self-hosting tests are accepted.
