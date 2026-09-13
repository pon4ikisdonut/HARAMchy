// SPDX-License-Identifier: GPL-2.0
/*
 * haram_guard.c - HARAMchy LSM security/detection module
 *
 * Detects forbidden ("haram") content and triggers a dramatic kernel
 * panic countdown. Provides:
 *   - LSM hooks for file_open, file_write, bprm_check, inode_create
 *   - /proc/haram/report, /proc/haram/abort, /proc/haram/status
 *   - /dev/haram character device
 *   - Netlink interface for haramd userspace daemon
 *   - Pattern matching with basic leetspeak normalization
 *
 * Copyright (c) 2026 HARAMchy Linux Project
 */

#define pr_fmt(fmt) "haram_guard: " fmt

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/lsm_hooks.h>
#include <linux/security.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/uaccess.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/timer.h>
#include <linux/jiffies.h>
#include <linux/netlink.h>
#include <linux/skbuff.h>
#include <linux/rtnetlink.h>
#include <linux/mutex.h>
#include <linux/notifier.h>
#include <linux/namei.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/version.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/binfmts.h>
#include <linux/dcache.h>
#include <net/netlink.h>

#include "haram_guard.h"

/* ------------------------------------------------------------------ */
/*  Module parameters                                                  */
/* ------------------------------------------------------------------ */

static int haram_enable;
module_param(haram_enable, int, 0644);
MODULE_PARM_DESC(haram_enable, "Enable haram_guard enforcement (0/1)");

static int haram_panic_timeout = HARAM_PANIC_TIMEOUT;
module_param(haram_panic_timeout, int, 0644);
MODULE_PARM_DESC(haram_panic_timeout, "Seconds before panic after violation");

static int netlink_pid;
module_param(netlink_pid, int, 0644);
MODULE_PARM_DESC(netlink_pid, "PID of haramd netlink peer");

/* ------------------------------------------------------------------ */
/*  Internal state                                                     */
/* ------------------------------------------------------------------ */

static DEFINE_MUTEX(haram_lock);
static DEFINE_MUTEX(panic_lock);

static struct timer_list	panic_timer;
static int			panic_pending;
static unsigned long		panic_start;	/* jiffies */
static int			abort_received;
static int			violation_count;
static u32			last_violation_code;

static struct proc_dir_entry	*haram_proc_dir;
static struct proc_dir_entry	*haram_proc_report;
static struct proc_dir_entry	*haram_proc_abort;
static struct proc_dir_entry	*haram_proc_status;

static struct miscdevice	haram_misc;
static struct sock		*haram_nl_sock;

static DECLARE_WAIT_QUEUE_HEAD(haram_wq);
static DEFINE_SPINLOCK(haram_event_lock);

/* Ring buffer for events (chardev read) */
#define EVENT_RING_SIZE 64
static struct haram_msg event_ring[EVENT_RING_SIZE];
static int event_head;
static int event_tail;

/* ------------------------------------------------------------------ */
/*  Forward declarations                                               */
/* ------------------------------------------------------------------ */

static int haram_hook_file_open(struct file *file);
static int haram_hook_bprm_check(struct linux_binprm *bprm);
static int haram_hook_inode_create(struct inode *dir, struct dentry *dentry,
	umode_t mode);

static ssize_t haram_proc_report_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos);
static ssize_t haram_proc_abort_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos);
static int haram_proc_status_show(struct seq_file *m, void *v);

static int haram_chardev_open(struct inode *inode, struct file *filp);
static int haram_chardev_release(struct inode *inode, struct file *filp);
static ssize_t haram_chardev_read(struct file *filp, char __user *buf,
	size_t count, loff_t *ppos);
static ssize_t haram_chardev_write(struct file *filp,
	const char __user *buf, size_t count, loff_t *ppos);
static long haram_chardev_ioctl(struct file *filp,
	unsigned int cmd, unsigned long arg);

static void haram_panic_timer_fn(struct timer_list *t);
static void haram_start_countdown(void);
static void haram_abort_panic(void);

static int haram_netlink_send(enum haram_event_type type, u32 code,
	const char *path, u32 pid, u32 uid);
static void haram_netlink_rcv(struct sk_buff *skb);

static int haram_pattern_match(const char *str);

/* ------------------------------------------------------------------ */
/*  Pattern matching with leetspeak normalization                      */
/* ------------------------------------------------------------------ */

/**
 * struct haram_pattern - a forbidden word pattern
 * @pattern: lowercase ASCII pattern to match
 * @code:    violation code to report
 */
struct haram_pattern {
	const char	*pattern;
	u32		code;
};

static const struct haram_pattern haram_patterns[] = {
	{ "pig",	HARAM_VIOL_PIG },
	{ "swine",	HARAM_VIOL_PIG },
	{ "pork",	HARAM_VIOL_PIG },
	{ NULL,		0 }
};

/**
 * haram_normalize_char - normalize a character for pattern matching
 *
 * Maps common leetspeak substitutions and transliterations back to
 * their base ASCII form. Returns lowercase normalized character.
 *
 * Mapping:
 *   0 -> o, 1 -> i/l, 3 -> e, 4 -> a, 5 -> s, 7 -> t
 *   @ -> a, $ -> s, ! -> i, + -> t
 *   Cyrillic: и->i, о->o, е->e, с->s, а->a, т->t, р->p, у->y
 */
static char haram_normalize_char(char c)
{
	if (c >= 'A' && c <= 'Z')
		c = c + ('a' - 'A');

	switch (c) {
	case '0': return 'o';
	case '1': return 'i';
	case '3': return 'e';
	case '4': return 'a';
	case '5': return 's';
	case '7': return 't';
	case '@': return 'a';
	case '$': return 's';
	case '!': return 'i';
	case '+': return 't';
	default:
		break;
	}

	/* Cyrillic normalization requires UTF-8 aware parsing;
	 * left as TODO for future multi-byte matcher implementation.
	 * For now, only Latin leetspeak is normalized.
	 */
	return c;
}

/**
 * haram_pattern_match - check a string for forbidden patterns
 * @str: input string (file path, command, etc.)
 *
 * Returns violation code (0 if clean).
 */
static int haram_pattern_match(const char *str)
{
	const struct haram_pattern *pat;
	char *lower;
	size_t len;
	int i, j;
	int matched = 0;

	if (!str)
		return 0;

	len = strlen(str);
	if (len == 0 || len > 4096)
		return 0;

	lower = kmalloc(len + 1, GFP_KERNEL);
	if (!lower)
		return 0;

	/* Normalize: lowercase + leetspeak */
	for (i = 0; i < (int)len; i++)
		lower[i] = haram_normalize_char(str[i]);
	lower[len] = '\0';

	/* Check each pattern */
	for (pat = haram_patterns; pat->pattern; pat++) {
		size_t plen = strlen(pat->pattern);

		for (i = 0; i <= (int)len - (int)plen; i++) {
			for (j = 0; j < (int)plen; j++) {
				if (lower[i + j] != pat->pattern[j])
					break;
			}
			if (j == (int)plen) {
				matched |= pat->code;
				break;
			}
		}
	}

	kfree(lower);
	return matched;
}

/* ------------------------------------------------------------------ */
/*  Event ring buffer                                                  */
/* ------------------------------------------------------------------ */

static void haram_push_event(const struct haram_msg *msg)
{
	unsigned long flags;

	spin_lock_irqsave(&haram_event_lock, flags);

	memcpy(&event_ring[event_head], msg, sizeof(*msg));
	event_head = (event_head + 1) % EVENT_RING_SIZE;
	if (event_head == event_tail)
		event_tail = (event_tail + 1) % EVENT_RING_SIZE;

	spin_unlock_irqrestore(&haram_event_lock, flags);
	wake_up_interruptible(&haram_wq);
}

static int haram_pop_event(struct haram_msg *msg)
{
	unsigned long flags;
	int ret = 0;

	spin_lock_irqsave(&haram_event_lock, flags);

	if (event_head != event_tail) {
		memcpy(msg, &event_ring[event_tail], sizeof(*msg));
		event_tail = (event_tail + 1) % EVENT_RING_SIZE;
		ret = 1;
	}

	spin_unlock_irqrestore(&haram_event_lock, flags);
	return ret;
}

/* ------------------------------------------------------------------ */
/*  Panic countdown                                                    */
/* ------------------------------------------------------------------ */

/**
 * haram_start_countdown - begin the panic countdown
 *
 * Activates a kernel timer that fires after @haram_panic_timeout seconds.
 * If not aborted, calls panic() with the haram message.
 */
static void haram_start_countdown(void)
{
	mutex_lock(&panic_lock);

	if (panic_pending) {
		mutex_unlock(&panic_lock);
		return;
	}

	panic_pending = 1;
	abort_received = 0;
	panic_start = jiffies;

	pr_emerg(HARAM_STR_RU_COUNTDOWN, haram_panic_timeout);
	pr_emerg(HARAM_STR_EN_COUNTDOWN, haram_panic_timeout);

	mod_timer(&panic_timer, jiffies + haram_panic_timeout * HZ);

	mutex_unlock(&panic_lock);
}

/**
 * haram_abort_panic - cancel the panic countdown if within mercy window
 *
 * Returns 0 on success, -ETIMEDOUT if window expired.
 */
static void haram_abort_panic(void)
{
	mutex_lock(&panic_lock);

	if (!panic_pending) {
		mutex_unlock(&panic_lock);
		return;
	}

	if (time_after(jiffies,
	    panic_start + (haram_panic_timeout - HARAM_MERCY_WINDOW) * HZ)) {
		pr_warn("HARAM: Mercy window expired (%ds)\n",
			HARAM_MERCY_WINDOW);
		mutex_unlock(&panic_lock);
		return;
	}

	abort_received = 1;
	panic_pending = 0;
	del_timer_sync(&panic_timer);

	pr_info(HARAM_STR_RU_MERCY);
	pr_info(HARAM_STR_EN_MERCY);

	haram_netlink_send(HARAM_EVT_ABORT, 0, "mercy", 0, 0);

	mutex_unlock(&panic_lock);
}

/**
 * haram_panic_timer_fn - timer callback, triggers kernel panic
 */
static void haram_panic_timer_fn(struct timer_list *t)
{
	mutex_lock(&panic_lock);

	if (abort_received || !panic_pending) {
		mutex_unlock(&panic_lock);
		return;
	}

	pr_emerg(HARAM_STR_RU_PANIC, current->comm,
		 task_pid_vnr(current), from_kuid(&init_user_ns, current_uid()));
	pr_emerg(HARAM_STR_EN_PANIC, current->comm,
		 task_pid_vnr(current), from_kuid(&init_user_ns, current_uid()));
	pr_emerg("HARAM: Kernel panic - not syncing: HARAM content detected\n");

	mutex_unlock(&panic_lock);

	/*
	 * We cannot hold panic_lock while calling panic() since
	 * other CPUs may be spinning on it.
	 */
	panic("ОБНАРУЖЕН ХАРАМ!! / HARAM DETECTED!!");
}

/* ------------------------------------------------------------------ */
/*  Netlink communication                                              */
/* ------------------------------------------------------------------ */

static int haram_netlink_send(enum haram_event_type type, u32 code,
	const char *path, u32 pid, u32 uid)
{
	struct sk_buff *skb;
	struct nlmsghdr *nlh;
	struct haram_msg *msg;
	int ret;

	if (!haram_nl_sock || !netlink_pid)
		return -ENOTCONN;

	skb = nlmsg_new(sizeof(*msg), GFP_KERNEL);
	if (!skb)
		return -ENOMEM;

	nlh = nlmsg_put(skb, 0, 0, NLMSG_DONE, sizeof(*msg), 0);
	if (!nlh) {
		kfree_skb(skb);
		return -EMSGSIZE;
	}

	msg = nlmsg_data(nlh);
	memset(msg, 0, sizeof(*msg));
	msg->type = type;
	msg->code = code;
	msg->pid = pid;
	msg->uid = uid;
	msg->tgid = task_tgid_vnr(current);
	msg->ts = ktime_get_boottime_ns();

	if (path)
		strncpy((char *)msg->path, path, HARAM_MAX_MSG_LEN - 1);

	NETLINK_CB(skb).dst_group = 1;
	ret = nlmsg_multicast(haram_nl_sock, skb, 0, 1, GFP_KERNEL);
	if (ret && ret != -ESRCH)
		pr_warn("netlink send failed: %d\n", ret);

	return 0;
}

static void haram_netlink_rcv(struct sk_buff *skb)
{
	struct nlmsghdr *nlh;
	struct haram_msg *msg;

	if (!skb)
		return;

	nlh = nlmsg_hdr(skb);
	if (nlh->nlmsg_len < NLMSG_HDRLEN + sizeof(*msg))
		return;

	msg = nlmsg_data(nlh);

	switch (msg->type) {
	case HARAM_EVT_NETLINK_CMD:
		if (msg->code == 0xFF) {
			/* Enable command from haramd */
			haram_enable = 1;
			pr_info("haramd: enforcement enabled\n");
		} else if (msg->code == 0xFE) {
			/* Disable command */
			haram_enable = 0;
			pr_info("haramd: enforcement disabled\n");
		}
		break;
	default:
		pr_debug("netlink: unknown event type %u\n", msg->type);
		break;
	}
}

/* ------------------------------------------------------------------ */
/*  LSM hooks                                                          */
/* ------------------------------------------------------------------ */

/**
 * haram_hook_file_open - LSM hook for file open
 * @file: file being opened
 *
 * Checks file path for haram patterns. Triggers violation if found.
 */
static int haram_hook_file_open(struct file *file)
{
	char *buf, *path;
	int code;
	struct haram_msg msg;

	if (!haram_enable)
		return 0;

	buf = kmalloc(PATH_MAX, GFP_KERNEL);
	if (!buf)
		return 0;

	path = d_path(&file->f_path, buf, PATH_MAX);
	if (IS_ERR(path)) {
		kfree(buf);
		return 0;
	}

	code = haram_pattern_match(path);
	if (code) {
		pr_emerg(HARAM_STR_RU_VIOLATION, code, path);
		pr_emerg(HARAM_STR_EN_VIOLATION, code, path);

		memset(&msg, 0, sizeof(msg));
		msg.type = HARAM_EVT_FILE_OPEN;
		msg.code = code;
		msg.pid = task_pid_vnr(current);
		msg.uid = from_kuid(&init_user_ns, current_uid());
		msg.tgid = task_tgid_vnr(current);
		msg.ts = ktime_get_boottime_ns();
		strncpy((char *)msg.path, path, HARAM_MAX_MSG_LEN - 1);

		haram_push_event(&msg);
		haram_netlink_send(HARAM_EVT_VIOLATION, code,
				   path, msg.pid, msg.uid);

		mutex_lock(&haram_lock);
		violation_count++;
		last_violation_code = code;
		mutex_unlock(&haram_lock);

		haram_start_countdown();
		kfree(buf);
		return -EACCES;
	}

	kfree(buf);
	return 0;
}

/**
 * haram_hook_bprm_check - LSM hook for binary exec
 * @bprm: linux_binprm being executed
 */
static int haram_hook_bprm_check(struct linux_binprm *bprm)
{
	char *buf, *path;
	int code;
	struct haram_msg msg;

	if (!haram_enable)
		return 0;

	buf = kmalloc(PATH_MAX, GFP_KERNEL);
	if (!buf)
		return 0;

	path = d_path(&bprm->file->f_path, buf, PATH_MAX);
	if (IS_ERR(path)) {
		kfree(buf);
		return 0;
	}

	code = haram_pattern_match(path);
	if (code) {
		pr_emerg(HARAM_STR_RU_VIOLATION, code, path);
		pr_emerg(HARAM_STR_EN_VIOLATION, code, path);

		memset(&msg, 0, sizeof(msg));
		msg.type = HARAM_EVT_EXEC;
		msg.code = code;
		msg.pid = task_pid_vnr(current);
		msg.uid = from_kuid(&init_user_ns, current_uid());
		msg.tgid = task_tgid_vnr(current);
		msg.ts = ktime_get_boottime_ns();
		strncpy((char *)msg.path, path, HARAM_MAX_MSG_LEN - 1);

		haram_push_event(&msg);
		haram_netlink_send(HARAM_EVT_VIOLATION, code,
				   path, msg.pid, msg.uid);

		mutex_lock(&haram_lock);
		violation_count++;
		last_violation_code = code;
		mutex_unlock(&haram_lock);

		haram_start_countdown();
		kfree(buf);
		return -EACCES;
	}

	kfree(buf);
	return 0;
}

/**
 * haram_hook_inode_create - LSM hook for inode creation
 * @dentry: dentry being created
 * @mode: creation mode
 */
static int haram_hook_inode_create(struct inode *dir, struct dentry *dentry,
	umode_t mode)
{
	char *buf, *path;
	int code;
	struct haram_msg msg;

	if (!haram_enable)
		return 0;

	buf = kmalloc(PATH_MAX, GFP_KERNEL);
	if (!buf)
		return 0;

	path = dentry_path_raw(dentry->d_parent, buf, PATH_MAX);
	if (IS_ERR(path)) {
		kfree(buf);
		return 0;
	}

	/* Check full path including new name */
	strlcat(path, "/", PATH_MAX - strlen(path) - 1);
	strlcat(path, dentry->d_name.name, PATH_MAX - strlen(path) - 1);

	code = haram_pattern_match(path);
	if (code) {
		pr_emerg(HARAM_STR_RU_VIOLATION, code, path);
		pr_emerg(HARAM_STR_EN_VIOLATION, code, path);

		memset(&msg, 0, sizeof(msg));
		msg.type = HARAM_EVT_INODE_CREATE;
		msg.code = code;
		msg.pid = task_pid_vnr(current);
		msg.uid = from_kuid(&init_user_ns, current_uid());
		msg.tgid = task_tgid_vnr(current);
		msg.ts = ktime_get_boottime_ns();
		strncpy((char *)msg.path, path, HARAM_MAX_MSG_LEN - 1);

		haram_push_event(&msg);
		haram_netlink_send(HARAM_EVT_VIOLATION, code,
				   path, msg.pid, msg.uid);

		mutex_lock(&haram_lock);
		violation_count++;
		last_violation_code = code;
		mutex_unlock(&haram_lock);

		haram_start_countdown();
		kfree(buf);
		return -EACCES;
	}

	kfree(buf);
	return 0;
}

/* ------------------------------------------------------------------ */
/*  LSM security hook list                                             */
/* ------------------------------------------------------------------ */

static struct security_hook_list haram_hooks[] = {
	LSM_HOOK_INIT(file_open, haram_hook_file_open),
	LSM_HOOK_INIT(bprm_check_security, haram_hook_bprm_check),
	LSM_HOOK_INIT(inode_create, haram_hook_inode_create),
};

/* ------------------------------------------------------------------ */
/*  /proc/haram interfaces                                             */
/* ------------------------------------------------------------------ */

static const struct proc_ops haram_report_ops = {
	.proc_write = haram_proc_report_write,
};

static const struct proc_ops haram_abort_ops = {
	.proc_write = haram_proc_abort_write,
};

static int haram_status_open(struct inode *inode, struct file *file)
{
	return single_open(file, haram_proc_status_show, NULL);
}

static const struct proc_ops haram_status_ops = {
	.proc_open = haram_status_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/**
 * haram_proc_report_write - handle writes to /proc/haram/report
 *
 * Accepts a hex violation code (e.g. "0x01") and triggers the
 * corresponding violation handling.
 */
static ssize_t haram_proc_report_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[32];
	u32 code;
	struct haram_msg msg;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	/* Parse hex or decimal */
	if (kbuf[0] == '0' && (kbuf[1] == 'x' || kbuf[1] == 'X')) {
		if (kstrtou32(kbuf + 2, 16, &code))
			return -EINVAL;
	} else {
		if (kstrtou32(kbuf, 10, &code))
			return -EINVAL;
	}

	if (code == 0)
		return -EINVAL;

	pr_emerg(HARAM_STR_RU_VIOLATION, code, "procfs/manual");
	pr_emerg(HARAM_STR_EN_VIOLATION, code, "procfs/manual");

	memset(&msg, 0, sizeof(msg));
	msg.type = HARAM_EVT_VIOLATION;
	msg.code = code;
	msg.pid = task_pid_vnr(current);
	msg.uid = from_kuid(&init_user_ns, current_uid());
	msg.tgid = task_tgid_vnr(current);
	msg.ts = ktime_get_boottime_ns();
	strncpy((char *)msg.path, "procfs/manual", HARAM_MAX_MSG_LEN - 1);

	haram_push_event(&msg);
	haram_netlink_send(HARAM_EVT_VIOLATION, code,
			   "procfs/manual", msg.pid, msg.uid);

	mutex_lock(&haram_lock);
	violation_count++;
	last_violation_code = code;
	mutex_unlock(&haram_lock);

	haram_start_countdown();

	return count;
}

/**
 * haram_proc_abort_write - handle writes to /proc/haram/abort
 *
 * Accepts "MERCY" or "СМИЛОСТИВЬСЯ" within the mercy window
 * to cancel an active panic countdown.
 */
static ssize_t haram_proc_abort_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[32];

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	/* Trim trailing newline */
	while (count > 0 && (kbuf[count - 1] == '\n' || kbuf[count - 1] == '\r'))
		kbuf[--count] = '\0';

	if (strcmp(kbuf, "MERCY") == 0 ||
	    strcmp(kbuf, "СМИЛОСТИВЬСЯ") == 0) {
		haram_abort_panic();
		return count;
	}

	pr_warn("haram_guard: unknown abort command '%s'\n", kbuf);
	return -EINVAL;
}

/**
 * haram_proc_status_show - show module status via /proc/haram/status
 *
 * Exports a truth table showing current detection state.
 */
static int haram_proc_status_show(struct seq_file *m, void *v)
{
	seq_printf(m, "=== HARAM Guard Status ===\n");
	seq_printf(m, "enabled:         %d\n", haram_enable);
	seq_printf(m, "panic_pending:   %d\n", panic_pending);
	seq_printf(m, "abort_received:  %d\n", abort_received);
	seq_printf(m, "violation_count: %d\n", violation_count);
	seq_printf(m, "last_code:       0x%x\n", last_violation_code);
	seq_printf(m, "haram_panic_timeout:   %d\n", haram_panic_timeout);
	seq_printf(m, "netlink_pid:     %d\n", netlink_pid);
	seq_printf(m, "\n=== Detection Truth Table ===\n");
	seq_printf(m, "PIG detected:    %s\n",
		   (last_violation_code & HARAM_VIOL_PIG) ? "YES" : "NO");
	seq_printf(m, "PORNO detected:  %s\n",
		   (last_violation_code & HARAM_VIOL_PORNO) ? "YES" : "NO");
	seq_printf(m, "ALCOHOL detected:%s\n",
		   (last_violation_code & HARAM_VIOL_ALCOHOL) ? "YES" : "NO");
	seq_printf(m, "GAMBLING detected:%s\n",
		   (last_violation_code & HARAM_VIOL_GAMBLING) ? "YES" : "NO");
	seq_printf(m, "USURY detected:  %s\n",
		   (last_violation_code & HARAM_VIOL_USURY) ? "YES" : "NO");
	seq_printf(m, "CUSTOM detected: %s\n",
		   (last_violation_code & HARAM_VIOL_CUSTOM) ? "YES" : "NO");
	seq_printf(m, "\n=== Patterns Loaded ===\n");
	seq_printf(m, "pig    -> 0x%x\n", HARAM_VIOL_PIG);
	seq_printf(m, "swine  -> 0x%x\n", HARAM_VIOL_PIG);
	seq_printf(m, "pork   -> 0x%x\n", HARAM_VIOL_PIG);
	return 0;
}

/* ------------------------------------------------------------------ */
/*  /dev/haram character device                                        */
/* ------------------------------------------------------------------ */

static const struct file_operations haram_fops = {
	.owner		= THIS_MODULE,
	.open		= haram_chardev_open,
	.release	= haram_chardev_release,
	.read		= haram_chardev_read,
	.write		= haram_chardev_write,
	.unlocked_ioctl	= haram_chardev_ioctl,
	.compat_ioctl	= compat_ptr_ioctl,
};

static int haram_chardev_open(struct inode *inode, struct file *filp)
{
	return 0;
}

static int haram_chardev_release(struct inode *inode, struct file *filp)
{
	return 0;
}

/**
 * haram_chardev_read - read events from the ring buffer
 *
 * Blocks if no events are available and O_NONBLOCK is not set.
 */
static ssize_t haram_chardev_read(struct file *filp, char __user *buf,
	size_t count, loff_t *ppos)
{
	struct haram_msg msg;

	if (count < sizeof(msg))
		return -EINVAL;

	/* Block until event available (unless non-blocking) */
	if (filp->f_flags & O_NONBLOCK) {
		if (!haram_pop_event(&msg))
			return -EAGAIN;
	} else {
		wait_event_interruptible(haram_wq, haram_pop_event(&msg));
	}

	if (copy_to_user(buf, &msg, sizeof(msg)))
		return -EFAULT;

	return sizeof(msg);
}

/**
 * haram_chardev_write - write violation commands to the device
 *
 * Same interface as /proc/haram/report.
 */
static ssize_t haram_chardev_write(struct file *filp,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[32];
	u32 code;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	if (kbuf[0] == '0' && (kbuf[1] == 'x' || kbuf[1] == 'X')) {
		if (kstrtou32(kbuf + 2, 16, &code))
			return -EINVAL;
	} else {
		if (kstrtou32(kbuf, 10, &code))
			return -EINVAL;
	}

	if (code == 0)
		return -EINVAL;

	last_violation_code = code;
	violation_count++;
	haram_start_countdown();

	return count;
}

/**
 * haram_chardev_ioctl - control the module via /dev/haram
 */
static long haram_chardev_ioctl(struct file *filp,
	unsigned int cmd, unsigned long arg)
{
	int val;

	switch (cmd) {
	case HARAM_IOC_GET_STATUS:
		val = haram_enable;
		if (copy_to_user((int __user *)arg, &val, sizeof(val)))
			return -EFAULT;
		return 0;

	case HARAM_IOC_SET_ENABLE:
		if (copy_from_user(&val, (int __user *)arg, sizeof(val)))
			return -EFAULT;
		haram_enable = !!val;
		pr_info("enforcement set to %d via ioctl\n", haram_enable);
		return 0;

	case HARAM_IOC_ABORT:
		haram_abort_panic();
		return 0;

	case HARAM_IOC_GET_EVENTS: {
		struct haram_msg msg;

		if (!haram_pop_event(&msg))
			return -EAGAIN;

		if (copy_to_user((void __user *)arg, &msg, sizeof(msg)))
			return -EFAULT;

		return sizeof(msg);
	}

	default:
		return -ENOTTY;
	}
}

/* ------------------------------------------------------------------ */
/*  Module init / exit                                                 */
/* ------------------------------------------------------------------ */

static int __init haram_guard_init(void)
{
	int ret;

	pr_info("haram_guard: loading HARAMchy security module\n");

	/* Initialize panic timer */
	timer_setup(&panic_timer, haram_panic_timer_fn, 0);

	/* Register LSM hooks */
	security_add_hooks(haram_hooks, ARRAY_SIZE(haram_hooks), "haram_guard");
	pr_info("haram_guard: LSM hooks registered\n");

	/* Create /proc/haram/ directory */
	haram_proc_dir = proc_mkdir("haram", NULL);
	if (!haram_proc_dir) {
		pr_err("failed to create /proc/haram\n");
		ret = -ENOMEM;
		goto err_proc;
	}

	haram_proc_report = proc_create("report", 0200,
					haram_proc_dir, &haram_report_ops);
	if (!haram_proc_report) {
		pr_err("failed to create /proc/haram/report\n");
		ret = -ENOMEM;
		goto err_report;
	}

	haram_proc_abort = proc_create("abort", 0200,
				       haram_proc_dir, &haram_abort_ops);
	if (!haram_proc_abort) {
		pr_err("failed to create /proc/haram/abort\n");
		ret = -ENOMEM;
		goto err_abort;
	}

	haram_proc_status = proc_create("status", 0444,
					haram_proc_dir, &haram_status_ops);
	if (!haram_proc_status) {
		pr_err("failed to create /proc/haram/status\n");
		ret = -ENOMEM;
		goto err_status;
	}

	/* Register character device */
	haram_misc.minor = MISC_DYNAMIC_MINOR;
	haram_misc.name = HARAM_CHARDEV_NAME;
	haram_misc.fops = &haram_fops;

	ret = misc_register(&haram_misc);
	if (ret) {
		pr_err("failed to register /dev/haram: %d\n", ret);
		goto err_misc;
	}

	/* Create netlink socket */
	{
		struct netlink_kernel_cfg cfg = {
			.input = haram_netlink_rcv,
		};

		haram_nl_sock = netlink_kernel_create(&init_net,
						      HARAM_NETLINK_PROTO,
						      &cfg);
		if (!haram_nl_sock) {
			pr_warn("netlink creation failed (non-fatal)\n");
			/* Non-fatal: chardev and procfs still work */
		}
	}

	pr_info("haram_guard: initialized (timeout=%ds, enable=%d)\n",
		haram_panic_timeout, haram_enable);
	pr_info(HARAM_STR_RU_DETECTED, 0, "init");
	pr_info(HARAM_STR_EN_DETECTED, 0, "init");

	return 0;

err_misc:
	proc_remove(haram_proc_status);
err_status:
	proc_remove(haram_proc_abort);
err_abort:
	proc_remove(haram_proc_report);
err_report:
	proc_remove(haram_proc_dir);
err_proc:
	return ret;
}

static void __exit haram_guard_exit(void)
{
	del_timer_sync(&panic_timer);

	if (haram_nl_sock)
		netlink_kernel_release(haram_nl_sock);

	misc_deregister(&haram_misc);
	proc_remove(haram_proc_dir);

	pr_info("haram_guard: unloaded. Total violations: %d\n",
		violation_count);
}

module_init(haram_guard_init);
module_exit(haram_guard_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("HARAMchy Linux Project");
MODULE_DESCRIPTION("HARAM content detection and punishment module");
MODULE_VERSION("1.0.0");
MODULE_ALIAS("haram");
