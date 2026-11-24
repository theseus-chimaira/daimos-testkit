# K05 v1905: physical original RAW PURE foreign-owner mispublication

Date: 2026-11-24. **Original 48K PDP-6 defect REPRODUCED**.
This is a deliberate invalid MM ownership fault injected after an
actual failed FULL restore. It is not a legitimate allocator
ownership transfer and is not a successful K05 acceptance test.

## Original machine sequence

The byte-identical v1903/v1904 fixed KCORE and optional PURE MRES
boot compressed TSFS and run the five original PIPE/BRK/RUN children.
The first original `mm_free(PACKED)` genuinely returns -5 while
the RAW source at `111200..120000` is test-pinned, leaving the
complete provisional PROCESS target at `120000..130000`.
Slot3 stays TRANSITION-held, VMbase0, with its private saved
executive continuation and the original MM count of 18.

After the external source pin is released, the physical controller
changes ONLY target MM metadata at `024725` from owner3/type1/pin0
`000001000003` to owner2/type1/pin0 `000001000002`. The target
physical address and full extent size do not change. This is an
explicit error injection, not a kernel MM call or a valid foreign
reallocation. The independent resident parent descriptor at
`024727` is not touched.

The ORIGINAL compiled C recovery then reaches its original
TRANSITION-clear PC `033313`. Physical MM count is STILL 18.
The RAW source at `111200..120000` is correctly retained but the
original full target at `120000..130000` survives under owner2;
nevertheless slot3 TRANSITION is clear with VMbase0 and its
recovery retry marker has been retired. No native target free
was performed. This violates the intended original FULL target
ownership proof: it can misclassify an orphaned PROCESS owner as
an unrelated allocation and unblock a child prematurely.

The v1902 native suite had explicitly permitted sole RAW unlock
after a target appeared to be assigned to another owner. That
old assertion is insufficient to distinguish a legitimately
unrelated foreign extent from the *same* failed FULL target with
corrupted ownership. The missing information is the original
temporary full target base, not an additional owner-free policy.

Original fixed KCORE SHA256:
`a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`.
Original optional PURE SHA256:
`55be5113d4d15fe5c4a44409dca22afd463c75f05f661b3f8f71451a057c577f`.
Exact accepted BUG REPRO transcript SHA256:
`660ca0198938bc52cb1a4496f00116d78e390e58905e94062b157c074db70ba1`.
Local defect transcript:
`$TMPDIR/daimos-k05-foreign-target-v1905-physical-v1/`.

Run with `V1905_BUILD` set to the previously accepted original
v1903 source-built `build` directory and `V1905_PROBE` to its
source-linked PURE installed-base probe:

    make test-pure-k05-foreign-repro-physical-v1905

The v1906 follow-up changes only optional PURE MRES and the
existing u-area retry-word interpretation. It records the exact
original target base and refuses to unlock if that address
remains allocated to *any* owner or overlaps an MM descriptor.
This test remains an explicitly versioned historical defect
reproducer; do not rewrite it to accept unsafe behavior.
