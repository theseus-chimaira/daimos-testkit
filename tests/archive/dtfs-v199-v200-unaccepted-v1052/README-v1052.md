# DTFS DTC3 historical diagnostics (v1052, 2026-11-03)

These four files were previously untracked in the old v115 SIMH testkit
worktree. They were copied byte for byte and checked against the originals.
The accompanying SHA256SUMS-v1052.txt records their checksums.

The v199 diagnostic attempts native FSCK on isolated DTC3 media and
checks a subsequent shell command. The v200 diagnostic attempts mount
and a subsequent shell command. Neither script is accepted as a passing
regression. Both scripts describe two boots but execute only phase A.
The v200 script reports successful write and reboot readback even though
neither action is performed. The scripts are historical evidence only;
they are not wired into any Makefile target.

The corresponding tracked branch tip is already in testkit main history
through the v1048 merge. No guest boot was run during preservation.
A future persistence test must verify a real write, reboot and readback
before claiming acceptance. 32K-specific tests remain deferred.
