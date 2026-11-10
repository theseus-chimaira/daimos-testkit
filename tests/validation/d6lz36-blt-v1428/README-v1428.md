# D6LZ36 BLT optimization, source and native acceptance (v1428)

The existing shared fixed D6LZ36 core uses BLT for overlapping
backward match copies instead of five instructions per decoded
word. The bitstream, input validation and resume ABI are unchanged.
The match-copy sequence is:

    hrl 6,6
    hrr 6,12
    add 12,0
    blt 6,-1(12)

The core shrinks 40 -> 39 words; unchanged adapter: 57 words;
linked KCORE initialized image: 9601 -> 9600 words, with
unchanged BSS and relocation-map lengths.

Native PDP-6 simulator instruction steps on actual DSH snapshots:

| State | Original | BLT | Reduction |
|---|---:|---:|---:|
| Idle | 17928 | 3238 | 81.9% |
| Variables | 19377 | 5791 | 70.1% |
| Function | 30637 | 7291 | 76.2% |

An illustrative 1964 DEC F-61 timing model charging every BLT
transfer estimates 4.35x, 2.93x, 3.53x speedups respectively.
These modeled ratios are NOT measured hardware times.

All 23 native compatibility, malformed-input, refill and
snapshot cases PASS. Both a rebuilt DSK Stage-1 against existing
media and a complete independent rebuilt Stage-1/KCORE boot
reach DSH and execute ECHO successfully.

All five Stage-1 sources assemble exactly one word smaller.
The old DTC Stage-1 already violates the separate historical
106-word test cap (140 words before, 139 after); this is NOT
caused by the BLT change and must be addressed independently.

To reproduce, set DAIMOS_REPO to the versioned v1428
worktree, PDP10_PREFIX to the cross-tools prefix and run
run-v1428.sh. Optionally set D6LZ36_BLT_MEASURE_V1428=1
to repeat the native instruction-step measurement.
