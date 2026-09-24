#!/usr/bin/env bash
# Advanced Malware Protection (AMP) leg.
# AMP is on-access: download the EICAR test file at runtime and access it.
# EICAR is the harmless industry-standard AV test string, not real malware.
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

output="/tmp/eicar.com.txt"
url="${EICAR_URL:-https://secure.eicar.org/eicar.com.txt}"

leg_intro "download the EICAR anti-malware test file, then read and copy it" \
          "AMP scans the file on access and quarantines it (EICAR is harmless)"

act "download EICAR over HTTPS from ${url}"
if curl -fsSL "${url}" -o "${output}" 2>/dev/null; then
  info "saved ${output} ($(wc -c < "${output}" | tr -d ' ') bytes)"
else
  info "download blocked; writing the EICAR string to ${output} locally instead"
  printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${output}" 2>/dev/null || true
fi

# On-access scan: AMP in enforce mode deletes/quarantines the file as it is
# touched, so a read that comes back empty (or a copy that fails) means AMP
# blocked it; a successful read means the file was accessed unimpeded.
accessed=0
for i in 1 2 3; do
  act "access ${i}/3: read and copy ${output}"
  if [ -s "${output}" ] && cat "${output}" >/dev/null 2>&1 && cp "${output}" "/tmp/eicar_copy_${i}.txt" 2>/dev/null; then
    accessed=$((accessed + 1))
    info "read + copied"
  elif [ ! -e "${output}" ]; then
    info "file is gone"
  else
    info "access denied"
  fi
  sleep 1
done

if [ "$accessed" -gt 0 ]; then
  ok "EICAR test file downloaded + accessed ($accessed/3 accesses)"
  leg_summary "EICAR accessed $accessed/3 times, not blocked"
else
  blocked "EICAR test file quarantined on access (0/3 accesses)"
  leg_summary "EICAR quarantined on access"
fi
