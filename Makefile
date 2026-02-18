ASM = nasm
QEMU = qemu-system-x86_64

STAGE1 = stage1.bin
STAGE2 = stage2.bin
IMG = disk.img

all: $(IMG)

$(STAGE1): bootloader/stage1.asm
	$(ASM) -f bin bootloader/stage1.asm -o $(STAGE1)

$(STAGE2): bootloader/stage2.asm
	$(ASM) -f bin bootloader/stage2.asm -o $(STAGE2)	

$(IMG): $(STAGE1) $(STAGE2)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(STAGE1) of=$(IMG) conv=notrunc
	dd if=$(STAGE2) of=$(IMG) bs=512 seek=1 conv=notrunc


run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)

clean:
	rm -f $(STAGE1) $(IMG)
