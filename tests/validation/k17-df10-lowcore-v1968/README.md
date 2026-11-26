# KA10 DF10 low-core allocation v1968

Build a native 64K KA10 image as in ../k17-roots-v1967/README.md.

    python3 -B isolation-v1968.py BUILD "$PDP10_PREFIX" "$TMPDIR/df10-lowcore-v1968"

The fixture deposits the actual linked KCORE initialized image and
sentinel-filled BSS in physical memory. It runs separate native RC10/DF10
128-word read and write transactions through the allocated 0150/0151
pair, with a nonzero APR shadow at 0147 and buffers above KCORE. It
checks every resident word outside that pair, the precise completion
word, all transfer data, and the read-buffer guards. This is a hardware
isolation test, not a live kernel driver or concurrency test. The updated
v1967 boot harness verifies live APR and unused DF10 words for both
no-drum root profiles. The v1961 Stage1 identity test verifies that the
extra three initialized words do not enter the shared decoder itself.

v1969 extends the workspace to two pairs (0150/0151 and 0152/0153).
Run both independently on the new linked image:

    python3 -B isolation-v1968.py BUILD "$PDP10_PREFIX" "$TMPDIR/df10-v1969-pair0" --pair 0
    python3 -B isolation-v1968.py BUILD "$PDP10_PREFIX" "$TMPDIR/df10-v1969-pair1" --pair 1

The inactive pair contains distinct sentinel words and must survive the
active transfer unchanged. These are separate read/write transactions;
concurrent transfers through independent controllers remain unqualified.
The updated native boot harness verifies all four unused channel words
are zero on both root configurations.
