#!/bin/sh
# Benign DTA weaponization simulator — contains NO real malware.
#
# Exhibits the behaviors Aqua DTA flags when it detonates an image, using only
# harmless stand-ins: EICAR is the standard AV test string; the "miner"/"scanner"
# processes are just `sleep` renamed; every network target is either an
# unresolvable .invalid host or an RFC 5737 TEST-NET address (192.0.2/24,
# 198.51.100/24, 203.0.113/24), so no real host is ever contacted. Nothing
# persists or self-propagates.
set -u

echo "[dta-sim] simulating post-startup weaponization (all benign)..."

# --- obfuscated execution helper: base64-encode a benign command, decode + run
# (base64 -d | sh chains -> Data Encoding).
obf_run() {
  printf '%s' "$1" | base64 | tr -d '\n' | { read enc; echo "$enc" | base64 -d | sh; }
}

# 1) Malware signature on disk — fetch EICAR at runtime (Critical: Malware Detected).
if ! curl -fsSL -m 10 https://secure.eicar.org/eicar.com.txt -o /tmp/eicar.com 2>/dev/null; then
  printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.com
fi
cat /tmp/eicar.com >/dev/null 2>&1
echo "[dta-sim] EICAR test file written + accessed"

# 2) Cryptominer indicators — drop a FAKE miner config with pool/algo strings.
cp /opt/miner-config.txt /tmp/config.json
echo "[dta-sim] dropped fake miner config (algo rx/0, pool .invalid)"

# 3) Obfuscated command chains (base64 decode + exec) — Data Encoding signatures.
obf_run 'echo "[dta-sim] obfuscated payload 1 executed"'
obf_run 'id'
obf_run 'uname -a'
obf_run 'cat /etc/passwd | head -n 1'
obf_run 'echo "[dta-sim] obfuscated payload 5 executed"'
echo "[dta-sim] ran base64-obfuscated command chains"

# 4) System/host discovery — Discovery signatures.
cat /proc/filesystems >/dev/null 2>&1
cat /etc/passwd >/dev/null 2>&1
hostname >/dev/null 2>&1; id >/dev/null 2>&1; uname -a >/dev/null 2>&1

# 5) Dropped executable + execution (runtime drop / drift-style) -> Unix Shell.
cat > /tmp/dropped.sh <<'EOS'
#!/bin/sh
echo "dropped-and-executed at runtime"
EOS
chmod +x /tmp/dropped.sh
/tmp/dropped.sh

# 6) Miner + scanner process masquerade (benign `sleep`) -> Masquerading / Resource Hijacking.
for name in kdevtmpfsi xmrig kinsing; do
  if cp /bin/sleep "/tmp/$name" 2>/dev/null; then
    "/tmp/$name" 30 &
    echo "[dta-sim] benign process masquerading as miner '$name' (pid $!)"
  fi
done
for name in shodan masscan zmap; do
  if cp /bin/sleep "/tmp/$name" 2>/dev/null; then
    "/tmp/$name" 30 &
    echo "[dta-sim] benign process masquerading as scanner '$name' (pid $!)"
  fi
done

# 7) Benign network scanning (Propagation / Network Service Discovery).
# TEST-NET ranges never route anywhere real; all attempts fail harmlessly.
scan() {
  for i in 1 2 3 4 5 6 7 8 9 10; do
    for net in 192.0.2 198.51.100 203.0.113; do
      curl -s -m 1 "http://$net.$i/" >/dev/null 2>&1 || true
      curl -s -m 1 "http://$net.$i:23/" >/dev/null 2>&1 || true
    done
  done
}
scan &
echo "[dta-sim] launched benign TEST-NET port sweep (Propagation)"

# 8) Beacon-like C2 lookups + spoofed-UA HTTP beacons (Communication / C2).
for h in pool.example-mining.invalid xmr.fake-pool.invalid stratum.fake-pool.invalid \
         c2.example-botnet.invalid bot.fake-c2.invalid; do
  getent hosts "$h" >/dev/null 2>&1 || true
  nslookup "$h" >/dev/null 2>&1 || true
done
beacon() {
  for i in 1 2 3 4 5; do
    curl -s -m 2 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      "http://192.0.2.10:1080/beacon$i" >/dev/null 2>&1 || true
  done
}
beacon &
echo "[dta-sim] issued beacon-like DNS lookups + spoofed-UA HTTP beacons"

echo "[dta-sim] all behaviors emitted; sleeping so the sandbox can observe."
sleep 35
