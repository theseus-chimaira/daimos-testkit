# K15 physical 48K lifecycle (v1995)

Reuse the v1987 actual user workload with freshly built GCC PDP6 strict
swapless TSFS images (directory and RAW). No recovery flags are required;
this is the healthy K15 gate. Set DAIMOS_REPO, PDP10_PREFIX and TMPDIR.
Build each profile with ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc,
BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 TSFS_ROOT_MEMBERS=3
TSFS_INPLACE_BOOT=1 DAIMOS_PURE_MRES_ENABLED=1
DAIMOS_SWAPLESS_ONLY_V1668=1 and DAIMOS_PBM_DIRECTORY_V1983=1 or 0.
Use matching installed tools and the source host media builders when needed.

    sh tests/validation/pure-directory-lifecycle48-v1995/run-v1995.sh "$DIRECTORY_BUILD" directory
    sh tests/validation/pure-directory-lifecycle48-v1995/run-v1995.sh "$RAW_BUILD" raw

The wrapper makes private root tapes, rebuilds the v1987 guest and POST,
and checks the original MM trace without changing the source build.
The directory replay requires actual mode3 restore, exact nonresident TERM,
marked-to-unmarked EXEC, typed waits, final MM/HALT, unchanged tapes and
all eleven v1987 negative trace controls. The RAW control uses the same
user workload and independently checks pressure ownership and final cleanup.

At DAIMOS af048d25, directory 48K admitted five children: four 251-word
bitmap owners at 060000,070000,100000,110000 and one 3584-word RAW owner.
Three compressed STOP processes were terminated without restore. Actual
slot3 FULL/EXEC 4096->2048, all five WAITs, exact final MM/HALT and root
tape integrity passed. Eleven corrupted traces were rejected.
At pressure: 18 extents, 16088 free words, largest APR-aligned gap 3072
words. This is a placement/headroom limitation, not exhausted total RAM.
The 48K capacity and real DSH acceptance gates remain separate.

Matched RAW control also passed five typed WAITs and final MM/HALT with
unchanged tapes. RAW: five 3584-word owners, 18 extents, 4950 free,
aligned span 2560 (rounded APR 2048). Directory: aligned span 3584
(rounded APR 3072), net additional free 11138. GCC MRES 3258/5460;
fixed KCORE -8 words. No sixth child or capacity improvement is claimed.
The current lower-only destination selection did not consolidate these
four high-to-low bitmap drops. No production change.
