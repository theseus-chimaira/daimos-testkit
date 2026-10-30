# v735–v737: disk-wakeup validation and pressure-INIT fixture gate

The v734 native PDP-6 image confirms DSK270 watchdog decrement, but
the v735 post-idle breakpoint on the disk failure handler did **not**
fire within a 65-second wall-clock bound. This is NOT a full-timeout
recovery PASS or proof of a missing failure path.

The v736 native breakpoint sequence was `proc_wait_event` (`013235`),
`proc_idle_loop` (`014102`), `proc_wakeup_event` (`013335`). At wakeup,
the original INIT disk completion channel `034745` contains `1` and
`storage_state` is zero. The disk completion event/wakeup path therefore
executes successfully on the corrected clean image.

The prior v712–v735 scheduler-pressure runs reused an ordinary clean
D6FS image and compiled the pressure test INIT separately, but the v669
reuse path did not install that INIT into the existing disk media.
`INIT V1` in those logs is the ordinary INIT, not evidence that the
pressure test started. Five-minute timeouts must not be reported as
full-system pressure-workload failures.

v737 makes the reused-image path fail closed unless the image carries
an exact SHA-256 identity for the test INIT compiled by the runner.
The identity is written only after a new full image build using
`SYSTEM_INIT_DXR` and copied along with isolated media by v670.
This is a build-fixture provenance assertion, not an independent
extraction or cryptographic proof of D6FS file contents; neither a
generic clean image nor a manually supplied stale marker is acceptance.

The gate rejected the ordinary v734 boot fixture with the expected
message `reused D6FS fixture has no verified pressure-test INIT`.
Acceptance still requires executing a freshly built, correctly installed
pressure-test INIT and seeing the workload's success markers.
