.code16
.arch i8086
.intel_syntax noprefix
.section .text
.global _start

/* CHARSET.COM - visual IBM PC/VGA character-set test for 80-column DOS. */

_start:
    push cs
    pop ds
    cld
    mov ah, 0x0f
    int 0x10
    cmp ah, 80
    jne bad_mode
    mov word ptr [video_segment], 0xb800
    cmp al, 7
    jne 1f
    mov word ptr [video_segment], 0xb000
1:  mov ax, word ptr [video_segment]
    mov es, ax

    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    rep stosw

    mov dh, 0
    mov dl, 0
    call setpos
    mov si, offset title
    mov ah, 0x0f
    call putstr

    mov dh, 1
    mov dl, 0
    call setpos
    mov si, offset pangram
    mov ah, 0x07
    call putstr

    mov dh, 2
    mov dl, 0
    call setpos
    mov si, offset misc_label
    mov ah, 0x07
    call putstr
    mov dl, 1
    mov cx, 31
2:  mov al, dl
    mov ah, 0x07
    stosw
    mov ax, 0x0720
    stosw
    inc dl
    loop 2b

    mov dh, 3
    mov dl, 0
    call setpos
    mov si, offset currency
    mov ah, 0x07
    call putstr

    mov dh, 4
    mov dl, 0
    call setpos
    mov si, offset grid_heading
    mov ah, 0x0e
    call putstr
    mov dh, 4
    mov dl, 40
    call setpos
    mov si, offset drawing_heading
    mov ah, 0x0e
    call putstr

    /* All 256 character codes in a 16 by 16 grid. */
    mov byte ptr [grid_row], 0
    mov byte ptr [glyph_value], 0
3:  mov dh, byte ptr [grid_row]
    add dh, 6
    mov dl, 0
    call setpos
    xor bx, bx
    mov bl, byte ptr [grid_row]
    mov al, byte ptr [hex_digits+bx]
    mov ah, 0x08
    stosw
    mov ax, 0x073a
    stosw
    mov ax, 0x0720
    stosw
    mov cx, 16
4:  mov al, byte ptr [glyph_value]
    mov ah, 0x07
    stosw
    mov ax, 0x0720
    stosw
    inc byte ptr [glyph_value]
    loop 4b
    inc byte ptr [grid_row]
    cmp byte ptr [grid_row], 16
    jb 3b

    /* Box-drawing and shading demonstration on the right. */
    mov dh, 6
    mov dl, 40
    call setpos
    mov ax, 0x07da
    stosw
    mov ax, 0x07c4
    mov cx, 37
    rep stosw
    mov ax, 0x07bf
    stosw
    mov dh, 7
5:  mov dl, 40
    call setpos
    mov ax, 0x07b3
    stosw
    mov dl, 78
    call setpos
    stosw
    inc dh
    cmp dh, 21
    jb 5b
    mov dh, 21
    mov dl, 40
    call setpos
    mov ax, 0x07c0
    stosw
    mov ax, 0x07c4
    mov cx, 37
    rep stosw
    mov ax, 0x07d9
    stosw

    mov dh, 8
    mov dl, 43
    call setpos
    mov si, offset shade_label
    mov ah, 0x07
    call putstr
    mov dh, 10
    mov dl, 43
    call setpos
    mov cx, 8
    mov ax, 0x07b0
    rep stosw
    mov cx, 8
    mov ax, 0x07b1
    rep stosw
    mov cx, 8
    mov ax, 0x07b2
    rep stosw

    mov dh, 12
    mov dl, 43
    call setpos
    mov si, offset blocks_label
    mov ah, 0x07
    call putstr
    mov dh, 14
    mov dl, 43
    call setpos
    mov cx, 6
    mov ax, 0x07db
    rep stosw
    mov cx, 6
    mov ax, 0x07dc
    rep stosw
    mov cx, 6
    mov ax, 0x07df
    rep stosw
    mov cx, 6
    mov ax, 0x07fe
    rep stosw

    mov dh, 17
    mov dl, 43
    call setpos
    mov si, offset lines_label
    mov ah, 0x07
    call putstr
    mov dh, 19
    mov dl, 43
    call setpos
    mov si, offset line_sample
    mov ah, 0x07
    call putstr

    mov ah, 2
    xor bh, bh
    mov dx, 0x1800
    int 0x10
    mov ax, 0x4c00
    int 0x21

bad_mode:
    mov dx, offset error_text
    mov ah, 9
    int 0x21
    mov ax, 0x4c01
    int 0x21

/* DH=row, DL=column; returns ES:DI text-memory position. */
setpos:
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

/* Write NUL-terminated DS:SI at ES:DI using attribute AH. */
putstr:
1:  lodsb
    or al, al
    jz 2f
    stosw
    jmp 1b
2:  ret

video_segment: .word 0xb800
grid_row:      .byte 0
glyph_value:   .byte 0
hex_digits:    .ascii "0123456789ABCDEF"

title:           .asciz "IBM VGA / DOS Character Set (Code Page 437)"
pangram:         .asciz "The quick brown fox jumped over the lazy dogs.  (,.;!? :)  0123456789"
misc_label:      .asciz "Misc: "
currency:        .ascii "Currency: $ "
                 .byte 0x9b, ' ', 0x9c, ' ', 0x9d, ' ', 0x9e, ' ', 0x9f
                 .ascii "     Arrows: "
                 .byte 0x1b,' ',0x1a,' ',0x18,' ',0x19,' ',0x1d,0
grid_heading:    .asciz "Character codes 00h-FFh"
drawing_heading: .asciz "Other drawing characters"
shade_label:     .asciz "Shading: light / medium / dark"
blocks_label:    .asciz "Blocks: full / lower / upper / square"
lines_label:     .asciz "Single and double lines:"
line_sample:     .byte 0xda,0xc4,0xc2,0xc4,0xbf,' ',0xc9,0xcd,0xcb,0xcd,0xbb,' '
                 .byte 0xc3,0xc4,0xc5,0xc4,0xb4,' ',0xcc,0xcd,0xce,0xcd,0xb9,0
error_text:      .ascii "CHARSET requires an 80-column text mode.\r\n$"
