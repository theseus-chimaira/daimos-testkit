# P0-A v1537: native guarded TSFS root loss routing

Date: 2026-11-13. Tested against DAIMOS v1536 plus the v1537
`tsfs_confirmed_root_member_loss_v1537` provider entry. No production
Type-551 permanent-loss detector is claimed.

Run:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-tsfs-confirmed-loss-v1537.sh
```

The script extracts the real `tsfs_root_owns_dtc_unit_v1516` and
`tsfs_confirmed_root_member_loss_v1537` assembly from current DAIMOS,
along with the actual fixed v1515 no-return HALT leaf. Every case runs
through `p10run --machine pdp6 --exec-mode step` and checks the real
linked HALT program counter or a normal zero return. The selected TSFS
root has public mount ID 4, live capacity 6, and physical root members
0 and 5 (`041` mask). Invalid contexts must not HALT.

| Case | Expected | Result |
| --- | --- | --- |
| Confirmed physical root member 0 | Root HALT PC | PASS |
| Confirmed physical root member 5 | Root HALT PC | PASS |
| Unrelated units 1 and 7 | Return 0, no HALT | PASS |
| D6FS-selected root | Return 0, no HALT | PASS |
| Invalid physical unit 8 | Return -1, no HALT | PASS |
| Root mount ID above live capacity | Return -1, no HALT | PASS |
| Missing physical root-member mask | Return -1, no HALT | PASS |

Four executed unsafe source mutants were rejected:
`no-owner-query`, `wrong-member`, `no-halt-dispatch`, and
`wrong-reason`. The last mutant is rejected by comparing the actual
boot-root HALT PC against the BACKSTORE HALT PC, not merely by seeing
that the simulator stopped.

The older v1516 script is also updated to extract exactly the v1516
predicate up to its own final `popj`. It no longer incorrectly links
later unrelated provider symbols. v1515, v1516 and v1517 native
regressions all PASS after that change.

The caller supplies a *trusted confirmed event* to exercise the
routing logic. This test does not inspect a physical transport or
prove that the Type-551 status bits distinguish a permanently lost
active root reel from a temporary selection or I/O error. No production
driver calls the new entry. P0-A positive physical evidence and
DSK/DRM/BACKSTORE role classification remain OPEN.
