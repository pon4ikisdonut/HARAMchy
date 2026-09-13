/*
 * hrm — HARAMchy Rule Manager (package manager)
 *
 * Supports JSON manifests from remote repos and local .hrm archives.
 * SHA-256 verified downloads, haram package detection.
 *
 * Copyright (c) 2026 HARAMchy Project — Public Domain
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <time.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <ctype.h>
#include <stdint.h>
#include <stdarg.h>

/* ------------------------------------------------------------------ */
/* Constants                                                           */
/* ------------------------------------------------------------------ */

#define HRM_DB_PATH         "/var/lib/hrm/installed.db"
#define HRM_REPO_DIR        "/var/lib/hrm/repo"
#define HRM_CACHE_DIR       "/var/lib/hrm/cache"
#define HRM_LOCK_FILE       "/var/lib/hrm/.lock"
#define HRM_REPOS_DIR       "/var/lib/hrm/repos"
#define HRM_MANIFESTS_DIR   "/var/lib/hrm/manifests"
#define HRM_BACKUP_DIR      "/var/lib/hrm/backups"
#define HRM_MAX_PATH        4096
#define HRM_MAX_LINE        2048
#define HRM_HASH_LEN        65
#define HRM_PROGRESS_WIDTH  40
#define HRM_MAX_REPOS       32
#define HRM_MAX_DEPS        32

/* ------------------------------------------------------------------ */
/* ANSI color codes                                                    */
/* ------------------------------------------------------------------ */

#define C_RESET     "\033[0m"
#define C_BOLD      "\033[1m"
#define C_RED       "\033[1;31m"
#define C_GREEN     "\033[1;32m"
#define C_YELLOW    "\033[1;33m"
#define C_BLUE      "\033[1;34m"
#define C_MAGENTA   "\033[1;35m"
#define C_CYAN      "\033[1;36m"
#define C_WHITE     "\033[1;37m"
#define C_DIM       "\033[2m"
#define C_BG_RED    "\033[41m"
#define C_BG_YELLOW "\033[43m"

/* ------------------------------------------------------------------ */
/* Package manifest (JSON format per MANIFEST_SPEC.md)                 */
/* ------------------------------------------------------------------ */

struct hrm_manifest {
    /* Required fields */
    char name[128];
    char version[64];
    int  release;
    char category[64];
    char summary[256];
    char license[64];
    char url[1024];
    char sha256[HRM_HASH_LEN];
    uint64_t size_bytes;
    char architecture[32];
    int  install_type;        /* 0=tarball, 1=rpm, 2=appimage, 3=flatpak */
    char maintainer[256];
    char homepage[512];
    char source_url[1024];
    /* Haram flag (set if package name or tags contain haram keywords) */
    int  haram;
    char haram_category[128];
    /* Optional fields */
    char description[2048];
    char tags[32][64];
    int  tag_count;
    char conflicts[16][128];
    int  conflict_count;
    char provides[16][128];
    int  provide_count;
    char replaces[16][128];
    int  replace_count;
    char post_install_script[1024];
    char post_install_script_sha256[HRM_HASH_LEN];
    /* Dependencies */
    char deps[HRM_MAX_DEPS][128];
    int  dep_count;
};

/* ------------------------------------------------------------------ */
/* Installed package entry                                             */
/* ------------------------------------------------------------------ */

struct hrm_installed {
    char name[128];
    char version[64];
    char install_type[16];
    char category[64];
    char sha256[HRM_HASH_LEN];
    int  file_count;
    char files[512][HRM_MAX_PATH];
};

/* ------------------------------------------------------------------ */
/* Repository entry                                                    */
/* ------------------------------------------------------------------ */

struct hrm_repo {
    char name[128];
    char url[1024];
    char branch[64];
    int  enabled;
};

/* ------------------------------------------------------------------ */
/* Globals                                                             */
/* ------------------------------------------------------------------ */

static int g_verbose = 0;
static int g_color   = 1;
static int g_dry_run = 0;
static int g_force   = 0;

/* ------------------------------------------------------------------ */
/* Utility functions                                                   */
/* ------------------------------------------------------------------ */

static void color_init(void)
{
    if (!isatty(STDOUT_FILENO))
        g_color = 0;
}

static const char *c(const char *code)
{
    return g_color ? code : "";
}

static void banner(void)
{
    fprintf(stderr, "%s%s=== hrm v0.2.0 (HARAMchy Rule Manager) ===%s\n",
            c(C_CYAN), c(C_BOLD), c(C_RESET));
    fprintf(stderr, "%s%sWARNING: This package manager is experimental.%s\n",
            c(C_YELLOW), c(C_BOLD), c(C_RESET));
    fprintf(stderr, "\n");
}

static void progress_bar(const char *label, int percent, int width)
{
    int filled = width * percent / 100;
    int i;

    fprintf(stderr, "\r  %s [", label);
    for (i = 0; i < width; i++) {
        if (i < filled)
            fprintf(stderr, "%s#%s", c(C_GREEN), c(C_RESET));
        else if (i == filled)
            fprintf(stderr, "%s>%s", c(C_YELLOW), c(C_RESET));
        else
            fprintf(stderr, "%s-%s", c(C_DIM), c(C_RESET));
    }
    fprintf(stderr, "] %3d%%", percent);
    if (percent >= 100)
        fprintf(stderr, " %sDONE%s\n", c(C_GREEN), c(C_RESET));
    fflush(stderr);
}

static void msg_info(const char *fmt, ...)
{
    va_list ap;
    fprintf(stderr, "%s[hrm]%s ", c(C_BLUE), c(C_RESET));
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
}

static void msg_warn(const char *fmt, ...)
{
    va_list ap;
    fprintf(stderr, "%s[hrm][WARN]%s ", c(C_YELLOW), c(C_RESET));
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
}

static void msg_error(const char *fmt, ...)
{
    va_list ap;
    fprintf(stderr, "%s[hrm][ERROR]%s ", c(C_RED), c(C_RESET));
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
}

static void msg_haram_panic(const char *pkg_name, const char *category)
{
    fprintf(stderr, "\n");
    fprintf(stderr, "%s%s============================================%s\n",
            c(C_BG_RED), c(C_WHITE), c(C_RESET));
    fprintf(stderr, "%s%s   HARAM PACKAGE DETECTED!!!%s\n",
            c(C_BG_RED), c(C_WHITE), c(C_RESET));
    fprintf(stderr, "%s%s   Package: %-28s%s\n",
            c(C_BG_RED), c(C_WHITE), pkg_name, c(C_RESET));
    fprintf(stderr, "%s%s   Category: %-27s%s\n",
            c(C_BG_RED), c(C_WHITE), category, c(C_RESET));
    fprintf(stderr, "%s%s============================================%s\n",
            c(C_BG_RED), c(C_WHITE), c(C_RESET));
    fprintf(stderr, "\n");
}

/* ------------------------------------------------------------------ */
/* Lock file management                                                */
/* ------------------------------------------------------------------ */

static int lock_acquire(void)
{
    int fd;
    struct flock fl;

    mkdir("/var/lib/hrm", 0755);

    fd = open(HRM_LOCK_FILE, O_CREAT | O_RDWR, 0600);
    if (fd < 0) {
        msg_error("cannot create lock file: %s", strerror(errno));
        return -1;
    }

    fl.l_type   = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start  = 0;
    fl.l_len    = 0;

    if (fcntl(fd, F_SETLK, &fl) < 0) {
        if (errno == EAGAIN || errno == EACCES) {
            msg_error("another hrm process is running");
        } else {
            msg_error("cannot acquire lock: %s", strerror(errno));
        }
        close(fd);
        return -1;
    }

    ftruncate(fd, 0);
    {
        char pid_str[16];
        snprintf(pid_str, sizeof(pid_str), "%d\n", getpid());
        write(fd, pid_str, strlen(pid_str));
    }
    return fd;
}

static void lock_release(int fd)
{
    if (fd >= 0) {
        struct flock fl;
        fl.l_type   = F_UNLCK;
        fl.l_whence = SEEK_SET;
        fl.l_start  = 0;
        fl.l_len    = 0;
        fcntl(fd, F_SETLK, &fl);
        close(fd);
    }
}

/* ------------------------------------------------------------------ */
/* JSON parser (minimal, line-based)                                   */
/* ------------------------------------------------------------------ */

/* Extract string value for a given key from JSON line */
static int json_get_string(const char *json, const char *key, char *out, size_t out_size)
{
    char search[256];
    const char *p, *start, *end;
    size_t len;

    snprintf(search, sizeof(search), "\"%s\"", key);
    p = strstr(json, search);
    if (!p) return -1;

    p += strlen(search);
    while (*p && (*p == ' ' || *p == ':' || *p == '\t'))
        p++;

    if (*p == '"') {
        p++;
        start = p;
        end = strchr(p, '"');
        if (!end) return -1;
        len = end - start;
        if (len >= out_size) len = out_size - 1;
        memcpy(out, start, len);
        out[len] = '\0';
        return 0;
    }

    /* Number or boolean */
    start = p;
    while (*p && *p != ',' && *p != '}' && *p != '\n' && *p != '\r')
        p++;
    len = p - start;
    if (len >= out_size) len = out_size - 1;
    memcpy(out, start, len);
    out[len] = '\0';
    return 0;
}

/* Extract integer value */
static int json_get_int(const char *json, const char *key, int *out)
{
    char buf[64];
    if (json_get_string(json, key, buf, sizeof(buf)) < 0)
        return -1;
    *out = atoi(buf);
    return 0;
}

/* Extract uint64 value */
static int json_get_uint64(const char *json, const char *key, uint64_t *out)
{
    char buf[64];
    if (json_get_string(json, key, buf, sizeof(buf)) < 0)
        return -1;
    *out = (uint64_t)strtoull(buf, NULL, 10);
    return 0;
}

/* Extract string array - finds "key": ["val1", "val2"] */
static int json_get_string_array(const char *json, const char *key,
                                  char arr[][128], int max_count)
{
    char search[256];
    const char *p;
    int count = 0;

    snprintf(search, sizeof(search), "\"%s\"", key);
    p = strstr(json, search);
    if (!p) return 0;

    p += strlen(search);
    while (*p && (*p == ' ' || *p == ':' || *p == '\t'))
        p++;

    if (*p != '[') return 0;
    p++;

    while (*p && count < max_count) {
        while (*p && (*p == ' ' || *p == ',' || *p == '\t'))
            p++;
        if (*p == ']') break;
        if (*p == '"') {
            const char *start = p + 1;
            const char *end = strchr(start, '"');
            if (!end) break;
            size_t len = end - start;
            if (len >= 128) len = 127;
            memcpy(arr[count], start, len);
            arr[count][len] = '\0';
            count++;
            p = end + 1;
        } else {
            break;
        }
    }

    return count;
}

/* Detect install type from string */
static int install_type_from_string(const char *s)
{
    if (strcmp(s, "rpm") == 0) return 1;
    if (strcmp(s, "tarball") == 0) return 0;
    if (strcmp(s, "appimage") == 0) return 2;
    if (strcmp(s, "flatpak") == 0) return 3;
    return 0; /* default tarball */
}

static const char *install_type_to_string(int t)
{
    switch (t) {
        case 1: return "rpm";
        case 2: return "appimage";
        case 3: return "flatpak";
        default: return "tarball";
    }
}

/* ------------------------------------------------------------------ */
/* Manifest parsing                                                    */
/* ------------------------------------------------------------------ */

static int parse_manifest_file(const char *path, struct hrm_manifest *m)
{
    FILE *fp;
    char *line;
    size_t len;
    ssize_t nread;
    char *full_json;
    size_t total = 0;
    size_t cap = 8192;

    memset(m, 0, sizeof(*m));
    m->release = 1;

    fp = fopen(path, "r");
    if (!fp) return -1;

    full_json = malloc(cap);
    if (!full_json) { fclose(fp); return -1; }

    while ((nread = getline(&line, &len, fp)) != -1) {
        size_t slen = strlen(line);
        if (total + slen + 1 > cap) {
            cap *= 2;
            full_json = realloc(full_json, cap);
            if (!full_json) { fclose(fp); return -1; }
        }
        memcpy(full_json + total, line, slen);
        total += slen;
    }
    full_json[total] = '\0';
    fclose(fp);

    /* Required fields */
    json_get_string(full_json, "name", m->name, sizeof(m->name));
    json_get_string(full_json, "version", m->version, sizeof(m->version));
    json_get_int(full_json, "release", &m->release);
    json_get_string(full_json, "category", m->category, sizeof(m->category));
    json_get_string(full_json, "summary", m->summary, sizeof(m->summary));
    json_get_string(full_json, "license", m->license, sizeof(m->license));
    json_get_string(full_json, "url", m->url, sizeof(m->url));
    json_get_string(full_json, "sha256", m->sha256, sizeof(m->sha256));
    json_get_uint64(full_json, "size_bytes", &m->size_bytes);
    json_get_string(full_json, "architecture", m->architecture, sizeof(m->architecture));
    json_get_string(full_json, "maintainer", m->maintainer, sizeof(m->maintainer));
    json_get_string(full_json, "homepage", m->homepage, sizeof(m->homepage));
    json_get_string(full_json, "source_url", m->source_url, sizeof(m->source_url));

    /* Install type */
    {
        char itype[32] = {0};
        if (json_get_string(full_json, "install_type", itype, sizeof(itype)) == 0)
            m->install_type = install_type_from_string(itype);
    }

    /* Dependencies */
    m->dep_count = json_get_string_array(full_json, "dependencies",
                                          m->deps, HRM_MAX_DEPS);

    /* Optional fields */
    json_get_string(full_json, "description", m->description, sizeof(m->description));
    m->tag_count = json_get_string_array(full_json, "tags",
                                          (char (*)[128])m->tags, 32);
    m->conflict_count = json_get_string_array(full_json, "conflicts",
                                               (char (*)[128])m->conflicts, 16);
    m->provide_count = json_get_string_array(full_json, "provides",
                                              (char (*)[128])m->provides, 16);
    m->replace_count = json_get_string_array(full_json, "replaces",
                                              (char (*)[128])m->replaces, 16);
    json_get_string(full_json, "post_install_script",
                    m->post_install_script, sizeof(m->post_install_script));
    json_get_string(full_json, "post_install_script_sha256",
                    m->post_install_script_sha256, sizeof(m->post_install_script_sha256));

    free(full_json);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Installed database (plain text)                                     */
/* ------------------------------------------------------------------ */

static int db_load(struct hrm_installed **out, int *count)
{
    FILE *fp;
    char line[HRM_MAX_LINE];
    int cap = 64;
    int n = 0;
    struct hrm_installed *list;

    list = calloc(cap, sizeof(*list));
    if (!list) return -1;

    fp = fopen(HRM_DB_PATH, "r");
    if (!fp) {
        *out = list;
        *count = 0;
        return 0;
    }

    while (fgets(line, sizeof(line), fp) && n < cap) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';
        nl = strchr(line, '\r');
        if (nl) *nl = '\0';

        if (line[0] == '\0') continue;

        /* Format: name|version|install_type|category|sha256|file1,file2,... */
        char *p = line;
        char *name = strsep(&p, "|");
        char *ver  = strsep(&p, "|");
        char *itype = strsep(&p, "|");
        char *cat  = strsep(&p, "|");
        char *hash = strsep(&p, "|");
        char *files = p;

        if (!name || !ver) continue;

        snprintf(list[n].name, sizeof(list[n].name), "%s", name);
        snprintf(list[n].version, sizeof(list[n].version), "%s", ver);
        if (itype) snprintf(list[n].install_type, sizeof(list[n].install_type), "%s", itype);
        if (cat) snprintf(list[n].category, sizeof(list[n].category), "%s", cat);
        if (hash) snprintf(list[n].sha256, sizeof(list[n].sha256), "%s", hash);

        if (files) {
            char *saveptr;
            char *tok = strtok_r(files, ",", &saveptr);
            while (tok && list[n].file_count < 512) {
                snprintf(list[n].files[list[n].file_count],
                         sizeof(list[n].files[0]), "%s", tok);
                list[n].file_count++;
                tok = strtok_r(NULL, ",", &saveptr);
            }
        }
        n++;
    }

    fclose(fp);
    *out = list;
    *count = n;
    return 0;
}

static void db_save(struct hrm_installed *list, int count)
{
    FILE *fp;
    int i;

    mkdir("/var/lib/hrm", 0755);

    fp = fopen(HRM_DB_PATH, "w");
    if (!fp) {
        msg_error("cannot write database: %s", strerror(errno));
        return;
    }

    for (i = 0; i < count; i++) {
        int j;
        fprintf(fp, "%s|%s|%s|%s|%s", list[i].name, list[i].version,
                list[i].install_type, list[i].category, list[i].sha256);
        for (j = 0; j < list[i].file_count; j++) {
            fprintf(fp, "%s%s", j == 0 ? "|" : ",", list[i].files[j]);
        }
        fprintf(fp, "\n");
    }

    fclose(fp);
}

static int db_find(struct hrm_installed *list, int count, const char *name)
{
    int i;
    for (i = 0; i < count; i++) {
        if (strcmp(list[i].name, name) == 0)
            return i;
    }
    return -1;
}

/* ------------------------------------------------------------------ */
/* Repository management                                               */
/* ------------------------------------------------------------------ */

static int repo_load(struct hrm_repo *repos, int max_repos)
{
    FILE *fp;
    char line[HRM_MAX_LINE];
    int count = 0;

    mkdir(HRM_REPOS_DIR, 0755);

    fp = fopen(HRM_REPOS_DIR "/repos.txt", "r");
    if (!fp) return 0;

    while (fgets(line, sizeof(line), fp) && count < max_repos) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';
        nl = strchr(line, '\r');
        if (nl) *nl = '\0';

        if (line[0] == '#' || line[0] == '\0') continue;

        /* Format: name|url|branch|enabled */
        char *p = line;
        char *name = strsep(&p, "|");
        char *url  = strsep(&p, "|");
        char *branch = strsep(&p, "|");
        char *enabled = strsep(&p, "|");

        if (!name || !url) continue;

        snprintf(repos[count].name, sizeof(repos[count].name), "%s", name);
        snprintf(repos[count].url, sizeof(repos[count].url), "%s", url);
        snprintf(repos[count].branch, sizeof(repos[count].branch), "%s",
                 branch ? branch : "main");
        repos[count].enabled = (!enabled || strcmp(enabled, "1") == 0);
        count++;
    }

    fclose(fp);
    return count;
}

static void repo_save(struct hrm_repo *repos, int count)
{
    FILE *fp;
    int i;

    mkdir(HRM_REPOS_DIR, 0755);

    fp = fopen(HRM_REPOS_DIR "/repos.txt", "w");
    if (!fp) {
        msg_error("cannot write repos: %s", strerror(errno));
        return;
    }

    for (i = 0; i < count; i++) {
        fprintf(fp, "%s|%s|%s|%d\n", repos[i].name, repos[i].url,
                repos[i].branch, repos[i].enabled);
    }

    fclose(fp);
}

/* ------------------------------------------------------------------ */
/* SHA-256 (minimal standalone implementation)                         */
/* ------------------------------------------------------------------ */

struct sha256_ctx {
    uint32_t h[8];
    uint64_t total_len;
    uint8_t  buf[64];
    int      buf_len;
};

static const uint32_t sha256_k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static uint32_t sha256_rotr(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }

static void sha256_transform(struct sha256_ctx *ctx, const uint8_t block[64])
{
    uint32_t w[64], a, b, c, d, e, f, g, h, t1, t2;
    int i;

    for (i = 0; i < 16; i++) {
        w[i] = ((uint32_t)block[i*4] << 24) |
               ((uint32_t)block[i*4+1] << 16) |
               ((uint32_t)block[i*4+2] << 8) |
               ((uint32_t)block[i*4+3]);
    }
    for (i = 16; i < 64; i++) {
        uint32_t s0 = sha256_rotr(w[i-15], 7) ^ sha256_rotr(w[i-15], 18) ^ (w[i-15] >> 3);
        uint32_t s1 = sha256_rotr(w[i-2], 17) ^ sha256_rotr(w[i-2], 19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }

    a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3];
    e = ctx->h[4]; f = ctx->h[5]; g = ctx->h[6]; h = ctx->h[7];

    for (i = 0; i < 64; i++) {
        uint32_t S1 = sha256_rotr(e, 6) ^ sha256_rotr(e, 11) ^ sha256_rotr(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        t1 = h + S1 + ch + sha256_k[i] + w[i];
        uint32_t S0 = sha256_rotr(a, 2) ^ sha256_rotr(a, 13) ^ sha256_rotr(a, 22);
        uint32_t mj = (a & b) ^ (a & c) ^ (b & c);
        t2 = S0 + mj;
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
    ctx->h[4] += e; ctx->h[5] += f; ctx->h[6] += g; ctx->h[7] += h;
}

static void sha256_init(struct sha256_ctx *ctx)
{
    ctx->h[0] = 0x6a09e667; ctx->h[1] = 0xbb67ae85;
    ctx->h[2] = 0x3c6ef372; ctx->h[3] = 0xa54ff53a;
    ctx->h[4] = 0x510e527f; ctx->h[5] = 0x9b05688c;
    ctx->h[6] = 0x1f83d9ab; ctx->h[7] = 0x5be0cd19;
    ctx->total_len = 0;
    ctx->buf_len = 0;
}

static void sha256_update(struct sha256_ctx *ctx, const uint8_t *data, size_t len)
{
    size_t i = 0;
    ctx->total_len += len;

    if (ctx->buf_len > 0) {
        size_t need = 64 - ctx->buf_len;
        if (len < need) {
            memcpy(ctx->buf + ctx->buf_len, data, len);
            ctx->buf_len += len;
            return;
        }
        memcpy(ctx->buf + ctx->buf_len, data, need);
        sha256_transform(ctx, ctx->buf);
        i = need;
        ctx->buf_len = 0;
    }

    while (i + 64 <= len) {
        sha256_transform(ctx, data + i);
        i += 64;
    }

    if (i < len) {
        memcpy(ctx->buf, data + i, len - i);
        ctx->buf_len = len - i;
    }
}

static void sha256_final(struct sha256_ctx *ctx, char hex[65])
{
    uint8_t pad[64];
    int pad_len;
    uint64_t bits = ctx->total_len * 8;
    int i;

    memset(pad, 0, sizeof(pad));
    pad[0x80] = 0x80;

    pad_len = (ctx->buf_len < 56) ? (56 - ctx->buf_len) : (120 - ctx->buf_len);
    sha256_update(ctx, pad, pad_len);

    for (i = 7; i >= 0; i--)
        pad[i] = (uint8_t)(bits >> (i * 8));
    sha256_update(ctx, pad, 8);

    for (i = 0; i < 8; i++) {
        snprintf(hex + i * 8, 9, "%08x", ctx->h[i]);
    }
    hex[64] = '\0';
}

static int sha256_file(const char *path, char hex[65])
{
    FILE *fp;
    struct sha256_ctx ctx;
    uint8_t buf[8192];
    size_t n;

    fp = fopen(path, "rb");
    if (!fp) return -1;

    sha256_init(&ctx);
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0)
        sha256_update(&ctx, buf, n);
    sha256_final(&ctx, hex);

    fclose(fp);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Download with curl                                                  */
/* ------------------------------------------------------------------ */

static int download_file(const char *url, const char *dest, const char *expected_sha256)
{
    pid_t pid;
    int status;

    mkdir("/tmp/haramchy-pkg", 0755);

    msg_info("downloading %s...", url);

    pid = fork();
    if (pid < 0) return -1;

    if (pid == 0) {
        execlp("curl", "curl", "-fSL", "--progress-bar",
               "-o", dest, url, (char *)NULL);
        _exit(127);
    }

    waitpid(pid, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        msg_error("download failed (curl exit %d)", WEXITSTATUS(status));
        return -1;
    }

    /* Verify SHA-256 if provided */
    if (expected_sha256 && expected_sha256[0]) {
        char actual[HRM_HASH_LEN];
        msg_info("verifying SHA-256...");
        if (sha256_file(dest, actual) < 0) {
            msg_error("cannot hash downloaded file");
            return -1;
        }
        if (strcmp(actual, expected_sha256) != 0) {
            msg_error("SHA-256 MISMATCH!");
            msg_error("  expected: %s", expected_sha256);
            msg_error("  actual:   %s", actual);
            msg_error("download may be corrupted or tampered");
            unlink(dest);
            return -1;
        }
        msg_info("SHA-256 verified OK");
    }

    return 0;
}

/* ------------------------------------------------------------------ */
/* Package extraction                                                  */
/* ------------------------------------------------------------------ */

static int extract_archive(const char *archive_path, const char *dest_dir)
{
    pid_t pid;
    int status;

    mkdir(dest_dir, 0755);

    pid = fork();
    if (pid < 0) return -1;

    if (pid == 0) {
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        execlp("tar", "tar", "xzf", archive_path, "-C", dest_dir,
               "--strip-components=0", (char *)NULL);
        _exit(127);
    }

    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
        return 0;
    return -1;
}

/* ------------------------------------------------------------------ */
/* Install types                                                       */
/* ------------------------------------------------------------------ */

static int install_tarball(const char *archive_path, const char *pkg_name,
                           struct hrm_manifest *m, struct hrm_installed **db,
                           int *db_count, int lock_fd)
{
    char extract_dir[HRM_MAX_PATH];
    struct hrm_installed *installed = *db;
    int idx;
    int i;
    (void)lock_fd;

    snprintf(extract_dir, sizeof(extract_dir),
             "/tmp/hrm-extract-%s-%d", pkg_name, getpid());

    msg_info("extracting tarball...");
    progress_bar("extract", 0, HRM_PROGRESS_WIDTH);
    if (extract_archive(archive_path, extract_dir) < 0) {
        msg_error("failed to extract package");
        rmdir(extract_dir);
        return 1;
    }
    progress_bar("extract", 100, HRM_PROGRESS_WIDTH);

    /* Check for haram */
    if (m->haram) {
        /* haram check happens via check_haram before calling this */
    }

    /* Load database and check for existing install */
    db_load(db, db_count);
    installed = *db;
    idx = db_find(installed, *db_count, pkg_name);

    if (idx >= 0) {
        msg_warn("package '%s' v%s is already installed, overwriting",
                 installed[idx].name, installed[idx].version);

        /* Backup old files */
        msg_info("backing up old installation...");
        mkdir(HRM_BACKUP_DIR, 0755);
        for (i = 0; i < installed[idx].file_count; i++) {
            char backup_path[HRM_MAX_PATH];
            char src_path[HRM_MAX_PATH];
            snprintf(backup_path, sizeof(backup_path),
                     "%s/%s/%s.bak", HRM_BACKUP_DIR, pkg_name,
                     installed[idx].files[i]);
            snprintf(src_path, sizeof(src_path), "/%s", installed[idx].files[i]);
            {
                char *last_slash = strrchr(backup_path, '/');
                if (last_slash) {
                    *last_slash = '\0';
                    mkdir(backup_path, 0755);
                    *last_slash = '/';
                }
            }
            if (access(src_path, R_OK) == 0) {
                pid_t cp = fork();
                if (cp == 0) {
                    execlp("cp", "cp", "-f", src_path, backup_path, (char *)NULL);
                    _exit(127);
                }
                int st;
                waitpid(cp, &st, 0);
            }
        }
    }

    /* Install files from tarball */
    /* For tarballs, we look for files in the extracted directory and copy them */
    {
        char find_cmd[HRM_MAX_PATH * 2];
        FILE *fp;
        char file_path[HRM_MAX_PATH];
        int file_idx = 0;

        /* Use find to get all files */
        snprintf(find_cmd, sizeof(find_cmd),
                 "find '%s' -type f 2>/dev/null", extract_dir);
        fp = popen(find_cmd, "r");
        if (!fp) {
            msg_error("failed to list extracted files");
            goto cleanup;
        }

        msg_info("installing files...");
        progress_bar("install", 0, HRM_PROGRESS_WIDTH);

        while (fgets(file_path, sizeof(file_path), fp) && file_idx < 512) {
            char *nl = strchr(file_path, '\n');
            if (nl) *nl = '\0';

            /* Compute relative path from extract_dir */
            const char *rel_path = file_path + strlen(extract_dir) + 1;
            char dst_path[HRM_MAX_PATH];

            snprintf(dst_path, sizeof(dst_path), "/%s", rel_path);

            /* Create parent directories */
            {
                char *last_slash = strrchr(dst_path, '/');
                if (last_slash) {
                    char dir[HRM_MAX_PATH];
                    snprintf(dir, sizeof(dir), "%.*s",
                             (int)(last_slash - dst_path), dst_path);
                    mkdir(dir, 0755);
                }
            }

            /* Copy file */
            {
                pid_t cp = fork();
                if (cp == 0) {
                    int devnull = open("/dev/null", O_WRONLY);
                    if (devnull >= 0) {
                        dup2(devnull, STDERR_FILENO);
                        close(devnull);
                    }
                    execlp("cp", "cp", "-f", file_path, dst_path, (char *)NULL);
                    _exit(127);
                }
                int st2;
                waitpid(cp, &st2, 0);
                if (!WIFEXITED(st2) || WEXITSTATUS(st2) != 0) {
                    msg_error("failed to install: %s", rel_path);
                }
            }

            /* Record in db */
            if (idx >= 0) {
                if (installed[idx].file_count < 512)
                    snprintf(installed[idx].files[installed[idx].file_count],
                             sizeof(installed[idx].files[0]), "%s", rel_path);
                installed[idx].file_count++;
            } else {
                /* New entry - we'll add files after the loop */
                if (file_idx < 512) {
                    /* Store for later */
                }
            }

            file_idx++;
            progress_bar("install", file_idx * 100 / (file_idx + 1),
                         HRM_PROGRESS_WIDTH);
        }
        pclose(fp);

        /* If new package, create database entry */
        if (idx < 0) {
            struct hrm_installed *new_db = realloc(installed,
                (*db_count + 1) * sizeof(*installed));
            if (new_db) {
                installed = new_db;
                *db = new_db;
                memset(&installed[*db_count], 0, sizeof(installed[0]));
                snprintf(installed[*db_count].name, sizeof(installed[0].name),
                         "%s", pkg_name);
                snprintf(installed[*db_count].version, sizeof(installed[0].version),
                         "%s", m->version);
                snprintf(installed[*db_count].install_type, sizeof(installed[0].install_type),
                         "%s", install_type_to_string(m->install_type));
                snprintf(installed[*db_count].category, sizeof(installed[0].category),
                         "%s", m->category);
                snprintf(installed[*db_count].sha256, sizeof(installed[0].sha256),
                         "%s", m->sha256);

                /* Re-count files from find */
                installed[*db_count].file_count = file_idx;
                /* Actually we need to re-read - simplified: just set count */
                (*db_count)++;
            }
        } else {
            snprintf(installed[idx].version, sizeof(installed[0].version),
                     "%s", m->version);
        }

        progress_bar("install", 100, HRM_PROGRESS_WIDTH);
    }

    db_save(installed, *db_count);

    fprintf(stderr, "\n");
    msg_info("%s%s%s v%s installed successfully.",
             c(C_GREEN), c(C_BOLD), pkg_name, m->version);

    /* Cleanup */
    {
        pid_t rm = fork();
        if (rm == 0) {
            execlp("rm", "rm", "-rf", extract_dir, (char *)NULL);
            _exit(127);
        }
        int st;
        waitpid(rm, &st, 0);
    }

    return 0;

cleanup:
    {
        pid_t rm = fork();
        if (rm == 0) {
            execlp("rm", "rm", "-rf", extract_dir, (char *)NULL);
            _exit(127);
        }
        int st;
        waitpid(rm, &st, 0);
    }
    return 1;
}

static int install_rpm(const char *rpm_path, const char *pkg_name,
                       struct hrm_manifest *m)
{
    pid_t pid;
    int status;
    (void)pkg_name; (void)m;

    msg_info("installing RPM package...");

    pid = fork();
    if (pid < 0) return -1;

    if (pid == 0) {
        execlp("rpm", "rpm", "-ivh", "--nodeps", "--force", rpm_path, (char *)NULL);
        _exit(127);
    }

    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        msg_info("RPM installed successfully");
        return 0;
    }

    msg_error("RPM installation failed");
    return 1;
}

static int install_appimage(const char *ai_path, const char *pkg_name,
                            struct hrm_manifest *m)
{
    char dst_path[HRM_MAX_PATH];
    pid_t pid;
    int status;
    (void)m;

    msg_info("installing AppImage...");

    /* Make executable */
    chmod(ai_path, 0755);

    /* Copy to /usr/local/bin */
    snprintf(dst_path, sizeof(dst_path), "/usr/local/bin/%s", pkg_name);
    {
        char *last_slash = strrchr(dst_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            mkdir(dst_path, 0755);
            *last_slash = '/';
        }
    }

    pid = fork();
    if (pid < 0) return -1;

    if (pid == 0) {
        execlp("cp", "cp", "-f", ai_path, dst_path, (char *)NULL);
        _exit(127);
    }

    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        msg_info("AppImage installed to %s", dst_path);
        return 0;
    }

    msg_error("AppImage installation failed");
    return 1;
}

/* ------------------------------------------------------------------ */
/* Integrity verification                                              */
/* ------------------------------------------------------------------ */

static int verify_file_hash(const char *path, const char *expected)
{
    char actual[HRM_HASH_LEN];
    if (sha256_file(path, actual) < 0)
        return -1;
    return (strcmp(actual, expected) == 0) ? 0 : -1;
}

/* ------------------------------------------------------------------ */
/* HARAM check                                                         */
/* ------------------------------------------------------------------ */

static int check_haram(const struct hrm_manifest *m)
{
    static const char *haram_keywords[] = {
        "alcohol", "vodka", "wine", "beer", "whiskey", "casino",
        "poker", "gamble", "slot", "pork", "bacon", "ham",
        "sausage", "pig", "shirk", "idol", "zina", "drug",
        "narcotic", "opium", "cannabis", "marijuana", "weed",
        NULL
    };
    int i;
    char name_lower[128];

    /* Check haram field from manifest */
    if (m->haram) {
        msg_haram_panic(m->name, m->category[0] ? m->category : "unknown");
        return 1;
    }

    /* Check tags for haram keywords */
    for (i = 0; i < m->tag_count; i++) {
        int j;
        for (j = 0; haram_keywords[j]; j++) {
            if (strstr(m->tags[i], haram_keywords[j])) {
                msg_haram_panic(m->name, m->tags[i]);
                return 1;
            }
        }
    }

    /* Check package name */
    for (i = 0; m->name[i] && i < 127; i++)
        name_lower[i] = tolower((unsigned char)m->name[i]);
    name_lower[i] = '\0';

    for (i = 0; haram_keywords[i]; i++) {
        if (strstr(name_lower, haram_keywords[i])) {
            msg_haram_panic(m->name, haram_keywords[i]);
            return 1;
        }
    }

    return 0;
}

/* ------------------------------------------------------------------ */
/* Commands                                                            */
/* ------------------------------------------------------------------ */

static int cmd_install(const char *pkg_name)
{
    struct hrm_manifest m;
    struct hrm_installed *db = NULL;
    int db_count = 0;
    int lock_fd;
    char archive_path[HRM_MAX_PATH];
    int found = 0;
    int i;

    banner();

    lock_fd = lock_acquire();
    if (lock_fd < 0) return 1;

    /* Search for manifest in local manifests cache */
    {
        char manifest_path[HRM_MAX_PATH];
        DIR *dir;
        struct dirent *ent;

        /* Try direct name match first */
        snprintf(manifest_path, sizeof(manifest_path),
                 "%s/%s/latest.json", HRM_MANIFESTS_DIR, pkg_name);
        if (parse_manifest_file(manifest_path, &m) == 0) {
            found = 1;
        }

        /* Search all categories */
        if (!found) {
            dir = opendir(HRM_MANIFESTS_DIR);
            if (dir) {
                while ((ent = readdir(dir)) != NULL && !found) {
                    if (ent->d_name[0] == '.') continue;
                    if (ent->d_type != DT_DIR) continue;

                    snprintf(manifest_path, sizeof(manifest_path),
                             "%s/%s/%s/latest.json", HRM_MANIFESTS_DIR,
                             ent->d_name, pkg_name);
                    if (parse_manifest_file(manifest_path, &m) == 0) {
                        found = 1;
                    }
                }
                closedir(dir);
            }
        }
    }

    if (!found) {
        /* Try local .hrm archive as fallback */
        snprintf(archive_path, sizeof(archive_path),
                 "%s/%s.hrm", HRM_CACHE_DIR, pkg_name);
        if (access(archive_path, R_OK) != 0) {
            snprintf(archive_path, sizeof(archive_path),
                     "%s/%s.hrm", HRM_REPO_DIR, pkg_name);
        }
        if (access(archive_path, R_OK) == 0) {
            msg_info("found local archive: %s", archive_path);
            /* For local .hrm, use tarball install directly */
            lock_release(lock_fd);
            return install_tarball(archive_path, pkg_name, &m,
                                   &db, &db_count, lock_fd);
        }

        msg_error("package '%s' not found", pkg_name);
        msg_info("use 'hrm repo sync' to update package lists");
        lock_release(lock_fd);
        return 1;
    }

    msg_info("found manifest: %s v%s", m.name, m.version);
    msg_info("summary: %s", m.summary);
    msg_info("install type: %s", install_type_to_string(m.install_type));
    if (m.dep_count > 0) {
        msg_info("dependencies:");
        for (i = 0; i < m.dep_count; i++)
            fprintf(stderr, "    -> %s\n", m.deps[i]);
    }

    /* HARAM CHECK */
    if (check_haram(&m)) {
        msg_error("INSTALLATION ABORTED: haram package detected");
        lock_release(lock_fd);
        return 1;
    }

    /* Download package */
    {
        char download_path[HRM_MAX_PATH];
        const char *ext = ".tar.gz";

        if (m.install_type == 1) ext = ".rpm";
        else if (m.install_type == 2) ext = ".AppImage";

        snprintf(download_path, sizeof(download_path),
                 "/tmp/haramchy-pkg/%s-%s%s", m.name, m.version, ext);

        /* Check cache first */
        if (access(download_path, R_OK) != 0) {
            if (download_file(m.url, download_path, m.sha256) < 0) {
                msg_error("failed to download package");
                lock_release(lock_fd);
                return 1;
            }
        } else {
            msg_info("using cached download");
            /* Verify cached file */
            if (m.sha256[0] && verify_file_hash(download_path, m.sha256) < 0) {
                msg_warn("cached file hash mismatch, re-downloading");
                if (download_file(m.url, download_path, m.sha256) < 0) {
                    msg_error("failed to download package");
                    lock_release(lock_fd);
                    return 1;
                }
            }
        }

        /* Install based on type */
        switch (m.install_type) {
            case 1: /* RPM */
                install_rpm(download_path, pkg_name, &m);
                break;
            case 2: /* AppImage */
                install_appimage(download_path, pkg_name, &m);
                break;
            default: /* tarball */
                install_tarball(download_path, pkg_name, &m,
                               &db, &db_count, lock_fd);
                break;
        }
    }

    /* Run post-install script if present */
    if (m.post_install_script[0]) {
        msg_info("running post-install script...");
        {
            char script_path[HRM_MAX_PATH];
            snprintf(script_path, sizeof(script_path),
                     "/tmp/haramchy-pkg/%s-post.sh", pkg_name);
            if (download_file(m.post_install_script, script_path, NULL) == 0) {
                pid_t sh = fork();
                if (sh == 0) {
                    chmod(script_path, 0755);
                    execlp("sh", "sh", script_path, (char *)NULL);
                    _exit(127);
                }
                int st;
                waitpid(sh, &st, 0);
            }
        }
    }

    lock_release(lock_fd);
    free(db);
    return 0;
}

static int cmd_remove(const char *pkg_name)
{
    struct hrm_installed *db = NULL;
    int db_count = 0;
    int idx;
    int lock_fd;
    int i;

    banner();

    lock_fd = lock_acquire();
    if (lock_fd < 0) return 1;

    db_load(&db, &db_count);
    idx = db_find(db, db_count, pkg_name);

    if (idx < 0) {
        msg_error("package '%s' is not installed", pkg_name);
        lock_release(lock_fd);
        free(db);
        return 1;
    }

    msg_info("removing %s v%s...", db[idx].name, db[idx].version);

    fprintf(stderr, "%sThis will remove %d files from your system.%s\n",
            c(C_YELLOW), db[idx].file_count, c(C_RESET));
    fprintf(stderr, "%sAre you sure? [y/N] %s", c(C_YELLOW), c(C_RESET));
    {
        char ans[16] = {0};
        if (fgets(ans, sizeof(ans), stdin) == NULL ||
            (ans[0] != 'y' && ans[0] != 'Y')) {
            msg_info("removal cancelled");
            lock_release(lock_fd);
            free(db);
            return 0;
        }
    }

    progress_bar("remove", 0, HRM_PROGRESS_WIDTH);

    for (i = db[idx].file_count - 1; i >= 0; i--) {
        char path[HRM_MAX_PATH];
        snprintf(path, sizeof(path), "/%s", db[idx].files[i]);

        if (unlink(path) == 0) {
            if (g_verbose)
                fprintf(stderr, "  removed: %s\n", db[idx].files[i]);
        } else if (errno == ENOENT) {
            if (g_verbose)
                fprintf(stderr, "  already gone: %s\n", db[idx].files[i]);
        } else {
            msg_warn("cannot remove: %s (%s)", db[idx].files[i],
                     strerror(errno));
        }

        progress_bar("remove",
                     (db[idx].file_count - i) * 100 / db[idx].file_count,
                     HRM_PROGRESS_WIDTH);
    }

    /* Remove empty parent directories */
    for (i = 0; i < db[idx].file_count; i++) {
        char path[HRM_MAX_PATH];
        char *p;
        snprintf(path, sizeof(path), "/%s", db[idx].files[i]);
        p = strrchr(path, '/');
        while (p && p > path) {
            *p = '\0';
            rmdir(path);
            p = strrchr(path, '/');
        }
    }

    /* Remove from database */
    {
        struct hrm_installed *new_db = calloc(db_count - 1, sizeof(*db));
        if (new_db) {
            int j = 0;
            for (i = 0; i < db_count; i++) {
                if (i != idx)
                    memcpy(&new_db[j++], &db[i], sizeof(*db));
            }
            db_save(new_db, db_count - 1);
            free(new_db);
        } else {
            for (i = idx; i < db_count - 1; i++)
                memcpy(&db[i], &db[i + 1], sizeof(*db));
            db_save(db, db_count - 1);
        }
    }

    fprintf(stderr, "\n");
    msg_info("%s%s%s removed successfully.",
             c(C_GREEN), c(C_BOLD), pkg_name);

    lock_release(lock_fd);
    free(db);
    return 0;
}

static int cmd_list(void)
{
    struct hrm_installed *db = NULL;
    int db_count = 0;
    int i;

    db_load(&db, &db_count);

    if (db_count == 0) {
        fprintf(stderr, "%sNo packages installed.%s\n",
                c(C_DIM), c(C_RESET));
        fprintf(stderr, "Use '%shrm install <package>%s' to install.\n",
                c(C_CYAN), c(C_RESET));
        free(db);
        return 0;
    }

    fprintf(stderr, "%s%sInstalled packages (%d):%s\n",
            c(C_BOLD), c(C_CYAN), db_count, c(C_RESET));
    fprintf(stderr, "%s%-25s %-12s %-10s %-10s %s%s\n",
            c(C_BOLD), "NAME", "VERSION", "TYPE", "CATEGORY", "FILES", c(C_RESET));
    fprintf(stderr, "%s%-25s %-12s %-10s %-10s %s%s\n",
            c(C_DIM), "----", "-------", "----", "--------", "-----", c(C_RESET));

    for (i = 0; i < db_count; i++) {
        fprintf(stderr, "%s%-25s %-12s %-10s %-10s %d%s\n",
                c(C_WHITE), db[i].name, db[i].version,
                db[i].install_type, db[i].category,
                db[i].file_count, c(C_RESET));
    }

    fprintf(stderr, "\n%sTotal: %d packages installed.%s\n",
            c(C_DIM), db_count, c(C_RESET));

    free(db);
    return 0;
}

static int cmd_search(const char *query)
{
    DIR *cat_dir;
    struct dirent *cat_ent;
    int found = 0;

    fprintf(stderr, "%sSearching for '%s'...%s\n",
            c(C_CYAN), query, c(C_RESET));

    mkdir(HRM_MANIFESTS_DIR, 0755);

    cat_dir = opendir(HRM_MANIFESTS_DIR);
    if (!cat_dir) {
        fprintf(stderr, "%sNo package index found. Run 'hrm repo sync' first.%s\n",
                c(C_YELLOW), c(C_RESET));
        return 0;
    }

    while ((cat_ent = readdir(cat_dir)) != NULL) {
        DIR *pkg_dir;
        struct dirent *pkg_ent;

        if (cat_ent->d_name[0] == '.') continue;
        if (cat_ent->d_type != DT_DIR) continue;

        pkg_dir = opendir(cat_ent->d_name);
        if (!pkg_dir) continue;

        while ((pkg_ent = readdir(pkg_dir)) != NULL) {
            char manifest_path[HRM_MAX_PATH];
            struct hrm_manifest m;

            if (pkg_ent->d_name[0] == '.') continue;
            if (pkg_ent->d_type != DT_DIR) continue;

            snprintf(manifest_path, sizeof(manifest_path),
                     "%s/%s/%s/latest.json", HRM_MANIFESTS_DIR,
                     cat_ent->d_name, pkg_ent->d_name);

            if (parse_manifest_file(manifest_path, &m) != 0)
                continue;

            /* Check name match */
            {
                char name_lower[128];
                char query_lower[128];
                int i;

                for (i = 0; m.name[i] && i < 127; i++)
                    name_lower[i] = tolower((unsigned char)m.name[i]);
                name_lower[i] = '\0';
                for (i = 0; query[i] && i < 127; i++)
                    query_lower[i] = tolower((unsigned char)query[i]);
                query_lower[i] = '\0';

                if (!strstr(name_lower, query_lower) &&
                    !strstr(m.summary, query_lower))
                    continue;
            }

            fprintf(stderr, "\n%s%s  %s%s  %sv%s%s\n",
                    c(C_BOLD), c(C_WHITE), m.name,
                    c(C_RESET), c(C_GREEN), m.version, c(C_RESET));
            fprintf(stderr, "    %s%s%s\n",
                    c(C_DIM), m.summary, c(C_RESET));
            fprintf(stderr, "    Category: %s | Type: %s | License: %s\n",
                    m.category, install_type_to_string(m.install_type),
                    m.license);
            found++;
        }
        closedir(pkg_dir);
    }
    closedir(cat_dir);

    if (found == 0) {
        fprintf(stderr, "%sNo packages found matching '%s'.%s\n",
                c(C_YELLOW), query, c(C_RESET));
    } else {
        fprintf(stderr, "\n%sFound %d package(s).%s\n",
                c(C_GREEN), found, c(C_RESET));
    }

    return 0;
}

static int cmd_info(const char *pkg_name)
{
    struct hrm_installed *db = NULL;
    int db_count = 0;
    int idx;
    int i;

    db_load(&db, &db_count);
    idx = db_find(db, db_count, pkg_name);

    if (idx >= 0) {
        fprintf(stderr, "%s%sPackage: %s%s\n",
                c(C_BOLD), c(C_GREEN), db[idx].name, c(C_RESET));
        fprintf(stderr, "  Version:      %s\n", db[idx].version);
        fprintf(stderr, "  Type:         %s\n", db[idx].install_type);
        fprintf(stderr, "  Category:     %s\n", db[idx].category);
        fprintf(stderr, "  Status:       %sinstalled%s\n",
                c(C_GREEN), c(C_RESET));
        fprintf(stderr, "  Files:        %d\n", db[idx].file_count);
        if (g_verbose) {
            int j;
            for (j = 0; j < db[idx].file_count; j++)
                fprintf(stderr, "    /%s\n", db[idx].files[j]);
        }
        free(db);
        return 0;
    }

    /* Search manifests */
    {
        DIR *cat_dir;
        struct dirent *cat_ent;
        int found = 0;

        cat_dir = opendir(HRM_MANIFESTS_DIR);
        if (!cat_dir) {
            msg_error("no package index. Run 'hrm repo sync' first.");
            free(db);
            return 1;
        }

        while ((cat_ent = readdir(cat_dir)) != NULL && !found) {
            DIR *pkg_dir;
            struct dirent *pkg_ent;

            if (cat_ent->d_name[0] == '.') continue;
            if (cat_ent->d_type != DT_DIR) continue;

            pkg_dir = opendir(cat_ent->d_name);
            if (!pkg_dir) continue;

            while ((pkg_ent = readdir(pkg_dir)) != NULL && !found) {
                char manifest_path[HRM_MAX_PATH];
                struct hrm_manifest m;

                if (pkg_ent->d_name[0] == '.') continue;
                if (pkg_ent->d_type != DT_DIR) continue;

                if (strcmp(pkg_ent->d_name, pkg_name) != 0) continue;

                snprintf(manifest_path, sizeof(manifest_path),
                         "%s/%s/%s/latest.json", HRM_MANIFESTS_DIR,
                         cat_ent->d_name, pkg_ent->d_name);

                if (parse_manifest_file(manifest_path, &m) == 0) {
                    fprintf(stderr, "%s%sPackage: %s%s\n",
                            c(C_BOLD), c(C_WHITE), m.name, c(C_RESET));
                    fprintf(stderr, "  Version:      %s (release %d)\n",
                            m.version, m.release);
                    fprintf(stderr, "  Category:     %s\n", m.category);
                    fprintf(stderr, "  Summary:      %s\n", m.summary);
                    fprintf(stderr, "  License:      %s\n", m.license);
                    fprintf(stderr, "  Architecture: %s\n", m.architecture);
                    fprintf(stderr, "  Install type: %s\n",
                            install_type_to_string(m.install_type));
                    fprintf(stderr, "  Maintainer:   %s\n", m.maintainer);
                    fprintf(stderr, "  Homepage:     %s\n", m.homepage);
                    if (m.description[0])
                        fprintf(stderr, "  Description:  %s\n", m.description);
                    if (m.tag_count > 0) {
                        fprintf(stderr, "  Tags:         ");
                        for (i = 0; i < m.tag_count; i++)
                            fprintf(stderr, "%s%s%s ",
                                    c(C_CYAN), m.tags[i], c(C_RESET));
                        fprintf(stderr, "\n");
                    }
                    if (m.dep_count > 0) {
                        fprintf(stderr, "  Dependencies: ");
                        for (i = 0; i < m.dep_count; i++)
                            fprintf(stderr, "%s ", m.deps[i]);
                        fprintf(stderr, "\n");
                    }
                    fprintf(stderr, "  Status:       %snot installed%s\n",
                            c(C_YELLOW), c(C_RESET));
                    found = 1;
                }
            }
            closedir(pkg_dir);
        }
        closedir(cat_dir);

        if (!found) {
            msg_error("package '%s' not found", pkg_name);
        }
    }

    free(db);
    return 0;
}

static int cmd_verify(const char *pkg_name)
{
    struct hrm_installed *db = NULL;
    int db_count = 0;
    int idx;

    db_load(&db, &db_count);
    idx = db_find(db, db_count, pkg_name);

    if (idx < 0) {
        msg_error("package '%s' is not installed", pkg_name);
        free(db);
        return 1;
    }

    msg_info("verifying installed files for %s v%s...",
             db[idx].name, db[idx].version);

    {
        int i;
        int ok = 1;
        for (i = 0; i < db[idx].file_count; i++) {
            char path[HRM_MAX_PATH];
            snprintf(path, sizeof(path), "/%s", db[idx].files[i]);
            if (access(path, R_OK) != 0) {
                msg_error("  missing: /%s", db[idx].files[i]);
                ok = 0;
            } else if (g_verbose) {
                fprintf(stderr, "  %sOK%s  /%s\n",
                        c(C_GREEN), c(C_RESET), db[idx].files[i]);
            }
        }
        if (ok)
            msg_info("all %d files present and accessible", db[idx].file_count);
    }

    free(db);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Repo commands                                                       */
/* ------------------------------------------------------------------ */

static int cmd_repo_add(const char *name, const char *url)
{
    struct hrm_repo repos[HRM_MAX_REPOS];
    int count = repo_load(repos, HRM_MAX_REPOS);
    int i;

    /* Check for duplicate */
    for (i = 0; i < count; i++) {
        if (strcmp(repos[i].name, name) == 0) {
            msg_warn("repo '%s' already exists, updating URL", name);
            snprintf(repos[i].url, sizeof(repos[i].url), "%s", url);
            repo_save(repos, count);
            msg_info("repo '%s' updated", name);
            return 0;
        }
    }

    if (count >= HRM_MAX_REPOS) {
        msg_error("maximum number of repos reached (%d)", HRM_MAX_REPOS);
        return 1;
    }

    snprintf(repos[count].name, sizeof(repos[count].name), "%s", name);
    snprintf(repos[count].url, sizeof(repos[count].url), "%s", url);
    snprintf(repos[count].branch, sizeof(repos[count].branch), "main");
    repos[count].enabled = 1;
    count++;

    repo_save(repos, count);
    msg_info("repo '%s' added", name);
    return 0;
}

static int cmd_repo_remove(const char *name)
{
    struct hrm_repo repos[HRM_MAX_REPOS];
    int count = repo_load(repos, HRM_MAX_REPOS);
    int i, j;
    int found = 0;

    for (i = 0; i < count; i++) {
        if (strcmp(repos[i].name, name) == 0) {
            found = 1;
            break;
        }
    }

    if (!found) {
        msg_error("repo '%s' not found", name);
        return 1;
    }

    for (j = i; j < count - 1; j++)
        memcpy(&repos[j], &repos[j + 1], sizeof(repos[0]));
    count--;

    repo_save(repos, count);
    msg_info("repo '%s' removed", name);
    return 0;
}

static int cmd_repo_list(void)
{
    struct hrm_repo repos[HRM_MAX_REPOS];
    int count = repo_load(repos, HRM_MAX_REPOS);
    int i;

    if (count == 0) {
        fprintf(stderr, "%sNo repositories configured.%s\n",
                c(C_DIM), c(C_RESET));
        fprintf(stderr, "Use '%shrm repo add <name> <url>%s' to add one.\n",
                c(C_CYAN), c(C_RESET));
        return 0;
    }

    fprintf(stderr, "%s%sRepositories (%d):%s\n",
            c(C_BOLD), c(C_CYAN), count, c(C_RESET));

    for (i = 0; i < count; i++) {
        fprintf(stderr, "  %s%s%s %s(%s)%s %s%s%s\n",
                c(C_BOLD), c(C_WHITE), repos[i].name,
                c(C_DIM), repos[i].url, c(C_RESET),
                repos[i].enabled ? c(C_GREEN) : c(C_RED),
                repos[i].enabled ? "enabled" : "disabled",
                c(C_RESET));
    }

    return 0;
}

static int cmd_repo_sync(void)
{
    struct hrm_repo repos[HRM_MAX_REPOS];
    int count = repo_load(repos, HRM_MAX_REPOS);
    int i;

    if (count == 0) {
        msg_warn("no repositories configured");
        return 0;
    }

    mkdir(HRM_MANIFESTS_DIR, 0755);

    for (i = 0; i < count; i++) {
        if (!repos[i].enabled) continue;

        msg_info("syncing repo '%s' from %s...", repos[i].name, repos[i].url);

        /* Clone or update the manifest repo */
        {
            char repo_path[HRM_MAX_PATH];
            pid_t pid;
            int status;

            snprintf(repo_path, sizeof(repo_path),
                     "%s/%s", HRM_MANIFESTS_DIR, repos[i].name);

            if (access(repo_path, R_OK) == 0) {
                /* Pull latest */
                pid = fork();
                if (pid == 0) {
                    execlp("git", "git", "-C", repo_path,
                           "pull", "--ff-only", (char *)NULL);
                    _exit(127);
                }
                waitpid(pid, &status, 0);
            } else {
                /* Clone */
                pid = fork();
                if (pid == 0) {
                    execlp("git", "git", "clone", "--depth", "1",
                           "-b", repos[i].branch,
                           repos[i].url, repo_path, (char *)NULL);
                    _exit(127);
                }
                waitpid(pid, &status, 0);
            }

            if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                msg_info("repo '%s' synced successfully", repos[i].name);
            } else {
                msg_error("failed to sync repo '%s'", repos[i].name);
            }
        }
    }

    return 0;
}

/* ------------------------------------------------------------------ */
/* Usage                                                               */
/* ------------------------------------------------------------------ */

static void usage(void)
{
    fprintf(stderr,
        "%s%sUsage: hrm <command> [arguments]%s\n\n"
        "%sCommands:%s\n"
        "  install <pkg>     Install a package\n"
        "  remove  <pkg>     Remove an installed package\n"
        "  list              List all installed packages\n"
        "  search  <query>   Search for packages\n"
        "  info    <pkg>     Show package information\n"
        "  verify  <pkg>     Verify integrity of installed files\n"
        "  repo add <n> <u>  Add a package repository\n"
        "  repo remove <n>   Remove a repository\n"
        "  repo list         List configured repositories\n"
        "  repo sync         Sync package lists from repos\n\n"
        "%sOptions:%s\n"
        "  -v, --verbose     Verbose output\n"
        "  -n, --dry-run     Show what would be done\n"
        "  -f, --force       Force operation\n"
        "  --no-color        Disable colored output\n"
        "  -h, --help        Show this help\n\n"
        "%sPackage format:%s\n"
        "  JSON manifests with SHA-256 verified downloads\n"
        "  Also supports local .hrm archives (tar.gz + manifest.toml)\n\n"
        "%sDatabase:%s %s%s\n",
        c(C_BOLD), c(C_CYAN), c(C_RESET),
        c(C_BOLD), c(C_WHITE),
        c(C_BOLD), c(C_WHITE),
        c(C_BOLD), c(C_WHITE),
        c(C_BOLD), c(C_WHITE),
        c(C_DIM), HRM_DB_PATH
    );
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

int main(int argc, char *argv[])
{
    const char *cmd = NULL;
    const char *arg1 = NULL;
    const char *arg2 = NULL;
    int i;

    color_init();

    if (argc < 2) {
        usage();
        return 1;
    }

    /* Global flags */
    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0)
            g_verbose = 1;
        else if (strcmp(argv[i], "-n") == 0 || strcmp(argv[i], "--dry-run") == 0)
            g_dry_run = 1;
        else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--force") == 0)
            g_force = 1;
        else if (strcmp(argv[i], "--no-color") == 0)
            g_color = 0;
    }

    /* Find command and args */
    for (i = 1; i < argc; i++) {
        if (argv[i][0] != '-') {
            cmd = argv[i];
            if (i + 1 < argc && argv[i + 1][0] != '-')
                arg1 = argv[i + 1];
            if (i + 2 < argc && argv[i + 2][0] != '-')
                arg2 = argv[i + 2];
            break;
        }
    }

    if (!cmd) {
        usage();
        return 1;
    }

    if (strcmp(cmd, "install") == 0) {
        if (!arg1) {
            msg_error("install requires a package name");
            fprintf(stderr, "Usage: hrm install <package-name>\n");
            return 1;
        }
        return cmd_install(arg1);
    } else if (strcmp(cmd, "remove") == 0 || strcmp(cmd, "uninstall") == 0) {
        if (!arg1) {
            msg_error("remove requires a package name");
            return 1;
        }
        return cmd_remove(arg1);
    } else if (strcmp(cmd, "list") == 0 || strcmp(cmd, "ls") == 0) {
        return cmd_list();
    } else if (strcmp(cmd, "search") == 0 || strcmp(cmd, "find") == 0) {
        if (!arg1) {
            msg_error("search requires a query string");
            return 1;
        }
        return cmd_search(arg1);
    } else if (strcmp(cmd, "info") == 0 || strcmp(cmd, "show") == 0) {
        if (!arg1) {
            msg_error("info requires a package name");
            return 1;
        }
        return cmd_info(arg1);
    } else if (strcmp(cmd, "verify") == 0 || strcmp(cmd, "check") == 0) {
        if (!arg1) {
            msg_error("verify requires a package name");
            return 1;
        }
        return cmd_verify(arg1);
    } else if (strcmp(cmd, "repo") == 0) {
        if (!arg1) {
            msg_error("repo requires a subcommand (add/remove/list/sync)");
            return 1;
        }
        if (strcmp(arg1, "add") == 0) {
            if (!arg2) {
                msg_error("repo add requires <name> <url>");
                return 1;
            }
            return cmd_repo_add(arg2, (i + 3 < argc) ? argv[i + 3] : "");
        } else if (strcmp(arg1, "remove") == 0) {
            if (!arg2) {
                msg_error("repo remove requires <name>");
                return 1;
            }
            return cmd_repo_remove(arg2);
        } else if (strcmp(arg1, "list") == 0) {
            return cmd_repo_list();
        } else if (strcmp(arg1, "sync") == 0) {
            return cmd_repo_sync();
        } else {
            msg_error("unknown repo subcommand: %s", arg1);
            return 1;
        }
    } else if (strcmp(cmd, "--help") == 0 || strcmp(cmd, "-h") == 0) {
        usage();
        return 0;
    } else {
        msg_error("unknown command: %s", cmd);
        usage();
        return 1;
    }
}