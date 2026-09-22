#!/usr/bin/env bash
# Advanced Malware Protection (AMP) leg.
# AMP is on-access: download the EICAR test file at runtime and access it.
# EICAR is the harmless industry-standard AV test string, not real malware.
set -uo pipefail

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

output="/tmp/eicar.com.txt"
url="${EICAR_URL:-https://secure.eicar.org/eicar.com.txt}"

info "Fetching EICAR test file from ${url}"
if ! curl -fsSL "${url}" -o "${output}" 2>/dev/null; then
  info "download blocked; writing EICAR string locally instead"
  printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${output}" 2>/dev/null || true
fi

# On-access scan: AMP in enforce mode deletes/quarantines the file as it is
# touched, so a read that comes back empty (or a copy that fails) means AMP
# blocked it; a successful read means the malware was accessed unimpeded.
info "Accessing ${output} to trigger on-access scan..."
accessed=0
for i in 1 2 3; do
  if [ -s "${output}" ] && cat "${output}" >/dev/null 2>&1 && cp "${output}" "/tmp/eicar_copy_${i}.txt" 2>/dev/null; then
    accessed=$((accessed + 1))
  fi
  sleep 1
done

if [ "$accessed" -gt 0 ]; then
  ok "EICAR test file downloaded + accessed ($accessed/3 reads)"
else
  blocked "EICAR test file quarantined on access (0/3 reads)"
fi
leg_summary
