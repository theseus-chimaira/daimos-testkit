# RC10/DF10 RM10 transfer regression v1967

    python3 -B transfer-v1967.py "$PDP10_PREFIX" "$TMPDIR/rm10-v1967"

Use a new work directory. The native KA10 simulator executes a real
DF10 control list and RC10 I/O instructions. Test 128-word DMA reads
and writes at logical blocks 0, 29, 30 and 2699, checking every word.
The original cec5436 simulator loses the final word of a 128-word
write (word index 127 is zero instead of the source value); abb7ee6
passes all eight transfers. This tests the hardware model, not the
DAIMOS driver. Full interrupt, NXM, media-error and driver lifecycle
qualification remains open.
