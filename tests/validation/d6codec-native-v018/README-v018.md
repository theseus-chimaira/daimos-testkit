# Native paired-descriptor decoder v018: multi-group regression

This opt-in isolated PDP-6 simulator test expands the v017 93-word decoder
coverage without modifying DAIMOS/KCORE or shared testkit build files.

The validated fixture contains two counted token groups: first a literal,
three overlapping word copies and three zeros; second a literal and two
more overlapping word copies. Exact 10-word output is checked.
It also requires nonzero failure for a zero-length descriptor and for a
truncated first compressed token group. The fixture PASSes in the PDP-6
simulator via `run-v018.sh`. The decoder source remains functionally
identical to v017 and measures 93 text words; only symbols were renamed.

During development, an incorrect bit-28 flag constant (021000000000)
caused a false decoder failure. The correct group-2 control bitmap for
count=2 with token 2 matched is 022000000000 (octal). Both the multi-group
and bad-input tests are now verified with that correction.

Still missing: full fuzz/malformed matrix, halfword match decoding,
resumable input, kernel-ABI preservation, and a matching native encoder.
Do not integrate into KCORE on this evidence alone.
