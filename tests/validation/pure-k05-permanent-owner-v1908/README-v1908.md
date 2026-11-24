# K05 v1908: long-held foreign FULL target with bounded slot-0 retries

Date: 2026-11-24. **Original 48K PDP-6 physical PASS, bounded scope.**

This is deliberately ONE additional test after v1907, not another
general MM fault matrix. Its unresolved question: if the genuine
failed-FULL provisional target remains claimed by a foreign MM owner
through many original parent quantum boundaries, does the kernel
preserve all ownership and private stack state without retry spinning
or expanding permanent resident RAM?

The production KCORE and optional PURE binaries are byte-identical
to v1906/v1907. The controller reuses the v1907 source-built native
five-child/TERM guest and source-linked PURE probe, including the
real first `mm_free(PACKED)` returning -5, source-pin release,
and test-only change of the full PROCESS target `120000..130000`
metadata at `024725` from owner3 to owner2. The parent actually
issues one user PROCCTL TERM(3), prints `TR` (refusal), and keeps
running. Unlike v1907, the controller **never repairs owner2,
never opens the typed WAIT gate, and never forces EXIT/FINALIZE**.

Ten independently executed resident parent `HB` checkpoints
after the foreign claim retain MM18, the complete unchanged
MM extent table, authoritative PACKED RAW source pin0, unchanged
foreign-claimed target PROCESS pin0, slot3 TRANSITION/VMbase0,
the saved executive CTX_PC/FDCTL, original ROOT and the
physical u-area 067 escrow `040000120000`. The parent stays
slot1. Original PCLK advances from `015624` to `016724` octal.

The existing **one** resident retry word continues to indicate
pending work. Its actual shared delay, in octal ticks at HB1..10:

    0100 0200 0200 0400 0400 0400 0400 1000 1000 1000

The last three readings prove arrival at and stability of the
original `01000` octal (512 decimal) tick cap while parent
activity and hardware clock progress. This is a *bounded
observation*, not a mathematical proof that an owner will remain
safe for infinite time. No native cleanup or guest HALT is
claimed: after HB10 the **operator stops the simulator**.

The verifier checks the exact original binaries, original
native refusal, one real TERM refusal, all 10 complete MM
snapshots, saved CPU/FILE/escrow, process and parent gate,
monotonic PCLK and bounded shared retry. Only **three** new
physical unsafe mutations run: premature TRANSITION unlock,
retry delay exceeding `01000`, and stalled original parent
PCLK. All reject. The v1906/v1907 broader controls have
already passed on the same unmodified production binaries.

Original production SHA256:

- KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Accepted physical normalized trace `6d5a43084392f9a32442dc7cb706d8d0e4e451aac0cc029784d35ba810954736`
- Accepted source-linked `.ini` `5798fd084ae1661dabd2166fca9e5f1490bc9243ed8e659c9d59fa5096bf7dca`

Reproduce from daimos-testkit, with `TMPDIR=${TMPDIR:-$HOME/tmp}`:

    export V1908_BUILD=$TMPDIR/pure-brk-pressure-v1614.JInvCL/build
    export V1908_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1908_WORK=$TMPDIR/daimos-k05-permanent-owner-v1908-physical-v1
    make test-pure-k05-long-owner-physical-v1908
    make test-pure-k05-long-owner-audit-v1908

The build/probe may be reused only after KCORE and PURE hashes
are verified unchanged; otherwise source-build the v1907 fixture
and run the existing source-linked v1845 PURE installation probe.

**Remaining K05:** no native terminal cleanup is possible while
the original saved executive stack and uncertain foreign target
remain live. Do not force TERMINATE/FINALIZE or claim guest HALT.
The tested retry remains safe for this measured window; separate
allocator corruption/real PI6 interleavings are still open.
RAW PURE/mode3 remain default OFF; no production changes in v1908.
