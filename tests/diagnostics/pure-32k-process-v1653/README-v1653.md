# P1-E v1653: original 32K KINIT ON/OFF capacity refusal

Date: 2026-11-17. Matched original source-linked
32K lowmem KINIT linker/safety refusal PASS.
This is NOT a physical 32K boot or process-lifecycle PASS.

## Original builds

The C89 test-v1653.c user DXR2 compiles successfully
and contains a self-RUN child, initialized private-data
check, exact EXIT-057/WAIT and parent normal exit.
It was NOT executed on the 32K PDP-6: the original
KINIT image safety gate rejected BOTH original
source-matched configurations before generating boot
media. The build is original lowmem GCC with
BOOT_CORE_WORDS=0100000, SIMH_CPU_KWORDS=32,
ROOT=tape, BOOT=dtc, TSFS_ROOT_MEMBERS=3,
TSFS_INPLACE_BOOT=1 and no auxiliary backing.

| Configuration | KINIT end octal | Above 32K core (words) | Above stack-safe limit |
| --- | ---: | ---: | ---: |
| PURE OFF | 110052 | 4,138 | 4,394 |
| PURE ON | 113621 | 6,033 | 6,289 |

The original full physical 32K limit is 100000 octal.
The original required KINIT bootstrap stack reserve is
0400 octal (256 decimal words); its safe image end
is therefore 077400. The original mkimage shell tool
rejects both link outputs before constructing media.
The PURE MRES opt-in transient KINIT increase is
03547 octal, exactly 1,895 decimal words. However,
PURE OFF is already too large by 4,394 decimal
words against the stack-safe limit. This is not a
PURE algorithm bug or an assembler/compiler failure.

The original source-linked KCORE maps and permanent
KCORE streams are byte-identical across PURE ON/OFF;
both have permanent KCORE end 024253 octal. The
PURE ON map contains the correct removable package,
while PURE OFF does not. The original MRES package
links are otherwise present. Do not reduce the
bootstrap stack reserve or remove needed storage
modules merely to force 32K success.

## Audit reproduction

Build the original 32K PURE ON image using
run-v1653.sh; it is EXPECTED to exit unsuccessfully
at the original mkimage gate while preserving the
build directory and safety diagnostics.

Build the corresponding identical 32K PURE OFF
KINIT using the same source/user DXR and same make
variables, changing only DAIMOS_PURE_MRES_ENABLED=0
and its versioned BUILD directory.

Set PURE_32K_ON_V1653 and PURE_32K_OFF_V1653
to the two original build root paths and run:

    sh tests/diagnostics/pure-32k-process-v1653/check-capacity-v1653.sh

The pass oracle compares byte-identical original
KCORE streams, KINIT maps, exact module selection
and actual host mkimage error messages. Three
independent false witness inputs are rejected:
forged KINIT end, forged success in the original
log, and altered KCORE stream.

## Scope and next architectural gate

This is **successful negative safety acceptance**,
not boot completion. The real 32K bootstrap remains
blocked even with PURE OFF. Completing 32K requires
a genuine lower transient KINIT footprint or staged
removable-package installation, preserving every
required device/source service and the bootstrap
stack, followed by new physical 32K boot/RAW tests.

P1-E remains OPEN; PURE default OFF and strict 32K
whole-KCORE optimization HOLD.
