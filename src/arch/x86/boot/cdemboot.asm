;
; cdemboot.asm
;
; CD-ROM 1.44 MB Floppy Emulation Boot sector
;
; Copyright (C) 2013 Bruno Ribeiro.
; Copyright (C) 2002 Michael Ringgaard.
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions
; are met:
;
; 1. Redistributions of source code must retain the above copyright
;    notice, this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
; 3. Neither the name of the project nor the names of its contributors
;    may be used to endorse or promote products derived from this software
;    without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
; SUCH DAMAGE.
;

OSLDRSEG    equ 0x9000
OSLDRBASE   equ (OSLDRSEG * 16)

OSLDRSTART  equ 8
OSLDRSIZE   equ 32

; The image is the first 512K of the 1.44 MB emulated floppy device. The first
; sector of the image is the boot sector.

IMGSTART    equ 1
IMGSEG      equ 0x7E0
IMGSIZE     equ (512 * 2) - 1

        ORG     0x7c00
        BITS    16
        SECTION .text

        ; Entry point for initial bootstap code
boot:
        jmp     short start
        nop
        nop

        db      'MACHINA '

ldrsize  dw     OSLDRSIZE
ldrstrt  dd     OSLDRSTART

start:
        ; Setup initial environment
        jmp     0:start1
start1:
        cli
        mov     ax, cs
        mov     ds, ax
        mov     ss, ax
        mov     sp, 0x7c00
        sti

        ; Save boot drive
        mov     [bootdrv], dl

        ; Display boot message
        mov     si, bootmsg
        call    print

readimg:
        ; Get boot drive geometry
        mov     dl, [bootdrv]
        mov     ah, 8
        xor     di, di
        mov     es, di
        int     0x13

        and     cl, 0x3F
        mov     byte [sectors], cl
        inc     dh
        mov     byte [heads], dh

        ; Load disk image from emulated floppy

loadnext:
        xor     eax, eax
        mov     ax, [sectno]        ; eax = image sector number

        mov     bx, ax
        shl     bx, 5               ; 512/16 segments per sector
        add     bx, IMGSEG
        mov     es, bx              ; es = segment for next image sector

        mov     di, IMGSIZE
        sub     di, ax              ; di = number of image sectors left to read

        mov     cx, [sectno]        ; make sure we do not cross a 64KB boundary
        and     cx, 0x7F
        neg     cx
        add     cx, 0x80
        cmp     cx, di
        jg      loadnext1
        mov     di, cx
loadnext1:
        mov     ebx, IMGSTART       ; eax = LBA of next image sector
        add     eax, ebx
        call    readsectors

        mov     ax, [sectno]        ; update next image sector to read
        add     ax, di
        mov     [sectno], ax

        cmp     ax, IMGSIZE
        jnz     loadnext

        ; Copy os loader from ram boot image
        push    ds

        mov     cx, [ldrsize]       ; cx = number of bytes to copy
        shl     cx, 9               ; convert from sectors to bytes

        mov     eax, [ldrstrt]      ; ds = loader start segment
        shl     eax, 5              ; convert from sectors to segments
        add     eax, 0x7c0
        mov     ds, ax

        mov     ax, OSLDRSEG        ; es = loader segment
        mov     es, ax

        xor     di, di
        xor     si, si

        cld                         ; copy os loader from boot image
        rep movsb
        pop     ds

        ; Call real mode entry point in os loader
        mov     ax, OSLDRSEG
        mov     ds, ax
        add     ax, [0x16]          ; "cs" from "kernel-loader.bin" PE Header
        push    ax
        push    word [0x14]         ; "ip" from "kernel-loader.bin" PE Header (should go to stub)

        mov     dl, 0xFD            ; boot drive (0xFD for CD emulation)
        mov     ebx, 0x7C00         ; RAM disk image
        retf

failed:
        ; Display boot message
        mov     si, nfoundmsg
        call    print
surrender:
        cli
        hlt
        jmp surrender

        ; Read sectors from boot drive
        ; input:
        ;   eax = LBA
        ;   di = maximum sector count
        ;   es = segment for buffer
        ; output:
        ;   di = sectors read
readsectors:

        ; Convert LBA to CHS
        cdq                         ; edx = 0
        movzx   ebx, word [sectors]
        div     ebx                 ; eax = track, edx = sector - 1
        mov     cx, dx              ; cl = sector - 1, ch = 0
        inc     cx                  ; cl = sector number
        xor     dx, dx
        mov     bl, [heads]
        div     ebx

        mov     dh, dl              ; head
        mov     dl, [bootdrv]       ; boot drive
        xchg    ch, al              ; ch = low 8 bits of cylinder number, al = 0
        shr     ax, 2               ; al[6:7] = high two bits of cylinder, ah = 0
        or      cl, al              ; cx = cylinder and sector

        ; Determine number of sectors to read
        mov     al, cl
        mov     ah, 0
        add     ax, di              ; ax = last sector to xfer
        cmp     ax, [sectors]
        jbe     readall

        mov     ax, [sectors]       ; read to end of track
        inc     ax
        sub     al, cl
        push    ax
        jmp     read

readall:
        mov     ax, di              ; we can read all sectors
        push    ax
        jmp     read

readagain:
        pusha
        mov     al, '#'             ; print # to mark errror
        call    printchar
        mov     ax, 0               ; reset disk system
        mov     dx, 0
        int     0x13
        popa

read:
        mov     ah, 2               ; read sector using bios
        xor     bx, bx
        int     0x13
        jc      readagain

        pop     di

        ret

        ; Print string to console
        ; si = ptr to first character of a null terminated string
print:
        push    ax
        cld
nextchar:
        mov     al, [si]
        cmp     al, 0
        je      printdone
        call    printchar
        inc     si
        jmp     nextchar
printdone:
        pop     ax
        ret

        ; Print a single character to the console
        ; al = character to be printed
printchar:
        mov     ah, 0x0e
        int     0x10
        ret

        ; Variables

sectno  dw      0
sectors dw      0
heads   dw      0
bootdrv db      0

        ; Message strings
bootmsg:
        db      'Loading boot image from CD-ROM... ', 0
foundmsg:
        db      'OS loader found...', 0
nfoundmsg:
        db      'OS loader not found...', 0

        ; Boot signature
        times   510-($-$$) db 0
        dw      0xAA55
