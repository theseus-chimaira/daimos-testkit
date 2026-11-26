# v1985 bitmap placement during atomic DROP

Run `make test-pure-bitmap-placement-v1985 DAIMOS_REPO=/path/to/DAIMOS`.
The default compiler is KCC; `PURE_TEST_COMPILER_V1984=gcc` selects GCC.
Both PDP-6 and KA10 execute real prefix prepare/verify, MM free-gap
search, placement/reorder, bounded FULL, clean unlock and staged VM
terminal with actual PREVM preservation. Reuse earlier fixtures; only
source-side addresses in the restore/terminal fixture are redirected
to the new exact packed base. No live scheduler/PI6 or actual tape I/O
in this native fixture.

25 counted DROP/commit/direct-leaf cases per CPU/compiler, plus four
FULL calls and two terminal calls. Check lowest 0200-aligned gap,
full descriptor table, no-fit original placement, lost/false reply,
foreign owner, invalid target/range/alignment/pins/duplicate/malformed
table, exact destination escrow, original RAW cancellation. Shift
one and three intervening descriptors without touching foreign data,
including independent MODULE/KERNEL_DYNAMIC owner namespaces. Force
real allocation and overwrite of the entire old APR, then restore
from the moved bitmap with plain/compressed executable loader. Check
clean failed FULL and exact retry, and PREVM terminal refusal/retry
with exact original moved source. Six unsafe mutants must execute and
fail assertions (no copy, overlap proof, descriptor shift, alignment,
reply proof or destination escrow).

Physical comparison: run the existing matched fixture builder
`../pure-directory-physical-v1984/prepare-raw-v1984.sh` with
`V1985_DIRECTORY=1`, `V1983_BUILD` pointing to the original build and
`DAIMOS_REPO` set. Same INIT and COMP bytes. Existing replay detects
placement from the linked map, and independent pressure verifier now
accepts exact resident sleeping owners, sector-aligned mode3 and
optional final-MM/HALT check (`--restore --final`). Do not accept
an old trace with only guest Z as final lifecycle evidence.

Actual 64K physical result (same fixture hashes as v1984): 12 children
(fixture ceiling), vs9 RAW and8 original bitmap. Four239-word relocated
bitmaps, one3584-word RAW and seven4096-word resident children.
Independent final verification:

    python3 verify-physical-v1985.py BUILD WORK OLD_BUILD OLD_WORK RAW_BUILD RAW_WORK

Evidence relative TMPDIR: pure-placement-build-v1985.s17eYq/build,
pure-placement-physical-v1985.GSp074 (verified-pressure-v1985.txt,
verified-final-v1985.txt, physical.clean). Restore slot3 from octal061400
into160000, exact239/4096 once-pinned pair; all12 checks/WAITs, final MM
and normal HALT PASS. Five corrupted final-state traces rejected.
Net equivalent RAW saving11186 after2194 resident overhead; measured
capacity gain3, not maximum capacity. PI6-specific, EXEC and nonresident
terminal physical acceptance still open.
