# Unified Aqua protection demo image — all five controls, NO real malware.
# Build context is the REPOSITORY ROOT:
#   docker build --platform linux/amd64 -f unified/Dockerfile -t <reg>/aqua-protection-demo:latest .
#
# Stage 1 compiles the eBPF rootkit (libbpf cloned + built) so runtime is fast.
# Stage 2 is an intentionally old ubuntu:20.04 (also yields a vuln finding on scan).

FROM ubuntu:20.04 AS bpfbuild
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget make gcc clang-12 libelf-dev zlib1g-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
COPY behavioural/src/ ./src/
RUN cd src && make            # clones libbpf, builds rootkit + rootkit.bpf.o

FROM ubuntu:20.04
# libelf1 + zlib1g are the RUNTIME libs the prebuilt eBPF rootkit links against.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget python3 dnsutils libc-bin coreutils \
        libelf1 zlib1g \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# behavioural (prebuilt)
COPY --from=bpfbuild /build/src/rootkit          /app/behavioural/rootkit
COPY --from=bpfbuild /build/src/rootkit.bpf.o    /app/behavioural/rootkit.bpf.o

# runtime legs
COPY combined-runtime/drift.sh      /app/drift.sh
COPY combined-runtime/amp.sh        /app/amp.sh
COPY combined-runtime/secure_ai.py  /app/secure_ai.py

# DTA weaponization simulator (benign)
COPY dta-sim/weaponize.sh    /app/weaponize.sh
COPY dta-sim/miner-config.txt /opt/miner-config.txt

# orchestration
COPY unified/run-behavioural.sh /app/run-behavioural.sh
COPY unified/entrypoint.sh      /app/entrypoint.sh

RUN chmod +x /app/*.sh /app/behavioural/rootkit

ENTRYPOINT ["/app/entrypoint.sh"]
