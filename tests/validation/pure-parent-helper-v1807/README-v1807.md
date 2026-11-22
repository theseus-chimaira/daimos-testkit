# v1807 K04-finalizer fixture reconciliation

The K01-K04 mainline closeout introduced the original
`proc_parent_waitable_v1768` parent-eligibility rule.
Historical v1680/v1681 RAW PURE FINALIZE tests extracted the
original `proc_finish_slot` body but did not link that new leaf.
The v1807 extraction links the **actual production PDP-6
instructions**, plus the original `kret_zero`/`kret_one`
return tails. It fails closed when source boundaries change.

The original v881 synthetic process table left the INIT slot
empty. Under the accepted K04 policy, a finalized child with
no waitable parent must be freed, not made an unreachable
ZOMB. The v1680/v1681 tests explicitly create a healthy RUN
INIT with a resident u-area and no fatal-close flag before
asserting ZOMB publication. The existing finalizer and
PREVM failure/retry tests still execute the original source.

v1681 also links the actual `mach_pi_disable` and
`mach_pi_restore` leaves extracted from
`system/kernel/core/kcore_pi_pdp6.s`, rather than inventing
PI state semantics in the native fixture. The rest of the
permanent PI dispatcher is deliberately not linked, because
the test fixture owns the process/scheduler symbols.

No production KCORE source or binary changes. These fixture
updates do **not** reopen K01-K04, establish physical
PI6 interrupt acceptance, or accept RAW PURE for mainline.

Run `make test-pure-integration-native-v1807` with
`DAIMOS_REPO` pointing to the integration checkout to
execute the combined native source, owner/refusal, terminal,
and multiowner regression matrix. This target is opt-in and
does not replace the original physical 48K/64K workloads.

The old v1665 64K TSFS PURE physical smoke pins the historical
`__kcore_low_end=024255`. Its explicit
`V1665_MAP_MODE_V1807=integration` mode instead checks that
the merged source exports a valid low-resident address within
the 16K low-resident bound. The historical default remains
unchanged. Neither mode relaxes the live `PURE LOADED` and
`INIT V1` guest requirements.
