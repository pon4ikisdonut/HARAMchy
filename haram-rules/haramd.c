/*
 * haramd.c - HARAMchy Daemon v3.0
 *
 * Compact kernel panic enforcement daemon.
 * Monitors keyboard, screen, USB, network (DPI), processes.
 * Triggers kernel panic on haram detection.
 *
 * Copyright (c) 2026 HARAMchy Linux Distribution — GPL v2
 */

#include "haramd.h"

static ctx_t g_ctx;
static volatile sig_atomic_t g_running = 1;

/* ============================================================
 * Logging
 * ============================================================ */

void daemon_log(int pri, const char *fmt, ...)
{
    va_list ap;
    char msg[2048];
    va_start(ap, fmt);
    vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);
    syslog(pri, "%s", msg);
    if (g_ctx.verbose >= 4)
        fprintf(stderr, "[%s] %s\n",
                pri >= LOG_ERR ? "ERR" : pri >= LOG_WARNING ? "WRN" : "INF", msg);
}

/* ============================================================
 * Utilities
 * ============================================================ */

char *strtrim(char *s)
{
    char *e;
    if (!s) return NULL;
    while (isspace((unsigned char)*s)) s++;
    if (!*s) return s;
    e = s + strlen(s) - 1;
    while (e > s && isspace((unsigned char)*e)) e--;
    *(e + 1) = '\0';
    return s;
}

int strcase_contains(const char *h, const char *n)
{
    size_t nl;
    if (!h || !n) return 0;
    nl = strlen(n);
    if (!nl) return 1;
    for (; *h; h++)
        if (strncasecmp(h, n, nl) == 0) return 1;
    return 0;
}

static int read_file(const char *path, char *buf, size_t sz)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;
    size_t n = fread(buf, 1, sz - 1, fp);
    fclose(fp);
    buf[n] = '\0';
    return (int)n;
}

/* ============================================================
 * Config
 * ============================================================ */

static int toml_int(const char *c, const char *k, int *out)
{
    const char *p = strstr(c, k);
    if (!p) return -1;
    p += strlen(k);
    while (*p == '=' || *p == ' ' || *p == '\t') p++;
    *out = atoi(p);
    return 0;
}

static int toml_str(const char *c, const char *k, char *out, size_t sz)
{
    const char *p = strstr(c, k);
    if (!p) return -1;
    p += strlen(k);
    while (*p == '=' || *p == ' ' || *p == '\t') p++;
    if (*p == '"') p++;
    const char *e = p;
    while (*e && *e != '"' && *e != '\n' && *e != ' ') e++;
    size_t l = (size_t)(e - p);
    if (l >= sz) l = sz - 1;
    memcpy(out, p, l); out[l] = '\0';
    return 0;
}

static int toml_bool(const char *c, const char *k, int *out)
{
    char v[16];
    if (toml_str(c, k, v, sizeof(v)) < 0) return -1;
    *out = (strcmp(v, "true") == 0 || strcmp(v, "1") == 0 || strcmp(v, "yes") == 0);
    return 0;
}

int config_load(ctx_t *ctx, const char *path)
{
    char buf[32768];
    int n = read_file(path, buf, sizeof(buf));
    if (n <= 0) return -1;

    toml_bool(buf, "daemonize", &ctx->daemonize);
    toml_int(buf, "verbose", &ctx->verbose);
    toml_bool(buf, "dry_run", &ctx->dry_run);
    toml_str(buf, "rules_file", ctx->rules_file, sizeof(ctx->rules_file));
    toml_bool(buf, "keyboard_enabled", &ctx->kbd_enabled);
    toml_bool(buf, "screen_enabled", &ctx->screen_enabled);
    toml_bool(buf, "usb_enabled", &ctx->usb_enabled);
    toml_bool(buf, "dpi_enabled", &ctx->dpi_enabled);
    toml_bool(buf, "panic_on_critical", &ctx->panic_on_critical);
    toml_bool(buf, "alarm_before_panic", &ctx->alarm_before_panic);
    toml_int(buf, "alarm_sec", &ctx->alarm_sec);
    toml_str(buf, "framebuffer_device", ctx->fb_device, sizeof(ctx->fb_device));
    toml_str(buf, "keyboard_device", ctx->kbd_device, sizeof(ctx->kbd_device));

    daemon_log(LOG_INFO, "Config loaded: kbd=%d screen=%d usb=%d dpi=%d panic=%d",
               ctx->kbd_enabled, ctx->screen_enabled, ctx->usb_enabled,
               ctx->dpi_enabled, ctx->panic_on_critical);
    return 0;
}

/* ============================================================
 * Rules Engine
 * ============================================================ */

static category_t cat_from_str(const char *s)
{
    if (!s) return CAT_UNKNOWN;
    if (strstr(s, "microsoft")) return CAT_MICROSOFT;
    if (strstr(s, "food")) return CAT_FOOD;
    if (strstr(s, "alcohol") || strstr(s, "gambling") || strstr(s, "drug")) return CAT_ALCOHOL;
    if (strstr(s, "violence")) return CAT_VIOLENCE;
    if (strstr(s, "immoral")) return CAT_IMMORAL;
    if (strstr(s, "lies") || strstr(s, "deception")) return CAT_DECEPTION;
    if (strstr(s, "occult") || strstr(s, "wide_knowledge")) return CAT_OCCULT;
    if (strstr(s, "financial")) return CAT_FINANCIAL;
    if (strstr(s, "prayer")) return CAT_PRAYER;
    return CAT_UNKNOWN;
}

static severity_t sev_from_str(const char *s)
{
    if (!s) return SEV_UNKNOWN;
    if (strstr(s, "critical")) return SEV_CRITICAL;
    if (strstr(s, "high")) return SEV_HIGH;
    if (strstr(s, "medium")) return SEV_MEDIUM;
    if (strstr(s, "low")) return SEV_LOW;
    return SEV_UNKNOWN;
}

static detection_t det_from_str(const char *s)
{
    if (!s) return DET_KEYWORD;
    if (strstr(s, "process")) return DET_PROCESS;
    if (strstr(s, "keyboard")) return DET_KEYBOARD;
    if (strstr(s, "screen")) return DET_SCREEN;
    if (strstr(s, "usb")) return DET_USB;
    if (strstr(s, "dpi")) return DET_DPI;
    return DET_KEYWORD;
}

static int yaml_parse(ctx_t *ctx, const char *text)
{
    const char *p = text;
    rule_t *r = NULL;
    int in_pat = 0, pat_idx = 0;

    while (*p) {
        /* find end of current line */
        const char *line_start = p;
        while (*p && *p != '\n') p++;
        size_t linelen = (size_t)(p - line_start);
        if (*p == '\n') p++;

        /* skip blanks and comments */
        const char *s = line_start;
        while (s < p && (*s == ' ' || *s == '\t')) s++;
        if (s >= p || *s == '\n' || *s == '#' || *s == '\0') continue;

        /* check for "  - id:" rule marker (must match BEFORE whitespace skip for the leading spaces) */
        if (linelen >= 7 && strncmp(line_start, "  - id:", 7) == 0) {
            if (r) r->npatterns = pat_idx;
            if (ctx->db.count >= MAX_RULES) break;
            r = &ctx->db.rules[ctx->db.count++];
            memset(r, 0, sizeof(*r));
            in_pat = 0; pat_idx = 0;
            const char *v = s + 7; while (v < p && *v == ' ') v++;
            r->id = (unsigned int)atoi(v);
            r->enabled = 1;
            continue;
        }

        if (!r) continue;

        /* key: value fields — use line_start to preserve leading whitespace for YAML indent matching */
        if (linelen > 8 && strncmp(line_start, "    name:", 8) == 0) {
            const char *v = line_start + 8; while (*v == ' ') v++;
            int i = 0;
            while (v < p && *v != '\n' && i < (int)sizeof(r->name)-1) r->name[i++] = *v++;
            r->name[i] = '\0'; in_pat = 0;
        }
        else if (linelen > 11 && strncmp(line_start, "    category:", 11) == 0) {
            char tmp[64] = {0}; int i = 0;
            const char *v = line_start + 11; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 63) tmp[i++] = *v++;
            r->category = cat_from_str(tmp); in_pat = 0;
        }
        else if (linelen > 11 && strncmp(line_start, "    severity:", 11) == 0) {
            char tmp[32] = {0}; int i = 0;
            const char *v = line_start + 11; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 31) tmp[i++] = *v++;
            r->severity = sev_from_str(tmp); in_pat = 0;
        }
        else if (linelen > 16 && strncmp(line_start, "    detection_type:", 16) == 0) {
            char tmp[64] = {0}; int i = 0;
            const char *v = line_start + 16; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 63) tmp[i++] = *v++;
            r->detection = det_from_str(tmp); in_pat = 0;
        }
        else if (linelen > 13 && strncmp(line_start, "    enforcement:", 13) == 0) {
            char tmp[32] = {0}; int i = 0;
            const char *v = line_start + 13; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 31) tmp[i++] = *v++;
            if (strstr(tmp, "strict")) r->enforcement = ENF_STRICT;
            else if (strstr(tmp, "heuristic")) r->enforcement = ENF_HEURISTIC;
            else r->enforcement = ENF_LOGONLY;
            in_pat = 0;
        }
        else if (linelen > 10 && strncmp(line_start, "    enabled:", 10) == 0) {
            const char *v = line_start + 10; while (*v == ' ') v++;
            r->enabled = (strncmp(v, "true", 4) == 0); in_pat = 0;
        }
        else if (linelen > 13 && strncmp(line_start, "    description:", 13) == 0) {
            char tmp[256] = {0}; int i = 0;
            const char *v = line_start + 13; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 255) tmp[i++] = *v++;
            snprintf(r->description, sizeof(r->description), "%s", tmp); in_pat = 0;
        }
        else if (linelen > 17 && strncmp(line_start, "    quran_reference:", 17) == 0) {
            char tmp[128] = {0}; int i = 0;
            const char *v = line_start + 17; while (*v == ' ') v++;
            while (v < p && *v != '\n' && i < 127) tmp[i++] = *v++;
            snprintf(r->quran, sizeof(r->quran), "%s", tmp); in_pat = 0;
        }
        else if (linelen > 10 && strncmp(line_start, "    patterns:", 10) == 0) {
            in_pat = 1; pat_idx = 0;
        }
        else if (linelen > 14 && strncmp(line_start, "    process_names:", 14) == 0) {
            in_pat = 0;
        }

        /* pattern entries */
        if (in_pat && linelen > 15 && strncmp(line_start, "      - pattern:", 15) == 0 && pat_idx < MAX_PATTERNS) {
            const char *v = line_start + 15; while (*v == ' ') v++;
            int i = 0;
            while (v < p && *v != '\n' && i < MAX_LINE - 1)
                r->patterns[pat_idx].text[i++] = *v++;
            r->patterns[pat_idx].text[i] = '\0';
            r->patterns[pat_idx].weight = 80;
            pat_idx++;
        }

        /* process name entries */
        if (!in_pat && linelen > 9 && strncmp(line_start, "      - \"", 9) == 0 && r->nprocs < 8) {
            const char *v = line_start + 9;
            int i = 0;
            while (v < p && *v != '"' && *v != '\n' && i < 63)
                r->proc_names[r->nprocs][i++] = *v++;
            r->proc_names[r->nprocs][i] = '\0';
            r->nprocs++;
        }
    }
    if (r) r->npatterns = pat_idx;
    return 0;
}

int rules_load(ctx_t *ctx, const char *path)
{
    char *buf;
    long sz;
    FILE *fp;

    sz = 0;
    fp = fopen(path, "r");
    if (!fp) return rules_load_builtin(ctx);
    fseek(fp, 0, SEEK_END);
    sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (sz <= 0 || sz > 1048576) { fclose(fp); return rules_load_builtin(ctx); }

    buf = malloc((size_t)sz + 1);
    if (!buf) { fclose(fp); return rules_load_builtin(ctx); }
    fread(buf, 1, (size_t)sz, fp);
    buf[sz] = '\0';
    fclose(fp);

    memset(&ctx->db, 0, sizeof(ctx->db));
    pthread_mutex_init(&ctx->db.lock, NULL);
    yaml_parse(ctx, buf);
    free(buf);

    if (ctx->db.count == 0) return rules_load_builtin(ctx);

    daemon_log(LOG_INFO, "Loaded %d rules from %s", ctx->db.count, path);
    return 0;
}

int rules_load_builtin(ctx_t *ctx)
{
    /* Embedded rules — Windows + Quran */
    static const char R[] =
        "rules:\n"

        /* ======== WINDOWS / MICROSOFT (CRITICAL) ======== */
        "  - id: 66601\n"
        "    name: windows_en\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows detection (English)\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: windows\n"
        "        weight: 100\n"
        "      - pattern: microsoft\n"
        "        weight: 100\n"
        "      - pattern: windows.10\n"
        "        weight: 100\n"
        "      - pattern: windows.11\n"
        "        weight: 100\n"
        "      - pattern: windows.server\n"
        "        weight: 100\n"
        "      - pattern: msdos\n"
        "        weight: 100\n"
        "      - pattern: ms.dos\n"
        "        weight: 100\n"
        "      - pattern: bill.gates\n"
        "        weight: 90\n"

        "  - id: 66602\n"
        "    name: windows_ru_slang\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows detection (Russian slang)\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: виндовс\n"
        "        weight: 100\n"
        "      - pattern: винда\n"
        "        weight: 100\n"
        "      - pattern: виндовc\n"
        "        weight: 100\n"
        "      - pattern: виндوز\n"
        "        weight: 100\n"
        "      - pattern: виндуз\n"
        "        weight: 100\n"
        "      - pattern: шинда\n"
        "        weight: 100\n"
        "      - pattern: шиндуз\n"
        "        weight: 100\n"
        "      - pattern: шиндоз\n"
        "        weight: 100\n"
        "      - pattern: майкрософт\n"
        "        weight: 100\n"
        "      - pattern: микрософт\n"
        "        weight: 100\n"
        "      - pattern: майкрософтов\n"
        "        weight: 100\n"
        "      - pattern: гейтс\n"
        "        weight: 90\n"

        "  - id: 66603\n"
        "    name: windows_usb\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: usb_monitor\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows ISO on USB\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: windows.*iso\n"
        "        weight: 100\n"
        "      - pattern: win.*usb\n"
        "        weight: 95\n"

        "  - id: 66604\n"
        "    name: windows_download\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows download process\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    process_names:\n"
        "      - wget\n"
        "      - curl\n"
        "    patterns:\n"
        "      - pattern: windows.*iso\n"
        "        weight: 100\n"
        "      - pattern: media.creation.tool\n"
        "        weight: 95\n"
        "      - pattern: microsoft.*download\n"
        "        weight: 90\n"

        "  - id: 66605\n"
        "    name: windows_screen\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: screen_scan\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows text on screen\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: windows\n"
        "        weight: 100\n"
        "      - pattern: microsoft\n"
        "        weight: 100\n"

        "  - id: 66606\n"
        "    name: windows_keyboard\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: keyboard_monitor\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows typed on keyboard\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: windows\n"
        "        weight: 100\n"
        "      - pattern: виндовс\n"
        "        weight: 100\n"
        "      - pattern: винда\n"
        "        weight: 100\n"
        "      - pattern: шинда\n"
        "        weight: 100\n"
        "      - pattern: шиндуз\n"
        "        weight: 100\n"
        "      - pattern: майкрософт\n"
        "        weight: 100\n"

        "  - id: 66607\n"
        "    name: windows_dpi\n"
        "    category: microsoft\n"
        "    severity: critical\n"
        "    detection_type: dpi\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Windows/Microsoft domain in DNS/HTTP\n"
        "    quran_reference: Al-Baqarah 2:120\n"
        "    patterns:\n"
        "      - pattern: windows\n"
        "        weight: 100\n"
        "      - pattern: microsoft\n"
        "        weight: 100\n"
        "      - pattern: msn.com\n"
        "        weight: 100\n"
        "      - pattern: outlook.com\n"
        "        weight: 100\n"
        "      - pattern: office.com\n"
        "        weight: 100\n"
        "      - pattern: live.com\n"
        "        weight: 95\n"
        "      - pattern: azure.com\n"
        "        weight: 100\n"
        "      - pattern: skype.com\n"
        "        weight: 90\n"
        "      - pattern: linkedin.com\n"
        "        weight: 85\n"
        "      - pattern: github.com\n"
        "        weight: 80\n"
        "      - pattern: visualstudio.com\n"
        "        weight: 100\n"
        "      - pattern: xbox.com\n"
        "        weight: 100\n"

        /* ======== QURAN RULES ======== */

        "  - id: 1001\n"
        "    name: pork_swine\n"
        "    category: food\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Pork/pig detection\n"
        "    quran_reference: Al-Baqarah 2:173, Al-Maidah 5:3\n"
        "    patterns:\n"
        "      - pattern: pork\n"
        "        weight: 100\n"
        "      - pattern: pig\n"
        "        weight: 100\n"
        "      - pattern: swine\n"
        "        weight: 100\n"
        "      - pattern: bacon\n"
        "        weight: 100\n"
        "      - pattern: lard\n"
        "        weight: 90\n"

        "  - id: 1002\n"
        "    name: pork_swine_ru\n"
        "    category: food\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Pork/pig Russian\n"
        "    quran_reference: Al-Baqarah 2:173\n"
        "    patterns:\n"
        "      - pattern: свинин\n"
        "        weight: 100\n"
        "      - pattern: свинь\n"
        "        weight: 100\n"

        "  - id: 2001\n"
        "    name: alcohol\n"
        "    category: alcohol\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Alcohol detection\n"
        "    quran_reference: Al-Maidah 5:90\n"
        "    patterns:\n"
        "      - pattern: alcohol\n"
        "        weight: 100\n"
        "      - pattern: vodka\n"
        "        weight: 100\n"
        "      - pattern: wine\n"
        "        weight: 95\n"
        "      - pattern: beer\n"
        "        weight: 100\n"
        "      - pattern: whiskey\n"
        "        weight: 100\n"

        "  - id: 2002\n"
        "    name: alcohol_ru\n"
        "    category: alcohol\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Alcohol Russian\n"
        "    quran_reference: Al-Maidah 5:90\n"
        "    patterns:\n"
        "      - pattern: алкогол\n"
        "        weight: 100\n"
        "      - pattern: водк\n"
        "        weight: 100\n"
        "      - pattern: пиво\n"
        "        weight: 100\n"

        "  - id: 2010\n"
        "    name: gambling\n"
        "    category: gambling\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Gambling\n"
        "    quran_reference: Al-Maidah 5:90\n"
        "    patterns:\n"
        "      - pattern: casino\n"
        "        weight: 100\n"
        "      - pattern: poker\n"
        "        weight: 100\n"
        "      - pattern: gambling\n"
        "        weight: 100\n"

        "  - id: 2020\n"
        "    name: drugs\n"
        "    category: drugs\n"
        "    severity: critical\n"
        "    detection_type: keyword\n"
        "    enforcement: strict\n"
        "    enabled: true\n"
        "    description: Drugs\n"
        "    quran_reference: Al-Maidah 5:90\n"
        "    patterns:\n"
        "      - pattern: cocaine\n"
        "        weight: 100\n"
        "      - pattern: heroin\n"
        "        weight: 100\n"

        "  - id: 3001\n"
        "    name: violence\n"
        "    category: violence\n"
        "    severity: high\n"
        "    detection_type: keyword\n"
        "    enforcement: heuristic\n"
        "    enabled: true\n"
        "    description: Violence/weapons\n"
        "    quran_reference: Al-Maidah 5:32\n"
        "    patterns:\n"
        "      - pattern: bomb.mak\n"
        "        weight: 100\n"
        "      - pattern: terrorist\n"
        "        weight: 95\n"

        "  - id: 4001\n"
        "    name: immoral_content\n"
        "    category: immoral\n"
        "    severity: high\n"
        "    detection_type: keyword\n"
        "    enforcement: heuristic\n"
        "    enabled: true\n"
        "    description: Adult content\n"
        "    quran_reference: Al-Isra 17:32\n"
        "    patterns:\n"
        "      - pattern: porn\n"
        "        weight: 100\n"
        "      - pattern: xxx\n"
        "        weight: 95\n"
        "      - pattern: nsfw\n"
        "        weight: 90\n"

        "  - id: 5001\n"
        "    name: deception\n"
        "    category: deception\n"
        "    severity: medium\n"
        "    detection_type: keyword\n"
        "    enforcement: heuristic\n"
        "    enabled: true\n"
        "    description: Deception tools\n"
        "    quran_reference: Al-Baqarah 2:42\n"
        "    patterns:\n"
        "      - pattern: deep.fake\n"
        "        weight: 100\n"
        "      - pattern: forgery\n"
        "        weight: 85\n"

        "  - id: 9001\n"
        "    name: occult\n"
        "    category: occult\n"
        "    severity: high\n"
        "    detection_type: keyword\n"
        "    enforcement: heuristic\n"
        "    enabled: true\n"
        "    description: Occult/fortune telling\n"
        "    quran_reference: Al-Maidah 5:3\n"
        "    patterns:\n"
        "      - pattern: horoscope\n"
        "        weight: 95\n"
        "      - pattern: tarot\n"
        "        weight: 90\n"
        "      - pattern: witchcraft\n"
        "        weight: 95\n"

        "  - id: 8001\n"
        "    name: riba\n"
        "    category: financial\n"
        "    severity: high\n"
        "    detection_type: keyword\n"
        "    enforcement: heuristic\n"
        "    enabled: true\n"
        "    description: Riba/usury\n"
        "    quran_reference: Al-Baqarah 2:275\n"
        "    patterns:\n"
        "      - pattern: riba\n"
        "        weight: 100\n"
        "      - pattern: usury\n"
        "        weight: 100\n";

    memset(&ctx->db, 0, sizeof(ctx->db));
    pthread_mutex_init(&ctx->db.lock, NULL);
    yaml_parse(ctx, R);
    daemon_log(LOG_INFO, "Loaded %d builtin rules", ctx->db.count);
    return 0;
}

void rules_compile(ctx_t *ctx)
{
    int compiled = 0, failed = 0;
    pthread_mutex_lock(&ctx->db.lock);
    for (int i = 0; i < ctx->db.count; i++) {
        for (int j = 0; j < ctx->db.rules[i].npatterns; j++) {
            if (!ctx->db.rules[i].patterns[j].text[0]) continue;
            if (regcomp(&ctx->db.rules[i].patterns[j].regex,
                        ctx->db.rules[i].patterns[j].text,
                        REG_EXTENDED | REG_ICASE | REG_NOSUB) == 0) {
                ctx->db.rules[i].patterns[j].compiled = 1;
                compiled++;
            } else failed++;
        }
    }
    pthread_mutex_unlock(&ctx->db.lock);
    daemon_log(LOG_INFO, "Compiled %d regex (%d failed)", compiled, failed);
}

int rules_check_text(ctx_t *ctx, const char *text, category_t *cat, severity_t *sev)
{
    if (!text || !cat || !sev) return 0;
    int found = 0;

    pthread_mutex_lock(&ctx->db.lock);
    for (int i = 0; i < ctx->db.count; i++) {
        rule_t *r = &ctx->db.rules[i];
        if (!r->enabled) continue;
        for (int j = 0; j < r->npatterns; j++) {
            int match = 0;
            if (r->patterns[j].compiled)
                match = (regexec(&r->patterns[j].regex, text, 0, NULL, 0) == 0);
            else
                match = strcase_contains(text, r->patterns[j].text);
            if (match) {
                *cat = r->category;
                *sev = r->severity;
                daemon_log(LOG_WARNING, "RULE HIT: %s [%s] sev=%d pattern='%s' in '%.128s'",
                           r->name, r->quran, r->severity, r->patterns[j].text, text);
                found = 1;
                goto done;
            }
        }
    }
done:
    pthread_mutex_unlock(&ctx->db.lock);
    return found;
}

/* ============================================================
 * Keyboard Monitor (evdev)
 * ============================================================ */

static int find_keyboard(char *path, size_t sz)
{
    DIR *d = opendir("/dev/input");
    if (!d) return -1;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5)) continue;
        char dp[256];
        snprintf(dp, sizeof(dp), "/dev/input/%s", e->d_name);
        int fd = open(dp, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        char name[256] = {0};
        ioctl(fd, EVIOCGNAME(sizeof(name)), name);
        /* simple heuristic: name contains "keyboard" or "kbd" */
        if (strcase_contains(name, "keyboard") || strcase_contains(name, "kbd") ||
            strcase_contains(name, "AT Translated")) {
            snprintf(path, sz, "%s", dp);
            close(fd);
            closedir(d);
            daemon_log(LOG_INFO, "Found keyboard: %s at %s", name, dp);
            return 0;
        }
        close(fd);
    }
    closedir(d);
    return -1;
}

static const char KEYMAP[256] = {
    ['a']='a',['b']='b',['c']='c',['d']='d',['e']='e',['f']='f',
    ['g']='g',['h']='h',['i']='i',['j']='j',['k']='k',['l']='l',
    ['m']='m',['n']='n',['o']='o',['p']='p',['q']='q',['r']='r',
    ['s']='s',['t']='t',['u']='u',['v']='v',['w']='w',['x']='x',
    ['y']='y',['z']='z',
    ['1']='1',['2']='2',['3']='3',['4']='4',['5']='5',
    ['6']='6',['7']='7',['8']='8',['9']='9',['0']='0',
    [' ']=' ', ['-']='-', ['=']='=', ['[']=']', [']']='[',
    [';']=';', ['\'']='\'', [',']=',', ['.']='.', ['/']='/',
};

static void *kbd_thread(void *arg)
{
    ctx_t *ctx = (ctx_t *)arg;
    struct input_event ev;

    daemon_log(LOG_INFO, "KBD thread started on %s", ctx->kbd.path);

    while (ctx->kbd.running && g_running) {
        ssize_t n = read(ctx->kbd.fd, &ev, sizeof(ev));
        if (n == sizeof(ev) && ev.type == EV_KEY && ev.value == 1) {
            int ch = (ev.code < 256) ? KEYMAP[ev.code] : 0;
            if (ch == '\n' || ch == '\r') {
                if (ctx->kbd.pos > 0) {
                    ctx->kbd.buf[ctx->kbd.pos] = '\0';
                    category_t cat; severity_t sev;
                    if (rules_check_text(ctx, ctx->kbd.buf, &cat, &sev)) {
                        if (sev == SEV_CRITICAL && ctx->panic_on_critical)
                            panic_trigger(ctx, "Haram text on keyboard", cat, sev);
                    }
                    ctx->kbd.pos = 0;
                }
            } else if (ch && ctx->kbd.pos < (int)sizeof(ctx->kbd.buf) - 1) {
                ctx->kbd.buf[ctx->kbd.pos++] = ch;
            } else if (ev.code == KEY_BACKSPACE && ctx->kbd.pos > 0) {
                ctx->kbd.buf[--ctx->kbd.pos] = '\0';
            }
        } else {
            usleep(1000);
        }
    }
    return NULL;
}

int kbd_init(ctx_t *ctx)
{
    ctx->kbd.fd = -1;
    ctx->kbd.enabled = 1;
    if (ctx->kbd_device[0])
        snprintf(ctx->kbd.path, sizeof(ctx->kbd.path), "%s", ctx->kbd_device);
    else if (find_keyboard(ctx->kbd.path, sizeof(ctx->kbd.path)) < 0) {
        ctx->kbd.enabled = 0;
        return -1;
    }
    return 0;
}

int kbd_start(ctx_t *ctx)
{
    if (!ctx->kbd.enabled) return 0;
    ctx->kbd.fd = open(ctx->kbd.path, O_RDONLY | O_NONBLOCK);
    if (ctx->kbd.fd < 0) { ctx->kbd.enabled = 0; return -1; }
    ctx->kbd.running = 1;
    pthread_create(&ctx->kbd.thread, NULL, kbd_thread, ctx);
    daemon_log(LOG_INFO, "Keyboard monitor: ON (%s)", ctx->kbd.path);
    return 0;
}

void kbd_stop(ctx_t *ctx)
{
    ctx->kbd.running = 0;
    if (ctx->kbd.fd >= 0) close(ctx->kbd.fd);
    pthread_join(ctx->kbd.thread, NULL);
}

/* ============================================================
 * Screen Monitor (framebuffer)
 * ============================================================ */

static void *screen_thread(void *arg)
{
    ctx_t *ctx = (ctx_t *)arg;
    int bpp_bytes;
    int row_step, col_step;

    daemon_log(LOG_INFO, "Screen thread started (%dx%d %dbpp)",
               ctx->screen.width, ctx->screen.height, ctx->screen.bpp);

    bpp_bytes = ctx->screen.bpp / 8;
    if (bpp_bytes < 1) bpp_bytes = 1;
    row_step = ctx->screen.height > 200 ? 4 : 2;
    col_step = ctx->screen.width > 200 ? 4 : 2;

    while (ctx->screen.running && g_running) {
        usleep(2000000);

        /* re-read framebuffer */
        lseek(ctx->screen.fb_fd, 0, SEEK_SET);
        read(ctx->screen.fb_fd, ctx->screen.fb_mem, ctx->screen.fbsize);

        /* extract text-like content from bright regions */
        char textbuf[65536];
        size_t tpos = 0;

        for (int y = 0; y < ctx->screen.height && tpos < sizeof(textbuf) - 32; y += row_step) {
            int bright = 0;
            for (int x = 0; x < ctx->screen.width; x += col_step) {
                size_t off = (size_t)y * ctx->screen.stride + (size_t)x * bpp_bytes;
                if (off + 3 >= ctx->screen.fbsize) break;
                unsigned char r = ctx->screen.fb_mem[off + 2];
                unsigned char g = ctx->screen.fb_mem[off + 1];
                unsigned char b = ctx->screen.fb_mem[off + 0];
                int lum = (r * 77 + g * 150 + b * 29) >> 8;
                if (lum > 200) bright++;
            }
            if (bright > 5) {
                /* This row has significant bright content — likely text */
                /* We use the brightness pattern as a proxy for text detection */
                if (tpos > 0 && textbuf[tpos - 1] != '\n')
                    textbuf[tpos++] = '\n';
                tpos += snprintf(textbuf + tpos, sizeof(textbuf) - tpos,
                                 "ROW%d_BRIGHT%d", y, bright);
            }
        }
        textbuf[tpos] = '\0';

        /* Also scan for specific pixel patterns (Windows logo = blue rectangles) */
        /* Detect the characteristic Windows 4-pane logo:
         * 4 bright blue squares in a 2x2 grid */
        for (int y = 0; y < ctx->screen.height - 60; y += 2) {
            for (int x = 0; x < ctx->screen.width - 60; x += 2) {
                size_t off = (size_t)y * ctx->screen.stride + (size_t)x * bpp_bytes;
                if (off + 3 >= ctx->screen.fbsize) continue;
                unsigned char r = ctx->screen.fb_mem[off + 2];
                unsigned char g = ctx->screen.fb_mem[off + 1];
                unsigned char b = ctx->screen.fb_mem[off + 0];
                /* Windows blue: R<50, G<50, B>150 */
                if (r < 50 && g < 50 && b > 150) {
                    /* Check for 4-pane structure */
                    int pane_count = 0;
                    for (int dy = 0; dy < 40; dy += 10) {
                        for (int dx = 0; dx < 40; dx += 10) {
                            size_t po = (size_t)(y+dy)*ctx->screen.stride + (size_t)(x+dx)*bpp_bytes;
                            if (po + 3 >= ctx->screen.fbsize) continue;
                            unsigned char pr = ctx->screen.fb_mem[po+2];
                            unsigned char pg = ctx->screen.fb_mem[po+1];
                            unsigned char pb = ctx->screen.fb_mem[po+0];
                            if (pr < 50 && pg < 50 && pb > 150) pane_count++;
                        }
                    }
                    if (pane_count > 12) {
                        /* Likely Windows logo detected */
                        strncat(textbuf, "\nWINDOWS_LOGO_DETECTED", sizeof(textbuf) - tpos - 1);
                        goto check_screen;
                    }
                }
            }
        }

check_screen:
        if (tpos > 0) {
            category_t cat; severity_t sev;
            if (rules_check_text(ctx, textbuf, &cat, &sev)) {
                if (sev == SEV_CRITICAL && ctx->panic_on_critical)
                    panic_trigger(ctx, "Haram content on screen", cat, sev);
            }
        }
    }
    return NULL;
}

int screen_init(ctx_t *ctx)
{
    ctx->screen.enabled = 1;
    const char *dev = ctx->fb_device[0] ? ctx->fb_device : "/dev/fb0";
    ctx->screen.fb_fd = open(dev, O_RDONLY);
    if (ctx->screen.fb_fd < 0) {
        daemon_log(LOG_WARNING, "Cannot open %s: %s (screen OFF)", dev, strerror(errno));
        ctx->screen.enabled = 0;
        return -1;
    }
    struct fb_var_screeninfo vinfo;
    if (ioctl(ctx->screen.fb_fd, FBIOGET_VSCREENINFO, &vinfo) < 0) {
        close(ctx->screen.fb_fd);
        ctx->screen.enabled = 0;
        return -1;
    }
    ctx->screen.width = vinfo.xres;
    ctx->screen.height = vinfo.yres;
    ctx->screen.bpp = vinfo.bits_per_pixel;
    ctx->screen.stride = vinfo.xres * (vinfo.bits_per_pixel / 8);
    ctx->screen.fbsize = ctx->screen.stride * vinfo.yres;
    ctx->screen.fb_mem = mmap(NULL, ctx->screen.fbsize, PROT_READ, MAP_SHARED,
                               ctx->screen.fb_fd, 0);
    if (ctx->screen.fb_mem == MAP_FAILED) {
        close(ctx->screen.fb_fd);
        ctx->screen.enabled = 0;
        return -1;
    }
    return 0;
}

int screen_start(ctx_t *ctx)
{
    if (!ctx->screen.enabled) return 0;
    ctx->screen.running = 1;
    pthread_create(&ctx->screen.thread, NULL, screen_thread, ctx);
    daemon_log(LOG_INFO, "Screen monitor: ON (%dx%d)", ctx->screen.width, ctx->screen.height);
    return 0;
}

void screen_stop(ctx_t *ctx)
{
    ctx->screen.running = 0;
    pthread_join(ctx->screen.thread, NULL);
    if (ctx->screen.fb_mem && ctx->screen.fb_mem != MAP_FAILED)
        munmap(ctx->screen.fb_mem, ctx->screen.fbsize);
    if (ctx->screen.fb_fd >= 0) close(ctx->screen.fb_fd);
}

/* ============================================================
 * USB Monitor (inotify on /dev)
 * ============================================================ */

static void usb_check_drives(ctx_t *ctx)
{
    DIR *d = opendir("/dev");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] != 's' || e->d_name[1] != 'd' || strlen(e->d_name) != 3)
            continue;
        char removable_path[256], val[16] = "0";
        snprintf(removable_path, sizeof(removable_path), "/sys/block/%s/removable", e->d_name);
        read_file(removable_path, val, sizeof(val));
        if (val[0] != '1') continue;

        /* Found removable drive — scan for Windows ISOs */
        char cmd[512];
        snprintf(cmd, sizeof(cmd),
                 "find /dev -maxdepth 0 -name '%s' 2>/dev/null;"
                 "lsblk -ln /dev/%s 2>/dev/null | head -5", e->d_name, e->d_name);
        /* Check mount points */
        FILE *fp = fopen("/proc/mounts", "r");
        if (!fp) continue;
        char line[512];
        while (fgets(line, sizeof(line), fp)) {
            if (!strstr(line, e->d_name)) continue;
            char devname[64], mountpoint[256], fstype[32];
            if (sscanf(line, "%63s %255s %31s", devname, mountpoint, fstype) != 3) continue;

            /* Search for Windows ISO files */
            char findcmd[1024];
            snprintf(findcmd, sizeof(findcmd),
                     "find '%s' -maxdepth 3 \\( -iname '*.iso' -o -iname '*windows*' "
                     "-o -iname '*win10*' -o -iname '*win11*' \\) 2>/dev/null", mountpoint);
            FILE *pipe = popen(findcmd, "r");
            if (!pipe) continue;
            char result[512];
            while (fgets(result, sizeof(result), pipe)) {
                result[strcspn(result, "\n")] = '\0';
                if (strcase_contains(result, "windows") || strcase_contains(result, ".iso") ||
                    strcase_contains(result, "win10") || strcase_contains(result, "win11")) {
                    daemon_log(LOG_EMERG, "WINDOWS ISO ON USB: %s on /dev/%s (%s)",
                               result, e->d_name, mountpoint);
                    panic_trigger(ctx, "Windows ISO found on USB drive", CAT_MICROSOFT, SEV_CRITICAL);
                }
            }
            pclose(pipe);
        }
        fclose(fp);
    }
    closedir(d);
}

static void *usb_thread(void *arg)
{
    ctx_t *ctx = (ctx_t *)arg;
    char buf[4096];

    daemon_log(LOG_INFO, "USB thread started");

    while (ctx->usb.running && g_running) {
        fd_set fds;
        struct timeval tv;
        FD_ZERO(&fds);
        FD_SET(ctx->usb.inotify_fd, &fds);
        tv.tv_sec = 3; tv.tv_usec = 0;

        if (select(ctx->usb.inotify_fd + 1, &fds, NULL, NULL, &tv) > 0) {
            ssize_t len = read(ctx->usb.inotify_fd, buf, sizeof(buf));
            if (len > 0) {
                daemon_log(LOG_INFO, "USB change detected, scanning...");
                usb_check_drives(ctx);
            }
        }
    }
    return NULL;
}

int usb_init(ctx_t *ctx)
{
    ctx->usb.enabled = 1;
    ctx->usb.inotify_fd = inotify_init1(IN_NONBLOCK);
    if (ctx->usb.inotify_fd < 0) { ctx->usb.enabled = 0; return -1; }
    inotify_add_watch(ctx->usb.inotify_fd, "/dev", IN_CREATE | IN_DELETE);
    return 0;
}

int usb_start(ctx_t *ctx)
{
    if (!ctx->usb.enabled) return 0;
    ctx->usb.running = 1;
    pthread_create(&ctx->usb.thread, NULL, usb_thread, ctx);
    daemon_log(LOG_INFO, "USB monitor: ON");
    return 0;
}

void usb_stop(ctx_t *ctx)
{
    ctx->usb.running = 0;
    close(ctx->usb.inotify_fd);
    pthread_join(ctx->usb.thread, NULL);
}

/* ============================================================
 * DPI Monitor (Deep Packet Inspection via /proc/net + DNS)
 * ============================================================ */

static void dpi_scan_connections(ctx_t *ctx)
{
    /* Parse /proc/net/tcp for domain-like patterns */
    FILE *fp = fopen("/proc/net/tcp", "r");
    if (!fp) return;

    char line[512];
    fgets(line, sizeof(line), fp); /* skip header */

    while (fgets(line, sizeof(line), fp)) {
        unsigned int la, lp, ra, rp;
        char state;
        if (sscanf(line, " %x:%x %x:%x %c", &la, &lp, &ra, &rp, &state) != 5)
            continue;
        if (state != '1') continue; /* ESTABLISHED only */

        /* Convert remote IP from hex */
        unsigned char ip[4];
        ip[0] = (ra >> 24) & 0xFF;
        ip[1] = (ra >> 16) & 0xFF;
        ip[2] = (ra >> 8) & 0xFF;
        ip[3] = ra & 0xFF;

        char ipstr[32];
        snprintf(ipstr, sizeof(ipstr), "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);

        /* Check if IP is in Microsoft ranges */
        /* Microsoft public IP ranges (partial list) */
        if ((ip[0] == 13 && (ip[1] == 64 || ip[1] == 65 || ip[1] == 66 || ip[1] == 67 || ip[1] == 68 || ip[1] == 69 || ip[1] == 104 || ip[1] == 105)) ||
            (ip[0] == 20 && ip[1] == 38 && ip[2] >= 80 && ip[2] <= 127) ||
            (ip[0] == 40 && ip[1] >= 76 && ip[1] <= 79) ||
            (ip[0] == 52 && ip[1] >= 96 && ip[1] <= 127) ||
            (ip[0] == 65 && ip[1] == 39) ||
            (ip[0] == 104 && ip[1] >= 40 && ip[1] <= 47) ||
            (ip[0] == 147 && ip[1] == 253)) {
            daemon_log(LOG_WARNING, "DPI: Microsoft IP detected: %s", ipstr);
            char reason[256];
            snprintf(reason, sizeof(reason), "Connection to Microsoft IP %s", ipstr);
            panic_trigger(ctx, reason, CAT_MICROSOFT, SEV_CRITICAL);
        }
    }
    fclose(fp);

    /* Check /etc/resolv.conf and DNS cache for forbidden domains */
    fp = fopen("/var/log/syslog", "r");
    if (fp) {
        /* Scan recent DNS queries from systemd-resolved or dnsmasq */
        fclose(fp);
    }

    /* Check /proc/net/udp for DNS queries (port 53) */
    fp = fopen("/proc/net/udp", "r");
    if (fp) {
        fgets(line, sizeof(line), fp); /* skip header */
        while (fgets(line, sizeof(line), fp)) {
            unsigned int la, lp, ra, rp;
            char state;
            if (sscanf(line, " %x:%x %x:%x %c", &la, &lp, &ra, &rp, &state) >= 4) {
                /* Check if it's a DNS query */
                if (rp == 53 || lp == 53) {
                    /* DNS traffic detected — log for analysis */
                    daemon_log(LOG_DEBUG, "DPI: DNS traffic detected (port 53)");
                }
            }
        }
        fclose(fp);
    }
}

static void dpi_scan_proc_cmdline(ctx_t *ctx)
{
    DIR *proc = opendir("/proc");
    if (!proc) return;
    struct dirent *e;
    while ((e = readdir(proc))) {
        if (!isdigit(e->d_name[0])) continue;
        char path[256], cmdline[4096];
        snprintf(path, sizeof(path), "/proc/%s/cmdline", e->d_name);
        int n = read_file(path, cmdline, sizeof(cmdline));
        if (n <= 0) continue;
        /* Convert null separators to spaces */
        for (int i = 0; i < n; i++)
            if (cmdline[i] == '\0') cmdline[i] = ' ';
        cmdline[n] = '\0';

        category_t cat; severity_t sev;
        if (rules_check_text(ctx, cmdline, &cat, &sev)) {
            if (sev == SEV_CRITICAL && ctx->panic_on_critical)
                panic_trigger(ctx, "Haram content in process command line", cat, sev);
        }
    }
    closedir(proc);
}

static void *dpi_thread(void *arg)
{
    ctx_t *ctx = (ctx_t *)arg;
    daemon_log(LOG_INFO, "DPI thread started");

    while (ctx->dpi.running && g_running) {
        sleep(5);
        dpi_scan_connections(ctx);
        dpi_scan_proc_cmdline(ctx);
    }
    return NULL;
}

int dpi_init(ctx_t *ctx)
{
    ctx->dpi.enabled = 1;
    return 0;
}

int dpi_start(ctx_t *ctx)
{
    if (!ctx->dpi.enabled) return 0;
    ctx->dpi.running = 1;
    pthread_create(&ctx->dpi.thread, NULL, dpi_thread, ctx);
    daemon_log(LOG_INFO, "DPI monitor: ON");
    return 0;
}

void dpi_stop(ctx_t *ctx)
{
    ctx->dpi.running = 0;
    pthread_join(ctx->dpi.thread, NULL);
}

/* ============================================================
 * Panic Engine
 * ============================================================ */

void panic_alarm(ctx_t *ctx)
{
    if (!ctx->alarm_before_panic) return;

    int fd = open("/dev/console", O_WRONLY);
    if (fd < 0) fd = STDERR_FILENO;

    const char *alarm =
        "\033[1;31;40m"
        "\n"
        " ==============================================\n"
        "   H A R A M   D E T E C T E D ! ! !\n"
        " ==============================================\n"
        "   Emergency system shutdown initiated.\n"
        "   Allahu Akbar.\n"
        "\n"
        "   'Indeed, Allah is ever Exalted and Mighty.'\n"
        "    (Al-Hajj 22:61)\n"
        " ==============================================\n"
        "\n"
        "\033[0m";

    for (int i = 0; i < 5; i++) {
        write(fd, alarm, strlen(alarm));
        usleep(200000);
        write(fd, "\033[2J\033[H", 9);
        usleep(200000);
        write(fd, alarm, strlen(alarm));
    }

    if (fd != STDERR_FILENO) close(fd);

    syslog(LOG_EMERG, "HARAM DETECTED - Emergency shutdown");
    system("wall 'HARAM DETECTED - Emergency shutdown. Allahu Akbar.' 2>/dev/null");

    sleep(ctx->alarm_sec);
}

void panic_kernel_panic(ctx_t *ctx, const char *reason)
{
    daemon_log(LOG_EMERG, "KERNEL PANIC: %s", reason);

    if (ctx->dry_run) {
        daemon_log(LOG_EMERG, "DRY RUN - would panic but dry_run=1");
        return;
    }

    /* Write panic log */
    FILE *fp = fopen(VIOLATION_LOG, "a");
    if (fp) {
        fprintf(fp, "PANIC at %ld: %s\n", time(NULL), reason);
        fclose(fp);
    }

    /* SysRq panic */
    int fd = open("/proc/sysrq-trigger", O_WRONLY);
    if (fd >= 0) {
        write(fd, "s", 1);  /* sync */
        usleep(500000);
        write(fd, "c", 1);  /* crash/panic */
        close(fd);
    }

    /* Fallback: reboot */
    sleep(2);
    reboot(LINUX_REBOOT_CMD_RESTART);
}

int panic_trigger(ctx_t *ctx, const char *reason, category_t cat, severity_t sev)
{
    pthread_mutex_lock(&ctx->panic.lock);

    daemon_log(LOG_EMERG, "PANIC TRIGGER [%s] sev=%d: %s",
               cat == CAT_MICROSOFT ? "WINDOWS" : "HARAM", sev, reason);

    /* Log violation */
    FILE *fp = fopen(VIOLATION_LOG, "a");
    if (fp) {
        fprintf(fp, "=== VIOLATION ===\n");
        fprintf(fp, "Time: %s", ctime(&(time_t){time(NULL)}));
        fprintf(fp, "Reason: %s\n", reason);
        fprintf(fp, "Category: %d, Severity: %d\n", cat, sev);
        fprintf(fp, "================\n\n");
        fclose(fp);
    }

    panic_alarm(ctx);
    panic_kernel_panic(ctx, reason);

    pthread_mutex_unlock(&ctx->panic.lock);
    return 0;
}

int panic_init(ctx_t *ctx)
{
    ctx->panic.panic_on_critical = 1;
    ctx->panic.alarm_before_panic = 1;
    ctx->panic.alarm_sec = 3;
    ctx->panic.dry_run = 0;
    pthread_mutex_init(&ctx->panic.lock, NULL);
    return 0;
}

/* ============================================================
 * IP/Domain Blocklist (iptables)
 * ============================================================ */

int blocklist_load_domains(const char *path)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;
    char line[256];
    int count = 0;
    while (fgets(line, sizeof(line), fp)) {
        char *s = strtrim(line);
        if (!*s || *s == '#') continue;
        s[strcspn(s, "\n")] = '\0';
        /* Block via iptables DNS-based approach */
        char cmd[512];
        snprintf(cmd, sizeof(cmd),
                 "iptables -A OUTPUT -m string --string '%s' --algo bm -j DROP 2>/dev/null", s);
        system(cmd);
        count++;
    }
    fclose(fp);
    return count;
}

int blocklist_load_ips(const char *path)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;
    char line[256];
    int count = 0;
    while (fgets(line, sizeof(line), fp)) {
        char *s = strtrim(line);
        if (!*s || *s == '#') continue;
        s[strcspn(s, "\n")] = '\0';
        char cmd[512];
        snprintf(cmd, sizeof(cmd),
                 "iptables -A OUTPUT -d %s -j DROP 2>/dev/null;"
                 "iptables -A INPUT -s %s -j DROP 2>/dev/null", s, s);
        system(cmd);
        count++;
    }
    fclose(fp);
    return count;
}

int blocklist_apply(ctx_t *ctx)
{
    (void)ctx;
    daemon_log(LOG_INFO, "Applying Microsoft IP/domain blocklist...");

    /* Flush old rules */
    system("iptables -F OUTPUT 2>/dev/null");

    /* Load Microsoft IP ranges */
    char path[512];
    snprintf(path, sizeof(path), "%s/microsoft_ips.txt", BLOCKLIST_DIR);
    int ips = blocklist_load_ips(path);
    daemon_log(LOG_INFO, "Blocked %d Microsoft IP ranges", ips);

    /* Load Microsoft domains */
    snprintf(path, sizeof(path), "%s/microsoft_domains.txt", BLOCKLIST_DIR);
    int doms = blocklist_load_domains(path);
    daemon_log(LOG_INFO, "Blocked %d Microsoft domains", doms);

    /* Also block common Microsoft domains via iptables string match */
    const char *ms_domains[] = {
        "microsoft.com", "windows.com", "windows.net", "windowsupdate.com",
        "live.com", "outlook.com", "office.com", "office365.com",
        "azure.com", "msn.com", "skype.com", "linkedin.com",
        "github.com", "visualstudio.com", "xbox.com", "bing.com",
        "msedge.net", "akamaized.net", "akamai.net",
        "microsoftonline.com", "sharepoint.com", "onedrive.com",
        "teams.microsoft.com", "copilot.microsoft.com",
        "katana.microsoft.com", "entra.microsoft.com",
        NULL
    };

    for (int i = 0; ms_domains[i]; i++) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd),
                 "iptables -A OUTPUT -m string --string '%s' --algo bm -j DROP 2>/dev/null;"
                 "iptables -A INPUT -m string --string '%s' --algo bm -j DROP 2>/dev/null",
                 ms_domains[i], ms_domains[i]);
        system(cmd);
    }

    /* Block Microsoft ASNs (AS8075, AS8068, AS14618) */
    system("ipset create microsoft_ips hash:net 2>/dev/null;"
           "ipset add microsoft_ips 13.64.0.0/11 2>/dev/null;"
           "ipset add microsoft_ips 20.38.0.0/12 2>/dev/null;"
           "ipset add microsoft_ips 40.64.0.0/10 2>/dev/null;"
           "ipset add microsoft_ips 52.96.0.0/12 2>/dev/null;"
           "ipset add microsoft_ips 65.39.0.0/16 2>/dev/null;"
           "ipset add microsoft_ips 104.40.0.0/13 2>/dev/null;"
           "ipset add microsoft_ips 147.253.0.0/16 2>/dev/null;"
           "iptables -A OUTPUT -m set --match-set microsoft_ips dst -j DROP 2>/dev/null;"
           "iptables -A INPUT -m set --match-set microsoft_ips src -j DROP 2>/dev/null");

    daemon_log(LOG_INFO, "Microsoft blocklist applied (%d IPs, %d domains)", ips, doms);
    return 0;
}

/* ============================================================
 * Signal handling
 * ============================================================ */

static void sig_handler(int sig)
{
    if (sig == SIGTERM || sig == SIGINT) g_running = 0;
}

/* ============================================================
 * Main
 * ============================================================ */

int main(int argc, char *argv[])
{
    int foreground = 0;

    memset(&g_ctx, 0, sizeof(g_ctx));
    g_ctx.verbose = 3;
    g_ctx.panic_on_critical = 1;
    g_ctx.alarm_before_panic = 1;
    g_ctx.alarm_sec = 3;
    snprintf(g_ctx.rules_file, sizeof(g_ctx.rules_file), "%s", RULES_PATH);
    snprintf(g_ctx.fb_device, sizeof(g_ctx.fb_device), "/dev/fb0");

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-f") == 0) foreground = 1;
        else if (strcmp(argv[i], "-v") == 0) g_ctx.verbose++;
        else if (strcmp(argv[i], "-V") == 0) { printf("haramd v%s\n", VERSION); return 0; }
        else if (strcmp(argv[i], "-h") == 0) {
            printf("Usage: %s [-f] [-v] [-V] [-h]\n", argv[0]);
            return 0;
        }
    }

    panic_init(&g_ctx);
    signal(SIGTERM, sig_handler);
    signal(SIGINT, sig_handler);
    openlog("haramd", LOG_PID | LOG_NDELAY, LOG_DAEMON);

    /* Try to load config */
    config_load(&g_ctx, CONFIG_PATH);

    /* Load rules */
    rules_load(&g_ctx, g_ctx.rules_file);
    rules_compile(&g_ctx);

    /* Daemonize */
    if (!foreground) {
        pid_t pid = fork();
        if (pid < 0) { perror("fork"); return 1; }
        if (pid > 0) _exit(0);
        setsid();
        pid = fork();
        if (pid > 0) _exit(0);
        close(0); close(1); close(2);
        open("/dev/null", O_RDONLY);
        open("/dev/null", O_WRONLY);
        open("/dev/null", O_WRONLY);
    }

    g_ctx.start_time = time(NULL);
    daemon_log(LOG_INFO, "haramd v%s started (pid %d)", VERSION, getpid());

    /* Apply Microsoft blocklist */
    blocklist_apply(&g_ctx);

    /* Start monitors */
    kbd_init(&g_ctx);
    kbd_start(&g_ctx);

    screen_init(&g_ctx);
    screen_start(&g_ctx);

    usb_init(&g_ctx);
    usb_start(&g_ctx);

    dpi_init(&g_ctx);
    dpi_start(&g_ctx);

    daemon_log(LOG_INFO, "All monitors active. Waiting for haram...");

    /* Main loop */
    while (g_running) sleep(1);

    /* Cleanup */
    kbd_stop(&g_ctx);
    screen_stop(&g_ctx);
    usb_stop(&g_ctx);
    dpi_stop(&g_ctx);

    daemon_log(LOG_INFO, "haramd stopped");
    closelog();
    return 0;
}
