#!/usr/bin/env bash
# Unified Aqua protection demo — one image, all five controls.
#
#   SCAN this image  -> DTA scores it Critical (from the benign weaponize.sh
#                       behaviors) + a vulnerability finding (old base image).
#   RUN this image    -> Drift + AMP + Secure AI fire in any monitored env;
#                       Behavioural (eBPF) fires only when run --privileged with
#                       /sys/kernel/debug mounted on an x86_64 BTF kernel, and
#                       fails gracefully otherwise.
#
# Run all legs (default):        docker run <image>
# Run one leg:                   docker run <image> amp
#   legs: drift | amp | secure-ai | behavioural | dta
# Run an arbitrary command:      docker run <image> /bin/sh -c '...'
#
# KEEP_RUNNING=true idles instead of exiting once the legs are done, so the
# container keeps running as a Deployment (which restarts anything that exits).
#
# No real malware anywhere: EICAR is the standard AV test string, the DTA leg is
# fully simulated (see weaponize.sh), and the eBPF rootkit is declawed.
set -u

AQUA_DEMO_VERSION="1.1.5"

# shellcheck source=colors.sh
. /app/colors.sh

# Stay alive until the pod is terminated. Backgrounding sleep and waiting on it
# lets the TERM trap fire immediately, so deletes do not sit out the grace period.
idle_if_asked() {
  case "${KEEP_RUNNING:-}" in
    true|TRUE|1|yes)
      info "KEEP_RUNNING is set; idling until the pod is terminated"
      trap 'info "terminating"; exit 0' TERM INT
      while :; do
        sleep 3600 &
        wait $!
      done
      ;;
  esac
}

# Each leg appends its verdict to a file seeded with the leg's display name;
# the scoreboard reads them back in order.
results=$(mktemp -d /tmp/aqua-demo.XXXXXX)
leg_n=0
leg_total=1

step() {
  local name="$1"
  shift
  leg_n=$((leg_n + 1))
  leg_header "$leg_n" "$leg_total" "$name"
  export AQUA_DEMO_RESULT="$results/$leg_n"
  echo "$name" > "$AQUA_DEMO_RESULT"
  "$@" || info "($name leg returned non-zero; continuing)"
}

run_leg() {
  case "$1" in
    drift)       step "Drift Prevention"       /app/drift.sh ;;
    amp)         step "Advanced Malware (AMP)" /app/amp.sh ;;
    secure-ai)   step "Secure AI"              python3 /app/secure_ai.py ;;
    behavioural) step "Behavioural (eBPF)"     /app/run-behavioural.sh ;;
    dta)         step "DTA weaponization"      /app/weaponize.sh ;;
    *)           return 1 ;;
  esac
}

if [ "$#" -gt 0 ]; then
  if run_leg "$1"; then
    idle_if_asked
    exit 0
  fi
  # not a known leg name — treat the arguments as a command to exec
  exec "$@"
fi

leg_total=5
banner "AQUA PROTECTION DEMO" "$AQUA_DEMO_VERSION" "5 attacks against 5 Aqua controls · no real malware"

for leg in drift amp secure-ai behavioural dta; do
  run_leg "$leg"
done

scoreboard "$results"
idle_if_asked
# keep the container alive briefly so the enforcer flushes incidents
sleep 5
