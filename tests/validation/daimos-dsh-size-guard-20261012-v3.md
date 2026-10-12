# DSH compact-AST memory guard (2026-10-12, v3)

Use `DSH_DXR=... DSH_MAP=... KCORE_MAP=... sh
tests/validation/daimos-dsh-size-guard-20261012-v3.sh`.

The measured PDP-6 KCC/DAS image is **035552 octal words**, with static
BSS **007651 octal words**. The guard rejects image/BSS regressions,
unwanted libc linkage, and rounded user VM extents above **050000**
octal words. The production image gate is **036000** octal words.

The shell's initial VM allocation plus fixed linked KCORE now fits within
32K as a numerical *lower bound*. This does **not** prove a viable
physical-memory layout or free space for kernel packages and additional
processes. The separate low-memory boot test still fails at LOGIN EXEC.

The 115-case DSH conformance suite passed for the compact payload code
with the same image and BSS size. Additional source-focused test probes
cover function-definition copying, function replacement, case arms,
and persistence of a function loaded through SOURCE.
