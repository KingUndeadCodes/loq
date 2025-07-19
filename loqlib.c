#include "loqlib.h"

int inputInteger(const char* prompt) {
    if (prompt != NULL) printf("%s", prompt);
    int integer;
    scanf("%d", &integer);
    return integer;
};

char* safe_strcat(char* dest, const char* src) {
    if (dest == NULL) {
        dest = (char*)malloc(strlen(src) + 1);
        strcpy(dest, src);
    } else {
        size_t dest_len = strlen(dest);
        size_t src_len = strlen(src);
        dest = (char*)realloc(dest, dest_len + src_len + 1);
        strcat(dest, src);
    }
    return dest;
}

char* unescape_string(const char* src) {
    size_t len = strlen(src);
    char* dest = (char*)malloc(len); // Result will never be longer than src
    char* d = dest;
    const char* s = src + 1; // Skip the opening quote

    while (*s && s < src + len - 1) { // Stop before the closing quote
        if (*s == '\\') {
            s++;
            switch (*s) {
                case 'n': *d++ = '\n'; break;
                case 't': *d++ = '\t'; break;
                case 'r': *d++ = '\r'; break;
                case '\\': *d++ = '\\'; break;
                case '"': *d++ = '"'; break;
                case '0': *d++ = '\0'; break;
                // Add more escape sequences as needed
                default: *d++ = *s; break;
            }
            s++;
        } else {
            *d++ = *s++;
        }
    }
    *d = '\0';
    return dest;
}