# K03 physical refusal acceptance v1739

Date: 2026-11-21. Three independent 256K PDP-6 guests were run after
repairing the installed host DAS/DAS2 phase mismatch. Each test used
the production requester-only BRK OOM policy enabled, without a
production kernel source modification.

DAIMOS commit `2eb0b2ee38c29ad248b6f3c06e6abcd35bec49a1`;
testkit base `fbf1fe1a3871de211ad196a6fb370e19dbfe5c3e`;
KCC `1dca382`; DAS `aa74f42`. Test runner:
`tests/validation/daimos-k03-physical-refusal-v1733.sh`.

| Gate | Result | Transcript SHA256 |
| --- | --- | --- |
| `runparent` | PASS | `22305822df8686e0d2cc14cc2ba1c7a6252e4acf4c910cdf3c2f4b54fa53ab30` |
| `held` | PASS | `b9734d7ea54dae4a7dbd6e8eecb0c225527cd0bf086fcfa5410e4498067a0f66` |
| `permanent` | PASS | `534d3c50bd43541716e9ef0ba768c23f5866106b6a56e3bc0e336aaec1595b2b` |

`runparent`: a genuine exhausted MM descriptor table rejected RUN
with cause `-3`; no child remained. The independent parent survived
and its WAIT contract was observed. Requester-only OOM recovered MM
accounting.

`held`: requester OOM occurred while a foreign filesystem lease was
in flight and a real pre-dispatch waiter existed. Seven fatal-owner
busy retries preceded release. The foreign lease owner and independent
spinner progressed; MM accounting recovered, with no reported error.

`permanent`: a real MM wrong-owner `-4` refusal preserved the failed
owner and u-area. Seven invalid MM attempts and six bounded reaper
attempts were observed; the victim remained unreaped while the
independent foreign FS lease owner and bystander progressed.
No reclamation of the permanently refused resource is claimed.

The v1731 requester-owner source contract and v1732 transitive
release graph pass, including their unsafe mutation checks. The
v1283 production-policy source matrix also passes with
`V1283_PRODUCTION_OOM_DEFAULT=1`.

Scope: these results establish the listed independent physical
refusal/owner behaviors. They do not establish guaranteed cleanup
under permanent provider refusal (K04), complete 32K memory-budget
acceptance, or the separate default D6FS-root interactive login.
