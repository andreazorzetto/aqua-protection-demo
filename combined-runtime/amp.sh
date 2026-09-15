#!/usr/bin/env bash
# Advanced Malware Protection (AMP) leg.
# AMP is on-access: download the EICAR test file at runtime and access it.
# EICAR is the harmless industry-standard AV test string, not real malware.
set -uo pipefail

output="/tmp/eicar.com.txt"
url="${EICAR_URL:-https://secure.eicar.org/eicar.com.txt}"

echo "Fetching EICAR test file from ${url}"
if ! curl -fsSL "${url}" -o "${output}" 2>/dev/null; then
  echo "download blocked; writing EICAR string locally instead"
  printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${output}"
fi

echo "Accessing ${output} to trigger on-access scan..."
for i in 1 2 3; do
  cat "${output}" >/dev/null 2>&1 || true
  cp "${output}" "/tmp/eicar_copy_${i}.txt" 2>/dev/null || true
  sleep 1
done
echo "Downloaded + accessed EICAR test file."
