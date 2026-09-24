#!/bin/sh
# Behavioural Detection leg for the unified image.
# The eBPF rootkit (bpf_probe_write_user on execve) is PREBUILT at image-build
# time, so here we just run it. It needs privilege + a BTF source; without those
# (e.g. in the DTA sandbox or a non-privileged run) it fails gracefully.
set -u

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

cd /app/behavioural || exit 0

leg_intro "load an eBPF program that writes into process memory on every exec" \
          "Behavioural Detection raises TRC-191 (detect-only, in the Aqua console)"

run_rootkit() {
  act "attach the eBPF rootkit: bpf_probe_write_user on execve (8s max)"
  info "declawed: each exec'd program name is overwritten with itself"
  # rootkit expects rootkit.bpf.o in the CWD; time-box it so the demo moves on.
  # Its output streams indented under the step; stdbuf stops stdio holding it
  # back until exit. The rootkit exits 0 even when the load fails, so success
  # is its "Tracing successfully" line, not the exit code.
  : > /tmp/rootkit.out
  timeout 8 stdbuf -oL -eL ./rootkit 2>&1 | while IFS= read -r line; do
    printf '%s\n' "${line}" >> /tmp/rootkit.out
    case "${line}" in Foreground*) continue ;; esac
    info "rootkit │ ${line}"
  done
  if grep -q 'Tracing successfully' /tmp/rootkit.out; then
    # Behavioural Detection has no prevent mode for this signature: the rootkit
    # running IS the expected outcome, and Aqua's verdict lands in the console,
    # not in this log.
    detected "eBPF rootkit attached (bpf_probe_write_user on execve)"
    leg_summary "look for TRC-191 in the Aqua console"
  else
    # No attach on a privileged BTF node means the bpf load/attach was
    # refused — behavioural enforcement blocked it.
    blocked "eBPF rootkit load/attach prevented"
    leg_summary "eBPF load/attach refused"
  fi
}

# CAP_SYS_ADMIN (bit 21 of CapEff) is what --privileged grants for bpf().
# Without it the load fails for want of privilege, not because Aqua refused it.
cap=$(awk '/^CapEff/ {print $2}' /proc/self/status 2>/dev/null)
act "check for privilege (CAP_SYS_ADMIN) and kernel BTF"
if [ -z "${cap}" ] || [ $(( 0x${cap} >> 21 & 1 )) -eq 0 ]; then
  skipped "eBPF unavailable here: the container is not privileged"
  leg_summary "needs privileged + debugfs + x86_64 BTF"
elif [ -f /sys/kernel/btf/vmlinux ]; then
  info "privileged; BTF present at /sys/kernel/btf/vmlinux"
  run_rootkit
else
  KREL="$(uname -r)"
  info "no kernel BTF; trying the btfhub archive for ${KREL}"
  URL="https://github.com/aquasecurity/btfhub-archive/raw/main/ubuntu/20.04/x86_64/${KREL}.btf.tar.xz"
  if wget -q "$URL" -O /tmp/btf.tar.xz 2>/dev/null && tar -xf /tmp/btf.tar.xz -C /tmp 2>/dev/null; then
    info "fetched BTF for ${KREL}"
    BTF_FILE="/tmp/${KREL}.btf" run_rootkit
  else
    skipped "eBPF unavailable here (needs privileged + debugfs + x86_64 BTF)"
    leg_summary "needs privileged + debugfs + x86_64 BTF"
  fi
fi
