# D6FS ordinary dispatch recovery, v1930

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-d6fs-retry-v1930

The extended native v1927/v1929 guest executes the actual D6FS dispatch,
physical identity proof and ordinary failure-notification leaves.
An ordinary request to a READ_SUSPECT mount refuses a foreign UUID,
then retries against the original volume and verifies all six saved
request registers at the controlled vector-dispatch boundary. The
healthy path must not issue another physical proof read. All ordinary
vector operation numbers 1..16 and REMOUNT refuse WRITE_UNCERTAIN,
without new physical I/O or reader retirement. The privileged raw
inspection operation remains available without clearing uncertainty;
its syscall privilege check is an existing separate contract, not
retested here. Three additional unsafe variants bypass read retry,
poison refusal or argument restoration; all reach a failing native
assertion. Thirteen total unsafe variants are rejected. The earlier
selector, mount, reader-slab and RW/RO transition gates also pass.

The fixture directly restores RO state before its old independent
reader retirement test; this does not implement write recovery or
an integrated unmount protocol. Physical controller callbacks and
normal vector-dispatch destinations are controlled. No complete-guest
media exchange, PI6 concurrency or unmount acceptance is claimed.
