# Reconstructed from `docker history teamnautilus/bpf_rootkit_demo:latest`
# (original Dockerfile was not published; this reproduces the observed layers)
FROM ubuntu:20.04

RUN apt update && apt install git wget make gcc clang-12 libelf-dev -y

COPY src ./src
COPY run.sh ./
RUN chmod +x ./run.sh

ENTRYPOINT ["/bin/sh", "-c", "./run.sh"]
