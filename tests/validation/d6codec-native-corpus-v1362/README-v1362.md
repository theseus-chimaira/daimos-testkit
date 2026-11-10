# v1362: native streamed current-DXR golden prefix matrix

Test the isolated, assembler-only `d6codec_stream_v1361.s` decoder
against five independently host-encoded, current-build DXR prefixes:
KCORE, D6FS, MonitorFS, SWAP and tape. Each fixture contains up to
128 original words. The complete grouped encoded prefixes are passed
to the native decoder with source windows of 1, 7 or 64 words.

The generator uses only the actual DAIMOS checkout's linked DXR files
under `build/system/boot/pdp6`; it does not use stale absolute paths.
For each test the native PDP-6 must return NEED_INPUT until the
declared compressed stream is consumed, return zero on exact
completion and reproduce every original 36-bit source word.

Run:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-native-corpus-v1362/run-v1362.sh
```

This is an unlinked native decoding test, not Stage-1 boot, KCORE
runtime or a complete native decode of all current 27 DXR images.
The decoder's 26-word caller state is held in the test image BSS,
not in permanently resident production kernel storage.
