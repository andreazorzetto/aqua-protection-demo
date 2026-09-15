# Advanced Malware Protection (AMP) demo target.
# Fetches the EICAR test file at RUNTIME (on-access) so AMP fires.
# Contains no malware at rest — EICAR is a harmless standard AV test string.
FROM ubuntu:20.04

RUN apt update && apt install -y wget curl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
