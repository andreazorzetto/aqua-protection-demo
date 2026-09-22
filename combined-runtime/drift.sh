#!/usr/bin/env bash
# Drift Prevention leg.
#
# Drift = executing a BINARY that was not part of the original image. It has to
# be a real ELF: a runtime-written shell script only execs the image's own
# /bin/sh, which WAS in the image, so nothing drifts and the policy never fires.
#
# Timing matters as much as the binary. This leg runs first, a second or two
# into the container's life, and drift prevention is usually not enforcing yet —
# the enforcer still has to register the container and resolve its image profile
# before it can tell a runtime-created binary from an image one. A single
# attempt at t=0 therefore reports "executed" on a cluster that blocks the very
# same exec seconds later, which makes the log lie. So probe repeatedly with a
# fresh binary each time and report the steady state, stopping as soon as an
# attempt is prevented, since that settles the question.
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

tries="${AQUA_DEMO_DRIFT_TRIES:-8}"
delay="${AQUA_DEMO_DRIFT_DELAY:-5}"

ran=0
prevented=0
i=1

info "Probing drift: executing a fresh runtime-created ELF up to ${tries} times, ${delay}s apart"

while [ "$i" -le "$tries" ]; do
  target="/tmp/drifted-binary-${i}"
  # /bin/true so each probe exits immediately; the exec is what drift keys on.
  if drop_elf "${target}" /bin/true && "${target}" >/dev/null 2>&1; then
    ran=$((ran + 1))
  else
    prevented=1
    break
  fi
  [ "$i" -lt "$tries" ] && sleep "${delay}"
  i=$((i + 1))
done

if [ "$prevented" -eq 1 ] && [ "$ran" -eq 0 ]; then
  blocked "runtime-created binary — prevented on the first attempt"
elif [ "$prevented" -eq 1 ]; then
  blocked "runtime-created binary — prevented after ${ran} early attempt(s) ran before enforcement engaged"
else
  ok "runtime-created binary — executed every time (${ran}/${tries} over $(( (tries - 1) * delay ))s)"
fi
leg_summary
