AS=as
LD=ld

all: FONTSEL.COM

FONTSEL.COM: FONTSEL.S
	$(AS) --32 -o FONTSEL.o FONTSEL.S
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ FONTSEL.o

clean:
	rm -f FONTSEL.o FONTSEL.COM CHARSET.o CHARSET.COM
