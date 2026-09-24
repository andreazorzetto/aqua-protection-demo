# Unified image — all five controls, no real malware

One Ubuntu image whose entrypoint runs every leg. Build context is the **repo root**:

```sh
docker build --platform linux/amd64 -f unified/Dockerfile \
  -t <registry>/aqua-protection-demo:latest .
docker push <registry>/aqua-protection-demo:latest
```

## What fires, and when

| Trigger | Controls |
|---------|----------|
| **Scan** the image | Dynamic Threat Analysis (Critical) + Vulnerability (old base) |
| **Run** it anywhere monitored | Drift Prevention, Advanced Malware (AMP), Secure AI |
| **Run** it `--privileged` + debugfs on x86_64 BTF | + Behavioural Detection (eBPF) |

## How it's built

- **Stage 1** compiles the eBPF rootkit (`libbpf` cloned + built) so runtime is
  fast and deterministic — no apt/clone at container start.
- **Stage 2** is an intentionally old `ubuntu:20.04` (also yields a vuln finding),
  with the prebuilt rootkit, the runtime scripts, and the weaponization simulator.
- `libelf1` + `zlib1g` are installed in the runtime stage — the prebuilt rootkit
  links against them dynamically.

## Reading the log

The log is laid out to be followed live. It opens with a banner (pod name,
kernel, legend), then each leg gets a numbered header, a one-line **attack** and
**expect**, and a timestamped line (`MM:SS` since start) for every step as it
runs. Each attack's outcome is coloured: **green ✔** when it executed (Aqua was
not enforcing) and **red ✘** when it was prevented (Aqua blocked it). Each leg
closes with a verdict badge, and a full run ends with a scoreboard of all legs.
Run the image once with protection off and once with it on and the same log
turns from green to red, so the effect of a policy is visible at a glance in
`kubectl logs`, k9s, or `docker run`.

The Drift leg probes repeatedly rather than once, because drift prevention is
not yet enforcing in the first seconds of a container's life: the enforcer has to
register the container and resolve its image profile before it can tell a
runtime-created binary from an image one. A single attempt at startup would
report green on a cluster that blocks the same exec moments later. So it
re-checks once a second until the container is `AQUA_DEMO_DRIFT_SETTLE` seconds
old (default 10), and stops at the first prevented attempt. When enforcement is
already on, the answer is immediate; the full window is only spent when nothing
blocks. If an attempt is prevented after earlier ones ran, the log reports the
container age at which it happened, which shows how long the enforcer took to
attach and what the setting can safely be lowered to.

Red is the only unambiguous signal, because a container can see what happened to
its own actions but never whether Aqua raised an incident. Green means the action
was not blocked, which is not the same as "not detected" — an audit-mode policy
alerts without stopping anything.

Two more states are neither green nor red, so they do not read as a miss or a block:

| State | Meaning |
|-------|---------|
| blue `●` | a **detect-only** control. Behavioural Detection has no prevent mode, so the rootkit attaching *is* the expected outcome and the verdict is in the Aqua console (TRC-191). |
| dim `‒` | the leg cannot run in this environment at all, e.g. eBPF without privilege or BTF. |

Colour is on by default. Set `NO_COLOR=1` (or `AQUA_DEMO_COLOR=never`) to emit
plain text for viewers that do not render ANSI; `AQUA_DEMO_COLOR=always` forces
it.

## Running on Kubernetes

Two manifests, depending on whether you want the pod to finish or to stay up:

| Manifest | Behavior |
|----------|----------|
| [`k8s/job.yaml`](k8s/job.yaml) | Runs every leg once, then completes. |
| [`k8s/deployment.yaml`](k8s/deployment.yaml) | Runs every leg once, then idles until deleted, so the pod stays `Running`. |

```sh
kubectl apply -f unified/k8s/job.yaml          # one clean run
kubectl apply -f unified/k8s/deployment.yaml   # long-running pod
```

The Deployment sets `KEEP_RUNNING=true`, which makes the entrypoint idle instead
of exiting — without it a Deployment would restart the container every time it
finished. To fire the legs again:

```sh
kubectl rollout restart deploy/aqua-protection-demo
```

Both are already privileged with `/sys/kernel/debug` mounted, which the
**Behavioural** leg needs along with an x86_64 node with BTF. Without those the
eBPF leg logs that it is skipping and the run continues.

To supply real AI keys for the Secure AI leg, create the Secret both manifests
already reference (it is `optional`, so they run with or without it):

```sh
kubectl create secret generic aqua-demo-ai-keys \
  --from-file=OPENAI_API_KEY=/path/to/openai.key
```

## Running a single control

Pass a leg name to run just one — useful for a focused demo:

```sh
docker run <image> amp        # drift | amp | secure-ai | behavioural | dta
```

In either manifest, set `args: ["amp"]` on the container. With the Deployment
that leg runs and the pod then idles.

## What the scan-time leg simulates

`weaponize.sh` exhibits the behaviors a sandbox flags when it detonates an
image, using only harmless stand-ins:

| Behavior | Benign stand-in |
|----------|-----------------|
| malware on disk | EICAR test string (downloaded at runtime) |
| cryptominer config | fake `miner-config.txt` (invalid pool/wallet) |
| miner processes | `sleep` renamed to `xmrig` / `kdevtmpfsi` / `kinsing` |
| scanner processes | `sleep` renamed to `shodan` / `masscan` / `zmap` |
| obfuscated exec | `base64 -d \| sh` of benign commands |
| host discovery | reads `/proc/filesystems`, `/etc/passwd`, `uname`/`id` |
| dropped executable | `/tmp/dropped.sh` written + run at runtime |
| network scanning | curl sweep of RFC 5737 TEST-NET ranges |
| C2 beacon | `.invalid` DNS lookups + spoofed-UA HTTP to TEST-NET |

No real miner, botnet, C2, or wallet, and no self-propagation or persistence.
Every network target is either an unresolvable `.invalid` host or an RFC 5737
TEST-NET address (`192.0.2/24`, `198.51.100/24`, `203.0.113/24`), so no real
host is ever contacted.

Scanned under an Aqua DTA assurance policy it scores **Critical** — 23
signatures across Collection, Communication, Execution, Propagation and
Weaponization, and 20 outbound connections.

## Safety

No real malware. EICAR is the standard AV test string; the DTA leg is fully
simulated (see [`weaponize.sh`](weaponize.sh)); the eBPF rootkit is declawed
(it overwrites each exec'd program name with itself). Safe to run anywhere — it
simply lights up more controls the more privilege it is given.
