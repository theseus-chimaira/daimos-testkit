# K07 backing identity during PURE reconstruction (v1923)

Run with installed KCC/DAS/p10run:

    DAIMOS_REPO=$HOME/git/DAIMOS sh tests/validation/pure-backing-identity-v1923/run-v1923.sh

This guest links the original unpacker, shared DXR image inspector and
payload engine, RAW DROP, PREFIX and FULL, and MM mutation assembly.
VFS reads/stat, pin/free/allocation and PI are controlled fixtures.
Five decoder checks cover wrong root mount ID, null root slab, null
u-area, zero backing and valid reconstruction. Ten restore cases
exercise PREFIX on mount 1 and FULL on mount 18: a matching TX2 with
no PURE flag, changed root index during header read, changed root
index during payload read, retired mount during payload read and
provider change during payload read. Each failed restore retains the
exact RAW suffix, backing, mode and transition, with no stray scratch
or pin; restoring the original root permits the next restore.

Five unsafe assembly variants must fail native assertions: missing
PURE flag check (03002), missing pre-payload identity check (01103),
missing post-payload identity check (01202), missing full-root
comparison (01102), and missing root mount-ID check (0101).
The v1387 historical runner now links its test-only codec ABI alias
and the original device-state leaf. This is not a substitute for
physical PI6 or concurrent provider mutation tests. No generation
identity across pre-existing mount reuse is claimed.
