/*
 * haram-siren — emergency siren and countdown display for HARAMchy
 *
 * Plays an air-raid style siren (aplay WAV or PC speaker fallback)
 * while displaying a 10-second countdown on the framebuffer / console.
 * Called from haramd or the kernel module via usermodehelper.
 *
 * Usage: haram-siren [--countdown=N] [--locale=ru|en] [--wav=PATH]
 *
 * Copyright (c) 2026 HARAMchy Project — Public Domain
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <linux/kd.h>
#include <linux/fb.h>
#include <termios.h>
#include <getopt.h>
#include <stdint.h>
#include <sys/mman.h>

/* ------------------------------------------------------------------ */
/* Constants                                                           */
/* ------------------------------------------------------------------ */

#define DEFAULT_COUNTDOWN   10
#define APLAY_TIMEOUT_US    500000   /* 0.5 seconds */
#define SIREN_PERIOD_MS     1000
#define SIREN_LOW_HZ        400
#define SIREN_HIGH_HZ       900
#define SIREN_STEPS         20
#define FB_DEVICE           "/dev/fb0"
#define CONSOLE_DEVICE      "/dev/console"
#define DEFAULT_WAV_PATH    "/usr/share/haram-siren/siren.wav"
#define PID_LOCK_FILE       "/tmp/haram-siren.lock"

/* ------------------------------------------------------------------ */
/* Locale strings                                                      */
/* ------------------------------------------------------------------ */

struct locale_strings {
    const char *detected;
    const char *self_destruct;
    const char *countdown_fmt;
    const char *merciful;
};

static const struct locale_strings loc_ru = {
    .detected      = "\xD0\x9E\xD0\x91\xD0\x9D\xD0\x90\xD0\xA0\xD0\xA3\xD0\x96\xD0\x95\xD0\x9D"
                     "\xD0\xA5\xD0\x90\xD0\xA0\xD0\x90\xD0\x9C\xD0\xA7\xD0\x98\xD0\x9A\xD0\x90"
                     "!!",  /* ОБНАРУЖЕН ХАРАМЧИКА!! */
    .self_destruct = "\xD0\xA1\xD0\xA0\xD0\x9E\xD0\xA7\xD0\x9D\xD0\x9E\xD0\x95 \xD0\xA1\xD0\x90"
                     "\xD0\x9C\xD0\xA3\xD0\x9D\xD0\x98\xD0\xA7\xD0\xA2\xD0\x9E\xD0\x96\xD0\x95"
                     "\xD0\x9D\xD0\x98\xD0\x95!!!",
    .countdown_fmt = "  %d  ",
    .merciful      = "\xD0\xA1\xD0\x9C\xD0\x98\xD0\x9B\xD0\x9E\xD0\xA1\xD0\xA2\xD0\x98\xD0\x92"
                     "\xD0\xAA\xD0\xA1\xD0\xAF",
};

static const struct locale_strings loc_en = {
    .detected      = "HARAM DETECTED!!",
    .self_destruct = "EMERGENCY SELF-DESTRUCT!!!",
    .countdown_fmt = "  %d  ",
    .merciful      = "MERCY",
};

/* ------------------------------------------------------------------ */
/* Globals                                                             */
/* ------------------------------------------------------------------ */

static volatile sig_atomic_t g_received_signal = 0;
static int g_fb_fd = -1;
static int g_console_fd = -1;
static unsigned char *g_fb_mem = NULL;
static size_t g_fb_size = 0;
static struct fb_var_screeninfo g_fb_vinfo;
static struct fb_fix_screeninfo g_fb_finfo;

/* ------------------------------------------------------------------ */
/* Signal handler                                                      */
/* ------------------------------------------------------------------ */

static void signal_handler(int sig)
{
    g_received_signal = sig;
}

/* ------------------------------------------------------------------ */
/* PC speaker helpers                                                  */
/* ------------------------------------------------------------------ */

static int pcspkr_open(void)
{
    int fd = open(CONSOLE_DEVICE, O_RDONLY);
    if (fd < 0)
        fd = open("/dev/tty0", O_RDONLY);
    return fd;
}

static int pcspkr_beep(int fd, unsigned int freq)
{
    if (fd < 0)
        return -1;
    return ioctl(fd, KIOCSOUND, freq);
}

static int pcspkr_off(int fd)
{
    return pcspkr_beep(fd, 0);
}

/* Modulated siren tone: sweeps up then down over `duration_ms` */
static void pcspkr_siren_cycle(int fd, int duration_ms)
{
    int step_us = (duration_ms * 1000) / (SIREN_STEPS * 2);
    int i;

    /* sweep up */
    for (i = 0; i < SIREN_STEPS && !g_received_signal; i++) {
        int freq = SIREN_LOW_HZ +
                   (SIREN_HIGH_HZ - SIREN_LOW_HZ) * i / SIREN_STEPS;
        pcspkr_beep(fd, freq);
        usleep(step_us);
    }
    /* sweep down */
    for (i = SIREN_STEPS; i >= 0 && !g_received_signal; i--) {
        int freq = SIREN_LOW_HZ +
                   (SIREN_HIGH_HZ - SIREN_LOW_HZ) * i / SIREN_STEPS;
        pcspkr_beep(fd, freq);
        usleep(step_us);
    }
}

/* ------------------------------------------------------------------ */
/* Framebuffer helpers                                                 */
/* ------------------------------------------------------------------ */

static int fb_open(void)
{
    g_fb_fd = open(FB_DEVICE, O_RDWR);
    if (g_fb_fd < 0)
        return -1;

    if (ioctl(g_fb_fd, FBIOGET_VSCREENINFO, &g_fb_vinfo) < 0 ||
        ioctl(g_fb_fd, FBIOGET_FSCREENINFO, &g_fb_finfo) < 0) {
        close(g_fb_fd);
        g_fb_fd = -1;
        return -1;
    }

    g_fb_size = g_fb_finfo.smem_len;
    g_fb_mem = mmap(NULL, g_fb_size, PROT_READ | PROT_WRITE,
                    MAP_SHARED, g_fb_fd, 0);
    if (g_fb_mem == MAP_FAILED) {
        close(g_fb_fd);
        g_fb_fd = -1;
        return -1;
    }

    return 0;
}

static void fb_close(void)
{
    if (g_fb_mem && g_fb_mem != MAP_FAILED) {
        munmap(g_fb_mem, g_fb_size);
        g_fb_mem = NULL;
    }
    if (g_fb_fd >= 0) {
        close(g_fb_fd);
        g_fb_fd = -1;
    }
}

/* Clear framebuffer to black */
static void fb_clear(void)
{
    if (!g_fb_mem)
        return;
    memset(g_fb_mem, 0, g_fb_size);
}

/* Draw a large blocky digit using simple bitmap font (8x16 scaled) */
static const unsigned char font8x16[10][16] = {
    /* 0 */ { 0x3C,0x66,0x6E,0x76,0x66,0x66,0x66,0x3C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 1 */ { 0x18,0x38,0x18,0x18,0x18,0x18,0x18,0x7E,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 2 */ { 0x3C,0x66,0x06,0x0C,0x18,0x30,0x66,0x7E,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 3 */ { 0x3C,0x66,0x06,0x1C,0x06,0x06,0x66,0x3C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 4 */ { 0x0C,0x1C,0x3C,0x6C,0x7E,0x0C,0x0C,0x0C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 5 */ { 0x7E,0x60,0x7C,0x06,0x06,0x06,0x66,0x3C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 6 */ { 0x1C,0x30,0x60,0x7C,0x66,0x66,0x66,0x3C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 7 */ { 0x7E,0x06,0x0C,0x18,0x30,0x30,0x30,0x30,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 8 */ { 0x3C,0x66,0x66,0x3C,0x66,0x66,0x66,0x3C,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
    /* 9 */ { 0x3C,0x66,0x66,0x3E,0x06,0x06,0x0C,0x38,
              0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 },
};

/*
 * Draw a single scaled glyph at pixel position (x, y).
 * `scale` is the pixel multiplier; color is a 32-bit BGRA value.
 */
static void fb_draw_glyph(int digit, int x, int y, int scale,
                           uint32_t color)
{
    unsigned int row, col;
    unsigned char bits;

    if (digit < 0 || digit > 9 || !g_fb_mem)
        return;

    for (row = 0; row < 16; row++) {
        bits = font8x16[digit][row];
        for (col = 0; col < 8; col++) {
            if (bits & (0x80 >> col)) {
                int sx, sy;
                for (sy = 0; sy < scale; sy++) {
                    for (sx = 0; sx < scale; sx++) {
                        int px = x + col * scale + sx;
                        int py = y + row * scale + sy;
                        if (px < (int)g_fb_vinfo.xres &&
                            py < (int)g_fb_vinfo.yres) {
                            size_t offset = (size_t)py *
                                g_fb_finfo.line_length +
                                px * (g_fb_vinfo.bits_per_pixel / 8);
                            if (offset + 4 <= g_fb_size) {
                                memcpy(g_fb_mem + offset, &color, 4);
                            }
                        }
                    }
                }
            }
        }
    }
}

/* Draw a two-digit countdown number centered on screen */
static void fb_draw_countdown(int number, uint32_t bg_color,
                               uint32_t fg_color)
{
    int scale, digit_w, digit_h, total_w, start_x, start_y;
    int tens, ones;

    if (!g_fb_mem)
        return;

    /* clear screen */
    {
        unsigned int i;
        for (i = 0; i < g_fb_size / 4; i++)
            ((uint32_t *)g_fb_mem)[i] = bg_color;
    }

    scale = (int)(g_fb_vinfo.yres / 32);
    if (scale < 2) scale = 2;
    digit_w = 8 * scale;
    digit_h = 16 * scale;

    tens = number / 10;
    ones = number % 10;

    total_w = digit_w * 2 + digit_w / 2;
    start_x = ((int)g_fb_vinfo.xres - total_w) / 2;
    start_y = ((int)g_fb_vinfo.yres - digit_h) / 2;

    if (tens > 0)
        fb_draw_glyph(tens, start_x, start_y, scale, fg_color);
    fb_draw_glyph(ones, start_x + digit_w + digit_w / 4,
                  start_y, scale, fg_color);
}

/* Draw a text banner at the top of the screen */
static void fb_draw_banner(const char *text, uint32_t fg_color)
{
    /* For simplicity, we use printk/console for text banners.
     * Framebuffer drawing of arbitrary UTF-8 text requires a full
     * font renderer which is beyond scope — the large digits are
     * the primary visual element. */
    (void)text;
    (void)fg_color;
}

/* ------------------------------------------------------------------ */
/* aplay with timeout                                                  */
/* ------------------------------------------------------------------ */

static int try_aplay(const char *wav_path, useconds_t timeout_us)
{
    pid_t pid;
    int status;
    useconds_t elapsed = 0;
    const useconds_t step = 50000; /* 50ms poll interval */

    if (access(wav_path, R_OK) != 0)
        return -1;

    pid = fork();
    if (pid < 0)
        return -1;

    if (pid == 0) {
        /* Child: exec aplay, redirect stdout/stderr to /dev/null */
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        execlp("aplay", "aplay", "-q", wav_path, (char *)NULL);
        _exit(127);
    }

    /* Parent: wait with timeout */
    while (elapsed < timeout_us) {
        pid_t r = waitpid(pid, &status, WNOHANG);
        if (r > 0) {
            /* Child finished */
            if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
                return 0;
            return -1;
        }
        usleep(step);
        elapsed += step;
    }

    /* Timeout — kill the child */
    kill(pid, SIGKILL);
    waitpid(pid, &status, 0);
    return -1;
}

/* ------------------------------------------------------------------ */
/* Console text fallback (printk-style)                                */
/* ------------------------------------------------------------------ */

static void console_banner(const struct locale_strings *loc)
{
    fprintf(stderr, "\n");
    fprintf(stderr, "============================================\n");
    fprintf(stderr, "  %s\n", loc->detected);
    fprintf(stderr, "  %s\n", loc->self_destruct);
    fprintf(stderr, "============================================\n");
    fprintf(stderr, "\n");
}

static void console_countdown(int n, const struct locale_strings *loc)
{
    fprintf(stderr, "\r  %s  ", "");
    fprintf(stderr, "\r");
    fprintf(stderr, loc->countdown_fmt, n);
    fflush(stderr);
}

/* ------------------------------------------------------------------ */
/* Lock file (prevent concurrent instances)                            */
/* ------------------------------------------------------------------ */

static int lock_create(void)
{
    int fd;
    char pid_str[16];
    struct flock fl;

    fd = open(PID_LOCK_FILE, O_CREAT | O_RDWR, 0600);
    if (fd < 0)
        return -1;

    fl.l_type = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = 0;
    fl.l_len = 0;

    if (fcntl(fd, F_SETLK, &fl) < 0) {
        close(fd);
        return -1;
    }

    ftruncate(fd, 0);
    snprintf(pid_str, sizeof(pid_str), "%d\n", getpid());
    write(fd, pid_str, strlen(pid_str));
    /* Keep fd open — lock held until process exits */
    return fd;
}

/* ------------------------------------------------------------------ */
/* Main countdown loop                                                 */
/* ------------------------------------------------------------------ */

static void run_countdown(int seconds, const struct locale_strings *loc,
                           const char *wav_path)
{
    int i;
    int use_fb = 0;
    int pcspkr_fd;
    int aplay_ok = 0;

    /* Try framebuffer */
    use_fb = (fb_open() == 0);

    /* Try PC speaker */
    pcspkr_fd = pcspkr_open();

    /* Pre-check: can we play WAV? Try a quick aplay test */
    if (wav_path && access(wav_path, R_OK) == 0) {
        aplay_ok = 1;
    }

    /* Display initial banner */
    if (!use_fb)
        console_banner(loc);
    else
        fb_draw_banner(loc->detected, 0x000000FF);

    fprintf(stderr, "[haram-siren] countdown: %d seconds\n", seconds);
    fprintf(stderr, "[haram-siren] audio: %s\n",
            aplay_ok ? "aplay (WAV)" : "PC speaker fallback");
    fprintf(stderr, "[haram-siren] display: %s\n",
            use_fb ? "framebuffer" : "console text");

    for (i = seconds; i >= 0 && !g_received_signal; i--) {
        struct timespec ts_start, ts_end;

        clock_gettime(CLOCK_MONOTONIC, &ts_start);

        /* Visual */
        if (use_fb) {
            fb_draw_countdown(i, 0x00000000, 0x00FF0000);
        } else {
            console_countdown(i, loc);
        }

        fprintf(stderr, "\n[haram-siren] T-%d\n", i);

        /* Audio: try aplay in background, use PC speaker as backup */
        if (i > 0) {
            pid_t audio_pid = -1;

            if (aplay_ok) {
                audio_pid = fork();
                if (audio_pid == 0) {
                    execlp("aplay", "aplay", "-q", wav_path,
                           (char *)NULL);
                    _exit(127);
                }
            }

            /* PC speaker siren for this second */
            if (pcspkr_fd >= 0)
                pcspkr_siren_cycle(pcspkr_fd, SIREN_PERIOD_MS);

            /* If aplay was started, kill it after the cycle */
            if (audio_pid > 0) {
                int wstatus;
                kill(audio_pid, SIGKILL);
                waitpid(audio_pid, &wstatus, 0);
            }
        }

        /* Wait remainder of 1 second */
        clock_gettime(CLOCK_MONOTONIC, &ts_end);
        {
            long elapsed_ns = (ts_end.tv_sec - ts_start.tv_sec) * 1000000000L
                            + (ts_end.tv_nsec - ts_start.tv_nsec);
            long remaining_ns = 1000000000L - elapsed_ns;
            if (remaining_ns > 0)
                usleep(remaining_ns / 1000);
        }
    }

    /* Silence speaker */
    if (pcspkr_fd >= 0) {
        pcspkr_off(pcspkr_fd);
        close(pcspkr_fd);
    }

    /* Final visual state */
    if (use_fb) {
        usleep(300000); /* brief pause at zero */
        fb_clear();
        fb_close();
    }

    fprintf(stderr, "\n");
    fprintf(stderr, "[haram-siren] countdown complete.\n");
}

/* ------------------------------------------------------------------ */
/* Argument parsing                                                    */
/* ------------------------------------------------------------------ */

static void usage(const char *prog)
{
    fprintf(stderr,
        "Usage: %s [OPTIONS]\n"
        "  --countdown=N    Countdown seconds (default: 10)\n"
        "  --locale=ru|en   Language (default: en)\n"
        "  --wav=PATH       Path to WAV siren file\n"
        "  --help           Show this help\n",
        prog);
}

int main(int argc, char *argv[])
{
    int countdown = DEFAULT_COUNTDOWN;
    const char *locale = "en";
    const char *wav_path = DEFAULT_WAV_PATH;
    const struct locale_strings *loc;
    int lock_fd;
    int opt;

    static struct option long_opts[] = {
        { "countdown", required_argument, NULL, 'c' },
        { "locale",    required_argument, NULL, 'l' },
        { "wav",       required_argument, NULL, 'w' },
        { "help",      no_argument,       NULL, 'h' },
        { NULL, 0, NULL, 0 }
    };

    while ((opt = getopt_long(argc, argv, "c:l:w:h", long_opts, NULL)) != -1) {
        switch (opt) {
        case 'c':
            countdown = atoi(optarg);
            if (countdown < 1 || countdown > 60) {
                fprintf(stderr, "error: countdown must be 1-60\n");
                return 1;
            }
            break;
        case 'l':
            locale = optarg;
            break;
        case 'w':
            wav_path = optarg;
            break;
        case 'h':
        default:
            usage(argv[0]);
            return (opt == 'h') ? 0 : 1;
        }
    }

    /* Select locale strings */
    if (strcmp(locale, "ru") == 0)
        loc = &loc_ru;
    else
        loc = &loc_en;

    /* Install signal handlers */
    signal(SIGTERM, signal_handler);
    signal(SIGINT,  signal_handler);

    /* Prevent concurrent siren instances */
    lock_fd = lock_create();
    if (lock_fd < 0) {
        fprintf(stderr, "[haram-siren] another instance is running, exiting.\n");
        return 1;
    }

    fprintf(stderr, "[haram-siren] HARAMchy emergency siren v1.0\n");
    fprintf(stderr, "[haram-siren] locale=%s countdown=%d wav=%s\n",
            locale, countdown, wav_path);

    run_countdown(countdown, loc, wav_path);

    fprintf(stderr, "[haram-siren] exiting.\n");
    return 0;
}
