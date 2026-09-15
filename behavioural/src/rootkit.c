#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <getopt.h>
#include <unistd.h>
#include <time.h>
#include <pwd.h>
#include <fcntl.h>
#include <syslog.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>

#include <arpa/inet.h>
#include <netinet/in.h>

#include <linux/perf_event.h>
#include <linux/hw_breakpoint.h>

#include <bpf/libbpf.h>
#include <bpf/bpf.h>

#include "rootkit.h"

static int bpfverbose = 0;
static volatile bool exiting;

char * get_currtime(void)
{
	char *datetime = malloc(100);
	time_t t = time(NULL);
	struct tm *tmp;

	memset(datetime, 0, 100);

	if ((tmp = localtime(&t)) == NULL)
		exiterr("could not get localtime");

	if ((strftime(datetime, 100, "%Y/%m/%d_%H:%M", tmp)) == 0)
		exiterr("could not parse localtime");

	return datetime;
}

static int output(context_t *e)
{
	char *currtime = get_currtime();

	wrapout("(%s) %s (pid: %u) rootkit", currtime, e->comm, e->pid);

	free(currtime);

	return 0;
}

int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args)
{
	if (level == LIBBPF_DEBUG && !bpfverbose)
		return 0;

	return vfprintf(stderr, format, args);
}

int usage(int argc, char **argv)
{
	fprintf(stdout,
	        "\n"
	        "Syntax: %s [options]\n"
	        "\n"
	        "\t[options]:\n"
	        "\n"
	        "\t-v: bpf verbose mode\n"
	        "\n",
	        argv[0]);

	exit(0);
}

void handle_event(void *ctx, int cpu, void *evdata, __u32 data_sz)
{
	output((context_t *) evdata);
}

void handle_lost_events(void *ctx, int cpu, __u64 lost_cnt)
{
	fprintf(stderr, "lost %llu events on CPU #%d\n", lost_cnt, cpu);
}

void trap(int what)
{
	exiting = 1;
}

int main(int argc, char **argv)
{
	char *btf_file;

	int opt;
	int err;
	int events_map_fd;
	int zero = 0;
	int current_pid;

	struct bpf_object *obj = NULL;
	struct bpf_program *program = NULL;
	struct bpf_map *events_map = NULL;
	struct bpf_link *link = NULL;
	struct perf_buffer *pb = NULL;

	struct bpf_object_open_opts openopts = {};

    // handle execution arguments

	while ((opt = getopt(argc, argv, "hv")) != -1) {
		switch(opt) {
		case 'v':
			bpfverbose = 1;
			break;
		case 'h':
		default:
			usage(argc, argv);
		}
	}

	fprintf(stdout, "Foreground mode...<Ctrl-C> or or SIG_TERM to end it.\n");

    // trap signals

	signal(SIGINT, trap);
	signal(SIGTERM, trap);

	umask(022);

    // set libbpf env

	libbpf_set_print(libbpf_print_fn);

	// bpf object open options

	openopts.sz = sizeof(struct bpf_object_open_opts);

	btf_file = getenv("BTF_FILE");
	if (btf_file != NULL) {
		openopts.btf_custom_path = strdup(btf_file);
    }

	// create bpf object from file

	obj = bpf_object__open_file("rootkit.bpf.o", &openopts);
	err = libbpf_get_error(obj);
	if (err) {
		fprintf(stderr, "ERROR: failed to open bpf object file: %d\n", err);
		goto cleanup;
	}

	// load program(s)

    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "ERROR: failed to load bpf object file: %d\n", err);
        goto cleanup;
    }

	// create maps from ebpf object

	events_map = bpf_object__find_map_by_name(obj, "events");
	err = libbpf_get_error(events_map);
	if (err) {
		fprintf(stderr, "ERROR: failed to find events map: %d\n", err);
		goto cleanup;
	}

	events_map_fd = bpf_map__fd(events_map);

	// create bpf programs from bpf object

	program = bpf_object__find_program_by_name(obj, "handle_execve_enter");
	err = libbpf_get_error(program);
	if (err) {
		fprintf(stderr, "ERROR: failed to find ebpf program: %d\n", err);
		goto cleanup;
	}

	// enable program autoload

	bpf_program__set_autoload(program, 1);

	// set BPF links

	link = bpf_program__attach(program);
	err = libbpf_get_error(link);
	if (err) {
		fprintf(stderr, "ERROR: failed to attach program to kprobe: %d\n", err);
		goto cleanup;
	}

	pb = perf_buffer__new(events_map_fd, 16, handle_event, handle_lost_events, NULL, NULL);
	err = libbpf_get_error(pb);
	if (err) {
		fprintf(stderr, "ERROR: failed to create perf event: %d\n", err);
		goto cleanup;
	}

	printf("Tracing successfully..!\n");

	// try to get events from BPF
	bool got_event = false;
    printf("trying to get events from BPF\n");
    for (int i; i<10; i++) {
        err = perf_buffer__poll(pb, 100);
		if (err > 0) {
			got_event = true;
			break;
		}
		if (exiting) {
			break;
		}
        sleep(1);
    }
	if (got_event) {
		printf("finished succefully!\n");
	} else {
    	printf("err got from perf_buffer__poll: %d\n", err);
	}

cleanup:

	if (pb)
		perf_buffer__free(pb);

	if (obj)
		bpf_object__close(obj);

	return 0;
}
