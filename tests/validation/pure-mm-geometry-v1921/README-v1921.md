# K06 integrated MM geometry and FULL reply checks, v1921

Run against current DAIMOS using the installed native toolchain:

    DAIMOS_REPO=$HOME/git/DAIMOS sh tests/validation/pure-mm-geometry-v1921/run-v1921.sh

Six native FULL transaction cases inject false successful source and
scratch pins, foreign source retag after target unpin, foreign target
retag during rollback, false successful source free and foreign source
retag on reported successful deletion. Checks include exact retained
owners and pin counts, no writes before target pin proof, no premature
publication, escrow, backing, suffix contents and balanced PI.
Five geometry cases exercise the sole and FULL scanners with sorted
adjacent independent namespaces, unrelated unsorted/overlapping ranges,
physical address overflow and descriptor capacity overflow.

Seven independent executed unsafe mutations fail at octal assertions
0103, 0203, 0310, 0407, 0502, 01012 and 01012, respectively. Native
v1395/v1397, v1612, v1839, v1855, v1902, v1906, v1918 and v1919 gates
also pass. Historical v1839 and v1855 mutation anchors are adjusted to
the new source without changing the required native assertions.

The actual MM rebase/claim/commit/release assembly is linked; the
allocation, pin/unpin, free, loader and PI operations are controlled
fixtures. This gate does not prove managed-arena table integrity or
physical PI6 acceptance. The existing terminal v1920 gate is separate.
