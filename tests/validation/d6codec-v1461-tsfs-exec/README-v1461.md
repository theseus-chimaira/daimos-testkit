# v1461 TSFS host producer and compressed EXEC regression

The v1459 TSFS-root image was produced by a stale `mktsfs`
binary installed on 2026-10-16. It emitted an old-format
compressed restart for `/SYSTEM/EXEC/LOGIN`, which the v1458
PDP-6 block decoder correctly rejects. The stale `tsfscheck`
also skipped all normal regular files because it compared the
entire low half of PARENT_FLAGS, including mode bits, against
the REG type. It reported the corrupt image as valid.

The corrected source masks with `TSFS_FILE_FLAG_MASK` before
checking REG. The boot Makefile now builds versioned
`mktsfs-v1461` and `tsfscheck-v1461` from the checked-out
sources and verifies the complete generated root set. A stale
external producer can no longer silently create an image that
passes the build's media-validation stage.

## Independent tests

* `check-media-v1461.py`: fresh image accepted; stale image
  rejected by the strict checker. Real fixture has 53 files
  and 401 extents.
* `native-login-extent-v1461.py`: takes the actual final
  compressed restart from the new TSFS image, compares the
  host decode against the linked LOGIN DXR, and decodes it
  on the native PDP-6 using the production 53-word fixed core
  and 58-word VFS adapter. Output: `HOST_REAL_TSFS_EXTENT_PASS`
  and `FIXED_VFS_PASS`.
* `verify-exec-media-v1461.py`: independently reconstructs
  the complete LOGIN, DSH and ECHO executables from the
  generated TSFS extents and compares every word against
  the source DXRs. Verified LOGIN=3221/13 extents,
  DSH=15760/62 and ECHO=1035/5.
* `boot-v1461.py`: real TSFS-root cold boot from isolated
  media, ROOT login, DSH, guest ECHO. `--guest-timeout` is
  configurable because DECtape seeks are slow. A timeout
  is never counted as a pass.
  The full-profile 256K acceptance passed with a 240-second
  guest-command allowance (`V1461_DSH_EXEC_PASS`); the initial
  70-second guest-command window timed out. Total cold-boot
  wall time was about 307 seconds.
* `trace-failure-v1461.py`: optional nonintrusive SIMH
  breakpoint and history diagnostic for EXEC failure paths.
* `inspect-layout-v1461.py`: inspect FILE/EXTENT metadata
  and 32-record extent-table block boundaries.

The producer and checker are **host tools**. No permanent
KCORE words, on-disk TSFS format, decoder code, or transient
decoder stack words are added by this change.
