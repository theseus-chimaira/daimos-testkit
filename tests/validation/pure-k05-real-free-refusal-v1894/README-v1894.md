# K05 v1894: original 48K PDP-6 real PACKED source-free refusal

Date: 2026-11-23. **Scoped full-system physical PASS** on the
unchanged source-built v1855 five-child 48K PDP-6, including the
original PIPE, writable sentinels, typed EXIT/WAIT and final HALT.
The independent physical audit and SEVEN executed deliberately
unsafe transcript controls PASS.

This test complements v1893. v1893 proved an actual completed
`mm_free(PACKED)` whose AC1 success reply was deliberately changed
to -5; the v1839 code correctly published its sole PROCESS successor.
v1894 proves the **opposite**: real original fixed-KCORE `mm_free`
returns its **own** `MM_ERR_BUSY=-5` because the source is physically
pinned, leaves both original MM owners intact, and v1839 safely
rolls back the provisional PROCESS after the external pin is
released. Neither test is an injected kernel source patch.

## Exact original runtime

The v1893 accepted physical trace identifies actual original
slot3 source descriptor at physical MM word `024703`, with
PACKED `111200..120000` and a separate PROCESS destination
`120000..130000`. The v1894 controller independently reads the
original KCORE/PURE hashes, the physical KCORE reclaim JRST from
the installed-MRES probe, the compiled production FULL DOBJ symbol
and relocation tables, and the linked PURE instruction bytes:

* Original FULL bounded loader: physical `036202` octal.
* Original PACKED-source `PUSHJ 17,mm_free`: physical `035310`.
* The original MM caller return consumer: physical `035311`.
* Original FULL service return: physical `033067`.
* Source MM descriptor: physical `024703`; target remains its
  separately allocated full PROCESS extent.

The original FULL loader executes normally, checks exact pins and
copies the retained RAW suffix over the completely reconstructed
target. The original transaction has successfully unpinned BOTH
owners when the simulator stops at its actual source `mm_free`
call, so their pins are zero and MM count is 18. The private
test-only simulator deposits only **one additional source pin**:

    before: 024703: 000004000003   (PACKED source pin0)
    inject: 024703: 000014000003   (PACKED source pin1)

The simulator then executes the ORIGINAL unmodified fixed-KCORE
`mm_free`, which checks the real pinned extent, refuses to delete
it, and returns genuine `MM_ERR_BUSY=-5` in AC1
(`777777777773`), with source pin1 and target pin0, MM count 18.
No other MM extent, original media, kernel instruction, source
file or TSFS root changes.

To test the v1839 **exact two unpinned owners** branch (rather
than the expected fail-closed pin-uncertain branch), the external
pin is then released by one private physical MM meta deposit:

    release: 024703: 000004000003  (PACKED source pin0)

At the original C reconciliation, PACKED source and PROCESS
target have both exact, unique, unpinned MM descriptors. The
kernel therefore cannot publish a RESIDENT APR and instead
frees ONLY the provisional PROCESS destination. At original
FULL service return `033067`, AC1 remains `MM_ERR_BUSY=-5`,
slot3 VM base is zero, MM count is 17, and its original RAW
PACKED source is still owned by slot3 and unpinned. Later the
unchanged guest retries, all five child PIPE/EXIT/WAIT status and
data sentinel checks pass, parent writes `Z`, the original machine
executes `HALT instruction, PC: 000000`, MM count is 8 and slot3
has no PROCESS/PACKED extent. ROOT remains unchanged throughout.

## Exact physical MM stages (octal)

| Original stage | Descriptors | PACKED source pin | PROCESS target pin |
|---|---:|---|---|
| Pinned FULL | 18 | 1 | 1 |
| Original pre-free call | 18 | 0 | 0 |
| Real `mm_free` refused | 18 | 1 | 0 |
| External temporary pin released | 18 | 0 | 0 |
| Original checked target rollback | 17 | 0 | deleted |
| Original terminal `Z` | 8 | gone | gone |

Every stage is independently captured from the original running
physical `mm_extents` table, checked for source and target geometry
and compared against all unrelated owner/pin records. The exact
selected TSFS root stays `070101000000` octal.

The read-only independent audit additionally replays SEVEN separately
executed forged physical transcripts: original source unexpectedly
pinned before the call, missing external injection, original
`mm_free` returning success despite the source pin, mismatched
refused-owner pin, missing external release, inexact two-unpinned
pair, and false success instead of rollback at the service return.
Each forged trace is rejected at its intended physical invariant.

Accepted original normalized full-system physical console SHA256:
`4cdba1d83d04a9d92a50a7f13965f389419175cec875f28f58e94f1ebdf97071`.
Unchanged KCORE and PURE DXR hashes respectively:

    33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b
    a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd

## Reproduction

From daimos-testkit with the accepted original source-built media:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1894_BUILD=$TMPDIR/pure-brk-pressure-v1614.qnobNT/build
    export V1894_PROBE=$TMPDIR/daimos-k05-pin-probe-v1890/probe.clean
    export V1894_PRIOR=$TMPDIR/daimos-k05-source-free-reply-v1893-real
    export V1894_WORK=$TMPDIR/daimos-k05-real-free-refusal-v1894-real
    make test-pure-k05-real-free-refusal-physical-v1894
    make test-pure-k05-real-free-refusal-audit-v1894

The original media is copied privately. There is no source-device
detach or original-genuine-free return overwrite in this variant.

## Limits

This physically settles the specific **real original native
MM source free -5 with a transient external pin**, followed by
exact checked two-unpinned-owner target rollback and normal retry.
It does NOT establish **persistent** source pin/refusal, other
failed target rollback, foreign owner, permanently incorrect
unpin, allocator uncertainty, terminal cleanup with permanently
quarantined owners, arbitrary PI6 ordering, 64K/KA10 or complete
K05-K09. No production source, kernel code, MRES, RAM, process
field or format changed. RAW PURE and mode3 remain OFF by default.
