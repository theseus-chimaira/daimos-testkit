# KCORE v1542: physical Type-236 BACKSTORE fail-stop

Date: 2026-11-13. Accepted full 256K KCC PDP-6 guest test.
This is a physical controller-completion test, not a synthetic
negative return or permanent drum-detachment detector.

## Proven sequence

The v1541 full-guest test builds a disposable, matching-source
KCC PDP-6 disk-root image and runs the real F07 swap workload.
Its test-only source instrumentation reuses v1511's actual
Type-236 PI2 controller error completion. It selects the first
physical BACKSTORE WRITE after swap is enabled and owns blocks.
All transfers still pass through the real Type-236 driver and
the unchanged production fixed BACKSTORE transfer gateway.
No injection code is installed into production DAIMOS.

The accepted v1306 SIMH sampler, constrained to seven linked
fields for PTY reliability, recorded four clean pre-failure
snapshots with zero PI2 injected errors. The physical controller
completed one selected WRITE with a real PI2 error return.
Fixed KCORE v1541 then HALTed before process-swap retry.

| Witness | Actual octal |
| --- | --- |
| Linked v1515 fatal entry | 003740 |
| Physical HALT PC | **003747** |
| Selected PI2 error counter | 000001 |
| BACKSTORE enabled | 000001 |
| Allocated BACKSTORE blocks | 000320 |

The terminal HALT was precisely v1515+7, the BACKSTORE-specific
instruction (root is +3, invalid reason is +9). The old v1511
post-error F07 continuation is intentionally superseded and its
original runner returns nonzero; the v1542 physical oracle passes.

The strict source-linked validator,
daimos-backstore-physical-verify-v1542.py, independently checks
the linked KCORE map, original SIMH console, raw post-HALT linked
word examinations, actual v1541 gateway and injected Type-236 PI2
source, and pre-error samples. All **nine** corrupt-evidence
mutations are rejected, including wrong reason, duplicate HALT,
missing controller error, false ownership, missing gate/driver,
and a false pre-error baseline.

To reverify the saved guest without another full simulator build,
pass the evidence guest directory to the reusable script:

```
sh tests/validation/daimos-backstore-physical-accept-v1542.sh GUEST_DIRECTORY
```

The full v1541 physical runner also invokes this same stricter
v1542 source/map/trace verifier and all nine mutation controls.

## SHA-256 of accepted disposable physical evidence

The original runtime directory was
$TMPDIR/daimos-oom-requester-live-v1075.BbvZyf.

| Relative path | SHA-256 |
| --- | --- |
| simh.out | da51dd455a94e1065e4274049de7b13836f6d2d2b7b644c5f57a26fa5cb57533 |
| simh.out.raw-v1306.log | 87452c844892ecf41359609b4350424bc8c62128961737c283a92e0ae75b4a5f |
| simh-sampler.log | 139234d53e14aa5824ab7c4a0f42eb457b0120ae6237a66ee7f8918a79743238 |
| build/system/boot/pdp6/kcore.map | eae83de5108b6ca20b04e56c729bb19e9208caad6cd532d0a16f3235946bfe00 |

## Scope

Native v1541 covers actual PDP-6 direct DSK270/DRM236 read/write
and mapped VOLUME service errors: 17 cases and six unsafe source
mutations PASS. Physical v1542 confirms a booted real Type-236 PI2
BACKSTORE failure and its distinct HALT PC. It does not prove
permanent physical drum removal, alternate disk controllers,
the independent secondary DSK/DRM negative matrix, or simultaneous
root/BACKSTORE faulting. Those remain separate KCORE P0-A checks.
