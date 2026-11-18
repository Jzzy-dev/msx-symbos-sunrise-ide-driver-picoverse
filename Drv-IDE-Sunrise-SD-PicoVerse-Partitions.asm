;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@            S y m b O S   -   M S X   D e v i c e   D r i v e r             @
;@             SUNRISE IDE INTERFACE  +  Nextor 3 logical partitions          @
;@                                                                            @
;@             (c) 2006-2007 by Prodatron / SymbiosiS (Jorn Mika)             @
;@      EBR extension: SeD_NcL (msx.org, Nov 2026) - "Sunrise EBR Test v2"    @
;@      Source reconstructed from the binary; PICOVERSE option added          @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;
; Build (sjasmplus):
;   original SeD_NcL driver (byte-identical to -IDSUNRI.DRV v2):
;       sjasmplus --raw=-IDSUNRI.DRV Drv-IDE-Sunrise-SD-PicoVerse-Partitions.asm
;   PicoVerse 2350 variant:
;       sjasmplus -DPICOVERSE --raw=-IDEUPPV.DRV Drv-IDE-Sunrise-SD-PicoVerse-Partitions.asm
;
; PICOVERSE: the PicoVerse 2350 Sunrise IDE emulation does not implement the
; ATA command #F8 (READ NATIVE MAX ADDRESS) that IDEACT uses as an "LBA
; supported?" probe, so activating a drive fails. The PicoVerse build skips
; sending that command (same change as JZZY's 2025 PicoVerse driver); IDEERR
; then just checks the status after selecting the drive.
;
; Partition mapping (sub-field bits 0-3 in the device record):
;   0      -> whole disk, no partition table
;   1      -> MBR entry 1 (primary)
;   2..4   -> if the MBR has a Nextor-style layout (entry 2 = extended
;             #05/#0F, entries 3+4 empty, #55AA signature): logical
;             volume 1..3 inside the extended partition (EBR chain).
;             Otherwise MBR entry 2..4 as before.
;   5..15  -> MBR entry n (original behaviour, not meaningful)

;--- MAIN ROUTINES ------------------------------------------------------------
;### IDEOUT -> write sectors (512b)
;### IDEINP -> read sectors (512b)
;### IDEACT -> read and init media (only hardware- and partiondata, no filesystem)

;--- WORK ROUTINES ------------------------------------------------------------
;### IDECOP -> wait for data request and copy 512byte
;### IDEERR -> check error state

;--- SUB ROUTINES -------------------------------------------------------------
;### IDESEC -> converts logical sector number into physical sector number
;### IDEADR -> set sector address
;### IDESHW -> maps IDE memory  to #4000-#7FFF
;### IDERDY -> wait for ready for next command
;### IDEDRQ -> wait for data request

;--- EBR EXTENSION ------------------------------------------------------------
;### EBRSAV -> remember device, IX=0 (hook replacing "ld ix,0" in IDEACT)
;### EBRCHK -> Nextor layout? then walk EBR chain (hook replacing
;###           "ld ix,(stobufx)" in IDEACT)


;--- SymbOS constants (from SymbOS-File-Const.asm) ----------------------------
stoerrpno   equ 4       ;Partition not found
stoerrptp   equ 5       ;Media or partition not supported
stoerrabo   equ 8       ;Aborted during media access
stoerrdvp   equ 30      ;Device not supported
stotypoky   equ 1       ;Device ready
stomedhdi   equ 16      ;IDE Device
stodattyp   equ 1
stodatbeg   equ 12      ;first logical sector (32bit) where partition starts
stodatsub   equ 26      ;bit0-3 partition, bit4-7 channel
stodatflg   equ 31      ;bit0=LBA mode


;==============================================================================
;### HEADER ###################################################################
;==============================================================================

        device none
        org #1000-32
        relocate_start

        db "SMD3"               ;ID
        dw ideend-idejmp        ;code length
        dw relocate_count       ;number of relocate table entries
        ds 8                    ;*reserved*
        db 2,1,1                ;Version Minor, Version Major, Type (1=IDE)
        db "Sunrise IDE  "      ;comment (13 chars)

idejmp  dw ideinp,ideout,ideact,idemof
idemof  ret:dw 0
        db 32*1+6       ;bit[0-4]=driver ID (6=sunrise), bit[5-7]=storage type (1=IDE)
        ds 4
ideslt  ds 3

stobnkx equ #815A       ;memory mapping, when low level routines read/write sector data
bnkmonx equ #8112       ;set special memory mapping during mass storage access
bnkmofx equ #8115       ;reset special memory mapping during mass storage access
bnkdofx equ #8136       ;hide mass storage device rom
stoadrx equ #8157       ;get device data record
stobufx equ #815B       ;address of 512byte buffer

;IDE registers (Sunrise memory mapped, page 1)
ideprtdat   equ #7c00       ;data
ideprterr   equ #7e01       ;error
ideprtscn   equ #7e02       ;sector count
ideprtsec   equ #7e03       ;sector number
ideprttrk   equ #7e04       ;track low/high (16bit)
ideprtsdh   equ #7e06       ;sdh
ideprtsta   equ #7e07       ;status(r)/command(w)

;IDE commands
ide_c_rdsec     equ #20     ;read sector(s)
ide_c_wrsec     equ #30     ;write sector(s)
ide_c_lbadat    equ #f8     ;READ NATIVE MAX ADDRESS (used as LBA probe)

ideparadr   equ #1be        ;partition table inside MBR/EBR
idepartyp   equ #04
ideparbeg   equ #08
ideparlen   equ #0c

idepartok   db #01,#11, #04,#06,#0e,#14,#16,#1e, #0b,#0c,#1b,#1c
idepartan   equ 12


;==============================================================================
;### MAIN ROUTINES ############################################################
;==============================================================================

;### IDEINP -> read sectors (512b)
;### Input      A=device (0-7), IY,IX=logical sector number, B=number of sectors, DE=address, (stobnkx)=banking config
;### Output     CF=0 -> ok, CF=1 -> A=error code
ideinp  ld c,1
ideinp0 push de                 ;(C=0 -> absolute LBA, no partition offset)
        call idesec             ;HL=track, E=sector, D=SDH, B=number
        push bc
        call ideadr
        jr c,ideinp3
        ld a,ide_c_rdsec        ;send read command
        ld (ideprtsta),a
        pop bc
        pop hl
        ld a,(stobnkx)
        call bnkmonx
        ld (iderdy4+1),a
        ld c,a
ideinp1 push bc
        ex de,hl
        ld hl,ideprtdat
        call idecop
        ex de,hl
        pop bc
        jr c,ideinp2
        call ideerr
        jr c,ideinp2
        call bnkmofx
        call bnkdofx            ;allow irqs between sectors
        call ideshw
        ld a,c
        out (#fc),a
        djnz ideinp1
ideinp2 push af
        call bnkmofx
        call bnkdofx
        pop af
        ret
ideinp3 push af
        call bnkdofx
        pop af
        pop hl
        pop hl
        ret

;### IDEOUT -> write sectors (512b)
ideout  ld c,1
        push de
        call idesec
        push bc
        call ideadr
        jr c,ideinp3
        ld a,ide_c_wrsec        ;send write command
        ld (ideprtsta),a
        pop bc
        pop hl
        ld a,(stobnkx)
        call bnkmonx
        ld (iderdy4+1),a
        ld c,a
ideout1 push bc
        ld de,ideprtdat
        call idecop
        call nc,iderdy
        pop bc
        jr c,ideinp2
        call ideerr
        jr c,ideinp2
        call bnkmofx
        call bnkdofx
        call ideshw
        ld a,c
        out (#fc),a
        djnz ideout1
        jr ideinp2

;### IDEACT -> read and init media (only hardware- and partiondata, no filesystem)
;### Input      A=device (0-7)
;### Output     CF=0 -> ok, CF=1 -> A=error code
ideactd dw 0                    ;address of device data record
ideact  push af
        call stoadrx
        ld (ideactd),hl
        push hl
        ld bc,stodatsub
        add hl,bc
        ld a,(hl)               ;bit4 = master/slave
        and #10
        push af
        or #40
        ld hl,0
        ld e,l
        ld b,l
        ld d,a
        call ideadr             ;select drive, LBA 0
        jp c,ideact8
    IFNDEF PICOVERSE
        ld a,ide_c_lbadat       ;LBA probe - not supported by PicoVerse
        ld (ideprtsta),a
    ENDIF
        call ideerr
        call bnkdofx
        pop de
        pop hl
        ld a,stoerrdvp
        jp c,ideact9            ;no -> error
        ld bc,stodatflg
        add hl,bc
        set 0,(hl)              ;LBA mode
        pop af                  ;A=device
        call ebrsav : nop       ;[EBR] was: ld ix,0
        ld iy,0
        ld b,1
        ld de,(stobufx)
        ld c,0
        call ideinp0            ;read MBR
        ret c
        ld hl,(ideactd)
        ld e,l
        ld d,h                  ;DE=device data record
        ld bc,stodatsub
        add hl,bc
        ld a,(hl)
        and #f                  ;A=partition number
        ld c,a
        ld b,a
        ld iy,0
        jr z,ideact5            ;0 -> whole disk (IX=IY=0 -> BC=0)
        jp ebrchk : db 0        ;[EBR] was: ld ix,(stobufx)
ideact0 ld bc,ideparadr
ideact1 add ix,bc               ;IX points to partition table entry
        ld bc,16
        dec a
        jr nz,ideact1
        ld a,(ix+idepartyp)
        ld b,a
        or a
        ld a,stoerrpno          ;partition does not exist
        scf
        ret z
        ld a,b
        ld hl,idepartok
        ld b,idepartan
ideact3 cp (hl)
        jr z,ideact4
        inc hl
        djnz ideact3
        ld a,stoerrptp          ;partition type not supported
        scf
        ret
ideact4 ld c,(ix+ideparbeg+2)
        ld b,(ix+ideparbeg+3)
        ld iyl,c
        ld iyh,b
        ld c,(ix+ideparbeg+0)
        ld b,(ix+ideparbeg+1)
ideact5 ex de,hl                ;HL=device data record, IY:BC=start sector
        ld (hl),stotypoky
        inc hl
        ld (hl),stomedhdi
        ld de,stodatbeg-stodattyp
        add hl,de
        ld (hl),c:inc hl
        ld (hl),b:inc hl
        ld a,iyl:ld (hl),a:inc hl
        ld a,iyh:ld (hl),a
        xor a
        ret
ideact8 push af
        call bnkdofx
        pop af
        pop hl
        pop hl
ideact9 pop hl
        ret


;==============================================================================
;### WORK ROUTINES ############################################################
;==============================================================================

;### IDECOP -> wait for data request und transfer 512 bytes
idecop  call idedrq
        ret c
        ld a,512/64
idecop1 ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi
        ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi
        ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi
        ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi:ldi
        dec a
        jp nz,idecop1
        ret

;### IDEERR -> check error state
;### Output     CF=0 -> ok, CF=1 -> error (A=6 r/w, 7 positioning, 8 abort, 9 unknown)
ideerr  ld a,(ideprtsta)
        and 1+4
        ret z
        cp 4
        ld a,1
        ret z
        ld a,(ideprterr)
        ld e,a
        ld d,6
        and 128+64
        jr nz,ideerr1
        ld a,e
        inc d
        and 2+16
        jr nz,ideerr1
        inc d
        bit 2,e
        jr nz,ideerr1
        inc d
ideerr1 ld a,d
        scf
        ret


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

;### IDESEC -> converts logical sector number into physical sector number
;### Input      A=device, IY,IX=logical sector, C=1 -> add partition offset
;### Output     HL=track, E=sector, D=SDH
idesec  push af
        call stoadrx
        pop af
        dec c
        ld c,a
        push bc
        jr nz,idesec2
        push hl
        ld bc,stodatbeg
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        add ix,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        jr nc,idesec1
        inc bc
idesec1 add iy,bc
        pop hl
idesec2 ld bc,stodatsub
        add hl,bc
        ld e,ixl
        ld c,ixh
        ld b,iyl
        ld d,iyh
        ld a,64
        or d
        ld d,a
        ld a,(hl)
        and #10
        or d
        ld d,a
        ld l,c
        ld h,b
        pop bc
        ld a,c
        ret

;### IDEADR -> set sector address
ideadr  call ideshw
        call iderdy
        ret c
        ld a,d
        ld (ideprtsdh),a
        call iderdy
        ret c
        ld (ideprttrk),hl
        ld c,b
        ld b,e
        ld (ideprtscn),bc
        ret

;### IDESHW -> maps IDE memory to #4000-#7FFF
ideshw  ld a,(ideslt+0)
        di
        out (#a8),a
        ld a,(ideslt+1)
        ld (#ffff),a
        ld a,(ideslt+2)
        out (#a8),a
        ld a,7*32+1
        ld (#4104),a
        ret

;### IDERDY -> wait for ready for next command
iderdy  push hl
        ld hl,256*30
iderdy1 ld a,(ideprtsta)
        and #80
        jr z,iderdy2
        dec l
        jr nz,iderdy1
        call bnkmofx
        call bnkdofx
        rst #30
        call ideshw
iderdy4 ld a,0
        out (#fc),a
        dec h
        jr nz,iderdy1
        ld a,stoerrabo
        scf
iderdy2 pop hl
        ret

;### IDEDRQ -> wait for data request
idedrq  ld a,(ideprtsta)
        and #08
        jr z,idedrq
        ret


;==============================================================================
;### EBR EXTENSION (SeD_NcL) ##################################################
;==============================================================================

;### EBRSAV -> remember device number, IX=0
ebrsav  ld (ebrdev),a
        ld ix,0
        ret

;### EBRCHK -> called with A=B=C=partition (1-15), DE=device record, MBR in (stobufx)
ebrchk  push af
        push de
        push bc
        cp 2
        jp c,ebrpri             ;partition 0/1 -> primary handling
        cp 5
        jp nc,ebrpri            ;5-15 -> primary handling
        ld hl,(stobufx)
        ld bc,ideparadr+16+idepartyp
        add hl,bc
        ld a,(hl)
        call ebrext             ;MBR entry 2 extended?
        jp nz,ebrpri
        ld bc,16
        add hl,bc
        ld a,(hl)
        or a                    ;entry 3 empty?
        jp nz,ebrpri
        add hl,bc
        ld a,(hl)
        or a                    ;entry 4 empty?
        jp nz,ebrpri
        ld hl,(stobufx)         ;-> Nextor layout
        ld bc,#1fe
        add hl,bc
        ld a,(hl)
        cp #55
        jp nz,ebrnf0
        inc hl
        ld a,(hl)
        cp #aa
        jp nz,ebrnf0
        ld hl,(stobufx)
        ld bc,ideparadr+16+ideparbeg
        add hl,bc
        call ebrl32             ;DE:HL=extended partition start
        ld (ebrbas),hl
        ld (ebrbas+2),de
        ld (ebrcur),hl
        ld (ebrcur+2),de
        call ebrc28
        jp c,ebrnf0
        ld a,h
        or l
        or d
        or e
        jp z,ebrnf0
        ld hl,(stobufx)
        ld bc,ideparadr+16+ideparlen
        add hl,bc
        call ebrl32
        call ebradb             ;DE:HL=extended end (exclusive)
        jp c,ebrnf0
        call ebrc28
        jp c,ebrnf0
        ld (ebrend),hl
        ld (ebrend+2),de
        pop bc
        pop de
        pop af
        dec a
        ld (ebrcnt),a           ;1..3 = logical volume number
        jp ebrlop

ebrpri  pop bc                  ;primary partition -> original code
        pop de
        pop af
        ld ix,(stobufx)
        jp ideact0

ebrnf0  pop bc
        pop de
        pop af
        jp ebrnf

;--- read EBR at (ebrcur), check, follow chain
ebrlop  ld hl,(ebrcur)
        ld de,(ebrcur+2)
        call ebrrng             ;inside extended partition?
        jp c,ebrnf
        ld ix,(ebrcur)
        ld iy,(ebrcur+2)
        ld hl,(ideactd)         ;(unused - idesec reloads HL)
        ld de,(stobufx)
        ld b,1
        ld c,0                  ;absolute LBA
        ld a,(ebrdev)
        call ideinp0            ;read EBR
        ret c
        ld hl,(stobufx)
        ld bc,#1fe
        add hl,bc
        ld a,(hl)
        cp #55
        jp nz,ebrnf
        inc hl
        ld a,(hl)
        cp #aa
        jp nz,ebrnf
        ld hl,(stobufx)
        ld bc,ideparadr+idepartyp
        add hl,bc
        ld a,(hl)               ;logical partition type
        or a
        jp z,ebrnf
        ld hl,idepartok
        ld b,idepartan
ebrlop1 cp (hl)
        jp z,ebrnxt
        inc hl
        djnz ebrlop1
        jp ebrntp

ebrnxt  ld a,(ebrcnt)
        dec a
        ld (ebrcnt),a
        jp z,ebrfnd             ;this is the wanted volume
        ld hl,(stobufx)         ;follow link (EBR entry 2)
        ld bc,ideparadr+16+idepartyp
        add hl,bc
        ld a,(hl)
        call ebrext
        jp nz,ebrnf             ;end of chain
        ld bc,ideparbeg-idepartyp
        add hl,bc
        call ebrl32
        ld a,h
        or l
        or d
        or e
        jp z,ebrnf
        call ebradb             ;link is relative to extended start
        jp c,ebrnf
        call ebrc28
        jp c,ebrnf
        call ebrrng
        jp c,ebrnf
        call ebrinc             ;must move forward (loop protection)
        jp c,ebrnf
        ld (ebrcur),hl
        ld (ebrcur+2),de
        jp ebrlop

ebrfnd  ld hl,(stobufx)         ;logical start is relative to this EBR
        ld bc,ideparadr+ideparbeg
        add hl,bc
        call ebrl32
        ld a,h
        or l
        or d
        or e
        jp z,ebrnf
        call ebradc
        jp c,ebrnf
        call ebrc28
        jp c,ebrnf
        call ebrrng
        jp c,ebrnf
        ld (ebrlst),hl
        ld (ebrlst+2),de
        ld hl,(stobufx)
        ld bc,ideparadr+ideparlen
        add hl,bc
        call ebrl32
        ld a,h
        or l
        or d
        or e
        jp z,ebrnf
        call ebradl             ;DE:HL=start+length
        jp c,ebrnf
        ld a,h                  ;-1 = last sector
        or l
        dec hl
        jp nz,ebrfnd1
        dec de
ebrfnd1 call ebrrng             ;last sector inside extended partition?
        jp c,ebrnf
        ld bc,(ebrlst)
        ld iy,(ebrlst+2)
        ld de,(ideactd)
        jp ideact5              ;store IY:BC as partition start

ebrnf   ld a,stoerrpno
        scf
        ret
ebrntp  ld a,stoerrptp
        scf
        ret

;### EBREXT -> ZF=1 if A is an extended partition type (#05/#0F)
ebrext  cp #0f
        ret z
        cp #05
        ret

;### EBRL32 -> DE:HL=(HL) 32bit
ebrl32  ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld h,b
        ld l,c
        ret

;### EBRC28 -> CF=1 if DE:HL does not fit into 28bit LBA
ebrc28  ld a,d
        cp #10
        ccf
        ret

;### EBRADB/EBRADC/EBRADL -> DE:HL += ebrbas / ebrcur / ebrlst (CF=overflow)
ebradb  ld bc,(ebrbas)
        add hl,bc
        push hl
        ex de,hl
        ld bc,(ebrbas+2)
        adc hl,bc
        ex de,hl
        pop hl
        ret
ebradc  ld bc,(ebrcur)
        add hl,bc
        push hl
        ex de,hl
        ld bc,(ebrcur+2)
        adc hl,bc
        ex de,hl
        pop hl
        ret
ebradl  ld bc,(ebrlst)
        add hl,bc
        push hl
        ex de,hl
        ld bc,(ebrlst+2)
        adc hl,bc
        ex de,hl
        pop hl
        ret

;### EBRINC -> CF=1 if DE:HL <= ebrcur
ebrinc  push hl
        push de
        ld b,h
        ld c,l
        ld hl,(ebrcur)
        or a
        sbc hl,bc
        ld b,d
        ld c,e
        ld hl,(ebrcur+2)
        sbc hl,bc
        pop de
        pop hl
        ccf
        ret

;### EBRRNG -> CF=1 if DE:HL outside [ebrbas, ebrend)
ebrrng  push hl
        push de
        or a
        ld bc,(ebrbas)
        sbc hl,bc
        ex de,hl
        ld bc,(ebrbas+2)
        sbc hl,bc
        pop de
        pop hl
        ret c
        push hl
        push de
        or a
        ld bc,(ebrend)
        sbc hl,bc
        ex de,hl
        ld bc,(ebrend+2)
        sbc hl,bc
        pop de
        pop hl
        ccf
        ret

ebrdev  db 0            ;device number
ebrcnt  db 0            ;logical volumes still to skip
ebrbas  dw 0,0          ;extended partition start (LBA)
ebrcur  dw 0,0          ;current EBR (LBA)
ebrend  dw 0,0          ;extended partition end (exclusive)
ebrlst  dw 0,0          ;logical partition start

ideend

        relocate_end
        relocate_table
