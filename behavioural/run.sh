#!/bin/bash

apt update

apt install -y linux-tools-$(uname -r)

cd src/

make

echo "running rootkit"
VMLINUX_FILE=/sys/kernel/btf/vmlinux
if [ -f "$VMLINUX_FILE" ]; then
    ./rootkit &
else
    wget https://github.com/aquasecurity/btfhub-archive/raw/main/ubuntu/20.04/x86_64/$(uname -r).btf.tar.xz -O /tmp/btfhub.tar.xz
    tar -xvf /tmp/btfhub.tar.xz
    BTF_FILE=$(uname -r).btf ./rootkit &
fi

sleep 5

pkill -9 rootkit

echo "rootkit killed and now exiting"