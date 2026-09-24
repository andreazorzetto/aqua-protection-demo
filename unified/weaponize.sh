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

# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

leg_intro "act like a compromised image: miners, C2 beacons, scans, dropped files" \
          "a DTA scan detonates the image and flags these; enforcement may block some"

# --- obfuscated execution helper: base64-encode a benign command, decode + run
# (base64 -d | sh chains -> Data Encoding).
obf_run() {
  printf '%s' "$1" | base64 | tr -d '\n' | { read enc; echo "$enc" | base64 -d | sh; }
}

# 1) Malware signature on disk — fetch EICAR at runtime (Critical: Malware Detected).
act "[Malware] fetch the EICAR test file to /tmp/eicar.com and read it"
if ! curl -fsSL -m 10 https://secure.eicar.org/eicar.com.txt -o /tmp/eicar.com 2>/dev/null; then
  printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.com 2>/dev/null || true
fi
if [ -s /tmp/eicar.com ] && cat /tmp/eicar.com >/dev/null 2>&1; then
  ok "EICAR test file written + accessed"
else
  blocked "EICAR test file quarantined on access"
fi

# 2) Cryptominer indicators — drop a FAKE miner config with pool/algo strings.
act "[Cryptomining] drop a fake miner config to /tmp/config.json"
if cp /opt/miner-config.txt /tmp/config.json 2>/dev/null; then
  ok "dropped fake miner config (algo rx/0, pool .invalid)"
else
  blocked "fake miner config drop prevented"
fi

# 3) Obfuscated command chains (base64 decode + exec) — Data Encoding signatures.
act "[Obfuscation] decode and run base64 commands: id, uname -a, cat /etc/passwd"
obf_run 'echo "[weaponize] obfuscated payload 1 executed"' >/dev/null 2>&1
obf_run 'id' >/dev/null 2>&1
obf_run 'uname -a' >/dev/null 2>&1
obf_run 'cat /etc/passwd | head -n 1' >/dev/null 2>&1
if obf_run 'echo ok' >/dev/null 2>&1; then
  ok "ran base64-obfuscated command chains"
else
  blocked "base64-obfuscated command chains prevented"
fi

# 4) System/host discovery — Discovery signatures.
act "[Discovery] enumerate the host: /proc/filesystems, /etc/passwd, id, uname"
cat /proc/filesystems >/dev/null 2>&1
cat /etc/passwd >/dev/null 2>&1
hostname >/dev/null 2>&1; id >/dev/null 2>&1; uname -a >/dev/null 2>&1
info "done"

# 5) Dropped executable + execution (runtime drop) -> Unix Shell.
cat > /tmp/dropped.sh <<'EOS'
#!/bin/sh
echo "dropped-and-executed at runtime"
EOS
chmod +x /tmp/dropped.sh 2>/dev/null || true
act "[Execution] drop a shell script and an ELF binary in /tmp, then run them"
attempt "dropped shell script executed at runtime" /tmp/dropped.sh

# A dropped ELF is what Drift Prevention keys on. The script above only execs
# /bin/sh, which was in the image, so it never drifts however it is labelled.
if drop_elf /tmp/dropped-bin; then
  attempt "dropped ELF binary executed at runtime (drift)" /tmp/dropped-bin 1
else
  blocked "dropped ELF binary staging prevented"
fi

# 6) Miner + scanner process masquerade (benign `sleep`) -> Masquerading / Resource Hijacking.
act "[Masquerading] run sleep renamed to miner names: kdevtmpfsi, xmrig, kinsing"
for name in kdevtmpfsi xmrig kinsing; do
  if cp /bin/sleep "/tmp/$name" 2>/dev/null; then
    attempt_bg "process masquerading as miner '$name'" "/tmp/$name" 30
  else
    blocked "miner '$name' drop prevented"
  fi
done
act "[Masquerading] run sleep renamed to scanner names: shodan, masscan, zmap"
for name in shodan masscan zmap; do
  if cp /bin/sleep "/tmp/$name" 2>/dev/null; then
    attempt_bg "process masquerading as scanner '$name'" "/tmp/$name" 30
  else
    blocked "scanner '$name' drop prevented"
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
act "[Propagation] sweep TEST-NET ranges on ports 80 and 23"
scan &
info "TEST-NET ranges are reserved for documentation and never route"

# 8) Beacon-like C2 lookups + spoofed-UA HTTP beacons (Communication / C2).
act "[C2] resolve mining-pool and botnet hostnames, send spoofed-UA HTTP beacons"
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
info "*.invalid names never resolve; 192.0.2.10 is TEST-NET and never routes"

countdown 35 "all behaviours emitted; holding 35s so the sandbox can observe them"
leg_summary
