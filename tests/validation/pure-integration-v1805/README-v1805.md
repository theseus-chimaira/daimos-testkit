# v1805 physical integration smoke

Use `run-dsk-smoke-v1805.sh` with the **default-OFF**
v1804 integration image. It checks a real 256K PDP-6 simulator
boot through DSK270, DRM236, D6FS and INIT/login and requires
that the guest remains alive until the controlled timeout.

Set `DAIMOS_REPO`, `PDP10_PREFIX`, and
`DAIMOS_BOOT_BUILD_V1805` (the directory containing the
previously built `boot.ini` and `kcore.map`).

This test does not install PURE, trigger RAW memory pressure,
exercise OOM or K01-K04 refusal, or inspect D6FS after guest
termination. It must not be treated as their acceptance.
