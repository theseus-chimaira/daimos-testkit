# v735 — DSK watchdog recovery and swap-pressure provenance

The corrected lowmem PDP-6 v734 image is CLEAN and its DSK watchdog
decrements the active-request LH tick counter in memory (v734 PASS).
An exploratory 65-second native run on a private copy reached
`proc_wait_event` and idle but did not reach the disk failure handler;
the bound expired at the idle PC. This is **inconclusive**, not a
watchdog-timeout pass or a demonstrated failure. No incomplete timeout
test is shipped as acceptance.

The v737 pressure runner independently checks the installed test INIT
by a hash attestation. Attempting to reuse the clean v734 lowmem image
through the v670 wrapper was correctly refused:

```
reused D6FS fixture has no verified pressure-test INIT;
rebuild using SYSTEM_INIT_DXR
```

Consequently the earlier scheduler idle observations are ordinary-INIT
diagnostics, not evidence of a swap-pressure regression. The next
acceptance run must build fresh disk media with the actual test INIT,
verify its installation, then perform workload and error-path assertions.
No kernel changes or production completion claims follow from v735.
