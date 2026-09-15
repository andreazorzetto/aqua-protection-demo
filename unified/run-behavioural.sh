#!/bin/sh
# Behavioural Detection leg for the unified image.
# The eBPF rootkit (bpf_probe_write_user on execve) is PREBUILT at image-build
# time, so here we just run it. It needs privilege + a BTF source; without those
# (e.g. in the DTA sandbox or a non-privileged run) it fails gracefully.
set -u

cd /app/behavioural || exit 0

run_rootkit() {
  # rootkit expects rootkit.bpf.o in the CWD; time-box it so the demo moves on.
  timeout 8 ./rootkit || true
}

if [ -f /sys/kernel/btf/vmlinux ]; then
  echo "[behavioural] BTF present — attaching eBPF rootkit"
  run_rootkit
else
  echo "[behavioural] no kernel BTF; trying btfhub fallback"
  KREL="$(uname -r)"
  URL="https://github.com/aquasecurity/btfhub-archive/raw/main/ubuntu/20.04/x86_64/${KREL}.btf.tar.xz"
  if wget -q "$URL" -O /tmp/btf.tar.xz 2>/dev/null && tar -xf /tmp/btf.tar.xz -C /tmp 2>/dev/null; then
    echo "[behavioural] fetched BTF for ${KREL}; attaching"
    BTF_FILE="/tmp/${KREL}.btf" run_rootkit
  else
    echo "[behavioural] eBPF unavailable in this environment (needs privileged + debugfs + x86_64 BTF) — skipping"
  fi
fi
