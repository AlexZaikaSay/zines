; OSD startup: reset entry, C runtime init, then main().
; Replaces the cc65 `none` target crt0, which has no reset vector.

        .export   _init, _exit
        .export   __STARTUP__ : absolute = 1    ; mark as startup code
        .import   _main, zerobss, initlib, donelib
        .import   __RAM_START__, __RAM_SIZE__

        .include  "zeropage.inc"

        .segment  "STARTUP"

_init:  sei
        cld
        ldx     #$FF                ; hardware stack
        txs

        ; C software stack grows down from the top of RAM
        lda     #<(__RAM_START__ + __RAM_SIZE__)
        sta     sp
        lda     #>(__RAM_START__ + __RAM_SIZE__)
        sta     sp+1

        jsr     zerobss
        jsr     initlib
        jsr     _main

_exit:  jsr     donelib
@halt:  jmp     @halt

nmi:
irq:    rti

        .segment  "VECTORS"

        .word   nmi
        .word   _init
        .word   irq
