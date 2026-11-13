#!/bin/sh
# v1535: strict physical v1527 checks plus CTY ACK witness, queued
# by the shared SIMH runner in instruction-time after CONT.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$self/daimos-dtfs-media-return-fullguest-v1527.sh"
