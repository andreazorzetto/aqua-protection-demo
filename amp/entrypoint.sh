#!/bin/sh
# Advanced Malware Protection (AMP) demo leg.
#
# AMP is an on-access engine: a malicious file baked into an image is NOT
# enough — the file has to be written/accessed at runtime for AMP to fire.
# So we download the EICAR test file at runtime and then access it.
#
# EICAR is the industry-standard *harmless* antivirus test string. It is not
# real malware; every AV/AMP engine flags it by convention so it is the safe
# way to prove on-access detection.

set -e

EICAR_URL="${EICAR_URL:-https://secure.eicar.org/eicar.com.txt}"
OUT="/tmp/eicar.com.txt"

echo "[AMP demo] fetching EICAR test file at runtime -> $OUT"
# try a couple of well-known mirrors; fall back to writing the string locally
if ! wget -q -O "$OUT" "$EICAR_URL" 2>/dev/null && ! curl -fsSL -o "$OUT" "$EICAR_URL" 2>/dev/null; then
    echo "[AMP demo] download blocked; writing EICAR string locally instead"
    printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$OUT"
fi

echo "[AMP demo] accessing the file to trigger on-access scan..."
# on-access: repeatedly read/execute-path the file so the enforcer sees the touch
for i in 1 2 3 4 5; do
    cat "$OUT" >/dev/null 2>&1 || true
    cp "$OUT" "/tmp/eicar_copy_$i.txt" 2>/dev/null || true
    sleep 2
done

echo "[AMP demo] done — AMP should have raised an on-access malware incident."
sleep 5
