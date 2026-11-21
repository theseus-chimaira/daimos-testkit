# D6FS interactive root I/O failure: Type 270 DRL v1740

Date: 2026-11-21. This is an unresolved diagnostic, not a passing
regression or a kernel fix. The 256K KCC PDP-6 full-profile default
ROOT login boot reaches `INIT V1` and `LOGIN:`, then halts at octal
PC `004270` (`kcore_critical_media_root_halt_v1515`). The source
four-member D6FS media passes preflight CLEAN verification.

At the HALT, the D6FS reader's logical block is octal `0743`, its
mount ID is 1, and its backing descriptor has valid callbacks and
total size `0535774` octal (179196 decimal blocks). The storage
error counter at octal `024633` has increased to 1. The simulator
shows a Type 270 read on DSK3 immediately before failure.

The Type 270 simulator CONI at the last transfer is
`001105004020` (octal), followed by a controller CONO `030200`
at PC `032073`, the DSK PI error handler. Its low status includes
`000020`, `DRL` (data request late), as defined in
`sims/PDP10/pdp6_dsk.c`. DCT tracing shows the final successful
device-to-DCT word followed by the same Type 270 DRL error.
The DCT implementation can reject a write when its buffer is still
occupied, but these traces alone do not establish whether the
underlying cause is interrupt masking, late DCT service, or a
simulator/controller scheduling defect.

Evidence SHA256:

* DSK CONI/CONO trace:
  `68f0e5435aeac142ad625925aa27d4e44aa0d1f062b61cf77e3d9faed284907f`
* DCT/DSK combined trace:
  `d0efafd8fb6fd16a3e63aeeb4308291cb1086320d9a1e786585891f98b561a03`
* HALT register and backing descriptor transcript:
  `fd7080e32323af85fadc86f3bc31711c021314a249b18cda270280c9abb6ce32`

No retry, limit increase, fault suppression or permanent production
code change was made. The next step is to distinguish missed PI3
DCT service from incorrect DCT buffer lifecycle, then fix the actual
source of the late transfer before re-running interactive login.
