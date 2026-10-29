/* Petit FatFs low level disk I/O for the OSD SD card (stub).
 * Based on the Petit FatFs skeleton (C)ChaN, 2014.
 * TODO: implement over the OSD SD card interface once its registers exist. */

#include "diskio.h"
#include "screen.h"
#include "memio.h"
#include <string.h>

static uint8_t do_cmd(uint8_t cmd)
{
    SD_CMD = cmd;
    while (SD_STATUS & SD_BUSY);
    return SD_STATUS;
}

/* Initialize the SD card */
DSTATUS disk_initialize(void)
{
    uint8_t res = do_cmd(SD_CMD_INIT);

    if ((res & (SD_READY | SD_ERROR)) == SD_READY)
    {
        return 0;
    }
    if (SD_ERRCODE == SD_ERR_NO_CARD)
    {
        return STA_NOINIT | STA_NODISK;
    }
    return STA_NOINIT;
}

/* Sector currently in SD_BUF; Petit FatFs reads many small pieces of the
 * same sector, so it is fetched from the card only when it changes */
static DWORD buf_sector = 0xFFFFFFFF;

/* Read `count` bytes at `offset` within `sector` into `buff` */
DRESULT disk_readp(BYTE *buff, DWORD sector, UINT offset, UINT count)
{
    if (!(SD_STATUS & SD_READY))
        return RES_NOTRDY;

    if (sector != buf_sector)
    {
        SD_LBA0 = (uint8_t)sector;
        SD_LBA1 = (uint8_t)(sector >> 8);
        SD_LBA2 = (uint8_t)(sector >> 16);
        SD_LBA3 = (uint8_t)(sector >> 24);
        if (do_cmd(SD_CMD_READ) & SD_ERROR)
        {
            buf_sector = 0xFFFFFFFF;
            return RES_ERROR;
        }
        buf_sector = sector;
    }

    /* buff == NULL: data forwarding is not used, nothing to copy */
    /* cc65's memcpy is hand-written assembly, much faster than a C loop.
     * SD_BUF is plain RAM while the card is idle, so dropping volatile
     * for the copy is safe. */
    if (buff)
    {
        memcpy(buff, (const BYTE *)SD_BUF + offset, count);
    }
    return RES_OK;
}

/* buff == NULL: sc != 0 starts writing sector sc, sc == 0 finishes it;
 * otherwise sends sc bytes from buff */
DRESULT disk_writep(const BYTE *buff, DWORD sc)
{
    (void)buff;
    (void)sc;
    return RES_NOTRDY;
}
