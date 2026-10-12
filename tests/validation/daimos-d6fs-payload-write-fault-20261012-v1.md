# Live D6FS backing data-write failure — 2026-10-12 v1

The testkit generates an isolated PDP-6 D6FS backing dispatcher that rejects
block writes whose **first 36-bit word** equals octal `0765432107654`. The
fixture creates a fresh `/CONFIG/FAULTDAT`, writes that marker at the start of
a new block, requires the system call to report failure, closes/reopens the
file, and checks that the original EOF remains zero. It also requires a clean
HALT and a CLEAN `d6fsck` scan of the resulting D6FS disk.

Live PDP-6 SIMH acceptance (2026-10-12): both probes passed, then d6fsck
selected superblock 670 sequence 3, state CLEAN, 179196 blocks and 360 FCBs.
The injector is in the generated assembler only; no production source code or
RAM state is modified. The source generator and test runner are in testkit.

**Limits:** this validates a failed data-block commit for a newly created
one-word file and the rollback's old-EOF behavior. It does *not* validate a
failed allocation-map write, cross-block partial success, an ambiguous final
FCB commit, power interruption, or true crash-atomic HISTFILE records.

A fresh image's first login attempt exceeded the original 45-second boot
window after printing the kernel device banner; restarting the same image
with a 120-second allowance passed the injected failure and orderly HALT.
The standalone runner therefore uses a 120-second boot limit. This is a
harness timeout adjustment, not evidence of an I/O correctness problem.
