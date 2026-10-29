
#include "memio.h"
#include "pff.h"
#include "screen.h"
#include <string.h>


struct header {
    char magic[4];
    uint8_t prg_banks;
    uint8_t chr_banks;
    uint8_t flags6;
    uint8_t flags7;
    uint8_t prg_ram_banks;
    uint8_t flags9;
    uint8_t flags10;
    uint8_t reserved[5];
};

/* Append s to path at *len; keeps room for the terminator.
 * Returns 0 if s does not fit (path holds what fitted). */
static uint8_t path_append(char *path, uint8_t size, uint8_t *len, const char *s)
{
    while (*s)
    {
        if (*len >= size - 1)
        {
            path[*len] = '\0';
            return 0;
        }
        path[(*len)++] = *s++;
    }
    path[*len] = '\0';
    return 1;
}

/* path = folder "/" file, always '\0'-terminated.
 * Returns 0 if the result does not fit into size bytes. */
static uint8_t combine_path(char *path, uint8_t size, const char *folder, const char *file)
{
    uint8_t len = 0;

    if (size == 0)
    {
        return 0;
    }
    path[0] = '\0';
    return path_append(path, size, &len, folder) &&
           path_append(path, size, &len, "/") &&
           path_append(path, size, &len, file);
}

static uint8_t load_rom(const char* folder, const char* rom_file)
{
    FRESULT res;
    char path[32];
    static uint8_t data[512];

    struct header hdr;
    uint8_t rom_secors_count;
    uint8_t chrom_secors_count;
    uint8_t sector_index;
    UINT br;

    uint8_t mapper;
    uint8_t vertical;
    uint8_t chr_is_ram;
    uint8_t flags;

    if (!combine_path(path, sizeof(path), folder, rom_file))
    {
        return 5;   /* path too long */
    }

    // print_status(path);
    // for(;;);
    res = pf_open(path);
    if (res != FR_OK)
    {
        return 1;
    }
    
    res = pf_read(&hdr, sizeof(hdr), &br);
    if (res != FR_OK)
    {
        return 2;
    }
    
    if (hdr.magic[0] != 'N' || 
        hdr.magic[1] != 'E' || 
        hdr.magic[2] != 'S' || 
        hdr.magic[3] != 0x1A)
    {
        return 3;
    }

    // print_status(hdr.magic);
    // for(;;);
    mapper = (hdr.flags6 >> 4) | (hdr.flags7 & 0xf0);
    vertical = hdr.flags6 & 0x01;
    chr_is_ram = hdr.chr_banks == 0;

    rom_secors_count = hdr.prg_banks << (14 - 9);
    chrom_secors_count = hdr.chr_banks << (13 - 9);

    // skip trainer if present
    if (hdr.flags6 & 0x04)
    {
        // empty read 512 bytes to skip trainer
        res = pf_read(data, sizeof(data), &br);
        if (res != FR_OK)
        {
            return 4;
        }
    }

    // set mapper and mirroring
    // TODO: handle another mappers
    if (mapper != 0)
    {
        return 6;   /* unsupported mapper */
    }
    CART_MAPPER = mapper;
    // TODO: handle trainer if present
    flags = vertical ? CART_VERT_MIRROR : 0;
    if (chr_is_ram)
    {
        flags |= CART_CHR_RAM;
    }
    CART_FLAGS = flags;
    CART_PRG_16K = hdr.prg_banks;
    CART_CHR_8K = hdr.chr_banks;
   
    // read rom
    LD_SEL = LD_PRG_ROM;
    LD_ADDR0 = 0;
    LD_ADDR1 = 0;
    LD_ADDR2 = 0;

    print_status("Loading ROM.. ");
    
    for (sector_index = 0; sector_index < rom_secors_count; sector_index++)
    {
        uint16_t i;
        res = pf_read(data, sizeof(data), &br);
        if (res != FR_OK)
        {
            return 4;
        }
        //print_status_arg("ROM block ", data[0]);
        for (i = 0; i < sizeof(data); ++i)
        {
            LD_DATA = data[i];
        }
    }
    print_status("Loading CHROM.. ");

    // read chr
    LD_SEL = LD_CHR;
    LD_ADDR0 = 0;
    LD_ADDR1 = 0;
    LD_ADDR2 = 0;
    for (sector_index = 0; sector_index < chrom_secors_count; sector_index++)
    {
        uint16_t i;
        res = pf_read(data, sizeof(data), &br);
        if (res != FR_OK)
        {
            return 4;
        }
        for (i = 0; i < sizeof(data); ++i)
        {
            LD_DATA = data[i];
        }
    }

    print_status("Loading NES done");
    // TODO: handle chram if necessary

    return 0;
}

uint8_t load_nes(const char* folder, const char* rom_file, const char* /*save_file*/)
{
    // TODO: handle save_file
    return  load_rom(folder, rom_file);
}
