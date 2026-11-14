// tfetch: a tiny system info tool for Termux, written in C
// Author: Haitham Aouati
// GitHub: github.com/haithamaouati

#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <getopt.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

#ifndef TFETCH_VERSION
#define TFETCH_VERSION "1.0.0"
#endif

#define ARRAY_LEN(a) (sizeof(a) / sizeof((a)[0]))
#define BANNER_ROWS 7
#define LABEL_WIDTH 7
#define VALUE_LEN 96
#define MAX_ROWS 10

// Banners, add a new one by defining another art_NAME array
// and listing it in the banners table below
// Rules: 7 lines, all the same width
// A banner that breaks the rules is shown in full above the info
static const char *const art_tux[] = {
    "     ___    ",
    "    (.· |   ",
    "    (<> |   ",
    "   / __  \\  ",
    "  ( /  \\ /| ",
    " _/\\ __)/_) ",
    " \\/-____\\/  ",
};

static const char *const art_android[] = {
    "                    ",
    "  ;,           ,;   ",
    "   ';,.-----.,;'    ",
    "  ,'           ',   ",
    " /    O     O    \\  ",
    "|                 | ",
    "'-----------------' ",
};

static const char *const art_term[] = {
    " __________ ",
    "| >_       |",
    "|          |",
    "|  ~ $ ls  |",
    "|          |",
    "|__________|",
    "   _|__|_   ",
};

struct banner {
    const char *name;
    const char *const *lines;
    size_t count;
};

#define BANNER(id) { #id, art_##id, ARRAY_LEN(art_##id) }

// The first entry is the default banner
static const struct banner banners[] = {
    BANNER(tux),
    BANNER(android),
    BANNER(term),
};

struct options {
    int clear;
    int palette;
    int date;
    int time;
    int art_color;
    const char *color;
    const struct banner *banner;
};

struct rows {
    const char *label[MAX_ROWS];
    char value[MAX_ROWS][VALUE_LEN];
    int n;
};

// Terminal styles, empty when colors are off
static const char *bold = "";
static const char *underline = "";
static const char *reset = "";
static char heading[64] = "";
static char art_style[32] = "";

static int colors_enabled(void)
{
    const char *no_color = getenv("NO_COLOR");
    const char *term = getenv("TERM");

    if (!isatty(STDOUT_FILENO))
        return 0;
    if (no_color && *no_color)
        return 0;
    if (term && strcmp(term, "dumb") == 0)
        return 0;
    return 1;
}

static void banner_names(char *out, size_t n)
{
    size_t used = 0;

    out[0] = '\0';
    for (size_t i = 0; i < ARRAY_LEN(banners) && used < n; i++)
        used += (size_t)snprintf(out + used, n - used, "%s%s",
                                 i ? ", " : "", banners[i].name);
}

static const struct banner *find_banner(const char *name)
{
    for (size_t i = 0; i < ARRAY_LEN(banners); i++)
        if (strcasecmp(banners[i].name, name) == 0)
            return &banners[i];
    return NULL;
}

static void usage(FILE *out)
{
    char names[128];

    banner_names(names, sizeof names);
    fprintf(out,
        "\n%stfetch%s %s\n"
        "A tiny system info tool for Termux, written in C.\n\n"
        " Author: Haitham Aouati\n"
        " GitHub: %sgithub.com/haithamaouati%s\n\n"
        "Usage: tfetch [OPTIONS]\n\n"
        "Options:\n"
        "  -c, --clear         Clear the terminal screen before displaying info\n"
        "  -p, --palette       Show the terminal color palette\n"
        "  -b, --banner NAME   Choose the ASCII art banner (default: %s)\n"
        "  -d, --date          Show the current date\n"
        "  -t, --time          Show the current time (hours, minutes, seconds)\n"
        "  -a, --all           Show all information, including -d, -t, and -p\n"
        "  -C, --color VALUE   Set bold color for info labels: a 256-color index\n"
        "                      (0-255) or an SGR sequence such as \"1;31\"\n"
        "  -A, --art-color     Also apply the -C color to the banner\n"
        "  -v, --version       Show the version and exit\n"
        "  -h, --help          Show this help message and exit\n\n"
        "Banners: %s\n",
        bold, reset, TFETCH_VERSION, underline, reset, banners[0].name, names);
}

static void die(const char *fmt, ...) __attribute__((noreturn, format(printf, 1, 2)));

static void die(const char *fmt, ...)
{
    va_list ap;

    fputs("tfetch: ", stderr);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    exit(2);
}

static void unknown_option(const char *what)
{
    fprintf(stderr, "tfetch: unknown option: %s\n", what);
    fputs("Try 'tfetch --help' for more information.\n", stderr);
    exit(2);
}

// Turn a color value into an SGR sequence
// Accepts a 256-color index (0-255) or digits separated by semicolons
static int parse_color(const char *s, char *seq, size_t n)
{
    size_t len = strlen(s);
    int digits_only = 1;

    if (len == 0 || len >= n - 8)
        return -1;
    for (size_t i = 0; i < len; i++)
        if (!isdigit((unsigned char)s[i]))
            digits_only = 0;

    if (digits_only && len <= 3) {
        long v = strtol(s, NULL, 10);
        if (v > 255)
            return -1;
        snprintf(seq, n, "38;5;%ld", v);
        return 0;
    }

    int semis = 0, prev_digit = 0;
    for (size_t i = 0; i < len; i++) {
        if (isdigit((unsigned char)s[i])) {
            prev_digit = 1;
        } else if (s[i] == ';' && prev_digit) {
            prev_digit = 0;
            semis++;
        } else {
            return -1;
        }
    }
    if (!prev_digit || semis == 0)
        return -1;
    snprintf(seq, n, "%s", s);
    return 0;
}

// Width of a line in characters, not bytes
static size_t line_width(const char *s)
{
    size_t n = 0;

    for (; *s; s++)
        if (((unsigned char)*s & 0xC0) != 0x80)
            n++;
    return n;
}

// A banner follows the rules when it has 7 lines of the same width
static int banner_is_valid(const struct banner *b, size_t *width)
{
    size_t first;

    if (b->count != BANNER_ROWS)
        return 0;
    first = line_width(b->lines[0]);
    if (first == 0)
        return 0;
    for (size_t i = 1; i < b->count; i++)
        if (line_width(b->lines[i]) != first)
            return 0;
    *width = first;
    return 1;
}

// Replace control characters so values cannot inject escape codes
static void sanitize(char *s)
{
    for (; *s; s++)
        if ((unsigned char)*s < 0x20 || *s == 0x7f)
            *s = '?';
}

static void get_user(char *out, size_t n)
{
    const char *u = getenv("USER");

    if (!u || !*u) {
        struct passwd *pw = getpwuid(getuid());
        u = pw ? pw->pw_name : NULL;
    }
    snprintf(out, n, "%s", (u && *u) ? u : "unknown");
    sanitize(out);
}

static void get_host(char *out, size_t n)
{
    if (gethostname(out, n) != 0 || out[0] == '\0') {
        const char *h = getenv("HOSTNAME");
        snprintf(out, n, "%s", (h && *h) ? h : "localhost");
    }
    out[n - 1] = '\0';
    sanitize(out);
}

static const char *get_os(const struct utsname *u)
{
#ifdef __ANDROID__
    (void)u;
    return "Android";
#else
    return strcmp(u->sysname, "Linux") == 0 ? "GNU/Linux" : u->sysname;
#endif
}

// Keep only the leading numeric part of the kernel release
static void get_kernel(const struct utsname *u, char *out, size_t n)
{
    const char *r = u->release;
    size_t i = 0;

    if (!isdigit((unsigned char)r[0])) {
        snprintf(out, n, "unknown");
        return;
    }
    while (isdigit((unsigned char)r[i]) ||
           (r[i] == '.' && isdigit((unsigned char)r[i + 1])))
        i++;
    snprintf(out, n, "%.*s", (int)i, r);
}

static int get_uptime_secs(long long *secs)
{
    struct timespec ts;
    FILE *f;
    double up;
    int ok;

    // Works on Android without reading /proc
    if (clock_gettime(CLOCK_BOOTTIME, &ts) == 0) {
        *secs = ts.tv_sec;
        return 1;
    }
    f = fopen("/proc/uptime", "r");
    if (!f)
        return 0;
    ok = fscanf(f, "%lf", &up) == 1;
    fclose(f);
    if (ok)
        *secs = (long long)up;
    return ok;
}

// Show only the two largest units to keep the line short
static void get_uptime(char *out, size_t n)
{
    long long secs, d, h, m;

    if (!get_uptime_secs(&secs)) {
        snprintf(out, n, "unknown");
        return;
    }
    d = secs / 86400;
    h = secs % 86400 / 3600;
    m = secs % 3600 / 60;
    if (d > 0)
        snprintf(out, n, "%lldd %lldh", d, h);
    else if (h > 0)
        snprintf(out, n, "%lldh %lldm", h, m);
    else
        snprintf(out, n, "%lldm", m);
}

// Count installed packages in a dpkg status file with one read
static long count_dpkg(const char *path)
{
    static const char needle[] = "Status: install ok installed\n";
    const size_t nlen = sizeof needle - 1;
    struct stat st;
    char *buf;
    const char *p, *end;
    size_t got = 0;
    long count = 0;
    int fd = open(path, O_RDONLY | O_CLOEXEC);

    if (fd < 0)
        return -1;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) {
        close(fd);
        return -1;
    }
    buf = malloc((size_t)st.st_size);
    if (!buf) {
        close(fd);
        return -1;
    }
    while (got < (size_t)st.st_size) {
        ssize_t r = read(fd, buf + got, (size_t)st.st_size - got);
        if (r <= 0)
            break;
        got += (size_t)r;
    }
    close(fd);

    p = buf;
    end = buf + got;
    while (p < end && (p = memmem(p, (size_t)(end - p), needle, nlen)) != NULL) {
        if (p == buf || p[-1] == '\n')
            count++;
        p += nlen;
    }
    free(buf);
    return count;
}

// Count package folders in a pacman database
static long count_pacman(const char *path)
{
    struct dirent *e;
    long count = 0;
    DIR *d = opendir(path);

    if (!d)
        return -1;
    while ((e = readdir(d)) != NULL)
        if (e->d_name[0] != '.' && strcmp(e->d_name, "ALPM_DB_VERSION") != 0)
            count++;
    closedir(d);
    return count;
}

static void get_pkgs(char *out, size_t n)
{
    char path[512];
    const char *prefix = getenv("PREFIX");
    long count = -1;

    if (prefix && *prefix) {
        snprintf(path, sizeof path, "%s/var/lib/dpkg/status", prefix);
        count = count_dpkg(path);
    }
#ifdef __ANDROID__
    if (count < 0)
        count = count_dpkg("/data/data/com.termux/files/usr/var/lib/dpkg/status");
#endif
    if (count < 0)
        count = count_dpkg("/var/lib/dpkg/status");
    if (count < 0 && prefix && *prefix) {
        snprintf(path, sizeof path, "%s/var/lib/pacman/local", prefix);
        count = count_pacman(path);
    }
    if (count < 0)
        count = count_pacman("/var/lib/pacman/local");

    if (count < 0)
        snprintf(out, n, "?");
    else
        snprintf(out, n, "%ld", count);
}

// Print a size given in KiB as MiB, or as GiB from 1 GiB up
static void format_kib(unsigned long long kib, char *out, size_t n)
{
    if (kib >= 1048576ULL) {
        unsigned long long tenths = kib * 10 / 1048576ULL;
        snprintf(out, n, "%llu.%llu GiB", tenths / 10, tenths % 10);
    } else {
        snprintf(out, n, "%llu MiB", kib / 1024);
    }
}

// Read used and total memory from /proc/meminfo
static void get_memory(char *out, size_t n)
{
    unsigned long long total = 0, avail = 0, memfree = 0;
    char line[128], used_str[32], total_str[32];
    struct sysinfo si;
    FILE *f = fopen("/proc/meminfo", "r");

    if (f) {
        while (fgets(line, sizeof line, f)) {
            if (strncmp(line, "MemTotal:", 9) == 0)
                total = strtoull(line + 9, NULL, 10);
            else if (strncmp(line, "MemAvailable:", 13) == 0)
                avail = strtoull(line + 13, NULL, 10);
            else if (strncmp(line, "MemFree:", 8) == 0)
                memfree = strtoull(line + 8, NULL, 10);
            if (total && avail && memfree)
                break;
        }
        fclose(f);
    }
    // Old kernels have no MemAvailable
    if (avail == 0)
        avail = memfree;

    // Fall back to sysinfo when /proc is blocked
    if (total == 0 && sysinfo(&si) == 0) {
        unsigned long long unit = si.mem_unit ? si.mem_unit : 1;
        total = (unsigned long long)si.totalram * unit / 1024;
        avail = (unsigned long long)si.freeram * unit / 1024;
    }

    if (total == 0 || avail > total) {
        snprintf(out, n, "? / ?");
        return;
    }
    format_kib(total - avail, used_str, sizeof used_str);
    format_kib(total, total_str, sizeof total_str);
    snprintf(out, n, "%s / %s", used_str, total_str);
}

static void get_time_str(const char *fmt, char *out, size_t n)
{
    time_t now = time(NULL);
    struct tm tm;

    tzset();
    if (!localtime_r(&now, &tm) || strftime(out, n, fmt, &tm) == 0)
        snprintf(out, n, "unknown");
}

static char *row_add(struct rows *r, const char *label)
{
    r->label[r->n] = label;
    return r->value[r->n++];
}

static void print_palette(int indent)
{
    for (int start = 0; start < 16; start += 8) {
        printf("%*s", indent, "");
        for (int i = start; i < start + 8; i++)
            printf("\033[48;5;%dm  \033[0m", i);
        putchar('\n');
    }
}

static void print_title(const char *user, const char *host)
{
    printf("%s%s@%s%s\n", heading, user, host, reset);
}

static void print_row(const char *label, const char *value)
{
    printf("%s%-*s%s%s\n", heading, LABEL_WIDTH, label, reset, value);
}

int main(int argc, char **argv)
{
    static const struct option longopts[] = {
        {"clear",     no_argument,       NULL, 'c'},
        {"palette",   no_argument,       NULL, 'p'},
        {"banner",    required_argument, NULL, 'b'},
        {"date",      no_argument,       NULL, 'd'},
        {"datetime",  no_argument,       NULL, 'd'},
        {"time",      no_argument,       NULL, 't'},
        {"all",       no_argument,       NULL, 'a'},
        {"color",     required_argument, NULL, 'C'},
        {"art-color", no_argument,       NULL, 'A'},
        {"version",   no_argument,       NULL, 'v'},
        {"help",      no_argument,       NULL, 'h'},
        {NULL, 0, NULL, 0},
    };
    static char outbuf[8192];
    struct options opt = {0};
    struct utsname un;
    struct rows rows = {0};
    char user[64], host[64], names[128];
    char seq[64] = "";
    size_t width = 0;
    int stacked, c;

    opt.banner = &banners[0];

    if (colors_enabled()) {
        bold = "\033[1m";
        underline = "\033[4m";
        reset = "\033[0m";
    }

    opterr = 0;
    while ((c = getopt_long(argc, argv, ":cpb:dtaC:Avh", longopts, NULL)) != -1) {
        switch (c) {
        case 'c': opt.clear = 1; break;
        case 'p': opt.palette = 1; break;
        case 'd': opt.date = 1; break;
        case 't': opt.time = 1; break;
        case 'a': opt.date = opt.time = opt.palette = 1; break;
        case 'A': opt.art_color = 1; break;
        case 'C': opt.color = optarg; break;
        case 'b':
            opt.banner = find_banner(optarg);
            if (!opt.banner) {
                banner_names(names, sizeof names);
                die("unknown banner '%s' (available: %s).", optarg, names);
            }
            break;
        case 'v':
            printf("tfetch %s\n", TFETCH_VERSION);
            return 0;
        case 'h':
            usage(stdout);
            return 0;
        case ':':
            die("option '%s' requires a value.", argv[optind - 1]);
        default:
            if (optopt) {
                char what[3] = {'-', (char)optopt, '\0'};
                unknown_option(what);
            }
            unknown_option(argv[optind - 1]);
        }
    }
    if (optind < argc)
        unknown_option(argv[optind]);

    // Build the label style and the optional banner style
    if (opt.color) {
        if (parse_color(opt.color, seq, sizeof seq) != 0)
            die("invalid color '%s' (use 0-255 or an SGR sequence like 1;31).",
                opt.color);
    } else if (opt.art_color) {
        die("option '-A' needs a color from -C.");
    }
    if (*bold && seq[0]) {
        snprintf(heading, sizeof heading, "%s\033[%sm", bold, seq);
        if (opt.art_color)
            snprintf(art_style, sizeof art_style, "\033[%sm", seq);
    } else {
        snprintf(heading, sizeof heading, "%s", bold);
    }

    if (uname(&un) != 0)
        memset(&un, 0, sizeof un);
    get_user(user, sizeof user);
    get_host(host, sizeof host);

    snprintf(row_add(&rows, "os"), VALUE_LEN, "%s", un.sysname[0] ? get_os(&un) : "unknown");
    snprintf(row_add(&rows, "host"), VALUE_LEN, "%s", un.machine[0] ? un.machine : "unknown");
    get_kernel(&un, row_add(&rows, "kernel"), VALUE_LEN);
    get_uptime(row_add(&rows, "uptime"), VALUE_LEN);
    get_pkgs(row_add(&rows, "pkgs"), VALUE_LEN);
    get_memory(row_add(&rows, "memory"), VALUE_LEN);
    if (opt.date)
        get_time_str("%a, %b %d, %Y", row_add(&rows, "date"), VALUE_LEN);
    if (opt.time)
        get_time_str("%H:%M:%S", row_add(&rows, "time"), VALUE_LEN);

    stacked = !banner_is_valid(opt.banner, &width);
    if (stacked)
        width = 0;

    // One write for the whole output
    setvbuf(stdout, outbuf, _IOFBF, sizeof outbuf);

    // Clear only after all arguments are validated
    if (opt.clear && isatty(STDOUT_FILENO))
        fputs("\033[H\033[2J\033[3J", stdout);

    putchar('\n');
    if (stacked) {
        // Banner in full on top, info below it
        for (size_t i = 0; i < opt.banner->count; i++)
            printf("%s%s%s\n", art_style, opt.banner->lines[i], reset);
        putchar('\n');
        print_title(user, host);
        for (int i = 0; i < rows.n; i++)
            print_row(rows.label[i], rows.value[i]);
    } else {
        // Banner beside the info, extra rows get blank padding
        printf("%s%s%s", art_style, opt.banner->lines[0], reset);
        print_title(user, host);
        for (int i = 0; i < rows.n; i++) {
            if ((size_t)i + 1 < opt.banner->count)
                printf("%s%s%s", art_style, opt.banner->lines[i + 1], reset);
            else
                printf("%*s", (int)width, "");
            print_row(rows.label[i], rows.value[i]);
        }
    }

    if (opt.palette) {
        putchar('\n');
        print_palette((int)width);
    }
    putchar('\n');

    return fflush(stdout) == 0 ? 0 : 1;
}
