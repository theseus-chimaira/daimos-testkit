# KCC induction pointer call-safety regression v1395

The v1373 host KCC incorrectly carried an array destination address in
one physical PDP-6 register across a function call inside a `for` loop.
The call spilled and relocated that pointer, but the loop back-edge still
incremented its former register. This could corrupt other memory, including
KIR1 symbol records inside native KGEN.

The minimal C89 fixture verifies both `-O` and `-O=gen` lowering of a
function call into an array; the independent call-free fixture ensures
the existing fast induction-pointer sequence remains available.

Run the host source regression in a fresh, isolated directory:

    HOST_KCC=/path/to/kcc sh tests/validation/kcc-indptr-call-v1395/run-v1395.sh

Expected: original v1373 host compiler FAIL; v1395 with the strengthened
loop-hazard check PASS. The native grouped D6FS acceptance uses the existing
strict `kcc-kir-global-v1390` gate, which must still report **4/6** until
the unrelated standalone KGEN UUO/126 crash is corrected. The v1395 host
test does not claim that native self-hosting or the full toolchain passes.
