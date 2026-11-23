# K05 v1893: original PDP-6 physical committed PACKED free, lost reply

Date: 2026-11-23. This test addresses a *different* uncertain MM
condition from v1890-v1892's unexpected extra target pin. v1839
fixed the case where `mm_free(PACKED)` physically succeeded but the
reported result was replaced with an error, and its KCC PDP-6 native
fixture validated the original source-linked C. That case still
needed an actual full-system PDP-6 proof with real MM descriptors,
normal child scheduling, WAIT and HALT.

**Accepted actual 48K physical PASS.** The source-built original
PDP-6 completes its five-child PIPE/EXIT/WAIT/HALT after the test-only
lost-reply injection; the independent exact-MM/read-only audit and
all six executed forged physical traces PASS. Full original
normalized physical transcript SHA256:
`8d852bc8f40944035bb27a6bc773b8b4b11913b1683ae32ec2e39d41e968f0cf`.

## Original physical transaction and injection

Use the original SOURCE-BUILT v1855 48K five-child PURE-on guest,
without modifying the user INIT, kernel, removable PURE, or DTC3
backing. Every child has the original writable sentinel/PIPE input
and exits with the same typed status. The physical test controller
copies DTC0-DTC3 into private media, derives the current installed
PURE base by inspecting the KCORE reclaim JRST, and resolves the
original MRES bounded FULL function from its real linked map.

It then obtains the original packed-source `mm_free` call from
**the actual compiled production DOBJ relocation table**:

* compiled `proc_pure_ram_restore_v1391` function starts at DOBJ
  `.text+000504` octal;
* original source `mm_free` call is at DOBJ `.text+000674`, distinct
  from the later cleanup free at `.text+000755`;
* the linked call must be `PUSHJ 17,mm_free` to original fixed-KCORE
  symbol `002320`, and its following return consumer must be
  `MOVE 010,1`;
* current runtime source-free call is at physical `035310`, with
  its actual return point `035311` octal. These are independently
  computed from the observed installed PURE base, not copied from
  a previous physical run.

The simulator breaks at `035311` **after the original real
`mm_free(PACKED)` returned**. Before changing any register, it
examines AC1 and the complete MM table. The original free MUST
have returned 0, physically removed the sole packed RAW suffix
`111200..120000`, and retained one exact full PROCESS owner
`120000..130000` pin0. All unrelated extents and the TSFS root must
be unchanged from the pinned FULL entrance snapshot; no foreign,
duplicated, changed-size or pinned destination owner is accepted.

Only after this original committed deletion is established, a
test-only SIMH `deposit 1 777777777773` changes the hardware AC1
return from success to `MM_ERR_BUSY=-5`. The deposit is independently
examined before executing the untouched production v1839 reconciliation.

The original FULL service return MUST then report `MM_OK=0`,
with slot3's real VM base set to `120000` and TRANSITION cleared,
the exact target PROCESS extents surviving unpinned and the old
PACKED source remaining absent. Finally the original five child
`w` exit markers, parent `Z` and actual `HALT instruction, PC: 000000`
must all complete, with no remaining slot3 PROCESS/PACKED extent.

The physical snapshots actually observed (all octal):

| Stage | MM descriptors | Slot3 PACKED | Slot3 PROCESS | AC1 |
|---|---:|---|---|---|
| FULL pinned | 18 | `111200..120000`, pin1 | `120000..130000`, pin1 | -- |
| Original successful free | 17 | absent | `120000..130000`, pin0 | `000000000000` |
| Injected lost reply | 17 | absent | `120000..130000`, pin0 | `777777777773` |
| Recovered FULL service | 17 | absent | `120000..130000`, pin0 | `000000000000` |
| All children WAIT/Z | 8 | absent | absent (fully reaped) | -- |

The actual slot3 process descriptor at recovered service has
`meta=046031400401`, `VM=010000120000`, `scheduler=200024000000`:
original TRANSITION is cleared, the restored VM base is `120000`
and the original typed scheduler state is correctly published.
All original MM descriptors not belonging to slot3 and the selected
TSFS root `070101000000` remain unchanged through the restored FULL.
The first `w` precedes the source-free checkpoint, the remaining
four follow it, then `Z` and actual HALT; an oracle requiring the
literal substring `wwwwwZ` would wrongly reject the original
physical simulator's legitimate debugger checkpoints. The verifier
instead counts the exact five guest `w` outputs across those
checkpoints, with final `Z` and HALT mandatory.

This specifically tests the v1839 policy: **a failed reply does
not prove the physical source still exists**. If the unique exact
un-pinned PROCESS successor is the only owner, rolling it back
would destroy the last valid copy of the child's writable state.

## Reproduction

From the daimos-testkit checkout, using the accepted source-built
current original five-child v1855 48K image and installed MRES
probe:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1893_BUILD=$TMPDIR/pure-brk-pressure-v1614.qnobNT/build
    export V1893_PROBE=$TMPDIR/daimos-k05-pin-probe-v1890/probe.clean
    export V1893_WORK=$TMPDIR/daimos-k05-source-free-reply-v1893-real
    make test-pure-k05-source-free-reply-physical-v1893
    make test-pure-k05-source-free-reply-audit-v1893

The independent read-only auditor checks that the raw original
SIMH monitor transcript matches the normalized one, repeats all
exact source-linked MM/ROOT/VM/WAIT/HALT checks, and executes six
different forged original physical transcripts. Each unsafe trace
must be rejected at its intended code-path/owner/reply check; a
forged transcript is never evidence that the simulator itself
executed a changed kernel.

## Scope and safety

The experiment uses NO production source changes or production
fault hooks. This is an injected loss of a successful return value,
not a claim that the real allocator spontaneously returns the wrong
status. The currently opted-in PURE MRES remains disabled in
production and K05-K09 remain OPEN. This does not establish genuine
permanent source-free refusal, failed target rollback, terminal
cleanup under an unresolved unique owner, allocator foreign-owner
ambiguity or all PI6 interleavings. Those need independent physical
tests and must not be inferred from successful reconciliation here.
