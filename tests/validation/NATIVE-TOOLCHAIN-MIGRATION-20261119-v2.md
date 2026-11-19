# Native DAIMOS guest toolchain migration - 2026-11-19 v2

This migration restores 71 source, fixture, script and supporting files
from the standalone compiler testkit to their original DAIMOS testkit
locations under `tests/validation/`. The source-hash and path ledger is
`NATIVE-TOOLCHAIN-RETURN-20261119-v4.tsv`; it records the source paths
before transfer, destination paths, old hashes, and original v3 hashes.
All 10 C files are unchanged; shell wrappers and four Python root builders
have their repository-relative references repaired for this checkout.

All 25 native guest roots are registered in
`NATIVE-TOOLCHAIN-TESTS-v1.tsv` as `ready` for explicit selection. The
word `ready` means the files are present and dispatch is permitted; it
is **not** evidence that the tests pass. Several suites depend on earlier
staged full-boot images, KCC and DAS native builds, prior accepted
artifacts and installed tooling. The runner does not implicitly build
or satisfy those prerequisites and does not run in `make check` or
`make regression`.

Commands:

```
python3 tools/run-native-toolchain-v1.py list
python3 tools/run-native-toolchain-v1.py run TEST_ID
python3 tools/run-native-toolchain-v1.py run-all
python3 tools/test-native-toolchain-dispatch-v2.py
```

The first and last commands do not run any compiler or guest test. The
other commands are explicitly selected, potentially long-running and
require the original per-suite environment. An explicit run that fails
is still a failure; no pass has been inferred from static validation.

The prior v1 document described the preparation stage. The v3 split
manifest is preserved as historical input; the v4 return ledger records
this subsequent re-home. Run the PDP10 cross-boundary audit to validate
that each of the 71 old compiler-testkit paths is gone and DAIMOS now
owns the authoritative file.
