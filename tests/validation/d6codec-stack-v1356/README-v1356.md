# v1356 full-DXR native staged codec stack measurement

The v055 staged ABI adapter saves AC10 through AC16. Its saved-register
frame must be included when calculating permanent KCORE stack usage.
This test reuses the original v051 complete darc DXR source/golden
stream, adds the v055 saved-register ABI checks, and scans a 512-word
canary stack after both staged engine calls return.

Run:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-stack-v1356/run-v1356.sh
```

Observed on native PDP-6 with the v1355 staged sources:
`__test_exit=0`, `__v051_first_changed=016` octal, i.e. **14 decimal
stack words** measured from the CRT's stack origin. This total includes
the CRT's `PUSHJ main`, wrapper save/restore, engine calls and the
encoder's internal match-probe calls. It does not imply a production
worst-case bound, or describe the additional stack of a real EXEC,
VFS, TSFS or boot consumer. The test asserts exactly 016 for regression
reproducibility; any deliberate call-depth change requires a new size
measurement and explicit test revision.

The active DAIMOS production decoder is still D6LZ36. This test
modifies no production KCORE or persistent data.
