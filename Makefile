ASM = nasm
QEMU = qemu-system-x86_64
CARGO   = cargo
OBJCOPY = rust-objcopy

STAGE1 = stage1.bin
STAGE2 = stage2.bin
KERNEL  = kernel.bin
IMG = disk.img

KERNEL_ELF = kernel/target/x86_64-unknown-none/release/kernel

all: $(IMG)

# --------------------------
# Bootloader stages
# --------------------------


$(STAGE1): bootloader/stage1.asm
	$(ASM) -f bin bootloader/stage1.asm -o $(STAGE1)

$(STAGE2): bootloader/stage2.asm
	$(ASM) -f bin bootloader/stage2.asm -o $(STAGE2)	

# --------------------------
# Build Rust kernel
# --------------------------

$(KERNEL_ELF):
	cd kernel && $(CARGO) build --release --target x86_64-unknown-none

$(KERNEL): $(KERNEL_ELF)
	$(OBJCOPY) \
		--binary-architecture i386:x86-64 \
		$< \
		-O binary \
		$@

$(IMG): $(STAGE1) $(STAGE2) $(KERNEL)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(STAGE1) of=$(IMG) conv=notrunc
	dd if=$(STAGE2) of=$(IMG) bs=512 seek=1 conv=notrunc
	dd if=$(KERNEL) of=$(IMG) bs=512 seek=10 conv=notrunc


run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)

clean:
	rm -f $(STAGE1) $(STAGE2) $(KERNEL) $(IMG)
	cd kernel && $(CARGO) clean