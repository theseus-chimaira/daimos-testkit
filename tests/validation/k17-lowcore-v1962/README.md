# K17.1 PDP-6 low-core reuse v1962

Run against a fresh 64K KCC LOWMEM hybrid TSFS image (build instructions
in ../k17-lowcore-v1961/README.md):

    python3 -B native-v1962.py BUILD WORK "$PDP10_PREFIX"

The physical boot stops immediately after the two transient KINIT clears,
then resumes until the first INIT output. It verifies both absolute symbols,
zero initialization, live APR effective low register fields, the published
idle stack base, and all 53 shared decoder words. --replay verifies the saved
console transcript. The original initial-user APR image has unaligned low
LH bits (the PDP-6 hardware masks them); do not mistake the hardware mask
for an exact software mapping check.
