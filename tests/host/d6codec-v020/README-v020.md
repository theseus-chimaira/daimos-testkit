# v020 DXR corpus: forbid odd-distance halfword matching

C99 variant of the v006 two-stage research encoder, changing only the
halfword-match search to even distances (`hd=2; hd+=2`). It is not a
kernel compressor. The packed descriptor format is otherwise unchanged.

81 DXR image files were read from the original v006 results file, stripped
of DXR metadata/relocation bitmaps exactly as in the original benchmark.
Every image round-tripped through the unchanged v006 decoder for both
encoders. Results in `corpus-v020.tsv` and `summary-v020.txt`:

* 159973 uncompressed image words
* 131548 compressed words with unrestricted v006 matches
* 131556 words with only even halfword-distance matches
* +8 words, about 0.0061% of the original compressed size

This result is grounded in the recorded DXR corpus, not all possible
DAIMOS, boot, tape, swap or executable data. Further corpus coverage is
necessary before committing a universal encoding restriction.

Build using host C99, `codec_even_v020.c` and `source_even_v020.c`,
original v006 `codec_v006.c` and `source_v006.c`, and compare_v020.c.
The sources retain the original two-stage allocation strategy and are
not suitable for resident memory-constrained kernel encoding.
