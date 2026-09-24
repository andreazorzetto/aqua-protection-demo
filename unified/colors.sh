# shellcheck shell=sh
# Shared log helpers for the demo legs: colours, the demo clock, leg headers,
# action and outcome lines, and the end-of-run scoreboard. POSIX sh; source,
# do not exec.
#
# Four outcome states, because a container can only observe what happened to its
# own actions — it can never see whether Aqua raised an incident:
#   green ✔ executed  — the action completed. Aqua did not block it. An
#                       audit-mode policy may still have alerted.
#   red   ✘ prevented — the action was blocked. The only unambiguous signal,
#                       and proof the control is in prevent mode.
#   blue  ● detected  — a detect-only control (Behavioural). The action running
#                       IS the expected outcome; the verdict is in the console.
#                       Neither green nor red, so it reads as neither a miss
#                       nor a block.
#   dim   ‒ skipped   — this environment cannot run the leg at all.
#
# Output is strictly line by line (no cursor movement or partial lines), so it
# streams the same in a terminal, `kubectl logs -f` and k9s.
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

# Some of these are only used by the scripts that source this file, which
# ShellCheck cannot see because it lints each file on its own.
# shellcheck disable=SC2034
if [ "$_use_color" = 1 ]; then
  C_RESET=$(printf '\033[0m');    C_BOLD=$(printf '\033[1m')
  C_GREEN=$(printf '\033[1;32m'); C_RED=$(printf '\033[1;31m')
  C_BLUE=$(printf '\033[1;34m');  C_YELLOW=$(printf '\033[1;33m')
  C_CYAN=$(printf '\033[1;36m');  C_DIM=$(printf '\033[2m')
  # Verdict badges: bold text on a solid background.
  B_GREEN=$(printf '\033[1;30;42m'); B_RED=$(printf '\033[1;97;41m')
  B_BLUE=$(printf '\033[1;97;44m');  B_YELLOW=$(printf '\033[1;30;43m')
  B_DIM=$(printf '\033[2;7m')
else
  C_RESET=''; C_BOLD=''; C_GREEN=''; C_RED=''; C_BLUE=''; C_YELLOW=''
  C_CYAN=''; C_DIM=''
  B_GREEN=''; B_RED=''; B_BLUE=''; B_YELLOW=''; B_DIM=''
fi

# Width of rules and headers. Fits a projector-sized terminal font.
AQUA_W=68

# Demo clock: seconds since the entrypoint started, shared by every leg so the
# timestamps line up across the whole run. A leg run on its own starts at 00:00.
: "${AQUA_DEMO_T0:=$(date +%s)}"
export AQUA_DEMO_T0

# Per-leg counters. Each leg is its own process, so these start fresh.
_AQUA_OK=0
_AQUA_BLOCK=0
_AQUA_DETECT=0
_AQUA_SKIP=0

_rep() {
  _r=''; _n="$2"
  while [ "$_n" -gt 0 ]; do _r="$_r$1"; _n=$((_n - 1)); done
  printf '%s' "$_r"
}

clock() {
  _s=$(( $(date +%s) - AQUA_DEMO_T0 ))
  printf '%02d:%02d' $((_s / 60)) $((_s % 60))
}

# Every event line: "  MM:SS <symbol> <text>". Notes indent under the text.
_line() { printf '  %s%s%s %s%s %s%s\n' "$C_DIM" "$(clock)" "$C_RESET" "$1" "$2" "$3" "$C_RESET"; }

# act "text": the attack step about to run.
act()  { printf '  %s%s%s %s▸%s %s\n' "$C_DIM" "$(clock)" "$C_RESET" "$C_CYAN" "$C_RESET" "$1"; }
# info "text": supporting detail under the current step.
info() { printf '          %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# The four outcome states.
ok()       { _AQUA_OK=$((_AQUA_OK + 1));         _line "$C_GREEN" '✔' "$1"; }
blocked()  { _AQUA_BLOCK=$((_AQUA_BLOCK + 1));   _line "$C_RED"   '✘' "$1"; }
detected() { _AQUA_DETECT=$((_AQUA_DETECT + 1)); _line "$C_BLUE"  '●' "$1"; }
skipped()  { _AQUA_SKIP=$((_AQUA_SKIP + 1));     _line "$C_DIM"   '‒' "$1"; }

# leg_header <n> <total> <name>: the rule that opens a leg.
leg_header() {
  _name=$(printf '%s' "$3" | tr '[:lower:]' '[:upper:]')
  _fill=$(( AQUA_W - 3 - ${#1} - 1 - ${#2} - 3 - ${#_name} - 1 - 9 ))
  [ "$_fill" -lt 3 ] && _fill=3
  printf '\n  %s━━ %s%s/%s · %s%s %s %s ━━%s\n' "$C_CYAN" "$C_BOLD" "$1" "$2" "$_name" \
    "$C_CYAN" "$(_rep '━' "$_fill")" "$(clock)" "$C_RESET"
}

# leg_intro "attack" "expect": what the leg does and what Aqua should do about it.
leg_intro() {
  printf '  %sattack%s  %s\n' "$C_DIM" "$C_RESET" "$1"
  printf '  %sexpect%s  %s\n\n' "$C_DIM" "$C_RESET" "$2"
}

# _badge <state>: the coloured verdict label for a leg state.
_badge() {
  case "$1" in
    executed)  printf '%s ✔ EXECUTED  %s' "$B_GREEN"  "$C_RESET" ;;
    prevented) printf '%s ✘ PREVENTED %s' "$B_RED"    "$C_RESET" ;;
    mixed)     printf '%s ◐ MIXED     %s' "$B_YELLOW" "$C_RESET" ;;
    detected)  printf '%s ● DETECTED  %s' "$B_BLUE"   "$C_RESET" ;;
    skipped)   printf '%s ‒ SKIPPED   %s' "$B_DIM"    "$C_RESET" ;;
    *)         printf '%s ? NO RESULT %s' "$B_DIM"    "$C_RESET" ;;
  esac
}

# leg_summary [note]: the leg's verdict line. Detect-only and skipped legs are
# not scored on the executed/prevented axis — "0 prevented" would misreport a
# detection control that did exactly its job. The verdict is also written to
# $AQUA_DEMO_RESULT (when the entrypoint sets it) for the scoreboard.
leg_summary() {
  if [ "$_AQUA_OK" -eq 0 ] && [ "$_AQUA_BLOCK" -eq 0 ]; then
    if [ "$_AQUA_DETECT" -gt 0 ]; then
      _state=detected; _note="${1:-detect-only; the verdict is in the Aqua console}"
    else
      _state=skipped;  _note="${1:-not runnable in this environment}"
    fi
  elif [ "$_AQUA_OK" -eq 0 ]; then
    _state=prevented; _note="${1:-$_AQUA_BLOCK of $_AQUA_BLOCK blocked by Aqua}"
  elif [ "$_AQUA_BLOCK" -eq 0 ]; then
    _state=executed;  _note="${1:-$_AQUA_OK of $_AQUA_OK ran, none blocked}"
  else
    _state=mixed;     _note="${1:-$_AQUA_BLOCK prevented, $_AQUA_OK executed}"
  fi
  printf '\n  %s└─▶%s %s  %s\n' "$C_DIM" "$C_RESET" "$(_badge "$_state")" "$_note"
  [ -n "${AQUA_DEMO_RESULT:-}" ] && printf '%s|%s\n' "$_state" "$_note" >> "$AQUA_DEMO_RESULT"
  return 0
}

# scoreboard <dir>: one row per leg, from the result files the entrypoint
# seeded with the leg name ("name" on line 1, "state|note" appended by the leg).
scoreboard() {
  _rule="$(_rep '━' "$AQUA_W")"
  _fill=$(( AQUA_W - 1 - 10 - 5 ))
  printf '\n\n  %s%s%s\n' "$C_CYAN" "$_rule" "$C_RESET"
  printf '   %sSCOREBOARD%s%s%s%s%s\n' "$C_BOLD" "$C_RESET" "$(_rep ' ' "$_fill")" "$C_DIM" "$(clock)" "$C_RESET"
  printf '  %s%s%s\n' "$C_CYAN" "$_rule" "$C_RESET"
  _i=0; _np=0; _ne=0; _nm=0; _nd=0; _ns=0
  for _f in "$1"/*; do
    [ -f "$_f" ] || continue
    _i=$((_i + 1))
    _name=$(sed -n 1p "$_f")
    _res=$(sed -n 2p "$_f")
    _state=${_res%%|*}; _note=${_res#*|}
    [ -n "$_res" ] || { _state=none; _note='the leg exited without a verdict'; }
    case "$_state" in
      prevented) _np=$((_np + 1)) ;; executed) _ne=$((_ne + 1)) ;;
      mixed) _nm=$((_nm + 1)) ;;     detected) _nd=$((_nd + 1)) ;;
      *) _ns=$((_ns + 1)) ;;
    esac
    printf '   %s%d%s  %-24s %s  %s%s%s\n' "$C_BOLD" "$_i" "$C_RESET" "$_name" \
      "$(_badge "$_state")" "$C_DIM" "$_note" "$C_RESET"
  done
  printf '  %s%s%s\n   ' "$C_CYAN" "$_rule" "$C_RESET"
  _sep=''
  [ "$_np" -gt 0 ] && { printf '%s%s%d prevented%s' "$_sep" "$C_RED" "$_np" "$C_RESET"; _sep='  ·  '; }
  [ "$_nm" -gt 0 ] && { printf '%s%s%d mixed%s' "$_sep" "$C_YELLOW" "$_nm" "$C_RESET"; _sep='  ·  '; }
  [ "$_ne" -gt 0 ] && { printf '%s%s%d executed%s' "$_sep" "$C_GREEN" "$_ne" "$C_RESET"; _sep='  ·  '; }
  [ "$_nd" -gt 0 ] && { printf '%s%s%d detected%s' "$_sep" "$C_BLUE" "$_nd" "$C_RESET"; _sep='  ·  '; }
  [ "$_ns" -gt 0 ] && { printf '%s%s%d skipped%s' "$_sep" "$C_DIM" "$_ns" "$C_RESET"; }
  printf '\n\n'
}

# banner <title> <version|""> <subtitle>: the run's opening card, with the legend.
banner() {
  _rule="$(_rep '━' "$AQUA_W")"
  _ver="${2:+v$2}"
  _fill=$(( AQUA_W - 1 - ${#1} - ${#_ver} ))
  printf '\n  %s%s%s\n' "$C_CYAN" "$_rule" "$C_RESET"
  printf '   %s%s%s%s%s%s%s\n' "$C_BOLD" "$1" "$C_RESET" "$(_rep ' ' "$_fill")" "$C_DIM" "$_ver" "$C_RESET"
  printf '   %s\n' "$3"
  printf '  %s%s%s\n' "$C_CYAN" "$_rule" "$C_RESET"
  printf '   %spod%s     %s  %s·%s  kernel %s  %s·%s  %s\n\n' "$C_DIM" "$C_RESET" \
    "$(hostname 2>/dev/null || cat /etc/hostname)" "$C_DIM" "$C_RESET" "$(uname -r)" "$C_DIM" "$C_RESET" "$(uname -m)"
  printf '   %s✔ executed %s  the attack ran; Aqua did not block it\n' "$C_GREEN" "$C_RESET"
  printf '   %s✘ prevented%s  Aqua blocked the attack\n' "$C_RED" "$C_RESET"
  printf '   %s● detected %s  detect-only control; the verdict is in the Aqua console\n' "$C_BLUE" "$C_RESET"
  printf '   %s‒ skipped  %s  this environment cannot run the leg\n' "$C_DIM" "$C_RESET"
}

# drop_elf <path>: put a real ELF at a path the image never had. Drift Prevention
# keys on executing a binary that was not in the image; a shell script only execs
# the image's own interpreter (/bin/sh), which is not drift and is never blocked.
# The appended byte makes the content hash differ from the source binary too —
# trailing bytes after the last ELF section are ignored by the loader.
# Braces + a redirect on the group, because 2>/dev/null on a simple command does
# not suppress errors raised while setting up its own redirection.
drop_elf() {
  _src="${2:-/bin/sleep}"
  cp "$_src" "$1" 2>/dev/null || return 1
  { printf '\0' >> "$1"; } 2>/dev/null || return 1
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

# countdown <seconds> "why": hold with a progress bar every 5s, so a long wait
# visibly stays alive in a streamed log.
countdown() {
  info "$2"
  _t=0
  while [ "$_t" -lt "$1" ]; do
    _step=5; [ $(( $1 - _t )) -lt 5 ] && _step=$(( $1 - _t ))
    sleep "$_step"
    _t=$((_t + _step))
    _done=$(( _t * 24 / $1 ))
    printf '          %s%s%s%s%s  %ds/%ds%s\n' "$C_CYAN" "$(_rep '█' "$_done")" "$C_DIM" \
      "$(_rep '░' $((24 - _done)))" "$C_RESET$C_DIM" "$_t" "$1" "$C_RESET"
  done
}
