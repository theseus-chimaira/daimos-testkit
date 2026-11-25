# K07 persistent provider identity, v1924

Run the native gates with the installed PDP-6 tools:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-provider-identity-v1924

The first gate links the actual RAW DROP, PREFIX, FULL and backing
unpacker. Nine cases replace an originally attached D6FS provider with
one of the three other supported providers before DROP, PREFIX or FULL.
Each refusal retains the exact original extent, suffix, backing and
transition, with no allocation or free. The decoder independently
refuses the replacement and accepts the original provider again.
The unsafe decoder and DROP admission variants fail guest assertions
0403 and 0402 octal respectively.

The second gate executes the original RUN credential-publication
instructions for all four providers, both mount-extension bits and
both SIDL rollback states (16 cases). Parent credentials and scheduler
state are unchanged. Removing the provider transfer fails assertion
020 octal. The v1563 native attach fixture now checks all four providers
in staged and stable processes, preserving the SIDL rollback flag and
SRUN link. The v200 real EXEC replacement leaf checks old/new provider
identity at destruction, rollback and commit for all eight existing
cases, as well as the unchanged credential payload.

Existing source-linked fixtures explicitly initialize the attached
provider bits. The common allocator fixture now publishes allocations
in sorted order, while explicit malformed-table stimuli remain possible.
This restores the v1684 two-owner test against the K06 geometry proof.
The v1381/v1390/v1563/v1612/v1649/v1667/v1684/v1855/v1919/v1920/v1921/
v1922/v1923 gates pass in this stage. The tests use controlled MM/VFS
fixtures or extracted production leaves; they are not a full guest
RUN/EXEC/unmount interleaving test.

This is persistent provider identity, not a media-generation number.
Same-provider replacement with the same public root handle and the
mutation/admission lifetime audit remain K07 work.
