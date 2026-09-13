/* SPDX-License-Identifier: GPL-2.0 */
/*
 * haram_guard.h - Header for HARAMchy security kernel module
 *
 * Defines shared structures, constants, and locale strings for
 * communication between kernel-space haram_guard and userspace haramd.
 */

#ifndef _HARAM_GUARD_H
#define _HARAM_GUARD_H

#include <linux/types.h>
#include <linux/ioctl.h>

/* ------------------------------------------------------------------ */
/*  Protocol constants                                                 */
/* ------------------------------------------------------------------ */

#define HARAM_NETLINK_PROTO	20		/* custom netlink protocol */
#define HARAM_CHARDEV_NAME	"haram"		/* /dev/haram */
#define HARAM_CHARDEV_MAJOR	240		/* reserved major number  */

#define HARAM_PANIC_TIMEOUT	10		/* seconds before panic  */
#define HARAM_MERCY_WINDOW	3		/* seconds to abort       */
#define HARAM_MAX_PATTERN_LEN	64		/* max pattern length     */
#define HARAM_MAX_MSG_LEN	256		/* max log message length */

/* ------------------------------------------------------------------ */
/*  Event types (kernel -> userspace and vice versa)                    */
/* ------------------------------------------------------------------ */

enum haram_event_type {
	HARAM_EVT_NONE		= 0,
	HARAM_EVT_FILE_OPEN	= 1,		/* file open attempted    */
	HARAM_EVT_FILE_WRITE	= 2,		/* file write attempted   */
	HARAM_EVT_EXEC		= 3,		/* exec attempted         */
	HARAM_EVT_INODE_CREATE	= 4,		/* inode creation         */
	HARAM_EVT_NETLINK_CMD	= 5,		/* command from haramd    */
	HARAM_EVT_VIOLATION	= 100,		/* confirmed violation    */
	HARAM_EVT_PANIC		= 101,		/* countdown started      */
	HARAM_EVT_ABORT		= 102,		/* mercy granted          */
};

/* ------------------------------------------------------------------ */
/*  Violation codes (written to /proc/haram/report)                    */
/* ------------------------------------------------------------------ */

enum haram_violation_code {
	HARAM_VIOL_PIG		= 0x01,		/* pig/swine content     */
	HARAM_VIOL_PORNO	= 0x02,		/* pornography           */
	HARAM_VIOL_ALCOHOL	= 0x04,		/* alcohol               */
	HARAM_VIOL_GAMBLING	= 0x08,		/* gambling              */
	HARAM_VIOL_USURY	= 0x10,		/* riba/usury            */
	HARAM_VIOL_CUSTOM	= 0x80,		/* custom pattern match  */
};

/* ------------------------------------------------------------------ */
/*  Message structures for chardev / netlink                           */
/* ------------------------------------------------------------------ */

/**
 * struct haram_msg - message exchanged via /dev/haram or netlink
 * @type:    event type (enum haram_event_type)
 * @code:    violation bitmask (enum haram_violation_code)
 * @pid:     offending process id
 * @uid:     offending user id
 * @tgid:    offending thread group id
 * @ts:      kernel timestamp (ktime_get_boottime_ns)
 * @path:    file path (zero-terminated, truncated to HARAM_MAX_MSG_LEN)
 * @data:    extra payload (event-specific)
 */
struct haram_msg {
	__u32	type;
	__u32	code;
	__u32	pid;
	__u32	uid;
	__u32	tgid;
	__u64	ts;
	__u8	path[HARAM_MAX_MSG_LEN];
	__u8	data[HARAM_MAX_MSG_LEN];
};

/* ------------------------------------------------------------------ */
/*  Chardev ioctl numbers                                              */
/* ------------------------------------------------------------------ */

#define HARAM_IOC_MAGIC		'h'

#define HARAM_IOC_GET_STATUS	_IO(HARAM_IOC_MAGIC, 1)
#define HARAM_IOC_SET_ENABLE	_IOW(HARAM_IOC_MAGIC, 2, int)
#define HARAM_IOC_ABORT		_IO(HARAM_IOC_MAGIC, 3)
#define HARAM_IOC_GET_EVENTS	_IOR(HARAM_IOC_MAGIC, 4, struct haram_msg)

/* ------------------------------------------------------------------ */
/*  Locale strings (kernel log messages)                                */
/* ------------------------------------------------------------------ */

/* --- Russian --- */
#define HARAM_STR_RU_DETECTED \
	"ОБНАРУЖЕН ХАРАМ!! Процесс %d (%s) нарушил шариат.\n"
#define HARAM_STR_RU_COUNTDOWN \
	"ХАРАМ: Паника через %d секунд. Напишите СМИЛОСТИВЬСЯ в /proc/haram/abort\n"
#define HARAM_STR_RU_MERCY \
	"ХАРАМ: Милость оказана. Паника отменена.\n"
#define HARAM_STR_RU_PANIC \
	"ОБНАРУЖЕН ХАРАМ!! Грешник: %s (PID %d, UID %d)\n"
#define HARAM_STR_RU_VIOLATION \
	"ХАРАМ: Нарушение code=0x%x в %s\n"

/* --- English --- */
#define HARAM_STR_EN_DETECTED \
	"HARAM DETECTED!! Process %d (%s) violated the code.\n"
#define HARAM_STR_EN_COUNTDOWN \
	"HARAM: Panic in %d seconds. Write MERCY to /proc/haram/abort\n"
#define HARAM_STR_EN_MERCY \
	"HARAM: Mercy granted. Panic aborted.\n"
#define HARAM_STR_EN_PANIC \
	"HARAM DETECTED!! Sinner: %s (PID %d, UID %d)\n"
#define HARAM_STR_EN_VIOLATION \
	"HARAM: Violation code=0x%x in %s\n"

#endif /* _HARAM_GUARD_H */
