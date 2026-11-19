# v1613: PDP-6 physical diskless TSFS PURE boot

The test builds a real 64K PDP-6 lowmem GCC TSFS image
with the opt-in PURE MRES, then boots it under SIMH with
all DSK and DRM media attachments omitted. It requires:

* KINIT package `proc_pure_mres_package_v1612`;
* actual 64K PDP-6 physical simulator and DTC root probe;
* the transient KINIT console witness `PURE LOADED`;
* userspace `INIT V1` and no root/INIT failure;
* a simulator still running until the controlled test timeout.

Run from daimos-testkit:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-boot-v1613/run-v1613.sh

For a previously built matching opt-in image, set
`PURE_BOOT_BUILD_V1613=/path/to/build`; the script will
still launch a real PDP-6 simulator with all AUX media
unattached. `KEEP_TEST=1` retains the console evidence.

This establishes boot reachability and actual PURE MINIT
selection, **not** completed RAW reclaim/slot-0 wake or
positive net RAM savings. The experimental build flag
`DAIMOS_PURE_MRES_ENABLED` stays OFF by default.

Use `pure-boot-select-v1613` for isolated actual KINIT
source selection. The separate exploratory large-child
pressure workload and its known negative evidence live in
`tests/diagnostics/pure-pressure-v1613`.
