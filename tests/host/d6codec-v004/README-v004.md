# D6 codec v004: executable load-image corpus and decoder specialization

Experimental research only, not a production DAIMOS change.

The benchmark parses each DXR/DXR2 container, validates its declared image
length and relocation word count, and compresses only the executable load
image. It excludes the DXR header and relocation bitmap. All three codec
variants must round-trip the exact original load image.

The v004 decoder specializes halfword matches with even halfword distances to
straight 36-bit word copies, retaining halfword extraction for odd distances.
This avoids two halfword extraction/insertion sequences per word for aligned
matches. It does not alter the format or encoder decisions.

Reproduce from the daimos-testkit root (replace /path/DAIMOS appropriately):

    cc -std=c99 -O2 -Wall -Wextra -Werror \
        tests/host/d6codec-v004/codec_v004.c \
        tests/host/d6codec-v004/test_v004.c -o /path/test_v004
    /path/test_v004
    cc -std=c99 -O2 -Wall -Wextra -Werror \
        tests/host/d6codec-v004/codec_v004.c \
        tests/host/d6codec-v004/bench_dxr_image_v004.c \
        /path/DAIMOS/tools/host/d6lz-codec.c -o /path/bench_v004
    /path/bench_v004 /path/DAIMOS/build/.../userland/program/*.dxr

The recorded corpus consists of 81 compiled uncompressed DXR images from the
2026-10-13 build tree. Totals in 36-bit words: original image 159973,
D6LZ36 140835, v004 word-only 140835, v004 halfword 135515. All 81
round-trip correctly. The halfword decoder advantage is 5320 words (3.78%
of D6LZ36 compressed size). This is NOT a resident code size benchmark, and
no PDP-6 dynamic instruction counts have yet been measured. Further malformed
stream testing and overflow review are required before kernel integration.

Production kernel and pdp10-doc left unchanged while codec remains experimental.
