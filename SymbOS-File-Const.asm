;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@             S y m b O S   -   File-Manager - C o n s t a n t s             @
;@                                                                            @
;@            (c) 2000-2026 by Prodatron / SymbiosiS (Joern Mika)             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


;Error Codes
stoerrmis   equ 0       ;Device not present
stoerruni   equ 2       ;Device not initialized
stoerrfai   equ 3       ;Media defective
stoerrpno   equ 4       ;Partition not found
stoerrptp   equ 5       ;Media or partition not supported
stoerrsec   equ 6       ;Error reading/writing sector
stoerrpos   equ 7       ;Positioning error
stoerrabo   equ 8       ;Aborted during media access
stoerrunk   equ 9       ;Unknown media error
stoerrhnd   equ 10      ;No file handler available
stoerrxdv   equ 11      ;Device does not exist (for path selection)
stoerrxdi   equ 12      ;Path does not exist (for path selection)
stoerrxfi   equ 13      ;File does not exist (for path selection)
stoerracs   equ 14      ;Access denied
stoerrnam   equ 15      ;Invalid file, wildcard, or path name
stoerrxhn   equ 16      ;Handler does not exist
stoerrdev   equ 17      ;Device slot already occupied
stoerrrea   equ 18      ;Error reading file (File organization)
stoerrnna   equ 19      ;Invalid destination name (incorrect or a path was specified)
stoerrdbl   equ 20      ;(Destination) name already exists
stoerrscm   equ 21      ;Incorrect sub-command code
stoerratr   equ 22      ;Invalid attribute
stoerrdfl   equ 23      ;No free space in directory
stoerrsfl   equ 24      ;No space left on device
stoerrwrp   equ 25      ;Write protection enabled, cannot write to media
stoerrrdy   equ 26      ;Device not ready
stoerrdne   equ 27      ;Directory is not empty and cannot be deleted
stoerrwdv   equ 28      ;Target device is not identical to source device
stoerrsup   equ 29      ;Command not supported for this file system
stoerrdvp   equ 30      ;Device not supported
stoerrrdo   equ 31      ;File is ReadOnly
stoerrxch   equ 32      ;Device channel not available
stoerrndi   equ 33      ;Target is not a directory
stoerrnfi   equ 34      ;Target is not a file
stoerrcmd   equ 35      ;Unsupported command
stoerrgen   equ 255     ;*Undefined error*

;Storage device status
stotypmis   equ 0           ;Device not present
stotypoky   equ 1           ;Device ready
stotypuni   equ 2           ;Device not initialized
stotypfai   equ 3           ;Device defective

;Media types
stomedfda   equ 1           ;FDC Floppy Disk Single Side (AMSDOS)
stomedfdd   equ 2           ;FDC Floppy Disk Double Side (FAT12)
stomedfds   equ 3           ;FDC Floppy Disk Single Side (FAT12)
stomedhdi   equ 16          ;IDE Device                  (FAT12/16/32)
stomedsdc   equ 17          ;SD/MMC Card                 (FAT12/16/32)
stomedusb   equ 18          ;USB Device                  (FAT12/16/32)
stomedhfs   equ 32          ;HostFS                      (HostFS)

;File system types (#!WARNING! -> Adjust FSYPRP if changing IDs!#)
stofilada   equ 1           ;Amsdos Data
stofilasy   equ 2           ;Amsdos System
stofilajy   equ 3           ;Amsdos PCW
stofilf12   equ 16          ;Fat 12
stofilf16   equ 17          ;Fat 16
stofilf32   equ 18          ;Fat 32
stofilhfs   equ 32          ;HostFS


;--- DEVICES ------------------------------------------------------------------
stodatsta   equ 0           ;L Device status
stodattyp   equ 1           ;L Bit[0-6]=Media type, Bit[7]=Flag indicating removable media
stodatfsy   equ 2           ;F File system type
stodatsec   equ 3           ;F Number of sectors per cluster (1-128; power of 2)
stodatmax   equ 4           ;F Number of available clusters (32-bit)
stodatdat   equ 8           ;F First logical sector of cluster 0
stodatbeg   equ 12          ;L First logical sector (32-bit) where partition starts (used only by low-level sector routines)
stodatjrd   equ 16          ;  Jump address "Read Sector"
stodatjwr   equ 18          ;  Jump address "Write Sector"
stodatjac   equ 20          ;  Jump address "Read Media"
stodatjcl   equ 22          ;  Jump address "Close Device"
stodatts2   equ 24          ;  **Reserved (2 bytes)**
stodatsub   equ 26          ;  IDE/SD/SCSI/USB  Bit[0-3] -> 0=Not partitioned, 1-4=Primary, 5-15=Extended), Bit[4-7] -> Channel (0=Master, 1=Slave or 0-15)
                            ;  FDC              Bit[0-1] -> Drive (0=A, 1=B, 2=C, 3=D), Bit[2] -> Head, Bit[3]=DoubleStep, Bit[4-7] -> SectorOffset (only after STOACT)
                            ;  HostFS           Bit[0-2] -> HostFS Drive or image (0-7), Bit[7]=Flag, if HostFS (0) or Image (1)
stodatrs1   equ 27          ;  **Reserved (1 byte)**
stodatspt   equ 28          ;L Number of sectors per track (max. 256)
stodathed   equ 30          ;L Number of heads (max. 16)
stodatflg   equ 31          ;L Internal driver flags (IDE -> bit0=LBA mode, SD -> bit0=slot, bit4=HC)
stodatfil   equ 32          ;F File system-specific sub-section
;FAT data
fatdattyp   equ 0           ;Type (0=FAT12, 1=FAT16, 2=FAT32)
fatdatdln   equ 1           ;Number of root directory sectors (8-bit, FAT12/16 only)
fatdatbeg   equ 2           ;First FAT sector (32-bit)
fatdatanz   equ 6           ;Size of FAT in sectors (32-bit)
fatdatdir   equ 10          ;First cluster (FAT32) or sector (FAT12/16) of the root directory (32-bit)
fatdatfsi   equ 14          ;FSInfo sector number (FAT32) or first free cluster (FAT12/16)

stodatlen   equ 32+16       ;Record length
stogrpmax   equ 8           ;Maximum 8 devices


;--- FAT DIRECTORY ENTRY ----------------------------------------------------
dir_name            equ 00  ;Filename (8+3 characters)
dir_attr            equ 11  ;Attributes (+1=ReadOnly, +2=Hidden, +4=System, +8=VolumeID, +16=Directory, +32=Archive, #0f=Longname, +128=Don't list non-matching directory entries)
dir_ntres           equ 12  ;*Reserved for Windows NT*
dir_crttimetenth    equ 13  ;Creation time (hundredths of a second, 0-199)
dir_crttime         equ 14  ;Time  -> Creation (b0-4=Seconds*2, b5-10=Minutes, b11-15=Hours)
dir_crtdate         equ 16  ;Date  -> Creation (b0-4=Day, b5-8=Month, b9-15=Year-1980)
dir_lstaccdat       equ 18  ;Date  -> Last access
dir_fstclushi       equ 20  ;Start cluster (High Word)
dir_wrttime         equ 22  ;Time  -> Last modification
dir_wrtdate         equ 24  ;Date  -> Last modification
dir_fstcluslo       equ 26  ;Start cluster (Low Word)
dir_filesize        equ 28  ;File length (32-bit)

;--- FAT BOOT SECTOR ----------------------------------------------------------
bs_jmpboot          equ 0   ;Jump to boot routine
bs_oemname          equ 3   ;OEM name
bpb_bytespersec     equ 11  ;Bytes per sector (only 512 supported)
bpb_secperclus      equ 13  ;Sectors per cluster
bpb_rsvdseccnt      equ 14  ;Number of reserved sectors (before start of first FAT)
bpb_numfats         equ 16  ;Number of FATs
bpb_rootentcnt      equ 17  ;Number of 32-byte entries in the root directory
bpb_totsec16        equ 19  ;Total number of sectors (if 16-bit, otherwise 0)
bpb_media           equ 21  ;#F8=Fixed, #F0=Removable
bpb_fatsz16         equ 22  ;Sectors per FAT (FAT12/16 only)
bpb_secpertrk       equ 24  ;Sectors per track
bpb_numheads        equ 26  ;Number of heads
bpb_hiddsec         equ 28  ;Number of sectors before partition sector 0
bpb_totsec32        equ 32  ;Total number of sectors in 32-bit (if not in 16-bit, otherwise 0)

bs_drvnum           equ 36  ;#00=floppy, #80=hard disk
bs_reserved1        equ 37  ;Reserved for WinNT (should be 0)
bs_bootsig          equ 38  ;#29, if the following 3 entries exist
bs_volid            equ 39  ;Usually timestamp, used to detect media changes
bs_vollab           equ 43  ;Volume label
bs_filsystype       equ 54  ;"FAT....." string

bpb_fatsz32         equ 36  ;Sectors per FAT (FAT32 only)
bpb_extflags        equ 40  ;[Bit0-3]=Active FAT number, if no mirroring is active, [Bit7]=1 if no mirroring is active
bpb_fsver           equ 42  ;FAT32 version, should be 0/0
bpb_rootclus        equ 44  ;First cluster of the Root Directory; should be 2 or directly after the first non-corrupt cluster
bpb_fsinfo          equ 48  ;Sector number of the "FSINFO" sector; should be 1
bpb_bkbootsec       equ 50  ;Sector containing a copy of the boot sector; 0=Not available, should otherwise be 6
bpb_reserved        equ 52  ;Reserved (should be 0)

bs32_drvnum         equ 64  ;#00=floppy, #80=hard disk
bs32_reserved1      equ 65  ;Reserved for WinNT (should be 0)
bs32_bootsig        equ 66  ;#29, if the following 3 entries exist
bs32_volid          equ 67  ;Usually timestamp, used to detect media changes
bs32_vollab         equ 71  ;Volume label
bs32_filsystype     equ 82  ;"FAT....." string

fsi_free_count      equ 488 ;Number of free clusters (-1=Unknown number) [32-bit]
fsi_nxt_free        equ 492 ;Cluster number from which to start searching for free clusters (-1=Unknown number, start from 2) [32-bit]
