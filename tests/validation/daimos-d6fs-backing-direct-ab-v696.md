# v696: Direct physical backend experiment

An isolated experiment generates two valid PDP-6 assembly objects from the
current D6FS `fs_backing.s` source. The baseline retains four shared physical
backend JRST slots; the candidate patches conditional read branches and
root-accounting PUSHJ instructions directly while retaining fall-through
write JRST instructions.

The two read-entry JRST instructions can disappear, but **both write JRST
instructions must remain** to preserve branch fall-through. Therefore the
maximum *gross* source reduction in this variant is **two instructions**,
not the four initially hypothesized in v695. Root-accounting calls are
retargeted individually, which requires four additional MRES exports and
KINIT patch writes. MRES export metadata precedes the installed image in
the package (`mres_install` computes `image = package + MRES_HEADER_WORDS +
export_words`), so it is not automatically four resident instruction words.

The script assembles both variants with `das`; this is NOT yet a complete
MRES-linked comparison, native execution test, or proof that the candidate
preserves all error paths. The proposed direct read targets default to
`kret_neg1`; installed targets would be patched by KINIT. A future runtime
relocator needs all eight target sites (the ordinary I/O branches/jumps and
four root-accounting PUSHJ sites), not merely the old four slots.

**Decision:** defer a production change until a linked-size A/B and native
root-accounting + missing-driver regression establish a net improvement.
The existing packed per-descriptor callback selection remains necessary.

Run:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
python3 tests/validation/daimos-d6fs-backing-direct-ab-v696.py \
    "$HOME/git/DAIMOS" "$TMPDIR/daimos-d6fs-direct-ab-v696" \
    --assembler "$HOME/cross/bin/das"
```
