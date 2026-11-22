# CAT/MAKE source consolidation regression v1814

Use the exact current DAIMOS source, not a stale installed binary:

    make test-cat-make-consolidation-v1814 \
      DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"

The C89 host regression compiles DAIMOS's real `libc/text.c`,
CAT-only `libc/cat_stream_v1814.c`, and `libc/u.c` with mocked native
word/character syscalls. Short reads (three words) and short writes
(two words) exercise the source reader and `u_write_words_all`.
The suite verifies zero, 7, 258, 259 and 1000 characters, exact S6REC
header/payload preservation when copying to files/pipes, long terminal
output with CR/LF, EOF, invalid record type and truncated payload.
The new CAT archive member must be linked only for CAT, so unrelated
native command images retain the original common `libc/text.c`.

The native gate independently runs production KCC and DAS on the
actual MAKE source and a fixed pre-change baseline at DAIMOS
`dbdc403f:userland/exec/make.c`. It inspects real KCC-generated
`main` stack frames and DOBJ section sizes, requiring at least
400 words saved and no BSS growth. Observed:

    before: main 01113 octal (587 words), TEXT 7876, BSS 839
    v1814:  main 00172 octal (122 words), TEXT 7748, BSS 839
    saving: 465 stack words, 128 TEXT words, zero BSS words

Both CAT and MAKE DXRs also linked from current sources. This is not
full guest runtime acceptance. The isolated v1814 attempted native
MAKE guest run stopped while building the boot image because DSH
TEXT was `036133`, exceeding the configured `036000` EXEC limit;
the guest test never reached SIMH. Its build evidence is preserved
under `$TMPDIR/daimos-native-make-common-simh-20261011-v1.*`.
Do not raise the limit just to pass a test. Investigate the source-
matched DSH size and re-run the guest option/goal and CAT long-record
cases after the root cause is resolved.
