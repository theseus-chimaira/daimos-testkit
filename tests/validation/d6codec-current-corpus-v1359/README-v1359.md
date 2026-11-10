# v1359: current linked DXR host corpus and native PDP-6 parity

Run with a DAIMOS worktree that already has a linked disk-root KCORE
and MRES package inventory under `build/system/boot/pdp6`:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-current-corpus-v1359/run-v1359.sh
```

The host generator discovers and validates current local `*.dxr`
artifacts, parses their complete 36-bit executable payloads with the
existing independent host DXR reader, groups word and zero-run tokens
with the `>=2` match threshold used by the staged native encoder, and
verifies full host encoded/decode roundtrips. It writes a TSV of the
actual inventory and word counts to `$TMPDIR/d6codec-current-corpus-v1359`.

Five real KCORE/MRES categories also have independently packed host
golden streams for the first up-to-128 words. The native PDP-6 v053
encoder through the v055 register-saving ABI must match the golden
36-bit words exactly; the decoder must restore the original words.
These categories are KCORE, D6FS, MonitorFS, SWAP and tape.

The first accepted run (DAIMOS v1358 isolated checkout, produced by
the fresh v1352 `permanent-size` build) found 27 parsable DXRs:
19,270 complete source words, 17,899 grouped encoded words. All
27 full host roundtrips and five native 128-word-prefix golden parity
tests PASS. No external historical paths or stale 81-DXR manifest
entries are used. This verifies *current kernel/package DXRs*, not
81 native userland applications, nor full-length native parity for
all 27 artifacts.

The generated assembly, results and simulator reports are transient
test evidence, not code or permanent resident KCORE storage. Nothing
about this test activates grouped compression in production images.
