.code16
.arch i8086
.intel_syntax noprefix
.section .text
.global _start

/*
 * FONTSEL 0.6 - PS/2-style VGA font selector and persistent DOS TSR
 *
 * Build with GNU binutils (see Makefile).  The resident portion hooks
 * INT 10h and INT 2Fh.  Only the selected 4096-byte font remains resident;
 * the selector UI and bundled font library are discarded after first use.
 */

.equ MUX_QUERY,       0xD7F0
.equ MUX_COMMIT,      0xD7F1
.equ MUX_STANDARD,    0xD7F2
.equ MUX_PREVIEW,     0xD7F3
.equ MUX_PREV_STD,    0xD7F4
.equ MUX_RESTORE,     0xD7F5
.equ MUX_REPLY,       0xF07D
.equ FONT_SIZE,       4096
.equ MAX_FONTS,       25
.equ NAME_SIZE,       13
.equ FILE_SIZE,       13
.equ LIST_BUFFER_SIZE, 2048

_start:
    jmp transient_start

/* --------------------------- resident portion --------------------------- */

old_int10:      .word 0, 0
old_int2f:      .word 0, 0
active_id:      .byte 0                 /* 0 = adapter ROM font */
resident_mark:  .ascii "FONTSEL1"

/* Active custom font.  This is the only font data retained by the TSR. */
.balign 2
active_font:
    .space FONT_SIZE, 0

/* Call the original video BIOS to load active_font. */
resident_load_custom:
    push ax
    push bx
    push cx
    push dx
    push bp
    push es
    push cs
    pop es
    mov bp, offset active_font
    mov ax, 0x1100
    mov bx, 0x1000                    /* BH=16 scanlines, BL=bank 0 */
    mov cx, 256
    xor dx, dx
    pushf
    call far ptr cs:[old_int10]
    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Restore the VGA adapter's own ROM 8x16 font. */
resident_load_standard:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    mov ax, 0x1104
    xor bx, bx
    pushf
    call far ptr cs:[old_int10]
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

resident_restore:
    cmp byte ptr cs:[active_id], 0
    je resident_load_standard
    jmp resident_load_custom

/*
 * INT 10h hook.  Mode-setting calls are passed to the BIOS first, then the
 * selected font is restored.  All other calls are chained without change.
 */
int10_handler:
    cmp ah, 0x00
    je int10_mode_set
    jmp far ptr cs:[old_int10]

int10_mode_set:
    pushf
    call far ptr cs:[old_int10]
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    call resident_restore
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    iret

/*
 * INT 2Fh private API
 *   AX=D7F0 query       -> AX=F07D, BX=0100, CL=active ID, ES=resident seg
 *   AX=D7F1 commit      -> DS:SI=4096 bytes, DL=font ID
 *   AX=D7F2 standard    -> make adapter ROM font active
 *   AX=D7F3 preview     -> DS:SI=4096 bytes, not retained
 *   AX=D7F4 preview ROM -> temporarily show adapter ROM font
 *   AX=D7F5 restore     -> restore committed selection
 */
int2f_handler:
    cmp ax, MUX_QUERY
    je mux_query
    cmp ax, MUX_COMMIT
    je mux_commit
    cmp ax, MUX_STANDARD
    je mux_standard
    cmp ax, MUX_PREVIEW
    je mux_preview
    cmp ax, MUX_PREV_STD
    je mux_preview_standard
    cmp ax, MUX_RESTORE
    je mux_restore
    jmp far ptr cs:[old_int2f]

mux_query:
    mov ax, MUX_REPLY
    mov bx, 0x0100
    mov cl, byte ptr cs:[active_id]
    push cs
    pop es
    iret

mux_commit:
    cmp cx, FONT_SIZE
    jne mux_bad_size
    mov byte ptr cs:[active_id], dl
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    cld
    push cs
    pop es
    mov di, offset active_font
    mov cx, FONT_SIZE / 2
    rep movsw
    call resident_load_custom
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    xor ax, ax
    iret

mux_bad_size:
    mov ax, 1
    iret

mux_standard:
    mov byte ptr cs:[active_id], 0
    call resident_load_standard
    xor ax, ax
    iret

mux_preview:
    cmp cx, FONT_SIZE
    jne mux_bad_size
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    push ds
    pop es
    mov bp, si
    mov ax, 0x1100
    mov bx, 0x1000
    mov cx, 256
    xor dx, dx
    pushf
    call far ptr cs:[old_int10]
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    xor ax, ax
    iret

mux_preview_standard:
    call resident_load_standard
    xor ax, ax
    iret

mux_restore:
    call resident_restore
    xor ax, ax
    iret

resident_end:

/* -------------------------- transient portion --------------------------- */

installed_now:      .byte 0
request_unload:     .byte 0
request_help:       .byte 0
request_load:       .byte 0
request_charset:    .byte 0
load_has_name:      .byte 0
selected_id:        .byte 0
saved_cursor_pos:   .word 0
saved_cursor_shape: .word 0
video_segment:      .word 0xB800
resident_seg:       .word 0
saved_10_off:       .word 0
saved_10_seg:       .word 0
saved_2f_off:       .word 0
saved_2f_seg:       .word 0
font_count:         .byte 0
list_end:           .word 0
dialog_top:         .byte 0
dialog_bottom:      .byte 0
name_row:           .byte 0

transient_start:
    push cs
    pop ds
    cld
    call parse_command_line
    cmp byte ptr [request_help], 0
    jne show_help

    /* Is our resident copy already installed? */
    mov ax, MUX_QUERY
    int 0x2f
    cmp ax, MUX_REPLY
    je resident_signature_check

    cmp byte ptr [request_unload], 0
    jne not_installed

    call detect_vga
    jc no_vga
    call load_font_list
    jc bad_font_list
    call install_tsr
    mov byte ptr [installed_now], 1
    mov byte ptr [selected_id], 0
    jmp dispatch_action

resident_signature_check:
    cmp word ptr es:[resident_mark], 0x4f46 /* "FO" */
    jne previous_resident
    cmp word ptr es:[resident_mark+2], 0x544e /* "NT" */
    jne previous_resident
    cmp word ptr es:[resident_mark+4], 0x4553 /* "SE" */
    jne previous_resident
    cmp word ptr es:[resident_mark+6], 0x314c /* "L1" */
    jne previous_resident
    jmp resident_found

resident_found:
    mov word ptr [resident_seg], es
    mov byte ptr [selected_id], cl
    cmp byte ptr [request_unload], 0
    jne unload_tsr
    call load_font_list
    jc bad_font_list
    mov al, byte ptr [selected_id]
    cmp al, byte ptr [font_count]
    jb dispatch_action
    mov byte ptr [selected_id], 0

dispatch_action:
    cmp byte ptr [request_load], 0
    jne command_load
    cmp byte ptr [request_charset], 0
    je run_menu
    call validate_text_mode
    jc bad_mode
    call draw_charset

run_menu:
    call validate_text_mode
    jc bad_mode
    call save_screen
    call draw_menu
    call preview_selected

menu_key_loop:
    xor ax, ax
    int 0x16
    cmp al, 27
    je menu_cancel
    cmp al, 13
    je menu_accept
    cmp ah, 0x4b
    je menu_left
    cmp ah, 0x4d
    je menu_right
    jmp menu_key_loop

menu_left:
    cmp byte ptr [selected_id], 0
    jne 1f
    mov al, byte ptr [font_count]
    dec al
    mov byte ptr [selected_id], al
    jmp menu_changed
1:  dec byte ptr [selected_id]
    jmp menu_changed

menu_right:
    inc byte ptr [selected_id]
    mov al, byte ptr [font_count]
    cmp byte ptr [selected_id], al
    jb menu_changed
    mov byte ptr [selected_id], 0
    jmp menu_changed

menu_changed:
    call draw_menu
    call preview_selected
    jmp menu_key_loop

menu_cancel:
    mov ax, MUX_RESTORE
    int 0x2f
    call restore_screen
    jmp exit_program

menu_accept:
    xor dx, dx
    mov dl, byte ptr [selected_id]
    or dl, dl
    jz commit_standard
    call load_selected_font
    jc menu_key_loop
    mov dl, byte ptr [selected_id]
    mov si, offset font_work
    mov cx, FONT_SIZE
    mov ax, MUX_COMMIT
    int 0x2f
    jmp commit_done

commit_standard:
    mov ax, MUX_STANDARD
    int 0x2f

commit_done:
    call save_last_choice
    call restore_screen
    call print_selected_message

exit_program:
    cmp byte ptr [installed_now], 0
    jne stay_resident
    mov ax, 0x4c00
    int 0x21

stay_resident:
    mov dx, offset resident_end
    add dx, 15
    mov cl, 4
    shr dx, cl
    mov ax, 0x3100
    int 0x21

no_vga:
    mov dx, offset msg_no_vga
    jmp print_error
bad_font_list:
    mov dx, offset msg_bad_font_list
    jmp print_error
bad_mode:
    mov dx, offset msg_bad_mode
print_error:
    mov ah, 9
    int 0x21
    cmp byte ptr [installed_now], 0
    jne stay_resident
    mov ax, 0x4c01
    int 0x21

not_installed:
    mov dx, offset msg_not_installed
    mov ah, 9
    int 0x21
    mov ax, 0x4c01
    int 0x21

/* Recognize /U, /L [font], /C, or /? as the first command-line token. */
parse_command_line:
    xor cx, cx
    mov cl, byte ptr [0x80]
    jcxz 3f
    mov si, 0x81
1:  cmp byte ptr [si], ' '
    jne 2f
    inc si
    loop 1b
    ret
2:  mov al, byte ptr [si]
    cmp al, '/'
    je 4f
    cmp al, '-'
    jne 3f
4:  inc si
    mov al, byte ptr [si]
    cmp al, '?'
    je 8f
    and al, 0xdf
    cmp al, 'U'
    je 7f
    cmp al, 'C'
    je 6f
    cmp al, 'L'
    jne 3f
    mov byte ptr [request_load], 1
    inc si
    dec cx
5:  jcxz 3f
    cmp byte ptr [si], 13
    je 3f
    cmp byte ptr [si], ' '
    jne 9f
    inc si
    loop 5b
    ret
6:  mov byte ptr [request_charset], 1
    ret
7:
    mov byte ptr [request_unload], 1
3:  ret
8:  mov byte ptr [request_help], 1
    ret
9:  mov di, offset requested_file
    mov bx, FILE_SIZE - 1
10: jcxz 11f
    mov al, byte ptr [si]
    cmp al, ' '
    je 11f
    cmp al, 13
    je 11f
    or bx, bx
    jz 12f
    stosb
    dec bx
12: inc si
    dec cx
    jmp 10b
11: xor al, al
    stosb
    mov byte ptr [load_has_name], 1
    ret

show_help:
    mov dx, offset help_text
    mov ah, 9
    int 0x21
    mov ax, 0x4c00
    int 0x21

/* Report the catalogue label committed through the interactive dialog. */
print_selected_message:
    mov dx, offset msg_font_set
    mov ah, 9
    int 0x21
    xor ax, ax
    mov al, byte ptr [selected_id]
    mov dl, NAME_SIZE
    mul dl
    mov si, offset font_names
    add si, ax
    call print_asciiz
    mov dx, offset msg_font_set_end
    mov ah, 9
    int 0x21
    ret

previous_resident:
    mov dx, offset msg_previous_resident
    mov ah, 9
    int 0x21
    mov ah, 0x19
    int 0x21
    add al, 'A'
    mov dl, al
    mov ah, 2
    int 0x21
    mov dl, ':'
    int 0x21
    mov dl, '\\'
    int 0x21
    mov si, offset cwd_buffer
    xor dx, dx
    mov ah, 0x47
    int 0x21
    jc 2f
    mov si, offset cwd_buffer
    cmp byte ptr [si], 0
    je 2f
    call print_asciiz
    mov dl, '\\'
    mov ah, 2
    int 0x21
2:  mov dx, offset msg_previous_command
    mov ah, 9
    int 0x21
    mov ax, 0x4c01
    int 0x21

print_asciiz:
1:  lodsb
    or al, al
    jz 2f
    mov dl, al
    mov ah, 2
    int 0x21
    jmp 1b
2:  ret

/* Read up to 25 filename=display name records from fonts\fonts.lst. */
load_font_list:
    push es
    push ds
    pop es
    mov byte ptr [font_count], 0
    mov dx, offset font_list_path
    mov ax, 0x3d00
    int 0x21
    jc 9f
    mov bx, ax
    mov dx, offset list_buffer
    mov cx, LIST_BUFFER_SIZE
    mov ah, 0x3f
    int 0x21
    jc 8f
    mov word ptr [list_end], ax
    add word ptr [list_end], offset list_buffer
    mov ah, 0x3e
    int 0x21

    mov si, offset list_buffer
1:  cmp si, word ptr [list_end]
    jae 7f
    mov al, byte ptr [si]
    cmp al, 13
    je 2f
    cmp al, 10
    je 2f
    cmp al, ' '
    je 2f
    cmp al, '#'
    je 6f
    cmp al, ';'
    je 6f
    cmp byte ptr [font_count], MAX_FONTS
    jae 7f

    /* Destination filename record = font_files + index * 13. */
    xor ax, ax
    mov al, byte ptr [font_count]
    mov dl, FILE_SIZE
    mul dl
    mov di, offset font_files
    add di, ax
    mov bp, FILE_SIZE - 1
3:  cmp si, word ptr [list_end]
    jae 7f
    mov al, byte ptr [si]
    inc si
    cmp al, '='
    je 4f
    cmp al, 13
    je 6f
    cmp al, 10
    je 1b
    or bp, bp
    jz 3b
    stosb
    dec bp
    jmp 3b
4:  xor al, al
    stosb

    /* Destination display-name record = font_names + index * 13. */
    xor ax, ax
    mov al, byte ptr [font_count]
    mov dl, NAME_SIZE
    mul dl
    mov di, offset font_names
    add di, ax
    mov bp, NAME_SIZE - 1
5:  cmp si, word ptr [list_end]
    jae 5f
    mov al, byte ptr [si]
    cmp al, 13
    je 5f
    cmp al, 10
    je 5f
    inc si
    or bp, bp
    jz 5b
    stosb
    dec bp
    jmp 5b
5:  xor al, al
    stosb
    inc byte ptr [font_count]
    jmp 1b

2:  inc si
    jmp 1b
6:  cmp si, word ptr [list_end]
    jae 7f
    mov al, byte ptr [si]
    inc si
    cmp al, 10
    jne 6b
    jmp 1b
7:  cmp byte ptr [font_count], 1
    jb 9f
    pop es
    clc
    ret
8:  mov ah, 0x3e
    int 0x21
9:  pop es
    stc
    ret

/* Load the selected external 8x16 font into font_work. */
load_selected_font:
    xor ax, ax
    mov al, byte ptr [selected_id]
    mov dl, FILE_SIZE
    mul dl
    mov si, offset font_files
    add si, ax
    jmp load_named_font

/* Load DS:SI named 8x16 font from the fonts subdirectory. */
load_named_font:
    push es
    push ds
    pop es
    mov di, offset font_path
    mov bx, 6
1:  mov al, byte ptr [font_prefix+bx-1]
    mov byte ptr [di+bx-1], al
    dec bx
    jnz 1b
    add di, 6
2:  lodsb
    stosb
    or al, al
    jnz 2b

    mov dx, offset font_path
    mov ax, 0x3d00
    int 0x21
    jc 4f
    mov bx, ax
    mov dx, offset font_work
    mov cx, FONT_SIZE
    mov ah, 0x3f
    int 0x21
    jc 3f
    cmp ax, FONT_SIZE
    jne 3f
    mov ah, 0x3e
    int 0x21
    pop es
    clc
    ret
3:  mov ah, 0x3e
    int 0x21
4:  mov ah, 0x0e
    mov al, 7
    xor bx, bx
    int 0x10
    pop es
    stc
    ret

/* Case-insensitive comparison of NUL strings DS:SI and DS:DI. */
stricmp:
    push ax
1:  mov al, byte ptr [si]
    mov ah, byte ptr [di]
    cmp al, 'a'
    jb 2f
    cmp al, 'z'
    ja 2f
    sub al, 32
2:  cmp ah, 'a'
    jb 3f
    cmp ah, 'z'
    ja 3f
    sub ah, 32
3:  cmp al, ah
    jne 4f
    or al, al
    jz 5f
    inc si
    inc di
    jmp 1b
4:  pop ax
    stc
    ret
5:  pop ax
    clc
    ret

/* Find requested_file in the catalogue; CF clear and AL=index if found. */
find_requested_font:
    xor cx, cx
1:  mov al, cl
    mov dl, FILE_SIZE
    mul dl
    mov si, offset requested_file
    mov di, offset font_files
    add di, ax
    call stricmp
    jnc 2f
    inc cl
    cmp cl, byte ptr [font_count]
    jb 1b
    stc
    ret
2:  mov al, cl
    clc
    ret

/* /L: load a named font, or the last filename saved after Enter. */
command_load:
    cmp byte ptr [load_has_name], 0
    jne 1f
    call read_last_choice
    jc load_choice_failed
1:  call find_requested_font
    jc 2f
    mov byte ptr [selected_id], al
    or al, al
    jz load_standard_choice
    jmp 3f
2:  mov byte ptr [selected_id], 0xff
3:  mov si, offset requested_file
    call load_named_font
    jc load_choice_failed
    mov dl, byte ptr [selected_id]
    mov si, offset font_work
    mov cx, FONT_SIZE
    mov ax, MUX_COMMIT
    int 0x2f
    call save_requested_choice
    jmp exit_program

load_standard_choice:
    mov ax, MUX_STANDARD
    int 0x2f
    call save_requested_choice
    jmp exit_program

load_choice_failed:
    mov dx, offset msg_load_failed
    jmp print_error

/* Read fonts\fontsel.dat into requested_file. */
read_last_choice:
    mov dx, offset last_choice_path
    mov ax, 0x3d00
    int 0x21
    jc 3f
    mov bx, ax
    mov dx, offset requested_file
    mov cx, FILE_SIZE - 1
    mov ah, 0x3f
    int 0x21
    jc 2f
    mov si, offset requested_file
    add si, ax
    mov byte ptr [si], 0
    mov ah, 0x3e
    int 0x21
    cmp byte ptr [requested_file], 0
    je 3f
    clc
    ret
2:  mov ah, 0x3e
    int 0x21
3:  stc
    ret

/* Save the currently selected catalogue filename. Errors are non-fatal. */
save_last_choice:
    xor ax, ax
    mov al, byte ptr [selected_id]
    mov dl, FILE_SIZE
    mul dl
    mov si, offset font_files
    add si, ax
    jmp save_choice

save_requested_choice:
    mov si, offset requested_file
save_choice:
    push ax
    push bx
    push cx
    push dx
    push si
    mov dx, offset last_choice_path
    xor cx, cx
    mov ah, 0x3c
    int 0x21
    jc 2f
    mov bx, ax
    xor cx, cx
    mov dx, si
1:  cmp byte ptr [si], 0
    je 3f
    inc si
    inc cx
    jmp 1b
3:  mov ah, 0x40
    int 0x21
    mov ah, 0x3e
    int 0x21
2:  pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/*
 * Unload only when our handlers are still at the head of both chains.
 * Removing a TSR from underneath a later-installed hook would leave that
 * program's chain pointing into freed memory.
 */
unload_tsr:
    mov ax, 0x3510
    int 0x21
    cmp bx, offset int10_handler
    jne unload_unsafe
    mov ax, es
    cmp ax, word ptr [resident_seg]
    jne unload_unsafe

    mov ax, 0x352f
    int 0x21
    cmp bx, offset int2f_handler
    jne unload_unsafe
    mov ax, es
    cmp ax, word ptr [resident_seg]
    jne unload_unsafe

    /* Copy the original vectors out before freeing the resident block. */
    mov es, word ptr [resident_seg]
    mov ax, word ptr es:[old_int10]
    mov word ptr [saved_10_off], ax
    mov ax, word ptr es:[old_int10+2]
    mov word ptr [saved_10_seg], ax
    mov ax, word ptr es:[old_int2f]
    mov word ptr [saved_2f_off], ax
    mov ax, word ptr es:[old_int2f+2]
    mov word ptr [saved_2f_seg], ax

    /* Put the adapter font back while our INT 2Fh service still exists. */
    mov ax, MUX_STANDARD
    int 0x2f

    push ds
    mov dx, word ptr cs:[saved_10_off]
    mov ax, word ptr cs:[saved_10_seg]
    mov ds, ax
    mov ax, 0x2510
    int 0x21
    mov dx, word ptr cs:[saved_2f_off]
    mov ax, word ptr cs:[saved_2f_seg]
    mov ds, ax
    mov ax, 0x252f
    int 0x21
    pop ds

    mov es, word ptr [resident_seg]
    mov ah, 0x49
    int 0x21
    jc unload_free_failed
    mov dx, offset msg_unloaded
    mov ah, 9
    int 0x21
    mov ax, 0x4c00
    int 0x21

unload_unsafe:
    mov dx, offset msg_unload_unsafe
    mov ah, 9
    int 0x21
    mov ax, 0x4c01
    int 0x21

unload_free_failed:
    mov dx, offset msg_unload_failed
    mov ah, 9
    int 0x21
    mov ax, 0x4c01
    int 0x21

detect_vga:
    mov ax, 0x1a00
    int 0x10
    cmp al, 0x1a
    jne 1f
    clc
    ret
1:  stc
    ret

validate_text_mode:
    mov ah, 0x0f
    int 0x10
    cmp ah, 80
    jne 2f
    cmp al, 2
    je 1f
    cmp al, 3
    je 1f
    cmp al, 7
    jne 2f
    mov word ptr [video_segment], 0xB000
    clc
    ret
1:  mov word ptr [video_segment], 0xB800
    clc
    ret
2:  stc
    ret

install_tsr:
    /* Save old vectors. */
    mov ax, 0x3510
    int 0x21
    mov word ptr [old_int10], bx
    mov word ptr [old_int10+2], es
    mov ax, 0x352f
    int 0x21
    mov word ptr [old_int2f], bx
    mov word ptr [old_int2f+2], es

    /* Install new vectors. */
    push ds
    push cs
    pop ds
    mov dx, offset int10_handler
    mov ax, 0x2510
    int 0x21
    mov dx, offset int2f_handler
    mov ax, 0x252f
    int 0x21
    pop ds

    /* Release our environment block; it need not remain resident. */
    mov es, word ptr [0x2c]
    mov ax, es
    or ax, ax
    jz 1f
    mov ah, 0x49
    int 0x21
1:  ret

/*
 * Render the embedded TEXTDEMO.OUT bytes as glyphs, not DOS controls.
 * Begin at the current console cursor, retain the existing display, and
 * scroll normally if the demonstration reaches the bottom of the screen.
 */
draw_charset:
    push es
    mov ax, word ptr [video_segment]
    mov es, ax
    mov ah, 3
    xor bh, bh
    int 0x10                           /* DH=row, DL=column */
    call menu_setpos
    mov si, offset charset_display_data
1:  cmp si, offset charset_bottom_rule
    jae 5f
    mov al, byte ptr [si]
    cmp al, 13
    jne 2f
    mov bx, si
    inc bx
    cmp bx, offset charset_bottom_rule
    jae 2f
    cmp byte ptr [bx], 10
    jne 2f
    add si, 2
    inc dh
    xor dl, dl
    jmp 3f
2:  inc si
    mov ah, 0x07
    stosw
    inc dl
    cmp dl, 80
    jb 4f
    xor dl, dl
    inc dh
3:  cmp dh, 25
    jb 6f
    mov ax, 0x0601                    /* scroll the complete text screen */
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184f
    int 0x10
    mov dx, 0x1800
6:  call menu_setpos
4:  jmp 1b
5:  mov ah, 2
    xor bh, bh
    int 0x10
    pop es
    ret

save_screen:
    mov ah, 3
    xor bh, bh
    int 0x10
    mov word ptr [saved_cursor_pos], dx
    mov word ptr [saved_cursor_shape], cx
    push ds
    push es
    mov ax, word ptr [video_segment]
    mov ds, ax
    push cs
    pop es
    xor si, si
    mov di, offset screen_save
    mov cx, 2000
    rep movsw
    pop es
    pop ds
    ret

restore_screen:
    push ds
    push es
    push cs
    pop ds
    mov ax, word ptr [video_segment]
    mov es, ax
    mov si, offset screen_save
    xor di, di
    mov cx, 2000
    rep movsw
    pop es
    pop ds
    mov cx, word ptr [saved_cursor_shape]
    mov ah, 1
    int 0x10
    mov dx, word ptr [saved_cursor_pos]
    mov ah, 2
    xor bh, bh
    int 0x10
    ret

/* Overlay a PS/2-style selector sized for one through five rows of fonts. */
draw_menu:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov ax, word ptr [video_segment]
    mov es, ax

    /* rows=ceil(font_count/5), top=10-rows, bottom=top+2*rows+4. */
    xor ax, ax
    mov al, byte ptr [font_count]
    add al, 4
    mov bl, 5
    div bl
    mov cl, al
    mov dl, 10
    sub dl, al
    mov byte ptr [dialog_top], dl
    add dl, 2
    mov byte ptr [name_row], dl
    mov al, cl
    shl al, 1
    add al, byte ptr [dialog_top]
    add al, 4
    mov byte ptr [dialog_bottom], al

    /* Blue modal dialog, columns 5..74. */
    xor dx, dx
    mov dl, byte ptr [dialog_top]
1:  mov ax, dx
    mov bx, 160
    push dx
    mul bx
    pop dx
    add ax, 10
    mov di, ax
    mov ax, 0x1720
    mov cx, 70
    rep stosw
    inc dx
    mov al, byte ptr [dialog_bottom]
    xor ah, ah
    cmp dx, ax
    jbe 1b

    /* Cyan single-line border. */
    xor dx, dx
    mov dh, byte ptr [dialog_top]
    mov dl, 5
    call menu_setpos
    mov ax, 0x1bda
    stosw
    mov ax, 0x1bc4
    mov cx, 68
    rep stosw
    mov ax, 0x1bbf
    stosw

    xor dx, dx
    mov dl, byte ptr [dialog_top]
    inc dl
1:  mov ax, dx
    mov bx, 160
    push dx
    mul bx
    pop dx
    add ax, 10
    mov di, ax
    mov ax, 0x1bb3
    stosw
    add di, 136
    stosw
    inc dx
    mov al, byte ptr [dialog_bottom]
    xor ah, ah
    cmp dx, ax
    jb 1b

    xor dx, dx
    mov dh, byte ptr [dialog_bottom]
    mov dl, 5
    call menu_setpos
    mov ax, 0x1bc0
    stosw
    mov ax, 0x1bc4
    mov cx, 68
    rep stosw
    mov ax, 0x1bd9
    stosw

    xor dx, dx
    mov dh, byte ptr [dialog_top]
    mov dl, 8
    call menu_setpos
    mov ah, 0x1e
    mov si, offset title
    call putstr
    xor cx, cx
2:
    /* Position in a five-column grid: 12-character fields, 1-cell gaps. */
    mov ax, cx
    mov bl, 5
    div bl
    mov dh, al
    shl dh, 1
    add dh, byte ptr [name_row]
    mov dl, ah
    mov al, 13
    mul dl
    mov dl, al
    add dl, 9
    call menu_setpos

    xor ax, ax
    mov al, cl
    mov dl, NAME_SIZE
    mul dl
    mov si, offset font_names
    add si, ax
    mov bp, di
    mov bx, si
    xor ax, ax
name_length_loop:
    cmp byte ptr [bx], 0
    je name_length_done
    inc bx
    inc al
    jmp name_length_loop
name_length_done:
    mov bl, 12
    sub bl, al
    shr bl, 1
    xor bh, bh
    shl bx, 1
    add di, bx
    mov ah, 0x1f
    cmp cl, byte ptr [selected_id]
    jne 3f
    mov ah, 0x3f
    mov ax, 0x3f20
    mov word ptr es:[di-2], ax
    mov bx, si
    mov ah, 0x3f
    call putstr
    mov ax, si
    sub ax, bx
    dec ax                              /* exclude the terminating NUL */
    shl ax, 1
    mov bx, di
    add bx, ax
    mov word ptr es:[bx], 0x3f20
    jmp 4f
3:  call putstr
4:
    inc cx
    xor ax, ax
    mov al, byte ptr [font_count]
    cmp cx, ax
    jb 2b

    /* Instructions: normal cyan text, keys in bright green. */
    xor dx, dx
    mov dh, byte ptr [dialog_bottom]
    sub dh, 2
    mov dl, 9
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr1a
    call putstr
    mov dl, 13
    call menu_setpos
    mov ax, 0x1a1b
    stosw
    mov dl, 14
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr1b
    call putstr
    mov dl, 19
    call menu_setpos
    mov ax, 0x1a1a
    stosw
    mov dl, 20
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr1c
    call putstr

    mov dh, byte ptr [dialog_bottom]
    dec dh
    mov dl, 9
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr2a
    call putstr
    mov dl, 15
    call menu_setpos
    mov ax, 0x1a11                    /* CP437 17: left-pointing triangle */
    stosw
    mov ax, 0x1ac4
    stosw
    mov ax, 0x1ad9
    stosw
    mov dl, 18
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr2b
    call putstr
    mov dl, 39
    call menu_setpos
    mov ah, 0x1a
    mov si, offset instr_esc
    call putstr
    mov dl, 42
    call menu_setpos
    mov ah, 0x1b
    mov si, offset instr2c
    call putstr

    /* Hide cursor while menu is active. */
    mov ah, 1
    mov cx, 0x2607
    int 0x10
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* DH=row, DL=column; return ES:DI byte offset. */
menu_setpos:
    push ax
    push bx
    xor ax, ax
    mov al, dh
    mov bl, 160
    mul bl
    xor bx, bx
    mov bl, dl
    shl bx, 1
    add ax, bx
    mov di, ax
    pop bx
    pop ax
    ret

/* ES=video, DI=destination byte offset, AH=attribute, DS:SI=NUL string. */
putstr:
    push ax
    push di
1:  lodsb
    or al, al
    jz 2f
    stosw
    jmp 1b
2:  pop di
    pop ax
    ret

preview_selected:
    mov dl, byte ptr [selected_id]
    or dl, dl
    jz 1f
    call load_selected_font
    jc 2f
    mov si, offset font_work
    mov cx, FONT_SIZE
    mov ax, MUX_PREVIEW
    int 0x2f
    ret
1:  mov ax, MUX_PREV_STD
    int 0x2f
2:
    ret

title:      .asciz " Select display font "
instr1a:    .asciz "Use "
instr1b:    .asciz " and "
instr1c:    .asciz " to select the display font."
instr2a:    .asciz "Press "
instr2b:    .asciz " to activate font or "
instr_esc:  .asciz "Esc"
instr2c:    .asciz " to quit."
help_text:
    .ascii "FONTSEL 0.6 - VGA Display Font Selector\r\n"
    .ascii "\r\n"
    .ascii "Selects and previews VGA text fonts and keeps the chosen font active\r\n"
    .ascii "after BIOS video-mode changes. Fonts are read from fonts\\fonts.lst.\r\n"
    .ascii "\r\n"
    .ascii "Usage:  FONTSEL [/? | /U | /C | /L [fontfile]]\r\n"
    .ascii "\r\n"
    .ascii "        no option   Open the font selector\r\n"
    .ascii "        /C          Show the character set, then open the selector\r\n"
    .ascii "        /L          Load the last activated font without opening the menu\r\n"
    .ascii "        /L file     Load file from the fonts directory without the menu\r\n"
    .ascii "        /U          Restore the default VGA font and unload the TSR\r\n"
    .ascii "        /?          Display this help screen\r\n"
    .ascii "\r\n"
    .ascii "Run FONTSEL from the directory containing its fonts subdirectory.\r\n$"
msg_no_vga: .ascii "FONTSEL requires VGA or compatible hardware.\r\n$"
msg_bad_mode:.ascii "FONTSEL requires an 80-column text mode.\r\n$"
msg_bad_font_list:.ascii "FONTSEL cannot read a valid fonts\\fonts.lst file.\r\n$"
msg_load_failed:.ascii "FONTSEL cannot load the requested or last activated font.\r\n$"
msg_font_set:.ascii "Display font set to $"
msg_font_set_end:.ascii ".\r\n$"
msg_not_installed:.ascii "FONTSEL is not resident.\r\n$"
msg_unloaded:.ascii "FONTSEL unloaded; default VGA font restored.\r\n$"
msg_unload_unsafe:.ascii "FONTSEL cannot unload: another TSR has hooked INT 10h or INT 2Fh after it.\r\n$"
msg_unload_failed:.ascii "FONTSEL restored the interrupt vectors, but DOS could not release its memory block.\r\n$"
msg_previous_resident:
    .ascii "An earlier PS2FONT TSR is already resident.\r\n"
    .ascii "Unload it with the previous executable before starting FONTSEL.\r\n"
    .ascii "Suggested command using the current directory:\r\n\r\n  $"
msg_previous_command:
    .ascii "PS2FONT.COM /U\r\n\r\nThen run FONTSEL again.\r\n$"

font_list_path: .asciz "fonts\\fonts.lst"
last_choice_path:.asciz "fonts\\fontsel.dat"
font_prefix:    .ascii "fonts\\"
font_path:      .space 20, 0
requested_file:.space FILE_SIZE, 0
font_names:     .space MAX_FONTS * NAME_SIZE, 0
font_files:     .space MAX_FONTS * FILE_SIZE, 0
list_buffer:    .space LIST_BUFFER_SIZE, 0
font_work:      .space FONT_SIZE, 0
cwd_buffer:     .space 68, 0

.balign 2
screen_save:
    .space 4000, 0

/*
 * Exact binary character demonstration supplied as TEXTDEMO.OUT.  The first
 * and last 78-byte records are its 76-character horizontal rules plus CR/LF;
 * retain them in the source image for reproducibility but do not display them.
 */
charset_top_rule:
    .incbin "TEXTDEMO.OUT", 0, 78
charset_display_data:
    .incbin "TEXTDEMO.OUT", 78, 991
charset_bottom_rule:
    .incbin "TEXTDEMO.OUT", 1069, 78
charset_data_end:

program_end:
