# Concurrent HISTFILE audit — 2026-10-11 v1

Source inspection found that the kernel's regular-file O_APPEND sets its
per-descriptor offset to `st.size_words` at OPEN, while later WRITE_WORDS
uses that stored offset without reacquiring end-of-file. Two descriptors
opened before either write can therefore share the same append location.
This is a real semantic gap, not merely a missing two-session test.

The host audit detects this known unsafe implementation and prints
`KNOWN UNSAFE`; its zero exit status means the audit detected the defect,
**not** that concurrent append is accepted. Correct remediation requires
atomic end-of-file reservation/append semantics across processes and a
subsequent live two-session SIMH test. Merely retrying the DSH write cannot
make the append position atomic. DSH also ignores a partial WRITE_WORDS
return; record integrity/error handling needs review.

The read-only-root and injected publication-error runtime tests remain open;
the shutdown guard source-contract test is not an injected I/O failure test.
