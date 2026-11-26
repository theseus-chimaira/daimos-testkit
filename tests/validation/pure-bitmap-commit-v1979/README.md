# v1979 staged prefix bitmap commit validation

Run `make test-pure-bitmap-commit-v1979 DAIMOS_REPO=/path/to/DAIMOS`.
The native PDP-6 and KA10 tests link the production codec, prefix
lease, MM commit primitive, reclaim selection and real MM allocator.
The legacy RAW gates are extracted unchanged from production source;
no live restore dispatcher or scheduler is enabled. Controlled backing
and fault fixtures are inherited from v1978.

Each target executes 47 commit/reclaim operations. The matrix covers
canonical word equality, corruption, stale/foreign owners, capacity,
pin provenance, lost success replies, false success, refused commit
and RAW cancellation, and exact allocator reuse. A complete 1024-word
resident image becomes one 176-word bitmap owner; all 848 released
words can be reused and overwritten before exact decoding.

Six deliberately unsafe source variants must reach native assertions:
no comparison, trusting a reply, retaining a pin, skipping a duplicate
owner, skipping capacity, and skipping the pin witness. A compiler or
linker failure is not accepted as a rejected mutant.

No installed mode3 support is implied by these tests.

v1984: two additional real reclaim cases exercise an RT lease on the
victim or another slot. Require unchanged RAW publication, no codec or
bitmap commit and unchanged RT ownership. Both RT-specific mutants
(codec allowed under lease, ordinary RAW wrongly refused) must reach
native assertions. Total49 operations/CPU and eight unsafe controls.
All directory prefix/commit/FULL/service/terminal runners now accept
`PURE_TEST_COMPILER_V1984=gcc` for production-compiler validation;
default remains KCC.
