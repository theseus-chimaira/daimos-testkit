# K01 v1718: completed permanent-MM ownership acceptance

Date: 2026-11-20. Accepted kernel source: DAIMOS
`6ea0d49705651e66e7b4ad40221461306ddf3c7d` (v1716), with no
production kernel changes afterward. Testkit integrated gate revision:
`4841f66b7d7fa168de18f93e7418f8fa7957d53e` (v1717).

## Independently verified integrated result

`daimos-k01-integrated-acceptance-v1717.sh` was re-executed against
the two completed, retained physical 256K PDP-6 F07 guests and the
33-case native source-linked acceptance record. Evidence directory:
`$TMPDIR/daimos-k01-integrated-v1717.1XMe7A`.

All six strict gates PASS:

1. `clean-v1336`: independent owner release, ordinary swaps and final
   physical MM/backing cleanup; 34 swap-outs and 34 swap-ins.
2. `clean-v1303`: actual no-partner pressure, one cooldown and no
   leaked BACKSTORE allocation.
3. `clean-v1349`: four distinct owner extents correctly retained and
   released; no remaining owner or error, six negative controls.
4. `fault-v1713`: actual injected BACKSTORE bitmap refusal, two
   deferred TERM events, bitmap repair, original owner verification,
   zero final BACKSTORE usage and 16 negative controls.
5. `native-33`: 33 individually passed native PDP-6 MM ownership,
   rollback, compaction, PI, swap and temporary-provider tests. Native
   evidence: `$TMPDIR/daimos-k01-native-acceptance-v1715.iLHr0R`.
6. `source-v1716`: structural inspection of all 26 direct `mm_free`
   call sites across 12 production assembler files, with five unsafe
   changes rejected.

The full guest images contain production v1710 current-owner
compaction and v1711 PI-atomic advisory pin lookup. The only diff
between the clean guest's MM source copy and production is the
test-only exported `mm_find_fit` symbol (no instruction changes).
The v1717 integrated verifier also rejects any committed kernel
changes since native validation or any uncommitted production source
modification, and checks the exact 33 unique native PASS records.

Independent earlier physical evidence also remains valid:
v1703 permanent real MM pin (`-5`), wrong owner (`-4`) and foreign
provider lease quarantine; v1704 genuine transient MM refusal,
recovery after unpin, exact owner retirement and PI6 user progress.

## Reproducibility and limits

The two F07 guest files are immutable recorded test evidence. Their
`addresses` and `simh.out` SHA-256 checksums are respectively:

| Guest | Addresses SHA-256 | SIMH output SHA-256 |
| --- | --- | --- |
| clean | `c890e777d5199a4ec8d3d7940be7e1b6e905345c892f6a9091055c6057103c3b` | `bcf4e6b2e42d0f0f845876b48d930399ed5b0866a4dd31c0d1c55626cd4524a8` |
| fault | `bb2721b75d51ef7341e6713358409dfbe86357a0ea84fbfd9cf0ce0e8f60ee7d` | `652144d0a6a186557c8c0fe3c042a480dcb3081bdda6779852475f0180940880` |

This accepts K01's bounded-retry/fail-closed physical MM ownership
contract. It is not a proof of every interrupt interleaving, or a
promise of successful recovery from permanently corrupt ownership.
The latter still requires the documented controlled offline
repair/restart policy; the kernel must never force-release an
unprovable extent. The separate K02 process-resource lifetime, K03
OOM policy and other KCORE backlog items are not closed by K01.
