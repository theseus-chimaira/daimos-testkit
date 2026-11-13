#!/bin/sh
# Real PDP-6 mounted DTFS with two independently scheduled processes.
# Reuse v1525's physically validated DTC-selected TSFS boot infrastructure;
# only the disposable PID1 test executable and expected stages differ.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-cross-owner-v1526.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="DTFSCROSS V1526"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START MOUNTED CROSS_CWD_REFUSED CROSS_FILE_REFUSED CROSS_RETIRED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
