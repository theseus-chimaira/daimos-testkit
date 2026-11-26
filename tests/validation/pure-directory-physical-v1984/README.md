# v1984 actual directory/RAW pressure comparison

Use the prepared v1983 source-built directory and matched RAW images.
RAW must use identical INIT/COMP bytes and the same strict TSFS root
configuration. `prepare-raw-v1984.sh` takes DAIMOS_REPO and V1983_BUILD;
it reproduces the matched RAW build procedure used here.
The existing replay-v1983.py accepts --raw for the RAW control.
Both use actual PDP-6 64K SIMH, private tapes and read-only breakpoints.

Independent verification of actual pressure and directory restore trace:

    python3 verify-pressure-v1984.py DIRECTORY_BUILD DIRECTORY_WORK \
        --restore --raw-build RAW_BUILD --raw-work RAW_WORK
    python3 test-verifier-v1984.py DIRECTORY_BUILD DIRECTORY_WORK

The verifier independently checks linked image digests, exact guest
fixture digests and DXR text boundary, true pressure marker, stable
u-area/MM ownership, non-overlap, map cells, actual relocated service
and terminal entries. Compare free and largest aligned gaps, retained
lengths and matched resident overhead. Restore verification binds
actual restore/finish PCs, exact original source, both pins, disjoint
full APR, transition and slot-zero execution, and complete checked
child markers. Eight mutated actual traces must reject.

Actual evidence relative to TMPDIR:
- pure-directory-guest-v1983.jLrxmz/build
- pure-directory-physical-v1984.fQfzgb
- pure-directory-raw-control-v1984.J5WhuQ/build
- pure-directory-raw-physical-v1984.Oaz4D2

Directory8 children (7 bitmap239,1 RAW3584), RAW9 children (9 RAW3584),
all full4096, prefix512. Gross equivalent savings23415, net21322 after
actual linked cost2093. Directory31078 free/largest aligned3584;
RAW5908 free/largest aligned1536. Admission capacity REGRESSION -1.
Actual directory slot3 restore and atomic finish with 239+4096 pinned
words; all8 directory and all9 RAW guest checks/WAITs reach Z. Both
original observers rejected SIMH's concatenated ZV1983_Z_STOP format;
final MM/HALT was not captured.
Corrected parser for future runs. Independent guest completion proof
is not final MM, physical PI6 or terminal-while-nonresident acceptance.
