# AAP timing vs DAIMOS kernel static coverage - historical v2

**Historical snapshot (2026-10-15):** static mnemonic occurrences in 74 `DAIMOS/system/kernel/**/*.s` assembly files; this includes files that may not be linked into a given image and excludes C-generated instructions. Do not interpret it as dynamic instruction frequency, model timing accuracy, or percentage of executed paths.

**Coverage proxy:** 16184 / 16675 (97.1% static-only). Source occurrence proxy only: passing one path per opcode does not validate all timing conditions.

| Mnemonic | Static source occurrences | At least one mapped real AAP timing fixture |
|---|---:|---|
| `MOVE` | 3231 | yes |
| `JRST` | 2442 | yes |
| `MOVEI` | 1146 | yes |
| `PUSHJ` | 1062 | yes |
| `MOVEM` | 699 | yes |
| `JUMPE` | 604 | yes |
| `PUSH` | 489 | yes |
| `POPJ` | 484 | yes |
| `ADD` | 423 | yes |
| `JUMPN` | 409 | yes |
| `LSH` | 408 | yes |
| `SETZ` | 347 | yes |
| `SUB` | 319 | yes |
| `ANDI` | 315 | yes |
| `POP` | 314 | yes |
| `ADDI` | 297 | yes |
| `HRRZ` | 265 | yes |
| `HLRZ` | 223 | yes |
| `CAIE` | 197 | yes |
| `SETO` | 144 | yes |
| `CAME` | 142 | yes |
| `SKIPN` | 136 | yes |
| `IOR` | 131 | yes |
| `CAML` | 129 | yes |
| `BLT` | 127 | yes |
| `CAIN` | 125 | yes |
| `CONO` | 121 | no |
| `SUBI` | 118 | yes |
| `TRNE` | 117 | yes |
| `CAILE` | 115 | yes |
| `JUMPL` | 105 | yes |
| `LDB` | 103 | yes |
| `CAMN` | 94 | yes |
| `TRNN` | 87 | yes |
| `CAIL` | 68 | yes |
| `CAMLE` | 63 | yes |
| `CAIGE` | 62 | yes |
| `TLZ` | 58 | no |
| `AND` | 56 | yes |
| `AOS` | 55 | yes |
| `AOJ` | 50 | yes |
| `TLNE` | 50 | no |
| `CONI` | 49 | no |
| `SKIPE` | 48 | yes |
| `TLO` | 48 | no |
| `IMULI` | 44 | yes |
| `HRL` | 40 | yes |
| `HRR` | 34 | yes |
| `IORI` | 29 | yes |
| `CAMGE` | 28 | no |
| `TLNN` | 27 | no |
| `MOVNI` | 25 | yes |
| `HRLZ` | 23 | yes |
| `HRRM` | 22 | yes |
| `MOVSI` | 21 | yes |
| `DATAO` | 19 | no |
| `JUMPLE` | 18 | yes |
| `IORM` | 17 | yes |
| `MOVN` | 16 | yes |
| `TDNE` | 16 | no |
| `DATAI` | 15 | no |
| `CAMG` | 15 | no |
| `ADDM` | 15 | yes |
| `CAIG` | 14 | yes |
| `JUMPGE` | 13 | yes |
| `XOR` | 13 | yes |
| `ILDB` | 12 | yes |
| `SOJ` | 10 | yes |
| `CONSO` | 10 | no |
| `HRLM` | 8 | yes |
| `DPB` | 8 | yes |
| `SKIPGE` | 7 | yes |
| `JUMPG` | 7 | yes |
| `IDPB` | 6 | yes |
| `TRO` | 6 | no |
| `HRRZS` | 5 | no |
| `XCT` | 5 | yes |
| `ANDM` | 5 | yes |
| `HLLZ` | 5 | yes |
| `CONSZ` | 4 | no |
| `SOS` | 4 | yes |
| `XORI` | 4 | yes |
| `ANDCA` | 4 | no |
| `TDNN` | 4 | no |
| `BLKO` | 3 | no |
| `XORM` | 3 | yes |
| `TRZ` | 3 | no |
| `BLKI` | 2 | no |
| `SKIPG` | 2 | yes |
| `DIV` | 2 | no |
| `AOBJN` | 1 | yes |
| `IBP` | 1 | yes |
| `ASH` | 1 | yes |
| `ANDCM` | 1 | no |
| `ROT` | 1 | no |
| `HLLM` | 1 | yes |
| `SKIPL` | 1 | yes |

## Remaining static mnemonic gaps

| Class | Unmatched occurrences | Main unrepresented mnemonics |
|---|---:|---|
| byte | 0 | - |
| block | 0 | - |
| call-stack | 0 | - |
| doubleword | 2 | div:2 |
| halfword | 5 | hrrzs:5 |
| conditionals | 43 | camge:28, camg:15 |
| logical-tests | 217 | tlz:58, tlne:50, tlo:48, tlnn:27, tdne:16, tro:6, tdnn:4, andca:4, trz:3, andcm:1 |
| interrupts-io | 223 | cono:121, coni:49, datao:19, datai:15, conso:10, consz:4, blko:3, blki:2 |

## DAIMOS-specific priorities

1. **Exception/PI/device I/O:** `CONO`, `CONI`, `DATAI`, `DATAO`, and related operations have no trustworthy timing characterization and need device-specific fixtures. Do not infer costs from opcode counts.
2. **Logic and control:** `TLNE`, `TLNN`, `TLZ`, `TLO`, `AOS`, `AOJ`, `SOS`, `SOJ`, and remaining `CAM` predicates warrant independent normal-path and boundary verification.
3. **Halfword stores:** `HRRM`, `HRLM`, `HLLM` and related modifying forms need direct memory-readback cases.
4. **Arithmetic:** `DIV` and overflow/carry boundaries are not adequately covered; the earlier IMUL boundary discrepancy remains unresolved.
5. **Memory and pointers:** `BLT` forward overlap is covered, but byte-pointer word-crossing, faulty/unmapped memory and memory contention are not.

## Why broad timing coverage is not yet certified

- The source proxy cannot measure instruction execution counts or hot paths in the **linked** DAIMOS KCORE/MRES images.
- A family match does not imply its addressing, operand, interrupt and exception variants are validated.
- At this original measurement stage the timing runners used short fixed waits; a later checkpoint below records the completed deterministic guest-stop change.
- The emulator logical ticks are not historical PDP-6 microsecond timings.

## Reproduction

`python3 "$PDP10_TESTKIT_REPO/tools/aap-kernel-coverage-v1.py" "$DAIMOS_REPO"`

`PDP10_TESTKIT_REPO="$PDP10_TESTKIT_REPO" python3 tests/validation/test-aap-kernel-coverage-v1.py`

Keep compiled C instruction profiles and exact linked-image inventory separate until obtained from actual instrumented runs.

## Post-milestone halfword-write evidence

Batch100 v11 covers HLLM, HRLM, HLRM, HRRM and six corresponding zero/one-fill forms with independent memory readback; remaining halfword self-update forms require separate coverage.

## AOJ/SOJ and AOS/SOS evidence

Batch100 v13 adds unconditional arithmetic jump forms and memory-modifying skip forms. Both outcomes and signed zero crossing were checked.

## Formal functional/timing acceptance gate

`pdp10-testkit/docs/PDP6-AAP-BROAD-COVERAGE-GATE-20261015-v1.tsv` enumerates 19
mandatory dimensions. `python3 "$PDP10_TESTKIT_REPO/tools/check-aap-broad-coverage-v1.py"`
reports their status; `--require-broad` fails until all are supported
by verified evidence or explicit justified exclusions. Initially only
9/19 are resolved. The static mnemonic proxy alone cannot satisfy this
gate.

## Reproducible batch runner update

All 1800 counted real guest cases now use a simulator-thread HALT
acknowledgement instead of a fixed host wait, with identical observed
complete logical-tick vectors before and after migration. A 20-workload
trace-on/off sample additionally verified guest result equivalence and
tick reproducibility. The broad-coverage gate still requires provenance,
linked image hot-path measurements and explicit exceptional-path work.

## Ownership update (2026-11-17)

This is a historical DAIMOS kernel assembly coverage snapshot, not a
current coverage percentage. The source-specific test and its profile
helpers now belong to `daimos-testkit`; generic AAP timing fixtures,
opcode mapping, and CPU simulator tests remain in `pdp10-testkit`.
The 2026-10-15 counts have not been recalculated by this move.
