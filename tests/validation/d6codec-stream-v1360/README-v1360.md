# v1360: resumable grouped-codec refill reference

Status: executable host reference and current-DXR validation. This is
**not** a native low-core decoder, not an activated boot image, and
not proof of register/stack/relocation safety.

Run against the linked DAIMOS kernel/MRES DXR inventory:

```
python3 tests/validation/d6codec-stream-v1360/run-v1360.py \
  /path/to/DAIMOS/build/system/boot/pdp6
```

`stream_model_v1360.py` implements two independent streaming paths:
one fetches from a bounded window reader and one explicitly suspends
with return value +1 (`NEED_INPUT`) and resumes after the caller
provides the next source window. Return zero means *both* the exact
output count and exact compressed-input count have been consumed.
Malformed input raises `InvalidStream`, corresponding to -1 on a
native interface. The continuation retains only the current control
bitmap/token index, descriptor count/index, output history and at most
15 packed descriptor words. No entire compressed group or stream is
stored in the decoder's persistent scratch.

Native source comparison remains separate: this host model uses the
same grouped format, and the staged native v053 encoder's bit-exact
reference checks are covered by v1358/v1359.

The accepted current-build run checks all 27 linked DXRs under each
of six refill-window widths (1, 2, 3, 7, 16 and 64 words), for 162
independent successful continuations. It also checks ten malformed
cases at each width, a constructed 30-zero-run group requiring the
maximum 15 descriptor words, and empty stream semantics. All pass.
The current DXR set reaches five descriptor words in an ordinary group.

This is the architectural basis for a future compact PDP-6 assembly
implementation. The native code will still need an explicit low-core
placement/link contract, measured nested stack usage, full input and
destination physical geometry, provider refill/rollback tests and
rebuild of every compressed artifact during the atomic format change.
