/*
 * haramd.h - HARAMchy Daemon v3.0
 *
 * Compact kernel panic enforcement daemon.
 * Monitors keyboard, screen, USB, network (DPI), processes.
 * Triggers kernel panic on haram detection.
 *
 * Copyright (c) 2026 HARAMchy Linux Distribution — GPL v2
 */

#ifndef HARAMD_H
#define HARAMD_H

#define _GNU_SOURCE
#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <time.h>
#include <syslog.h>
#include <ctype.h>
#include <stdarg.h>
#include <pthread.h>
#include <regex.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <sys/reboot.h>
#include <sys/socket.h>
#include <sys/inotify.h>
#include <linux/input.h>
#include <linux/fb.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/reboot.h>
#include <net/if.h>

#define VERSION "3.0.0"
#define PID_FILE "/var/run/haramd.pid"
#define LOG_FILE "/var/log/haramd.log"
#define RULES_PATH "/etc/haram-rules/rules.yaml"
#define CONFIG_PATH "/etc/haram-rules/config.toml"
#define BLOCKLIST_DIR "/etc/haram-rules/blocklists"
#define VIOLATION_LOG "/var/log/haramd-violations.log"

#define MAX_RULES 512
#define MAX_PATTERNS 32
#define MAX_LINE 4096

/* ============================================================
 * Enums
 * ============================================================ */

typedef enum { CAT_UNKNOWN=0, CAT_MICROSOFT, CAT_FOOD, CAT_ALCOHOL,
               CAT_GAMBLING, CAT_DRUGS, CAT_VIOLENCE, CAT_IMMORAL,
               CAT_DECEPTION, CAT_OCCULT, CAT_FINANCIAL, CAT_PRAYER,
               CAT_MAX } category_t;

typedef enum { SEV_UNKNOWN=0, SEV_CRITICAL, SEV_HIGH, SEV_MEDIUM,
               SEV_LOW, SEV_MAX } severity_t;

typedef enum { DET_KEYWORD=0, DET_PROCESS, DET_KEYBOARD, DET_SCREEN,
               DET_USB, DET_DPI, DET_MAX } detection_t;

typedef enum { ENF_STRICT=0, ENF_HEURISTIC, ENF_LOGONLY, ENF_MAX } enforcement_t;

/* ============================================================
 * Structures
 * ============================================================ */

typedef struct {
    char text[MAX_LINE];
    int weight;
    regex_t regex;
    int compiled;
} pattern_t;

typedef struct {
    unsigned int id;
    char name[128];
    category_t category;
    severity_t severity;
    detection_t detection;
    enforcement_t enforcement;
    int enabled;
    int npatterns;
    pattern_t patterns[MAX_PATTERNS];
    char description[256];
    char quran[128];
    char proc_names[8][64];
    int nprocs;
} rule_t;

typedef struct {
    rule_t rules[MAX_RULES];
    int count;
    pthread_mutex_t lock;
} rules_db_t;

typedef struct {
    int fb_fd;
    unsigned char *fb_mem;
    int width, height, bpp, stride;
    size_t fbsize;
    pthread_t thread;
    volatile int running;
    int enabled;
} screen_mon_t;

typedef struct {
    int fd;
    char path[128];
    char buf[4096];
    int pos;
    pthread_t thread;
    volatile int running;
    int enabled;
} kbd_mon_t;

typedef struct {
    int inotify_fd;
    pthread_t thread;
    volatile int running;
    int enabled;
} usb_mon_t;

typedef struct {
    pthread_t thread;
    volatile int running;
    int enabled;
} dpi_mon_t;

typedef struct {
    int panic_on_critical;
    int alarm_before_panic;
    int alarm_sec;
    int dry_run;
    pthread_mutex_t lock;
} panic_engine_t;

typedef struct {
    /* config */
    int daemonize, verbose, dry_run;
    char rules_file[512];
    int kbd_enabled, screen_enabled, usb_enabled, dpi_enabled;
    int panic_on_critical, alarm_before_panic, alarm_sec;
    char fb_device[128];
    char kbd_device[128];

    /* subsystems */
    rules_db_t db;
    screen_mon_t screen;
    kbd_mon_t kbd;
    usb_mon_t usb;
    dpi_mon_t dpi;
    panic_engine_t panic;

    volatile int running;
    time_t start_time;
} ctx_t;

/* ============================================================
 * Function declarations
 * ============================================================ */

/* core */
void daemon_log(int pri, const char *fmt, ...) __attribute__((format(printf,2,3)));
int config_load(ctx_t *ctx, const char *path);
int rules_load(ctx_t *ctx, const char *path);
int rules_load_builtin(ctx_t *ctx);
void rules_compile(ctx_t *ctx);
int rules_check_text(ctx_t *ctx, const char *text, category_t *cat, severity_t *sev);

/* monitors */
int kbd_init(ctx_t *ctx);
int kbd_start(ctx_t *ctx);
void kbd_stop(ctx_t *ctx);

int screen_init(ctx_t *ctx);
int screen_start(ctx_t *ctx);
void screen_stop(ctx_t *ctx);

int usb_init(ctx_t *ctx);
int usb_start(ctx_t *ctx);
void usb_stop(ctx_t *ctx);

int dpi_init(ctx_t *ctx);
int dpi_start(ctx_t *ctx);
void dpi_stop(ctx_t *ctx);

/* panic */
int panic_init(ctx_t *ctx);
int panic_trigger(ctx_t *ctx, const char *reason, category_t cat, severity_t sev);
void panic_alarm(ctx_t *ctx);
void panic_kernel_panic(ctx_t *ctx, const char *reason);

/* iptables */
int blocklist_apply(ctx_t *ctx);
int blocklist_load_domains(const char *path);
int blocklist_load_ips(const char *path);

/* util */
char *strtrim(char *s);
int strcase_contains(const char *h, const char *n);

#endif
