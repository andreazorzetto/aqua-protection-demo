#!/usr/bin/env bash
# Combined runtime demo — one container, three runtime incidents.
#
# Fires (given an Enforcer with the right capabilities):
#   1. Drift Prevention      — writes & executes a new binary at runtime
#   2. Advanced Malware (AMP) — fetches + accesses the EICAR test file
#   3. Secure AI             — outbound TLS calls to AI providers
# Plus a vulnerability finding on scan, courtesy of the old base image.
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

run_step() {
  printf '\n%s----- %s -----%s\n' "$C_CYAN" "$1" "$C_RESET"
  shift
  "$@" || printf '%s(step returned non-zero; continuing)%s\n' "$C_DIM" "$C_RESET"
}

printf '%scombined-runtime starting%s\n' "$C_CYAN" "$C_RESET"
printf '%s  ✔ green%s = attack executed (not enforced)   %s✘ red%s = attack prevented (Aqua blocked)\n' \
  "$C_GREEN" "$C_RESET" "$C_RED" "$C_RESET"

run_step "Drift Prevention"          /app/drift.sh
run_step "Advanced Malware (AMP)"    /app/amp.sh
run_step "Secure AI"                 python3 /app/secure_ai.py

echo "combined-runtime finished"
# keep the container alive briefly so the enforcer flushes incidents
sleep 5
