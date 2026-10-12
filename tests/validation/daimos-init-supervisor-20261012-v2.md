# INIT-to-SUPERVISOR PID 1 split verification (2026-10-12 v2)

The startup `/SYSTEM/INIT` parses SYSTEM/INITTAB, mounts storage, and
executes `/SYSTEM/EXEC/SUPERVISOR`, which retains PID 1. Each service
is passed as two counted SIXBIT EXEC arguments; all eight configured
INITTAB slots remain supported.

Size guard: set `INIT_DXR`, `SUPERVISOR_DXR`, `DSH_DXR` to matching fresh
build paths and run `sh tests/validation/daimos-init-supervisor-size-20261012-v2.sh`.

Observed sizes (octal): startup INIT image 004210 / BSS 000461;
SUPERVISOR image 001530 / BSS 000461; DSH image 035727 / BSS 003374.
Resident supervisor VM rounds to 006000 octal words with the common
02000-word stack and 020-word origin.

Full PDP-6 boot and DSH conformance via the CTY simulator harness:
**115/115 PASS**. This verifies successful INIT-to-SUPERVISOR EXEC,
LOGIN and DSH launch; the supervisor itself refuses to run except as PID 1.

Dedicated 32K `daimos-low-memory-boot-v2.sh`: **NOT PASSED**. INIT and
LOGIN start, but ROOT's DSH launch reports `LOGIN: EXEC FAILED`. A
smaller resident PID 1 is not sufficient by itself to guarantee enough
core for a new process image. Track as separate physical-memory work.

Further follow-up: test multiple simultaneous INITTAB services, ONCE
vs. RESPAWN service restarts, malformed EXEC argument rejection, and
configuration-boundary cases. These are not covered by the 115 DSH probes.
