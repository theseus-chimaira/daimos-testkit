# K02 v1730: final process-resource cleanup acceptance

Date: 2026-11-20. Verdict: K02 CLOSED under bounded, fail-closed
resource ownership. K03 and K04 remain independently OPEN.

DAIMOS acceptance baseline: 38e6b4d140e5a4babed205e9274449bf4fbea0f7.
Testkit baseline: e5ee925f7158885b1069ed44f9279a0e443dc0cf.
The production system/kernel source is unchanged since the v1720
low-memory EXEC fix 5d6e91c1. Only disposable test-kernel copies have
fault injection or new diagnostic RAM.

## Reproducible consolidated acceptance

The testkit daimos-k02-final-accept-v1730.sh driver has native,
physical and all modes. It preserves a versioned results manifest
and a log for each test under $TMPDIR, stopping on the first failed
strict verifier. A guest cannot pass merely by reaching HALT.

Nine of nine native PDP-6 source-linked gates PASSED in a single
v1730 run. Manifest: $TMPDIR/daimos-k02-final-accept-v1730.S4As0T.

| Native gate | Exact ownership boundary |
| --- | --- |
| v1719 | staged EXEC rollback and retained backing, two unsafe controls |
| v1720 | destructive EXEC VM_NONE and stable u-area, seven cases and two controls |
| v1722 | unpublished RUN FD map, TSFS, independent FILE/PIPE refusal |
| v892 | unpublished RUN failed MM release, exact-once reaper retry |
| v1728 | eight session HUP refusals, TTY and FILE retained, three controls |
| v970 | private fatal-stack owner guarded against foreign HUP |
| v1099 | typed PIPE/FIFO -4/-5 close and four unsafe controls |
| v1102 | bounded reaper backoff and four unsafe controls |
| v922 | repeated partial session HUP and finalized-member skip |

Four of four fresh booted 256K PDP-6 physical guests PASSED:

| Physical case | Observed strict result |
| --- | --- |
| v1721 | Real PROCESS MM free followed by two failed backing detaches and an accepted third; no second MM free; preserved record 037 octal; original EXEC owner call 1, slot-zero calls 2; parent WAIT PASS |
| v1726 | Two concurrent RUN children, two live cross-owner observations; physical PIPE MM pin/busy/unpin/free 1/1/1/1; D6FS provider calls/refusals 3/2; valid leases 3; independent WAITs |
| v1729 | Three refused session HUPs preserve leader TTY and protected FD3; D6FS calls/refusals 5/5, valid leases 5; separate actual post-VM_NONE fatal EXEC and successful parent WAIT; zero ownership errors |
| v900 | Named FIFO final-close refuses actual MM_BUSY but stays linked/reopenable; three close visits, one pin, one unpin, one BUSY, zero errors |

All four physical runners returned exit code zero. The v1729
verifier also previously rejected six unsafe transcript mutations.

## SHA-256 of fresh v1730 physical runner logs

| Guest | SHA-256 |
| --- | --- |
| v1721 | e9af92f20ad88ed25ec855a42fc491ce02f36b9276b0e24c98f85d74d816bb63 |
| v1729 | 015e8710cf564baf3210a18a9c6fa0271380b3ae9442362872df9dd99884a0b7 |
| v1726 | 3ddb83c089420238552cef8b78ece39fd399792536abf0a8502f03661e70bf2a |
| v900 | a8852636c8893c7863332c14cc7e3f4e188ef6a72b863dc4c8608236cff6f9d6 |

The consolidated native driver log hash is
cc0ad212a1e50cf0044cf95b98762e9884a9da7ff31c3de52c1bff3d861054d5.
These are runner log hashes, not unmodified production image hashes;
the original instrumented KCORE/SIMH hashes are documented in
DAIMOS design reports v1721, v1726 and v1729.

## Scope and resident-memory boundary

K02 covers failure-safe ownership of MM, VM, FD, PIPE and FIFO
resources across ordinary/fatal EXIT, EXEC and failed/unpublished
RUN. A refused close must keep its existing owner available for
checked retry, never release twice, and never block independent
scheduler progress by spinning. A staged stack-only owner that
cannot be safely retired must fail-stop instead of silently leaking.

Production K02 fixes: v1719 added 23 KCORE instructions and v1720
added 7, a cumulative 30 words of executable text. No additional
fixed or per-process RAM was allocated. From v1721 through v1730,
production KCORE text, fixed RAM and process-state deltas are ZERO.

The last matched GCC low-memory disk-root size measurement, whose
production kernel inputs remain unchanged, was: KCORE 10,461 words;
KCORE plus MRES 17,186 words; final permanent address 17,233 decimal.
The independent strict 040000 octal 32K permanent-address gate is
still OVER BUDGET (free-word accounting -850). K02 closure does NOT
assert that the strict 32K link is accepted.

Not covered by K02: native device/media implementation errors
(filesystem/provider-specific work), permanent-resource reclamation
policy (K04), automatic OOM killing (K03), or every interrupt
interleaving. Controlled offline recovery may still be required
for irrecoverably held resources. Never force-unpin or force-free
ownership that cannot be verified.
