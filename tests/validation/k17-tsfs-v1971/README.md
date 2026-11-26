# v1971 KA10 CTY configuration and TSFS/RM10 swap

Stock v1970 lowmem INITTAB selected only DCS0, which was
not installed on KA10. Both disk roots reached INIT but
reported NO INITTAB. DAIMOS d8ac3b25 selected CTY0 for
the native KA10 lowmem profile; unchanged KCORE/KINIT.
Both disk-root CTY sessions passed login, PWD, ECHO,
TRUE, logout/respawn, backing map and zero used blocks.
Superseded by v1972 DCS+CTY profile. The historical
shell-v1971.py runs only the two disk cases; TRUE is not
present on stock TSFS. Earlier CTY-only tape runs stopped
after INIT and were not accepted as interactive.

Same six-child v1955 fixture with native 64K KA10 tape
root and RM10, pre-DCS build v1970. Original four tapes
unchanged. A/B/C MM9/20/8 free42726/182/42740; bitmap0/64/0;
slot2 8192-word DISK run0..63; drum reads2/2/66 writes0/64/64
errors0. Six exact canary/token/WAIT checks, stable owners
and pipe cleanup. Unchanged AUXSTORE descriptor and
reserved region; physical backing data written.
Original disk-only oracle rejected storage_count0200 at
all three gates. Forward DTC uses hardware IOWD and
tape_wait_done clears storage_state, not last positive
transfer length. Corrected explicit root=tape oracle
requires state0 and count0200, and rejects count0,
0201 and negative count; original disk oracle still
requires count0 and reproduces its earlier report.
No production storage change.

Evidence $TMPDIR/k17-tsfs-v1971.QRmruU/swap,
shell-r2 and stock-{tape,disk}. Console SHA256
f6e085cb1016da0c298c0ca7bed228e1d5d94f6cf8a5af158494226c8475c1d9.
Run same original pressure fixture, KA10 ROOT=tape:
    V1971_ROOT=tape sh ../k17-rm10-v1970/run-swap-v1970.sh BUILD WORK
The newer v1972 DCS-installed TSFS pressure remains
a separate regression.
