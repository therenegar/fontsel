# VGA Display Font Selector

<img width="720" height="600" alt="ISO" src="https://github.com/user-attachments/assets/218517d7-e823-4bc8-b354-42fa9221efab" />
<img width="720" height="600" alt="charset" src="https://github.com/user-attachments/assets/73a31d68-0997-4cb0-bea9-435ffeec07b6" />
<img width="720" height="600" alt="help" src="https://github.com/user-attachments/assets/1313db51-426c-4b03-8d96-97b313a2f728" />



----

FONTSEL recreates the mystical IBM PS/2 Model 30-286 font selector on ordinary VGA-compatible DOS machines. Read more here: https://int10h.org/blog/2022/06/ibm-ps2-30-286-hidden-vga-fonts/

It allows for font selection, with live previewing, and application system-wide - with a resident component that keeps the chosen font active even after BIOS video mode changes.

The 5 fonts that were hidden in the PS/2 30-286 are included. Additional fonts (up to a maximum of 25) can be added to the `\fonts` sub-directory (see Customizing fonts).


Requirements
------------

* MS-DOS, PC DOS, DR-DOS, FreeDOS or a compatible real-mode DOS
* VGA or a VGA-compatible BIOS supporting INT 10h font services
* 80-column text mode 2, 3, or 7
* 8086 or later CPU (the binary deliberately contains no 286/386-only code)

Use
---

Change to the directory containing FONTSEL.COM and run:
```
    FONTSEL
```
On the first invocation it installs a resident manager and opens the menu.
Later invocations detect the resident copy and reopen the selector without installing a second copy.

- Left/Right  selects and preview a font
- Enter       applies the highlighted font
- Escape      cancels and restore the previous font

To restore the default video ROM font and remove the resident component:
```
    FONTSEL /U
```
To draw a complete CP437 character demonstration before opening the selector:
```
    FONTSEL /C
```
To load the last font that was applied, without opening the selector:
This is suitable for use in AUTOEXEC.BAT to apply your chosen font at startup. 
```
    FONTSEL /L
```
To apply a specific font file in the `\fonts` sub-directory, without opening the selector:
```
    FONTSEL /L NEIL16.F16
```

Both /L forms install the resident manager when necessary and otherwise update the installed copy. 

For command-line help:
```
    FONTSEL /?
```

Unloading is refused if another program has subsequently hooked INT 10h or INT 2Fh, because removing FONTSEL from the middle of an interrupt chain would
leave that program pointing into released memory.  In that case, reboot to remove the complete chain safely.


Font catalogue
--------------

`FONTSEL.COM`, the fonts directory, `FONTS\FONTS.LST`, and the selected .F16 files must remain together.  
Run FONTSEL from the directory containing FONTSEL.COM.

Each non-comment line in `fonts.lst` has this form:
```
    filename=Display name
```
The first entry must be:
```
    STANDARD=Standard
```
STANDARD is a special entry for the adapter ROM font and is not a disk file.
A maximum of 25 fonts can be specified. Display names are limited to 12 characters.
Every external font must be exactly 4096 bytes: 256 glyphs, 8 pixels wide and 16 scanlines high. 


Memory Usage
------------

Only one 4096-byte font plus the two interrupt handlers remains resident.
The menu, saved screen, catalogue and disk font buffer are transient.


Font sources
------------

HOWARD16, ELITE16, OAKLEY16 (Oak8), OAKLYB16 (Oak9), NEIL16, ITALIC16, and CGA16 come from IBM's internally distributed HOWARD the FONT 3.61 archive by Alan E. Beelitz and contributors. http://int10h.org/filez/howard361.zip

Olympiad EGA derives from the recovered IBM Olympiad EGA 8x14 raster font. http://int10h.org/filez/Olympiad_ProtoFonts_Disks.zip
It is mapped to CP437 and padded with one blank scanline above and below to fit a VGA 8x16 cell without scaling its original glyphs.  The recovered font conversion is credited to VileR/int10h.org and distributed under CC BY-SA 4.0; see LICENSE-OLYMPIAD.TXT.


Technical notes
---------------

The TSR hooks INT 10h and INT 2Fh.  It chains normal video BIOS calls.  For AH=00h mode sets, it calls the original BIOS first and then reloads the committed font using the original INT 10h handler.  It does not intercept or fight explicit application font-load requests.

The private INT 2Fh interface begins at AX=D7F0h.  This is provisional and may change after hardware testing.

