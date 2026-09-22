# shellcheck shell=sh
# Shared colour helpers for the demo legs. POSIX sh; source, do not exec.
#
# Semantics used across every leg:
#   GREEN  = the attack EXECUTED (Aqua is not enforcing — the "protection off" run)
#   RED    = the attack was BLOCKED or PREVENTED (Aqua enforced — "protection on")
# Run the image once with protection off and once with it on and the same log
# turns from mostly green to mostly red.
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
  C_DIM=$(printf '\033[2m');    C_YELLOW=$(printf '\033[33m')
else
  C_RESET=''; C_GREEN=''; C_RED=''; C_CYAN=''; C_DIM=''; C_YELLOW=''
fi

# Per-leg counters, reset by head().
_AQUA_OK=0
_AQUA_BLOCK=0

head()  { printf '\n%s========================= %s =========================%s\n' "$C_CYAN" "$1" "$C_RESET"; _AQUA_OK=0; _AQUA_BLOCK=0; }
info()  { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
note()  { printf '%s%s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }

# ok/blocked: print a coloured result line and bump the tally.
ok()      { _AQUA_OK=$((_AQUA_OK + 1));       printf '%s  ✔ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
blocked() { _AQUA_BLOCK=$((_AQUA_BLOCK + 1)); printf '%s  ✘ %s%s\n' "$C_RED" "$1" "$C_RESET"; }

# leg_summary: one green/red line tallying this leg's outcomes.
leg_summary() {
  if [ "$_AQUA_BLOCK" -gt 0 ] && [ "$_AQUA_OK" -eq 0 ]; then
    printf '%s  → %d prevented, 0 executed — Aqua blocked this leg%s\n' "$C_RED" "$_AQUA_BLOCK" "$C_RESET"
  elif [ "$_AQUA_BLOCK" -gt 0 ]; then
    printf '%s  → %d executed%s, %s%d prevented%s\n' "$C_GREEN" "$_AQUA_OK" "$C_RESET" "$C_RED" "$_AQUA_BLOCK" "$C_RESET"
  else
    printf '%s  → %d executed, 0 prevented — nothing stopped this leg%s\n' "$C_GREEN" "$_AQUA_OK" "$C_RESET"
  fi
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
