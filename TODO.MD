# DAIMOS testkit - open work

Updated 2026-11-17. Only unresolved OS-testkit work belongs here.
Completed v1062-v1064 checkpoint notes are preserved in Git history;
older verification observations are retained in `STATUS.MD` and the
historical status archive. Do not treat a dated 2026-09-30 run as a
current complete regression result.

## Native toolchain integration after re-home (2026-11-19)

- [ ] Run the 25 relocated guest-native KCC/DAS/DLINK suites individually
  with their prerequisite staged builds and check their original oracles.
  Static fixture and dispatch validation is not guest execution evidence.

## P1 - complete DAIMOS regression acceptance

- [ ] Obtain a clean, source-fingerprinted **full** `make regression`
  result covering host checks, direct PDP-6 OS target tests,
  KINIT/KCORE/MRES size/boot, process/TTY/IPC, scheduler, MM, storage,
  D6FS/TSFS/DTFS, DSH and root/login paths.
- [ ] Independently reassess the 2026-09-30 pre-DSH failure: the last
  recorded serial run reached compressed boot-source and root classes,
  then timed out in the auto-root all-media case. Recheck against the
  current DAIMOS revision before claiming this is still the blocker;
  do not raise timeout limits to hide a real fault.
- [ ] Verify the remaining v72 startup-snapshot and optional SYSINFO/
  48K MonitorFS stress cases only if their original interfaces are
  reintroduced and independently validated. Do not restore obsolete
  tests just to increase the test count.

## P1 - INIT configuration and runtime policies

DAIMOS owns administrator policy in INIT, not KINIT. Add acceptance for:

- [ ] Additional/nonessential mounts from `/CONFIG/FSTAB`.
- [ ] Swap reservation selection and activation.
- [ ] LOGSTORE reservation and service selection/activation.
- [ ] Failure handling that leaves the OS bootable and diagnosable.

Hardware discovery/root selection remains the stage-one/KINIT contract;
these administrative decisions must not be moved into the kernel.

## P1 - verify OS test registrations and ownership

- [x] Relocate 127 GCC/KCC/DAS/DLINK/ABI/optimizer source identities into
  `pdp10-testkit` (99 moved, 28 deduplicated); receive 23 DAIMOS OS
  sources/validators. Preserve original assertions and C/ASM fixtures.
- [x] Split recursive OS `RM -R` from the independent native KCC MAKE
  suffix/CLEAN assertions. Add a registered, cross-repository static
  owner/path/fixture guard and eight fast relocated OS host checks.
- [ ] Audit **indirect and dynamically dispatched** DAIMOS OS scripts,
  update their active registrations, and verify actual runtime
  execution where necessary. The 150-file static migration does not
  prove the full OS test suite has executed.
- [ ] Recheck historical compiler/toolchain-in-guest integration reports
  before interpreting their old paths as current OS test ownership.
  Native compiler assertions belong to PDP10 even when run under DSH.

The authoritative transfer is
`tests/validation/TESTKIT-SCOPE-MIGRATION-20261117-v3.tsv`, with the
readable explanation in the adjacent v3 Markdown document. Earlier
v1/v2 snapshots are available through Git history.

## P2 - harness and documentation

- [ ] Improve CTY input/line-terminator injection when the SIMH console
  reliably delivers the required sequence. This is useful additional
  coverage but does not block v0.9 if DCS0/GE0 login is green.
- [ ] Reconfirm the current DSH and DTFS persistence probe inventory
  before publishing numeric totals. Older README counts were historical.
- [ ] Keep README.MD for stable usage and ownership, STATUS.MD for the
  latest verified checks, and this file for open work. Preserve older
  detailed checkpoint history in its dated archive, not in the active
  README/TODO.

## Acceptance discipline

No compiler/assembler test duplication in the OS suite. Do not hide
required failures with XFAILs, broad skips, longer timeouts or kernel
workarounds. The only release-grade result is a full, provenance-matched
DAIMOS OS acceptance sweep; isolated host/ownership checks are not a
substitute. Tools and compiler fixes belong in their production source
repos, with their tests in `pdp10-testkit`.
