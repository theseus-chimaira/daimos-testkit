# Transactional EXEC backing handover, v1934

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-exec-handover-v1934

The native PDP-6 fixture links the production staged EXEC transaction,
backing decoder, transient reservation publication/release and both
backing-owner scanners. Controlled loader, startup and VM teardown
callbacks exercise nine paths: load failure, startup failure, old VM
free refusal, low/high replacement mount IDs, new/old RT ownership,
non-RT commit and NOMEM handoff. Real file and mount scans require
both live PURE dependencies throughout the staged transaction, including
a simulated backing detach before destructor return. The surviving
permanent dependency must remain after both holds are released. The
NOMEM boundary verifies the outer hold is released while the old
permanent owner remains. Three unsafe variants (missing old hold,
missing new hold, missing release) fail native assertions.

Earlier v20, v200, v1719, v1720 and v1933 native gates pass. Historical
transaction fixtures with zero PURE text words execute the actual
hold/release leaves and refuse unexpected PURE decoding/publication.
The v1719 wrong-record mutation preserves the production credential
identity update. No whole-guest physical I/O or PI6 concurrency claim.
The destructive low-memory loader's publication of its stable u-area
and credential identity requires a separate audit; the v1720 mocked
VM/loader test is not proof of its complete PURE lifetime.
