# v1958/v1959 runtime BACKSTORE partial transfer and recovery

Full KCC 64K v1955 pressure fixture. Both READ and WRITE
stop after exactly eight native DCT IOWD increments out of
128, not eight monitor steps. WRITE has already fetched one
word at command issue. Remove selected DSK0, attach a
distinct file differing in addressed sector, before PI5.
The v1541 dedicated reason2 HALT preserves the original
DISK run (READ) or resident APR (WRITE), transition, bitmap,
pins and entire MM table. Failed event -1 and active
controller ownership cleared. Original and replacement
media SHA256 unchanged after detach; WRITE's affected
sector also equals the source image. No actual write to
replacement medium, no claim of resume after critical loss.
Fault at eight words is a representative partial transfer,
not exhaustive every-word or every-phase coverage.

Actual v1954 driver preliminary runs in
$TMPDIR/k09-runtime-v1958.SCQ4Vp/{read,write-replay}.
Fresh v1959 committed driver runs in
$TMPDIR/k09-address-v1959.1opCid/{partial-read,partial-write}.
Normal lifecycle there in physical: MM9/20/8,
free43633/1089/43647, 64 sectors used at B, zero at C,
reads50/129/193 writes1/65/65. Six exact WAIT/canary checks,
both parent pipe FDs closed. PID1 marker then harness stop.

Run: V1956_OPERATION=read sh run-v1958.sh BUILD WORK
Repeat with write. Use v1955 pressure fixture and installed
v1954 simulator. Source-linked noncritical queue/recovery
tests are exercised by ../dsk270-address-v1959/run-v1959.sh.
