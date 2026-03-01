ASM = nasm
QEMU = qemu-system-x86_64
CARGO   = cargo
OBJCOPY = rust-objcopy

STAGE1 = stage1.bin
STAGE2 = stage2.bin
KERNEL  = kernel.bin
KERNEL_DEBUG = kerenel_debug.bin
IMG = disk.img
IMG_DEBUG = disk_debug.img

KERNEL_ELF = kernel/target/x86_64-unknown-none/release/kernel
#KERNEL_ELF_DEBUG= kernel/target/x86_64-unknown-none/debug/kernel

RUST_SOURCES := $(shell find kernel/src -name "*.rs")

all: $(IMG)

# --------------------------
# Bootloader stages
# --------------------------


$(STAGE1): bootloader/stage1.asm
	$(ASM) -f bin bootloader/stage1.asm -o $(STAGE1)

$(STAGE2): bootloader/stage2.asm
	$(ASM) -f bin bootloader/stage2.asm -o $(STAGE2)	

# --------------------------
# Build Rust kernel debug
# --------------------------

#$(KERNEL_ELF_DEBUG): $(RUST_SOURCES)
#	cd kernel && $(CARGO) build  --target x86_64-unknown-none

#$(KERNEL_DEBUG): $(KERNEL_ELF_DEBUG)
#	$(OBJCOPY) \
		--binary-architecture i386:x86-64 \
		$< \
		-O binary \
		$@

#$(IMG_DEBUG): $(STAGE1) $(STAGE2) $(KERNEL_DEBUG)
#	dd if=/dev/zero of=$(IMG_DEBUG) bs=512 count=2880
#	dd if=$(STAGE1) of=$(IMG_DEBUG) conv=notrunc
#	dd if=$(STAGE2) of=$(IMG_DEBUG) bs=512 seek=1 conv=notrunc
#	dd if=$(KERNEL_DEBUG) of=$(IMG_DEBUG) bs=512 seek=10 conv=notrunc



# --------------------------
# Build Rust kernel 
# --------------------------

$(KERNEL_ELF): $(RUST_SOURCES)
	cd kernel && $(CARGO) build --release --target x86_64-unknown-none

#$(KERNEL): $(KERNEL_ELF)
#	$(OBJCOPY) \
		--binary-architecture i386:x86-64 \
		$< \
		-O binary \
		$@

$(IMG): $(STAGE1) $(STAGE2) $(KERNEL_ELF)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(STAGE1) of=$(IMG) conv=notrunc
	dd if=$(STAGE2) of=$(IMG) bs=512 seek=1 conv=notrunc
	dd if=$(KERNEL_ELF) of=$(IMG) bs=512 seek=10 conv=notrunc





run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)


#run_debug: $(IMG_DEBUG)
#	($(QEMU) -drive format=raw,file=$(IMG_DEBUG) -s -S)
#	& sleep 1; \
	rust-gdb $(KERNEL_DEBUG) -ex "target remote :1234"

clean:
	rm -f $(STAGE1) $(STAGE2) $(KERNEL_ELF) $(IMG) $(KERNEL_DEBUG) $(IMG_DEBUG)
	cd kernel && $(CARGO) clean