OUTPUT = ./output

GIT = $(shell which git || /bin/false)

# libbpf
LIBBPF = ./libbpf
LIBBPF_SRC = $(abspath $(LIBBPF)/src)
LIBBPF_OBJ = $(abspath $(OUTPUT)/libbpf.a)
LIBBPF_OBJDIR = $(abspath ./$(OUTPUT)/libbpf)
LIBBPF_DESTDIR = $(abspath ./$(OUTPUT))

CC = gcc
CLANG = clang-12
CFLAGS = -ggdb -gdwarf -O2 -Wall -fpie -Wno-unused-variable -Wno-unused-function
LDFLAGS =
BPF_CFLAGS_STATIC = "-I$(abspath $(OUTPUT))"

## program

PROGRAM = rootkit

all:
	$(MAKE) -C . $(PROGRAM)

# static libbpf generation for the git submodule

.PHONY: libbpf
libbpf: $(LIBBPF_OBJ)

$(LIBBPF_OBJ): $(LIBBPF_SRC) $(wildcard $(LIBBPF_SRC)/*.[ch]) | $(OUTPUT)/libbpf
	CC="$(CC)" CFLAGS="$(CFLAGS)" LD_FLAGS="$(LDFLAGS)" \
	   $(MAKE) -C $(LIBBPF_SRC) \
		BUILD_STATIC_ONLY=1 \
		OBJDIR=$(LIBBPF_OBJDIR) \
		DESTDIR=$(LIBBPF_DESTDIR) \
		INCLUDEDIR= LIBDIR= UAPIDIR= prefix= libdir= install

$(LIBBPF_SRC):
ifeq ($(wildcard $@), )
	echo "INFO: cloning 'libbpf'"
	$(GIT) clone https://github.com/libbpf/libbpf.git
endif

# output dir

$(OUTPUT):
	mkdir -p $(OUTPUT)

$(OUTPUT)/libbpf:
	mkdir -p $(OUTPUT)/libbpf

## program bpf dependency

$(PROGRAM).bpf.o: $(PROGRAM).bpf.c
	$(CLANG) $(CFLAGS) -target bpf -D__TARGET_ARCH_x86 -I. -I$(OUTPUT) -c $< -o $@

## C

.PHONY: $(PROGRAM)

$(PROGRAM): libbpf | $(PROGRAM).bpf.o
	$(CLANG) $(BPF_CFLAGS_STATIC) -lelf -lz -I. -I$(OUTPUT) $(PROGRAM).c -o $@ $(LIBBPF_OBJ)

## clean

clean:
	$(MAKE) -C $(LIBBPF_SRC) clean
	rm -rf $(OUTPUT)
	rm -rf $(PROGRAM)
	rm -rf $(PROGRAM).bpf.o $(PROGRAM).o
