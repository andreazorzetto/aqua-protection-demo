# Mock rootkit using eBPF

this program uses 'bpf_probe_write_user' on binary executions to mock the behavior of eBPF rootkits.

in practive, this program overrides the binary name with the same binary name, so nothing bad happens.

## build:

```
$ make
```

## run:

on kernels with BTF support:

```
$ sudo ./rootkit
```

on kernels without BTF support:

```
$ sudo BTF_FILE=<btf_file.btf> ./rootkit
```