# v707 — Direct patching of fixed file-device word operations

PTR READ, PTP WRITE, CR READ and CP WRITE each had one call site and a
one-word optional-service JRST trampoline. KINIT now patches the existing
PUSHJ instruction instead. Each site defaults to `PUSHJ 17,kret_neg1`,
preserving the missing-device return contract.

The deferred runtime-module mover's fixed-binding table was updated to
refer to the new call sites. No runtime relocation table is introduced.

This change is intended to save four KCORE instruction words and skip one
JRST per corresponding operation. The source regression verifies the
bindings; actual link size and native behavior must be checked separately.
