# v1324: correct early-HALT handling in read-only PDP-6 sampling

The v1306 sampler requested a fixed number of diagnostic samples.
If the simulated guest HALTed normally before the last requested
interval, it exited with a diagnostic error despite a complete guest
HALT and normal SIMH postflight. This could mask the *real* test
failure (e.g. v1322's original `!t` owner-allocation rejection) or
reject a legitimate fast guest. The diagnostic sample budget should
not be part of functional acceptance.

The versioned v1324 sampler retains v1306's exact read-only Ctrl-E,
examine and GO, original-boot-file preservation, canonical clean guest
transcript, raw debug log and bounded timeout. It now treats `--count`
as a maximum, not a mandatory minimum, when SIMH has genuinely
completed a guest HALT and its postflight EXIT. It still rejects:

* nonzero SIMH exits;
* simulator exit without an observed guest HALT;
* truncated postflight without the normal SIMH `Goodbye` marker;
* missing/malformed linked counter addresses;
* failed or timed-out diagnostic requests.

The test runner, not the sampler, remains solely responsible for the
guest process milestones, real MM allocation errors, swap cooldown
classification and zero resource leaks. A successful v1324 sampler
is **never** full-system no-partner liveness acceptance.

The v1324 stub self-test exercises both normal early HALT (one actual
sample of a requested four) and a simulator whose postflight exits
without `Goodbye`; it also reruns the prior v1306 source checks.
No DAIMOS production code or persistent KCORE/MRES words are changed.

Run `make test-daimos-simh-swap-live-sampler-v1324` from the testkit.
The versioned new simulator wrapper must be selected explicitly in
future disposable guest runs; it does not change currently running
v1306 sampler processes.
