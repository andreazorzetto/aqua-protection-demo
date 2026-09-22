# shellcheck shell=sh
# Shared colour helpers for the demo legs. POSIX sh; source, do not exec.
#
# Four outcome states, because a container can only observe what happened to its
# own actions — it can never see whether Aqua raised an incident:
#   GREEN ✔ executed  — the action completed. Aqua did not block it. An
#                       audit-mode policy may still have alerted.
#   RED   ✘ prevented — the action was blocked. The only unambiguous signal,
#                       and proof the control is in prevent mode.
#   plain · detected  — a detect-only control (Behavioural). The action running
#                       IS the expected outcome; the verdict is in the console.
#                       Deliberately uncoloured so it does not read as a failure.
#   dim   ‒ skipped   — this environment cannot run the leg at all.
#
# Colour is on by default (k9s / kubectl logs / most viewers render ANSI).
# Disable with NO_COLOR=1 (any value) or AQUA_DEMO_COLOR=never; force with
# AQUA_DEMO_COLOR=always.

[ -n "${_AQUA_COLORS_SOURCED:-}" ] && return 0
_AQUA_COLORS_SOURCED=1

_use_color=1
case "${AQUA_DEMO_COLOR:-auto}" in
  never|off|0) _use_color=0 ;;
  always|on|1) _use_color=1 ;;
  *) [ -n "${NO_COLOR:-}" ] && _use_color=0 ;;
esac

if [ "$_use_color" = 1 ]; then
  C_RESET=$(printf '\033[0m'); C_GREEN=$(printf '\033[1;32m')
  C_RED=$(printf '\033[1;31m'); C_CYAN=$(printf '\033[1;36m')
  C_DIM=$(printf '\033[2m')
else
  C_RESET=''; C_GREEN=''; C_RED=''; C_CYAN=''; C_DIM=''
fi

# Per-leg counters. Each leg is its own process, so these start fresh.
_AQUA_OK=0
_AQUA_BLOCK=0
_AQUA_DETECT=0
_AQUA_SKIP=0

info() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# The four outcome states.
ok()       { _AQUA_OK=$((_AQUA_OK + 1));         printf '%s  ✔ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
blocked()  { _AQUA_BLOCK=$((_AQUA_BLOCK + 1));   printf '%s  ✘ %s%s\n' "$C_RED" "$1" "$C_RESET"; }
detected() { _AQUA_DETECT=$((_AQUA_DETECT + 1)); printf '  · %s\n' "$1"; }
skipped()  { _AQUA_SKIP=$((_AQUA_SKIP + 1));     printf '%s  ‒ %s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# leg_summary: one line tallying this leg. Detect-only and skipped legs are not
# scored on the executed/prevented axis — "0 prevented" would misreport a
# detection control that did exactly its job.
leg_summary() {
  if [ "$_AQUA_OK" -eq 0 ] && [ "$_AQUA_BLOCK" -eq 0 ]; then
    if [ "$_AQUA_DETECT" -gt 0 ]; then
      printf '  → detect-only control; the verdict is in the Aqua console, not here\n'
    elif [ "$_AQUA_SKIP" -gt 0 ]; then
      printf '%s  → leg skipped in this environment%s\n' "$C_DIM" "$C_RESET"
    fi
    return 0
  fi
  if [ "$_AQUA_BLOCK" -gt 0 ] && [ "$_AQUA_OK" -eq 0 ]; then
    printf '%s  → %d prevented, 0 executed — Aqua blocked this leg%s\n' "$C_RED" "$_AQUA_BLOCK" "$C_RESET"
  elif [ "$_AQUA_BLOCK" -gt 0 ]; then
    printf '%s  → %d executed%s, %s%d prevented%s\n' "$C_GREEN" "$_AQUA_OK" "$C_RESET" "$C_RED" "$_AQUA_BLOCK" "$C_RESET"
  else
    printf '%s  → %d executed, 0 prevented%s\n' "$C_GREEN" "$_AQUA_OK" "$C_RESET"
  fi
}

# drop_elf <path>: put a real ELF at a path the image never had. Drift Prevention
# keys on executing a binary that was not in the image; a shell script only execs
# the image's own interpreter (/bin/sh), which is not drift and is never blocked.
# The appended byte makes the content hash differ from the source binary too —
# trailing bytes after the last ELF section are ignored by the loader.
drop_elf() {
  _src="${2:-/bin/sleep}"
  cp "$_src" "$1" 2>/dev/null || return 1
  printf '\0' >> "$1" 2>/dev/null || true
  chmod +x "$1" 2>/dev/null || true
}

# attempt "label" cmd...: run synchronously. Exit 0 -> executed (green),
# non-zero (e.g. exec blocked with "Operation not permitted") -> prevented (red).
attempt() {
  label="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$label — executed"; else blocked "$label — prevented"; fi
}

# attempt_bg "label" cmd...: launch in the background (for processes meant to
# keep running, e.g. a masquerading miner). Child stderr is captured so a blocked
# exec does not leak an uncoloured "Operation not permitted" into the log. Alive
# shortly after launch -> executed (green); died immediately -> prevented (red).
attempt_bg() {
  label="$1"; shift
  "$@" 2>/dev/null &
  _pid=$!
  sleep 0.3
  if kill -0 "$_pid" 2>/dev/null; then ok "$label — running (pid $_pid)"; else blocked "$label — prevented"; fi
}
