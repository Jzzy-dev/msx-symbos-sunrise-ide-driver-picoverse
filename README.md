# msx-symbos-sunrise-ide-driver-picoverse
A Sunrise IDE driver for MSX machines booting Symbos on PicoVerse

Now with multipartition thanks to SeD_NcL

<img width="2000" height="1500" alt="WhatsApp Image 2026-11-18 at 09 44 57" src="https://github.com/user-attachments/assets/fef3d654-0e15-4447-8018-fbe8b2382c7a" />

<a href="https://msx.pics/image/xtaHE"><img src="https://msx.pics/images/2026/10/05/SL-3002.md.jpeg" alt="SL 3002" border="0"></a>

<a href="https://msx.pics/image/xtrId"><img src="https://msx.pics/images/2026/10/05/SL-3001.md.jpeg" alt="SL 3001" border="0"></a>

<a href="https://msx.pics/image/xtXiZ"><img src="https://msx.pics/images/2026/10/05/SL-3003.md.png" alt="SL 3003" border="0"></a>

This is based on the Symbos mass-storage driver for Sunrise IDE by Prodatron (https://github.com/Prodatron/symdrv-msx-massstorage), but making it work on PIcoVerse 2350.

## Drivers

| File | Source | Partitions |
|------|--------|------------|
| `-IDEsdPV.DRV` | `Drv-IDE-Sunrise-SD-PicoVerse.asm` | Single partition (primary partitions only) |
| `-IDEUPPV.DRV` | `Drv-IDE-Sunrise-SD-PicoVerse-Partitions.asm` | Multiple partitions, including Nextor 3 logical volumes |

### What makes them PicoVerse drivers

The PicoVerse 2350 Sunrise IDE emulation does not support ATA command `#F8` (READ NATIVE MAX ADDRESS). The original Sunrise driver sends it when a drive is activated, to check for LBA support, and activation fails on PicoVerse. Both drivers skip that command; everything else works as on a real Sunrise IDE.

## -IDEUPPV.DRV: multiple partitions (Nextor 3)

Nextor 3 formats a card with one primary partition plus an extended partition that holds the other volumes as logical partitions. Prodatron's original driver only reads primary partitions, so only the first volume was reachable.

The multi-partition driver is the work of **[SeD_NcL](https://www.msx.org/users/sed-ncl)**, who added an EBR (extended boot record) parser to the Sunrise driver and released it as "Sunrise EBR Test v2" in the [SymbOS MSX thread on msx.org](https://www.msx.org/forum/development/msx-development/symbos-msx-multitasking-operating-system-help-needed?page=408). `-IDEUPPV.DRV` is his driver with the `#F8` probe removed for PicoVerse. Thanks SeD_NcL!

Partition mapping (Control Panel / Mass Storage, "Primary partition" setting):

| Setting | Nextor 3 layout* | Any other layout |
|---------|------------------|------------------|
| 0 | whole disk | whole disk |
| 1 | primary partition (first volume) | MBR entry 1 |
| 2 | logical volume 1 | MBR entry 2 |
| 3 | logical volume 2 | MBR entry 3 |
| 4 | logical volume 3 | MBR entry 4 |

\* MBR entry 2 is an extended partition (`#05`/`#0F`), entries 3 and 4 are empty, and the MBR has a valid `#55AA` signature.

The EBR walker checks every sector address against the bounds of the extended partition and the 28-bit LBA limit, and stops if the chain does not move forward. Supported volume types are FAT12 and FAT16 (plus the FAT32 types the original driver accepts).

Tested on a PicoVerse 2350 booting from SD (loadrom).

### Kernel fix

Use it together with SeD_NcL's patched `SYM.COM` and `SYMBOS.BIN` ("Sector Fix v7", for SymbOS 4.0 build 250131), available from the msx.org thread above. In the stock kernel, a carry in the cluster-to-sector calculation is wrongly reported as disk error 032. Keep `SYM.COM` and `SYMBOS.BIN` together as a matched pair.

### Limitations

- Only the first three logical volumes can be reached (settings 2-4).
- PicoVerse emulates the Master device only. Do not configure a Slave drive: a saved Slave configuration without a device attached has been seen to cause a black desktop.
- Experimental: test reading first, and use a backup of your SD card when writing.

## Building

Assemble with [sjasmplus](https://github.com/z00m128/sjasmplus):

```
sjasmplus -DPICOVERSE --raw=-IDEUPPV.DRV Drv-IDE-Sunrise-SD-PicoVerse-Partitions.asm
```

`Drv-IDE-Sunrise-SD-PicoVerse-Partitions.asm` is a commented source reconstructed from SeD_NcL's binary. Without `-DPICOVERSE` it builds a file byte-identical to his `-IDSUNRI.DRV` (Sunrise EBR Test v2), relocation table included.

## Credits

- Original Sunrise IDE driver: Prodatron / SymbiosiS (Jörn Mika), [symdrv-msx-massstorage](https://github.com/Prodatron/symdrv-msx-massstorage) (LGPL-2.1)
- Nextor 3 logical partition support and kernel sector fix: [SeD_NcL](https://www.msx.org/users/sed-ncl)
- PicoVerse adaptation: JZZY
