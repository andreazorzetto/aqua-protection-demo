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

AQUA_DEMO_VERSION="1.1.3"

# shellcheck source=../combined-runtime/colors.sh
. /app/colors.sh

# One legend so a reader knows what the colours mean. Run the image with Aqua
# not enforcing and the lines are mostly green (attacks executed); run it with
# enforcement on and they turn red (attacks prevented).
legend() {
  printf '%s  ✔ green%s = attack executed (not enforced)   %s✘ red%s = attack prevented (Aqua blocked)\n' \
    "$C_GREEN" "$C_RESET" "$C_RED" "$C_RESET"
}

# Stay alive until the pod is terminated. Backgrounding sleep and waiting on it
# lets the TERM trap fire immediately, so deletes do not sit out the grace period.
idle_if_asked() {
  case "${KEEP_RUNNING:-}" in
    true|TRUE|1|yes)
      echo
      echo "KEEP_RUNNING set — idling; container stays up until terminated."
      trap 'echo "[entrypoint] terminating"; exit 0' TERM INT
      while :; do
        sleep 3600 &
        wait $!
      done
      ;;
  esac
}

step() {
  local name="$1"
  printf '\n%s========================= %s =========================%s\n' "$C_CYAN" "$name" "$C_RESET"
  shift
  "$@" || printf '%s(%s leg returned non-zero; continuing)%s\n' "$C_DIM" "$name" "$C_RESET"
}

run_leg() {
  case "$1" in
    drift)       step "Drift Prevention"        /app/drift.sh ;;
    amp)         step "Advanced Malware (AMP)"  /app/amp.sh ;;
    secure-ai)   step "Secure AI"               python3 /app/secure_ai.py ;;
    behavioural) step "Behavioural (eBPF)"      /app/run-behavioural.sh ;;
    dta)         step "DTA weaponization (sim)" /app/weaponize.sh ;;
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

printf '%s=== unified aqua-protection-demo v%s starting ===%s\n' "$C_CYAN" "$AQUA_DEMO_VERSION" "$C_RESET"
legend

for leg in drift amp secure-ai behavioural dta; do
  run_leg "$leg"
done

printf '\n%s=== unified aqua-protection-demo v%s finished ===%s\n' "$C_CYAN" "$AQUA_DEMO_VERSION" "$C_RESET"
legend
idle_if_asked
# keep the container alive briefly so the enforcer flushes incidents
sleep 5
