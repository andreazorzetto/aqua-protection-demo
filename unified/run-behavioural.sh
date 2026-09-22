#!/bin/sh
# Behavioural Detection leg for the unified image.
# The eBPF rootkit (bpf_probe_write_user on execve) is PREBUILT at image-build
# time, so here we just run it. It needs privilege + a BTF source; without those
# (e.g. in the DTA sandbox or a non-privileged run) it fails gracefully.
set -u

# shellcheck source=../combined-runtime/colors.sh
. "$(dirname "$0")/colors.sh"

cd /app/behavioural || exit 0

run_rootkit() {
  # rootkit expects rootkit.bpf.o in the CWD; time-box it so the demo moves on.
  if timeout 8 ./rootkit; then
    # Behavioural Detection has no prevent mode for this signature: the rootkit
    # running IS the expected outcome, and Aqua's verdict lands in the console,
    # not in this log. Reported uncoloured so it does not read as a failure.
    detected "eBPF rootkit attached (bpf_probe_write_user on execve)"
    info "[behavioural] expect TRC-191 \"Userspace memory modification by BPF\" in Aqua"
  else
    # Non-zero here on a privileged BTF node means the bpf load/attach was
    # refused — behavioural enforcement blocked it.
    blocked "eBPF rootkit load/attach prevented"
  fi
}

if [ -f /sys/kernel/btf/vmlinux ]; then
  info "[behavioural] BTF present — attaching eBPF rootkit"
  run_rootkit
else
  info "[behavioural] no kernel BTF; trying btfhub fallback"
  KREL="$(uname -r)"
  URL="https://github.com/aquasecurity/btfhub-archive/raw/main/ubuntu/20.04/x86_64/${KREL}.btf.tar.xz"
  if wget -q "$URL" -O /tmp/btf.tar.xz 2>/dev/null && tar -xf /tmp/btf.tar.xz -C /tmp 2>/dev/null; then
    info "[behavioural] fetched BTF for ${KREL}; attaching"
    BTF_FILE="/tmp/${KREL}.btf" run_rootkit
  else
    skipped "eBPF unavailable here (needs privileged + debugfs + x86_64 BTF)"
  fi
fi
leg_summary
