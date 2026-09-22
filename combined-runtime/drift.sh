#!/usr/bin/env bash
# Drift Prevention leg.
# Drift = executing a BINARY that was not part of the original image. It has to
# be a real ELF: running a runtime-written shell script only execs the image's
# own interpreter (/bin/sh), which was in the image, so nothing drifts and the
# policy never fires. So we put a real ELF at a path the image never had and
# execute that. With drift prevention enforcing, the exec is refused with
# "Operation not permitted".
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

target="/tmp/drifted-binary"

if drop_elf "${target}"; then
  info "Executing runtime-created binary: ${target} (a copy of /bin/sleep, not in the image)"
  attempt "runtime-created binary ${target}" "${target}" 1
else
  blocked "could not stage ${target} — the write itself was prevented"
fi
leg_summary
