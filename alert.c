/*
 * alert.c - Send alert JSON to MS Teams PowerAutomate channel via webhook
 * Based on alert.sh, ENVIRONMENT-driven version (no TIER logic)
 * To compile we need to install "libcurl-devel" package on EL9
 * Compile as: gcc -o alert alert.c -lcurl
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <curl/curl.h>
#include <sys/utsname.h>
#include <time.h>
#include <sys/stat.h>

#define CONFIG_DEFAULT "/etc/alert.conf"
#define IMAGE_URL_DEFAULT "https://www.energise.co.nz/wp-content/uploads/2016/04/Prove-you-are-not-a-robot-and-digitalise-books-and-refine-maps.jpg"
#define VERSION "1.0"
#define PROGNAME "alert"
#define TIER_FILE "/etc/tier"
#define OHAI_BIN "/bin/ohai"

// Helper function to trim newline and trailing spaces
void trim_newline(char *str) {
    size_t len = strlen(str);
    while (len > 0 && (str[len-1] == '\n' || str[len-1] == ' ')) {
        str[len-1] = '\0';
        len--;
    }
}

// Read a variable from config file (simple VAR=VALUE, no spaces)
int read_config_value(const char *config, const char *var, char *out, size_t outsz) {
    FILE *f = fopen(config, "r");
    if (!f) return 0;
    char buf[1024];
    int found = 0;
    while (fgets(buf, sizeof(buf), f)) {
        // Skip comments and lines without '='
        if (buf[0] == '#' || strchr(buf, '=') == NULL) continue;
        if (strncmp(buf, var, strlen(var)) == 0 && buf[strlen(var)] == '=') {
            // Remove any quotes
            char *val = buf + strlen(var) + 1;
            trim_newline(val);
            if (val[0] == '"' && val[strlen(val)-1] == '"') {
                val[strlen(val)-1] = '\0';
                val++;
            }
            strncpy(out, val, outsz - 1);
            out[outsz-1] = '\0';
            found = 1;
            break;
        }
    }
    fclose(f);
    return found;
}

// Try to read environment from /etc/tier, returns 1 if successful
int read_environment_file(char *env, size_t envsz) {
    FILE *f = fopen(TIER_FILE, "r");
    if (!f) return 0;
    if (fgets(env, envsz, f)) {
        trim_newline(env);
        fclose(f);
        return 1;
    }
    fclose(f);
    return 0;
}

// Try to read environment from ohai output
int read_environment_ohai(char *env, size_t envsz) {
    struct stat st;
    if (stat(OHAI_BIN, &st) != 0 || !(st.st_mode & S_IXUSR)) return 0;
    const char *cmd = OHAI_BIN " | grep -i scm_appbranch | cut -d\\\" -f4";
    FILE *fp = popen(cmd, "r");
    if (!fp) return 0;
    if (fgets(env, envsz, fp)) {
        trim_newline(env);
        pclose(fp);
        if (env[0] == '\0') return 0;
        return 1;
    }
    pclose(fp);
    return 0;
}

// Read body from file or stdin
char* read_body(const char *file) {
    FILE *f = stdin;
    if (file) {
        f = fopen(file, "r");
        if (!f) {
            fprintf(stderr, "Could not open body file: %s\n", file);
            exit(1);
        }
    }
    size_t sz = 4096, used = 0;
    char *body = malloc(sz);
    body[0] = 0;
    char line[1024];
    while (fgets(line, sizeof(line), f)) {
        // Prepend "- ", append "\r\r"
        size_t needed = strlen(line) + 8;
        if (used + needed > sz) {
            sz *= 2;
            body = realloc(body, sz);
        }
        trim_newline(line);
        strcat(body, "- ");
        strcat(body, line);
        strcat(body, "\\r\\r");
        used = strlen(body);
    }
    if (file) fclose(f);
    return body;
}

// Replace all double quotes with colons (like: sed 's/"/:/g')
void replace_quotes(char *s) {
    for (; *s; ++s) if (*s == '"') *s = ':';
}

// Get short hostname
void get_short_hostname(char *buf, size_t sz) {
    struct utsname uts;
    if (uname(&uts) == 0) {
        strncpy(buf, uts.nodename, sz-1);
        buf[sz-1] = 0;
        char *dot = strchr(buf, '.');
        if (dot) *dot = 0;
    } else {
        strncpy(buf, "unknown", sz-1);
        buf[sz-1] = 0;
    }
}

// Get current date as YYYY-MM-DD
void get_current_date(char *buf, size_t sz) {
    time_t t = time(NULL);
    struct tm tm = *localtime(&t);
    snprintf(buf, sz, "%04d-%02d-%02d", tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday);
}

// Print usage
void show_usage(int code) {
    printf("Usage: alert [[-c|--config] configuration-file] [[-e|--environment] environment] [[-t|--title] \"TITLE line\"] [[-b|--body] \"body text\"] [[-f|--file] file for body text] [[-i|--image \"URL\"]] [[-w|--webhook \"URL\"]] [[-h|--help]] [[-v|--version]]\n");
    printf("-e, --environment environment value (overrides config ENVIRONMENT and detection)\n");
    printf("-c, --config      configuration file (optional - default %s)\n", CONFIG_DEFAULT);
    printf("-t, --title       title message (required)\n");
    printf("-b, --body        body text (optional when --file is used)\n");
    printf("-f, --file        read body text from file or stdin (required when --body is not used)\n");
    printf("-i, --image       Logo graph URL (optional)\n");
    printf("-w, --webhook     webhook URL (overrides config WEBHOOK_URL)\n");
    printf("-h, --help        show usage (optional)\n");
    printf("-v, --version     show version (optional)\n");
    printf("\nFor all options read the man page \"man alert\"\n"); 
    exit(code);
}

int main(int argc, char *argv[]) {
    char config[256] = CONFIG_DEFAULT;
    char title[1024] = "";
    char body[8192] = "";
    char *body_ptr = NULL;
    char file[256] = "";
    char image_url[1024] = IMAGE_URL_DEFAULT;
    char webhook_url[2048] = "";
    char environment[128] = "";
    int optidx = 0, c;
    int env_arg_given = 0;
    int webhook_arg_given = 0;
    int body_ptr_is_malloc = 0;

    static struct option longopts[] = {
        {"config", required_argument, 0, 'c'},
        {"environment", required_argument, 0, 'e'},
        {"title", required_argument, 0, 't'},
        {"body", required_argument, 0, 'b'},
        {"file", required_argument, 0, 'f'},
        {"image", required_argument, 0, 'i'},
        {"webhook", required_argument, 0, 'w'},
        {"help", no_argument, 0, 'h'},
        {"version", no_argument, 0, 'v'},
        {0,0,0,0}
    };

    while ((c = getopt_long(argc, argv, "c:e:t:b:f:i:w:hv", longopts, &optidx)) != -1) {
        switch (c) {
            case 'c': strncpy(config, optarg, sizeof(config)-1); break;
            case 'e': strncpy(environment, optarg, sizeof(environment)-1); env_arg_given = 1; break;
            case 't': strncpy(title, optarg, sizeof(title)-1); break;
            case 'b': strncpy(body, optarg, sizeof(body)-1); break;
            case 'f': strncpy(file, optarg, sizeof(file)-1); break;
            case 'i': strncpy(image_url, optarg, sizeof(image_url)-1); break;
            case 'w': strncpy(webhook_url, optarg, sizeof(webhook_url)-1); webhook_arg_given = 1; break;
            case 'h': show_usage(0);
            case 'v': printf("%s,v%s\n", PROGNAME, VERSION); return 0;
            default: show_usage(1);
        }
    }

    // Only require config file for WEBHOOK_URL if -w is not given
    if (!webhook_arg_given) {
        if (access(config, R_OK) != 0) {
            fprintf(stderr, "Configuration file %s not found.\n", config);
            return 1;
        }
        if (!read_config_value(config, "WEBHOOK_URL", webhook_url, sizeof(webhook_url))) {
            fprintf(stderr, "WEBHOOK_URL not found in config file.\n");
            return 1;
        }
    }

    // ENVIRONMENT: CLI > config > /etc/tier > ohai
    if (!env_arg_given) {
        if (access(config, R_OK) == 0) {
            read_config_value(config, "ENVIRONMENT", environment, sizeof(environment));
        }
        if (environment[0] == '\0') {
            // Try /etc/tier
            if (!read_environment_file(environment, sizeof(environment)) || environment[0] == '\0') {
                // Try ohai
                if (!read_environment_ohai(environment, sizeof(environment)) || environment[0] == '\0') {
                    fprintf(stderr, "ENVIRONMENT not specified (not set by -e/--environment, not in config, not in /etc/tier, not from ohai). Exiting.\n");
                    show_usage(1);
                }
            }
        }
    }

    if (title[0] == '\0') {
        fprintf(stderr, "Missing required --title argument.\n");
        return 1;
    }

    // Get body
    if (body[0] != '\0') {
        // Prepend "- "
        static char temp[8192 + 8]; // static ensures temp's lifetime is until program ends
        snprintf(temp, sizeof(temp), "- %s", body);
        body_ptr = temp;
	body_ptr_is_malloc = 0;
    } else if (file[0] != '\0') {
        body_ptr = read_body(file);
	body_ptr_is_malloc = 1;
    } else {
        printf("Reading body from stdin...\n");
        body_ptr = read_body(NULL);
	body_ptr_is_malloc = 1;
    }

    replace_quotes(body_ptr);

    // Compose header/footer using ENVIRONMENT variable
    char hostname[128], date[32];
    get_short_hostname(hostname, sizeof(hostname));
    get_current_date(date, sizeof(date));

    char header[256], bottom[256];
    snprintf(header, sizeof(header), "Alert on %s (%s)", hostname, environment);
    snprintf(bottom, sizeof(bottom), "Message generated on system %s (%s, %s)", hostname, environment, date);

    // Compose JSON payload
    char json[16384];
    snprintf(json, sizeof(json),
        "{\"type\":\"message\",\"attachments\":[{\"contentType\":\"application/vnd.microsoft.card.adaptive\",\"contentUrl\":null,\"content\":{"
        "\"$schema\":\"http://adaptivecards.io/schemas/adaptive-card.json\",\"type\":\"AdaptiveCard\",\"version\":\"1.4\","
        "\"body\":[{\"type\":\"ColumnSet\",\"columns\":[{\"type\":\"Column\",\"targetWidth\":\"atLeast:narrow\","
        "\"items\":[{\"type\":\"Image\",\"style\":\"Person\",\"url\":\"%s\",\"size\":\"Medium\"}],\"width\":\"auto\"},{\"type\":\"Column\","
        "\"spacing\":\"medium\",\"verticalContentAlignment\":\"center\",\"items\":[{\"type\":\"TextBlock\",\"text\":\"%s\","
        "\"size\":\"ExtraLarge\",\"color\": \"${color}\"}],\"width\":\"auto\"}]},{\"type\":\"TextBlock\", \"text\":\"%s\","
        "\"weight\":\"bolder\",\"size\":\"Large\"},{\"type\":\"TextBlock\",\"text\":\"%s\",\"wrap\":\"true\"},{\"type\":\"TextBlock\",\"text\":\"%s\","
        "\"wrap\":\"true\"}],\"msteams\":{\"width\":\"Full\"}}}]}",
        image_url, header, title, body_ptr, bottom
    );

    // Send webhook using libcurl
    CURL *curl = curl_easy_init();
    if (!curl) {
        fprintf(stderr, "curl initialization failed\n");
	if (body_ptr_is_malloc && body_ptr != NULL) free(body_ptr);
        return 1;
    }
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_URL, webhook_url);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
	if (body_ptr_is_malloc && body_ptr != NULL) free(body_ptr);
        return 1;
    }
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (body_ptr_is_malloc && body_ptr != NULL) free(body_ptr);
    return 0;
}
