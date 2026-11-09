; ld_stream: write count bytes from src to the cartridge loader data port.
;
;   void __fastcall__ ld_stream(const uint8_t *src, uint16_t count);
;
; Used to forward SD sector data (SD_BUF) straight into the NES memories:
; 14 CPU cycles per byte, against ~170 for a memcpy into a buffer plus a C loop.

        .export _ld_stream
        .import popax
        .importzp ptr1, tmp1, tmp2

LD_DATA = $4034                 ; OSD_ADDR_LOADER + LD_REG_DATA (zines_pkg.sv)

_ld_stream:
        sta tmp1                ; count low: bytes after the full pages
        stx tmp2                ; count high: full 256-byte pages
        jsr popax
        sta ptr1
        stx ptr1+1
        ldy #0
        ldx tmp2
        beq rest
page:   lda (ptr1),y
        sta LD_DATA
        iny
        bne page
        inc ptr1+1
        dex
        bne page
rest:   ldx tmp1
        beq done
tail:   lda (ptr1),y
        sta LD_DATA
        iny
        dex
        bne tail
done:   rts
