#!/usr/bin/env bash
# Drift Prevention leg.
#
# Drift = executing a BINARY that was not part of the original image. It has to
# be a real ELF: a runtime-written shell script only execs the image's own
# /bin/sh, which WAS in the image, so nothing drifts and the policy never fires.
#
# Timing matters as much as the binary. Drift prevention is not enforcing in the
# first seconds of a container's life: the enforcer still has to register the
# container and resolve its image profile. One attempt at startup would report
# "executed" on a cluster that blocks the same exec moments later. So probe once
# a second until the container is AQUA_DEMO_DRIFT_SETTLE seconds old, stopping
# at the first prevented attempt. The race only exists while the container is
# young, so an older container (the leg re-run via exec, say) gets one attempt.
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

settle="${AQUA_DEMO_DRIFT_SETTLE:-10}"
delay="${AQUA_DEMO_DRIFT_DELAY:-1}"

# Seconds since the container's PID 1 started. Both numbers come from the host
# clock, so this works inside a PID namespace. Field 22 of /proc/1/stat is the
# start time in clock ticks; strip "pid (comm) " first, since comm may hold spaces.
container_age() {
  local hz start up
  hz=$(getconf CLK_TCK 2>/dev/null) || hz=100
  start=$(sed 's/^.*) //' /proc/1/stat 2>/dev/null | awk '{print $20}')
  up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
  [ -n "$start" ] && [ -n "$up" ] || return 1
  echo $(( up - start / hz ))
}

# Cap attempts in case /proc cannot be read, so the loop always terminates.
max_tries=$(( settle / delay + 1 ))
ran=0
prevented=0
announced=0
age=""
i=0

while :; do
  i=$((i + 1))
  target="/tmp/drifted-binary-${i}"
  # /bin/true so each probe exits at once; the exec is what drift keys on.
  # exec -a sets argv[0] to "true": on a busybox base (Alpine) /bin/true is
  # busybox itself, which picks its applet from argv[0] and would otherwise
  # answer "applet not found" (exit 127), a false "prevented". GNU true ignores it.
  if drop_elf "${target}" /bin/true && (exec -a true "${target}") >/dev/null 2>&1; then
    ran=$((ran + 1))
  else
    prevented=1
    age=$(container_age) || age=""
    break
  fi

  if age=$(container_age); then
    [ "${age}" -ge "${settle}" ] && break
  else
    age=""
    [ "${i}" -ge "${max_tries}" ] && break
  fi

  if [ "${announced}" -eq 0 ]; then
    if [ -n "${age}" ]; then
      info "Runtime-created binary ran at t+${age}s. Re-checking until t+${settle}s in case the enforcer is still attaching."
    else
      info "Runtime-created binary ran. Re-checking for ${settle}s in case the enforcer is still attaching."
    fi
    announced=1
  fi
  sleep "${delay}"
done

when=""
[ -n "${age}" ] && when=" at t+${age}s"

if [ "${prevented}" -eq 1 ] && [ "${ran}" -eq 0 ]; then
  blocked "runtime-created binary — prevented on the first attempt"
elif [ "${prevented}" -eq 1 ]; then
  blocked "runtime-created binary — prevented${when}, after ${ran} early attempt(s) ran before enforcement engaged"
else
  ok "runtime-created binary — executed (${ran} attempt(s)${when:+, last${when}})"
fi
leg_summary
