# v1981 staged directory bitmap slot-zero service

Run `make test-pure-bitmap-service-v1981 DAIMOS_REPO=/path/to/DAIMOS`.
The native PDP-6/KA10 fixture reuses the actual v1979 DROP and v1980
FULL transaction, bounded DXR loader and physical MM/PI leaves. It
links the complete production PURE service, including RAW recovery,
not a substitute dispatcher. The fixture supplies scheduler requests
and controlled VFS/MM fault replies; it does not run the scheduler,
PI6 delivery, actual physical I/O, EXIT or WAIT.

Each target executes 46 service/unlock calls: plain/compressed restore,
lost successful restore reply, READY_ONCE not reissued as a restore,
clean short-read/no-fit/pin/commit/mount failure followed by successful
retry, dirty transactions refusing old RAW recovery and new requests,
service eligibility and exact clean-unlock refusals. Five executed
unsafe source variants must reach native assertions (not build errors).
The v1980 FULL suite is an independent regression.
