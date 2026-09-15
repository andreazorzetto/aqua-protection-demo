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
  with the prebuilt rootkit, the runtime scripts, and the benign DTA simulator.
- `libelf1` + `zlib1g` are installed in the runtime stage — the prebuilt rootkit
  links against them dynamically.

## Running on Kubernetes

[`k8s/job.yaml`](k8s/job.yaml) runs all five legs once (a Job, not a Deployment,
so it does not restart after finishing):

```sh
kubectl apply -f unified/k8s/job.yaml
```

It is already privileged with `/sys/kernel/debug` mounted, which the
**Behavioural** leg needs along with an x86_64 node with BTF. Without those the
eBPF leg logs that it is skipping and the run continues.

To supply real AI keys for the Secure AI leg, create the Secret the Job already
references (it is `optional`, so the Job runs with or without it):

```sh
kubectl create secret generic aqua-demo-ai-keys \
  --from-file=OPENAI_API_KEY=/path/to/openai.key
```

## Running a single control

Pass a leg name to run just one — useful for a focused demo:

```sh
docker run <image> amp        # drift | amp | secure-ai | behavioural | dta
```

In the Job, set `args: ["amp"]` on the container.

## Safety

No real malware. EICAR is the standard AV test string; the DTA leg is fully
simulated (see [`../dta-sim/`](../dta-sim/)); the eBPF rootkit is declawed
(it overwrites each exec'd program name with itself). Safe to run anywhere — it
simply lights up more controls the more privilege it is given.
