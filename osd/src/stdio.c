
#include <stdint.h>

uint8_t strlen(const char *s)
{
    uint8_t len = 0;
    while (s[len] != '\0')
    {
        len++;
    }
    return len;
}


uint8_t strncpy(char *dest, const char *src, uint8_t n)
{
    uint8_t i = 0;
    while (src[i] != '\0' && i < n)
    {
        dest[i] = src[i];
        i++;
    }
    if (i < n)
        dest[i] = '\0';
    return i;
}