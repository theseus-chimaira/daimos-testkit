# DAIMOS guest-native toolchain migration: preparation v1

This repository will own the 25 explicitly selected guest-native KCC,
DAS and DLINK suites previously registered as manual tests in
`pdp10-testkit/SPECIAL_TESTS.tsv`. The source scripts and companion
fixtures have **not yet moved**. This stage creates a destination
registry and fail-closed dispatcher only. All 25 entries are marked
`pending-migration` and cannot execute.

Run `python3 tools/run-native-toolchain-v1.py list` to inspect the
planned identities. `run ID` returns status 2 for pending entries;
`run-all` skips them. `python3 tools/test-native-toolchain-dispatch-v1.py`
validates this without launching DAIMOS, compilers or simulators.

The next stage must transfer complete fixture directories, repair
repository-relative paths, preserve staged-build dependencies, verify
oracles, and update the cross-repository ownership manifests/audits
before activating any test. No normal DAIMOS or compiler sweep may
include this opt-in runner.
