# Aqua Protection Demo

A single repository of artifacts that demonstrate Aqua's runtime and scan-time
controls, so a Solution Architect (or a customer) can trigger multiple detections
from one place instead of hunting down scattered demos.

> **No real malware.** EICAR is the standard AV test string, the DTA leg is a
> simulated weaponization (no miner/botnet/C2), and the eBPF component is declawed.

## The unified image (recommended)

[`unified/`](unified/) builds **one image that exercises all five controls**:

```sh
docker build --platform linux/amd64 -f unified/Dockerfile \
  -t <registry>/aqua-protection-demo:latest .        # context = repo root
```

| When you… | Aqua control(s) that fire |
|-----------|---------------------------|
| **scan** the image | **Dynamic Threat Analysis** (scores Critical from the benign weaponization) + **Vulnerability** finding (old base image) |
| **run** the image (any monitored env) | **Drift Prevention**, **Advanced Malware (AMP)**, **Secure AI** |
| **run** it `--privileged` + debugfs on an x86_64 BTF node | additionally **Behavioural Detection** (eBPF) |

The eBPF leg is prebuilt at image-build time and fails gracefully when it can't
attach (non-privileged runs, or the DTA sandbox), so the image is safe to run
anywhere and simply lights up more controls the more privilege it has.

## The individual legs

Each control also exists as a standalone artifact for focused demos:

| Leg | Aqua control | Mechanism |
|-----|--------------|-----------|
| [`behavioural/`](behavioural/) | **Behavioural Detection** | eBPF `bpf_probe_write_user` on `execve` (+ `k8s/job.yaml`: privileged, debugfs, run-once) |
| [`amp/`](amp/) | **Advanced Malware Protection** | fetch + access EICAR at runtime (on-access) |
| [`secure-ai/`](secure-ai/) | **Secure AI** | outbound TLS calls to AI providers (fires without an API key) |
| [`combined-runtime/`](combined-runtime/) | **Drift + AMP + Secure AI** | Alpine sequential runner ("run once, get three incidents") |

## Control types

- **Runtime** (Behavioural, Drift, AMP, Secure AI) — fire when the container
  **runs** in an environment with an Aqua Enforcer that has the relevant
  capabilities enabled.
- **Scan-time** (DTA, Vulnerability) — fire when Aqua **scans** the image; DTA
  detonates it in Aqua's cloud sandbox, so the customer only needs to *scan* it.

## Enforcer / policy prerequisites

| Control | Enforcer capability | Policy |
|---------|--------------------|--------|
| Behavioural | Advanced runtime protection (Behavioural Detection) | Runtime Policy |
| Drift | Runtime protection (Drift Prevention) | Runtime Policy: drift/executables |
| AMP | Advanced Malware Protection | Runtime Policy (malware) |
| Secure AI | Host + Container Protection, Enforcer ≥ 2022.4.860 | Runtime Policy: `Secure AI - Discovery`, `Secure AI - Unauthorized Models` |
| DTA | — (scan-time) | Assurance Policy with Dynamic Threat Analysis |

## DTA result

Scanned under a DTA assurance policy the unified image scores **Critical** — 23
signatures across Collection, Communication, Execution, Propagation and
Weaponization, and 20 outbound connections. The simulated behaviors are listed
in [`unified/README.md`](unified/README.md).

## Provenance
- `behavioural/` recovered from `teamnautilus/bpf_rootkit_demo:latest`.
- The weaponization simulator and the runtime legs are original benign work.
