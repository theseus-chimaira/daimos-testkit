# v1326: preserve guest-only milestones across SIMH GO prompts

The v1324 sampler fixed the premature-normal-HALT sample-budget
error. Inspection of the current physical v1323 F07 guest exposed
another preexisting diagnostic limitation: SIMH can print `sim> `
after a read-only debugger GO, immediately before subsequent guest
console characters. The prior running-phase parser copied this
prompt into the canonical guest transcript, even though the raw
SIMH debug log was stored separately. A strict milestone comparison
may therefore fail for reasons unrelated to the simulated kernel.

The versioned v1326 implementation applies one streaming filter
for SIMH's exact `sim> ` prompt throughout normal execution and
post-HALT examines, preserving a four-byte tail across PTY read
boundaries. All unmodified bytes remain in the raw debug log; the
canonical guest log contains only guest and normal postflight output.
The read-only sample count is still a maximum, not a required number
when the guest HALTs and SIMH completes its EXIT cleanly.

The v1326 selftest models an actual GO prompt immediately before
HALT and asserts that only the raw log contains `sim> HALT`, while
the canonical guest transcript has no SIMH prompt. It retains the
early-HALT success case, rejects a truncated EXIT without `Goodbye`,
and reruns v1324 and v1306 compatibility checks. The test **does not**
replace any full-guest functional, physical-MM or backing-storage
acceptance; those remain independent strict verification steps.

Use `make test-daimos-simh-swap-live-sampler-v1326` to verify.
No production DAIMOS code, resident RAM or kernel image is changed.
The already running v1323 guest still uses its original v1306 sampler;
v1326 cannot retroactively change that evidence.
