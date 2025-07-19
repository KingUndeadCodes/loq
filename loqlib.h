#ifndef __LOQLIB_H__
#define __LOQLIB_H__

#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

int inputInteger(const char* prompt);
char* safe_strcat(char* dest, const char* src);
char* unescape_string(const char* src);

#endif