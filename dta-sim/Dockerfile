# Benign DTA weaponization simulator — no real malware.
# Scan with a DTA assurance policy. The old base tag also yields a vuln finding.
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates dnsutils libc-bin \
    && rm -rf /var/lib/apt/lists/*

COPY miner-config.txt /opt/miner-config.txt
COPY weaponize.sh /weaponize.sh
RUN chmod +x /weaponize.sh

ENTRYPOINT ["/weaponize.sh"]
