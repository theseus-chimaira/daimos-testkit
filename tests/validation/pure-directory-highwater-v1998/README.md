# v1998 continuous MM ownership high-water, actual DSH

Use the accepted v1997 direct 48K DSH evidence as the media fixture.
The script copies all tape images into a new private directory, uses
unchanged v1996 KCORE/MRES and the real v1997 marked DSH, and arms
71 physical MM write breakpoints at the first actual DSH prompt.
The watches continue through SET/BRK, DROP, pressure child RUN,
child WAIT, FULL/CTY wake, shell WAIT and normal HALT. This is not a
timing measurement: monitor breakpoint actions add host overhead.

    python3 run-v1998.py BUILD USERLAND_BUILD_ROOT/userland V1997_EVIDENCE NEW_WORK
    DAIMOS_REPO=/path/to/DAIMOS sh bind-v1998.sh BUILD NEW_WORK
    python3 verify-v1998.py NEW_WORK
    python3 test-v1998.py NEW_WORK

Source-bind the four native write sites by reassembling their exact
built objects with local labels. Require byte-identical DOBJ files.
The verifier rejects any unclassified writer. Replays all 103
writes, including count commits, BRK, DROP, finish, pins and all
intermediate descriptor shifts. 21 stable states including initial;
held/restored MM tables agree with independent snapshots. It does
not mistake incomplete shifts for committed allocation. Final state
is replayed through HALT, not separately sampled after HALT.

Actual 48K committed peak 42402 occupied/reserved, free6750,
MM12 at peak; max MM13/32. FULL retains pinned 242-word bitmap
and pinned 16384-word destination plus 256-word loader workspace.
Compared with restored state, 498 extra words. DROP old occupied
41789 -> 25647, including conservative disjoint copy bound
41789+242=42031. Source copy is within the original pinned APR;
destination lies in a proven free gap. No claim about every
physical memory read/write, RT time or stack depth. No compactor
move or other unsupported MM path exercised in this run.

Initial free8272, post-BRK7248, held12872, restored7248,
final replayed23896. All real DSH identity, payload, variable,
typed WAIT57 and HALT gates repeat. Root and all copied tapes
and kernel/userland source hashes unchanged.
Eight corrupted trace controls reject: unpaired event, unknown
writer, missing count watch, missing commit, DROP metadata,
arena geometry, checkpoint mismatch, missing HALT.

Evidence TMPDIR/pure-directory-highwater-v1998.8hfPRl.
No production change. This qualifies the controlled real DSH
allocator path, not universal maximum capacity or continuous
high-water of every workload. Stock foreground workload,
RT latency and private/idle stack qualification remain open.
