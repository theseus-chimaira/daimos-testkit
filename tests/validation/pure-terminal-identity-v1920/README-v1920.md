# K06 terminal identity, v1920

Run against the current DAIMOS source:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-terminal-identity-v1920
    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-terminal-finalizer-v1920

The former v1900 acceptance of an unescrowed second PROCESS extent
is deliberately superseded. Before v1920, the new native test fails
at 0103: direct terminal deletion accepts an unidentified scratch.
The current 23 cases verify sole-owner admission, transaction marker
refusal, sorted nonoverlapping geometry, exact alignment, pin refusal,
no-owner refusal, normal PREVM, lost or false free replies, malformed
post-free count, foreign overlap and replacement owners. The original
RAW identity is retained even on an initial pinned refusal. It is
never rediscovered on retry. Five independent unsafe leaf mutants
fail at 02503, 0603, 02003, 01311 and 02103 octal.

The integrated test links the actual MM deletion, VM, detach, storage
mode, finalizer and idle retry instructions. A test-only gateway
executes the real MM free, then injects a foreign interior claim and
returns an error. Actual PREVM must preserve the original terminal
escrow and exit status across that refusal and a subsequent same-slot
replacement. After the injected replacement is removed, the original
source absence permits VM_NONE and finalizer completion without a
second MM free. The unsafe PREVM escrow-loss mutant fails at 05.
The standard v1681 test also exercises real MM pin/unpin and retry
backoff. v1680 pin guard, v1609, v1666 and v1919 gates remain valid.

These are native source-linked tests, not full physical PI6 or guest
acceptance. The v1900 direct dual-owner native/finalizer fixtures are
historical and must use their matching pre-v1920 DAIMOS source.
