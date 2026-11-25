# D6FS ordinary I/O failure and PURE backing availability, v1929

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-d6fs-loss-v1929

The extended v1927 native guest links the real D6FS ordinary block
read/write leaves, backing dispatch, mounted identity verifier, cache
invalidation and root I/O fail-stop classifier. Six new assertions
(0300..0305 octal) exercise read failure, foreign and original UUID
retry, wrong-reader isolation, write uncertainty, refusal to reconcile
it through identity proof and simultaneous read/write uncertainty.
A failed source's private clean tag is invalidated; another source's
tag survives. Twelve earlier header faults/retries and the mount
lifecycle cases remain covered. Ten unsafe variants are rejected,
including six added v1929 controls. The test fixture deliberately
restores RO state before the independent retirement exercise; this
is not a production write recovery procedure.

The extended v1926 gate has 118 DROP cases, including exact D6FS
READ_SUSPECT, WRITE_UNCERTAIN and combined flags on low/high mounts.
Six unsafe mutants fail, including a removed D6FS availability check.
Earlier v1513, v1538, v1544, v1546 and v1602 native gates pass. Their
source extraction includes the actual new fault leaf. The v1602
negative clean-publication control now injects its false clean tag
after failure invalidation, to test an actual unsafe publication.
Actual controller completion, full guest physical media replacement
and PI6 concurrency remain outside these controlled native tests.
