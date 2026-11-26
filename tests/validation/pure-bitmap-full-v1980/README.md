# v1980 staged bounded directory-bitmap FULL restore

Run `make test-pure-bitmap-full-v1980 DAIMOS_REPO=/path/to/DAIMOS`.
The native PDP-6 and KA10 matrix starts with the v1979 real DROP,
then overwrites released memory and invokes the staged restore.
Links the real allocator/pin/free/atomic finish, PI gate, directory
codec, backing unpacker, bounded DXR loader and fixed low-core block
codec. The fixture copies the actual fixed decoder image to 062.
Only VFS payload/metadata publication and explicitly selected MM/I/O
fault replies are controlled; no physical filesystem is mounted.

Each target executes 52 restore calls. Plain and compressed DXR2
backing, exact mutable overlay including zero words, actual no-fit
and descriptor exhaustion, capacity overrun before payload read,
partial read, changed mount, malformed executable/bitmap streams,
changed process/owner/pin identity, false and lost MM replies,
rollback refusal, failed source pin retirement and hard write fault.
Verify actual PI enabled during load/decode/compare and disabled at
MM commit. Force reuse of the released bitmap extent; overwrite it
and verify complete restored APR. No installed scheduler dispatch.

Six source mutations must reach native assertions: missing compare,
trust finish reply, missing pin proof, missing post-I/O identity or
owner proof, and ignoring target-free refusal. The old RAW FULL
v1839/v1855/v1919 suites remain independent regression tests.
