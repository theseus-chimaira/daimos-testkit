# v1997 physical real DSH lifecycle

Use the v1996 48K GCC strict swapless directory build and its matching
userland build. No production source, installed executable, simulator
timing, or original tape is modified.

    export DAIMOS_REPO=/path/to/DAIMOS
    export PDP10_PREFIX=/path/to/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    V1997_DIRECT=1 sh tests/validation/pure-directory-dsh-v1997/run-v1997.sh BUILD USERLAND_BUILD_ROOT directory marked

The direct fixture replaces INIT only, establishing LOGIN's normal CTY
session, attachment and foreground group. DSH is the genuine linked
program, with only PURE and mutable DXR header flags changed. A test
parent independently creates 8192 BSS words of pressure (10240 APR),
holds the child on a pipe and checks its typed exit57. Compact TSFS
test media put data on member 1 using a disposable formatter copy;
the stock and split images are independently verified for identical
boot and file payloads. Normal tape timing remains enabled.

Observed 48K: DSH slot2/uarea055250, initial APR15360, after SET
APR16384. Actual mode3 sleeping, unpinned exact owner056000/242,
raw suffix3200, immutable prefix13184. Independent bitmap decode
contains the SIXBIT variable. Actual terminal wake after pressure
child WAIT restores mode0 APR16384 at074000, same slot/uarea/backing/
credential, cleared escrow and backing, original opcode signatures,
same SET value. Shell exits57, typed WAIT and HALT pass. MM extents
10/13/10 at checkpoints, not continuous high-water or post-HALT MM.
All three root tapes and source images hash unchanged.

Evidence: TMPDIR/pure-directory-dsh-v1997-directory-marked.Nt1Z4X.
Replay: python3 verify-direct-v1997.py EVIDENCE_DIRECTORY
Six corrupted replay controls rejected (mode, identity, MM overlap,
backing, bitmap, missing WAIT marker).

Full stock root controls (omit V1997_DIRECT) directory normal/marked
both ROOT login, SET, enumeration and signature PASS, then ECHO
timeout at original 180s. Both remain mode0 with unpublished SIDL
child APR2048 and closely adjacent PCs; not a compression failure
witness or proof of permanent I/O failure. Original logs:
pure-directory-dsh-v1997-directory-{normal.yTW8Q5,marked.tBTXqX}.
Exploratory V1997_PRESSURE_WORDS=6144 stock foreground workload
compiled but did not reach its pressure command (marked.h2Otwu).
Stock ECHO, foreground pressure and RT/continuous high-water remain
open. First direct fixture omitted controlling TTY and did not reach
DSH prompt (marked.FQICzg); fixed using the genuine LOGIN contract.
Default compression activation remains OFF.
