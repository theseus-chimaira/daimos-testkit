# Integrated DLINK negative RH18 displacement v1977

    sh tests/validation/dlink-rh18-v1977/run-v1977.sh

Runs the installed DAIMOS host DLINK, verifies native PDP6 loads using
both LOCAL_RH18 and SYMBOL_RH18 negative indexed displacements, checks
actual DOBJ relocation types, and rejects positive RH18 overflow and
negative LH18. The earlier standalone daimos-tools fix 48fc3df was not
present in the integrated DAIMOS host/native linker.

Actual native DAIMOS link/archive/execute replay (including K10 TX2):

    DAIMOS_REPO=$HOME/git/DAIMOS DAIMOS_RH18_WRAP_V1977=1 DAIMOS_MUTABLE_MARK_V1976=1 KEEP_WORK=1 sh tests/validation/daimos-native-tools-v1.sh

The native executable must print RH18 WRAP OK and NATIVE LINK OK;
when the TX2 option is enabled it also checks its exact on-disk marker.
