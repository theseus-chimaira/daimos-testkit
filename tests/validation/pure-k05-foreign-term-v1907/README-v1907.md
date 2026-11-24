# K05 v1907: one native user TERM during foreign-claimed FULL rollback

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS**.
This deliberately tests ONE previously uncombined interaction;
it does not repeat the full v1906 ownership fault matrix.

## Hypothesis and actual setup

The original foreign event path must refuse a user TERM while a
child retains an unpublished RAW FULL destination, TRANSITION,
and a saved executive continuation. In v1906, the original
destination's base also lives in the existing u-area 067 RH.
Terminal processing must not reinterpret it as FINALIZE, destroy
the private stack, change FILE/FDCTL, or release either MM owner.

The v1907 source generator extends the **v1903** original
five-child compressed TSFS/RUN/PIPE/BRK parent, adding only ONE
real `dsys_procctl(SYS_PROCCTL_EVENT_PID,
SYS_EVENT_ARG(3U,SYS_EVENT_TERM))` request. Its separate
test-only volatile user gate is `135361`; the existing v1903
typed WAIT exit gate remains `135357`. Neither lies in KCORE.

The original first `mm_free(PACKED)` returns -5. The physical
controller releases the external source pin and temporarily
relabels only the full PROCESS target metadata `024725`
from slot3 to foreign slot2. At the first resident parent HB,
while TRANSITION and escrow are held, it opens the new user
TERM gate. The genuine user C call prints `TR` (refused).

The TERM snapshot confirms MM18 and identical complete RAW and
foreign PROCESS extents, saved executive CTX_PC/FDCTL,
`u[067]=040000120000`, TRANSITION, VMbase0, original ROOT and
the still-closed typed WAIT gate. Two further original parent
HBs prove forward progress without target deletion or unlock.
The controller then repairs its OWN deliberately corrupted MM
owner field. The original v1906 native target-free and second
FULL commit, five child EXIT/typed WAIT, parent Z and real
PDP-6 HALT PC0 all PASS with final MM6 and no child owner leak.

The unchanged v1906 full lifecycle verifier re-PASSes. Exactly
FOUR additional physical negative mutants reject: false TERM
acceptance (`TA`), TERM gate prematurely set, an altered foreign
target at TERM, and a lost target-base escrow. This limited set
covers the NEW TERM boundary; the 16 v1906 MM negatives remain
separately accepted and are not redundantly rerun.

Production KCORE/PURE hashes are unchanged from v1906:

- KCORE SHA256 `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE SHA256 `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Accepted physical transcript SHA256 `da5ae4d1920279f78965080297985b5e698f1ae6ea3390b573a5edb34b26c7dc`
- Accepted local physical evidence `$TMPDIR/daimos-k05-foreign-term-v1907-physical-v1/`

## Reproduce

From `daimos-testkit` with `DAIMOS_REPO=$HOME/git/DAIMOS`,
`PDP10_PREFIX=$HOME/cross`, `TMPDIR=${TMPDIR:-$HOME/tmp}`:

    make test-pure-k05-foreign-term-build-v1907

Use the reported source-built `pure-brk-pressure-v1614.*/build`
as `V1907_BUILD`. The previously accepted v1906 PURE probe may
be reused ONLY if source-built KCORE/PURE hashes match exactly;
otherwise run the existing v1845 source-linked PURE probe.

    V1907_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean \
      V1907_WORK=$TMPDIR/daimos-k05-foreign-term-v1907-physical \
      make test-pure-k05-foreign-term-physical-v1907
    V1907_WORK=$TMPDIR/daimos-k05-foreign-term-v1907-physical \
      make test-pure-k05-foreign-term-audit-v1907

**Scope:** This proves original user TERM refusal during a
foreign-claimed target plus full recovery after explicit test
repair. It does not authorize terminal cleanup of unrecoverable
owners or bypass the existing TRANSITION guard. K05 stays OPEN.
