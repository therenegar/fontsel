# DOS Display Font Selector

**FONTSEL** recreates the mystical IBM PS/2 Model 30-286 font selector on ordinary VGA-compatible DOS machines - [read the history here](https://int10h.org/blog/2022/06/ibm-ps2-30-286-hidden-vga-fonts/).

It allows for font selection, with live previewing and system-wide activation - with a resident component that keeps the chosen font active even after BIOS video mode changes.
The 5 secret fonts that were hidden in the PS/2 30-286 are included. Additional fonts (up to a maximum of 25) can be added to the `\fonts` sub-directory.

<img width="720" height="600" alt="neil" src="https://github.com/user-attachments/assets/f7f8e10e-e5f6-448e-bd3e-52241a879bf2" />
<img width="720" height="600" alt="fatscii" src="https://github.com/user-attachments/assets/d838344e-9732-4cc1-b8f4-86a6bbebcd26" />
<img width="720" height="600" alt="scribble" src="https://github.com/user-attachments/assets/b8ae93ce-2070-47a1-80e0-ca9a8ca77eac" />
<img width="720" height="600" alt="charset" src="https://github.com/user-attachments/assets/0ea75dc7-704e-489b-926f-84c76ac31d13" />
<img width="720" height="600" alt="help" src="https://github.com/user-attachments/assets/2077d639-502f-48ae-8388-5ff589802996" />

----

Requirements
------------

* MS-DOS, PC DOS, DR-DOS, FreeDOS or a compatible real-mode DOS (3.3 or higher)
* VGA or a VGA-compatible BIOS supporting INT 10h font services
* 80-column text mode 2, 3, or 7
* 8086 or later CPU (the binary deliberately contains no 286/386-only code)


Usage
-----

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
```
    FONTSEL /L
```
This is suitable for use in AUTOEXEC.BAT to apply your chosen font at startup. 

To apply a specific font file in the `\fonts` sub-directory, without opening the selector:
```
    FONTSEL /L FONTNAME.F16
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

`FONTSEL.COM` and the fonts directory must remain together. 
Run FONTSEL from the directory containing FONTSEL.COM.

Each non-comment line in `fonts.lst` has this form:
```
    filename=Display name
```
The first entry must be:
```
    STANDARD=Boca
```
STANDARD is a special entry for the adapter ROM font and is not a disk file.
A maximum of 25 fonts can be specified. Display names are limited to 12 characters.
Every external font must be exactly 4096 bytes: 256 glyphs, 8 pixels wide and 16 scanlines high. 


Memory Usage
------------

Only one 4096-byte font plus the two interrupt handlers remains resident. This can be moved to upper memory with LOADHIGH or XMS memory managers.
The menu, saved screen, catalogue and disk font buffer are transient.


Font sources
------------

HOWARD16, ELITE16, OAKLEY16 (Oak8), OAKLYB16 (Oak9), NEIL16, ITALIC16, and CGA16 come from IBM's internally distributed HOWARD the FONT 3.61 archive by Alan E. Beelitz and contributors. http://int10h.org/filez/howard361.zip


Technical notes
---------------

The TSR hooks INT 10h and INT 2Fh.  It chains normal video BIOS calls.  For AH=00h mode sets, it calls the original BIOS first and then reloads the committed font using the original INT 10h handler.  It does not intercept or fight explicit application font-load requests.
The private INT 2Fh interface begins at AX=D7F0h. 

