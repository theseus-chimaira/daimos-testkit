# Executable namespace revision validation, v1936

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-namespace-epoch-v1936

The native PDP-6 gate links the actual provider gateway, loader,
reservation and mount publication/retirement leaves. It checks 50
provider/opcode classifications (MEMFS and D6FS, operations 1..25),
including failed mutation replies, saturating revision arithmetic,
and actual mount slot publication and retirement. The previous eight
loader cases are extended with changed namespace during lookup,
mutation completion during reservation lease wait and saturated
revision refusal. A stale walk cannot reach STAT or leave a reservation.
Five unsafe variants fail executed guest assertions: omit the final
revision comparison, allow wrap, omit completion update, omit mount
publication update and omit retirement update.

The file lookup and physical completion callbacks are controlled;
this is not an integrated recursive pathname walker or PI6 test.
The revision tracks gateway mutations and VFS mount publication,
not silent physical media exchange. Unrelated mutations may conservatively
invalidate a walk. Direct MEMFS mutation admission remains separate.
