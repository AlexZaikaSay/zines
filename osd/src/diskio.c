/* Petit FatFs low level disk I/O for the OSD SD card (stub).
 * Based on the Petit FatFs skeleton (C)ChaN, 2014.
 * TODO: implement over the OSD SD card interface once its registers exist. */

#include "diskio.h"
#include "screen.h"
#include "memio.h"


uint8_t getDiskStatus(void)
{
    return SD_STATUS;
}

/* Initialize the SD card */
DSTATUS disk_initialize(void)
{
    printstatus("DISK INIT");

    return STA_NOINIT;
}

/* Read `count` bytes at `offset` within `sector` into `buff` */
DRESULT disk_readp(BYTE *buff, DWORD sector, UINT offset, UINT count)
{
    (void)buff;
    (void)sector;
    (void)offset;
    (void)count;
    return RES_NOTRDY;
}

/* buff == NULL: sc != 0 starts writing sector sc, sc == 0 finishes it;
 * otherwise sends sc bytes from buff */
DRESULT disk_writep(const BYTE *buff, DWORD sc)
{
    (void)buff;
    (void)sc;
    return RES_NOTRDY;
}
