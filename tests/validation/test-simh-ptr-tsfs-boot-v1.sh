#!/bin/sh
# Rebuild and compare DAIMOS paper-tape KINIT + TSFS boot under SIMH PDP-6.
# Keep the project's active build directory and any AAP edits untouched.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work=${SIMH_PTR_TSFS_WORK_V1:-$TMPDIR/daimos-simh-ptr-tsfs-v1}
simh=${SIMH_PDP6:-$HOME/cross/bin/pdp6}
mkdir -p "$work"
# DSH_IMAGE_LIMIT=037000 is the existing documented phase-one exception.
# It does not resolve the 036021-versus-036000 size regression.
make -C "$root/DAIMOS/system/boot/pdp6" -j2 image ROOT=tape BOOT=ptr \
  SIMH_DPY_MODE=HEADLESS DSH_IMAGE_LIMIT=037000 BUILD="$work/build" \
  > "$work/build-v1.log" 2>&1 || { tail -25 "$work/build-v1.log" >&2; exit 1; }
test -s "$work/build/media/tsfs-root0.dta"
test -s "$work/build/media/ptr-boot1.pt"
test -s "$work/build/media/ptr-boot2.pt"
set +e
timeout "${SIMH_PTR_TSFS_TIMEOUT_V1:-75}" "$simh" "$work/build/boot.ini" \
  > "$work/simh-console-v1.log" 2>&1
status=$?
set -e
if test "$status" -ne 0 && test "$status" -ne 124; then
  echo "SIMH exited abnormally: $status" >&2; exit "$status"
fi
python3 - "$work/simh-console-v1.log" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text(errors='replace')
for marker in ('TAPE2','DAIMON','DTC','DTFS','INIT V1','LOGIN:'):
    print('SIMH PTR+TSFS %s: %s'%(marker,'observed' if marker in s else 'NOT OBSERVED'))
assert all(x in s for x in ('TAPE2','DAIMON','INIT V1','LOGIN:')), 'boot milestones incomplete'
print('SIMH PTR+TSFS v1: startup milestone PASS; steady-state and root mount NOT independently proven')
PY
