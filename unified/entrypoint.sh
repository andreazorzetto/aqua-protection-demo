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
# No real malware anywhere: EICAR is the standard AV test string, the DTA leg is
# fully simulated (see weaponize.sh), and the eBPF rootkit is declawed.
set -u

step() {
  local name="$1"
  echo
  echo "========================= $name ========================="
  shift
  "$@" || echo "($name leg returned non-zero; continuing)"
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
    exit 0
  fi
  # not a known leg name — treat the arguments as a command to exec
  exec "$@"
fi

echo "=== unified aqua-protection-demo starting ==="

for leg in drift amp secure-ai behavioural dta; do
  run_leg "$leg"
done

echo
echo "=== unified aqua-protection-demo finished ==="
sleep 5
