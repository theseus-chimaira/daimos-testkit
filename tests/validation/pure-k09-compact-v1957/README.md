# v1957 compact TSFS locality and physical 48K nine-owner acceptance

Source-matched v1956 KCC GENERAL/STRICT builds and original
v1951 two-grown/seven-ordinary native child/parent binaries.
No production kernel, host formatter, simulator timing, child
geometry or acceptance gate changes. Full original manifests
contain 42 lines; compact manifest retains 12 entries:
directories, exact INIT/MOUNTALL and CONFIG files. tsfscheck
reports files=15 extents=13 in OCTAL (13/11 decimal).

The ordinary compact member-0 root still puts executable data
near blocks0376..0411 while metadata is at4/5. The test-only
formatter copy changes only initial data_member 0 to 1.
All file extent locations move to member1, keeping data close
to its own head position and metadata close to member0's.
Independently run stock tsfscheck and compare original compact
Stage1, complete bootstrap tail, file table, shape/checksum
and every stored/compressed data sector against stock builder.
No replacement of guest code or simulator timing.
Batch SIMH monitor arm/disarm commands in DO files: pty-run
paces each guest byte by 100ms, not needed for monitor scripts.
All 71 original physical watches and their EX/GO actions
remain unchanged. The historical five-grown comparator is
parameterized with V1673_GROWN_CHILDREN=2; default remains 5.

Both original member-0 controls were stopped after A (first
RUN underway); no lifecycle acceptance claimed for them.
Both split-member native runs completed A/B/C and all nine
exact PID/status WAITs with child canaries/token verified.
A/B/C MM9/26/9, free24224/2649/24224, largest24224/1496/24224,
packed0/9/0. Tenth RUN refused from fragmentation. Exact
baseline MM table, stable parent VM/u-area and mode map
restored, baseline idle-stack pin only. Original parent
coordination pipe remains intentionally open in unchanged
fixture, not an orphan. PID1 emits PASS then sleeps; harness
stops simulator, not normal HALT. Four private tapes unchanged
on each run, source images and binaries unchanged.

Both physical replay reports byte-identical: 2931 writes,
170 extent-count commits, 18 PURE resizes (9/9), 2 BRK
resizes (2/0), 2741 staging writes. Peak 47940 occupied or
reserved /49152; min free1212, largest1212, MM28/32.
Phase writes1469/1462, commits97/73. Peak includes fixed
resident and unavailable physical RAM, not just allocations.
Both five unsafe trace variants and forged summary rejected.
No production growth.

Evidence $TMPDIR/k09-compact-v1957.BOOsmY/{general,strict}-locality.
General console.clean SHA256
15708a742cb1e68d728739b31518f30fc96f6e2e5d211ceccb76487ee237fa4a.
Strict console.clean SHA256
e25dec86ab2666055c5e03dc71e9bab2717f7d0dc8cdba78acabf6e10d9daca2.
Both highwater.json SHA256
566b3d9bcafc5ca20c1df5db3ff1baa5cd89db1daabd24f35dab92561f569c19.
Negative evidence daimos-v1674-highwater-negative.vPLC5F and .rkvmZr.
Builds $TMPDIR/k09-nine-v1956.UGyDrH/{general,strict}.

Run:
    DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1957.sh BUILD FIXTURE WORK
    V1673_GROWN_CHILDREN=2 python3 ../pure-runtime-highwater-v1674/compare-v1674.py GENERAL_JSON STRICT_JSON
