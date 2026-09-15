# DTA simulator

A benign image that triggers Aqua Dynamic Threat Analysis (DTA). Scanning it with
a DTA assurance policy scores the image Critical without any real malware.

## What it does (all harmless)

| Behavior | Benign stand-in | DTA signal it targets |
|----------|-----------------|-----------------------|
| malware on disk | EICAR test string (downloaded at runtime) | Malware Detected (Critical) |
| cryptominer config | fake `miner-config.txt` (invalid pool/wallet) | miner-config indicator |
| miner processes | `sleep` renamed to `xmrig` / `kdevtmpfsi` / `kinsing` | Resource Hijacking / Masquerading |
| scanner processes | `sleep` renamed to `shodan` / `masscan` / `zmap` | Masquerading |
| obfuscated exec | `base64 -d | sh` of benign commands | Data Encoding |
| host discovery | reads `/proc/filesystems`, `/etc/passwd`, `uname`/`id` | Discovery |
| dropped executable | `/tmp/dropped.sh` written + run at runtime | Unix Shell / runtime-drop |
| network scanning | curl sweep of RFC 5737 TEST-NET ranges | Network Service Discovery / Propagation |
| C2 beacon | `.invalid` DNS lookups + spoofed-UA HTTP to TEST-NET | Command and Control / File Transfer |

No real miner, botnet, C2, or wallet, and no self-propagation or persistence.
Every network target is either an unresolvable `.invalid` host or an RFC 5737
TEST-NET address (`192.0.2/24`, `198.51.100/24`, `203.0.113/24`), so no real host
is ever contacted.

## Result

Scanned with a DTA assurance policy, `dta-sim` scores **Critical** — 23 signatures
across Collection, Communication, Execution, Propagation and Weaponization, and 20
outbound connections (all to non-routable TEST-NET / `.invalid` targets).

## Build + scan

```sh
docker build --platform linux/amd64 -t <registry>/dta-sim:latest dta-sim/
docker push <registry>/dta-sim:latest
# then scan <registry>/dta-sim:latest with your DTA assurance policy
```
