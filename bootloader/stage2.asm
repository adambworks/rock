;detect memory map (INT 15h e820)

;enable A20 line (so you can access > 1MB memory)

;set up a GDT

;switch to protected mode (32-bit)

;set up paging + long mode (64-bit)

;load kernel ELF into memory

;jump into kernel entry point


[BITS 16]
[ORG 0x8000]

;load_kernel:
    mov si, dap
    mov ah, 0x42        ; extended read
    mov dl, 0x80        ; first hard disk
    int 0x13
    jc disk_error
    



;enable a20 fast
;@author osdev.org/A20 Line
in al, 0x92
test al, 2
jnz after_a20
or al, 2
and al, 0xFE
out 0x92, al
after_a20:
; 




;move to / protected mode
cli
lgdt[gdt_descriptor]
;change last bit of cr0 to 1
mov eax, cr0
or eax, 1
mov cr0, eax ; 32 bit mode

jmp code_seg:start_protected_mode




disk_error:
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x4F44    ; 'D' white on red
    mov word [es:2], 0x4F53    ; 'S'
    mov word [es:4], 0x4F4B    ; 'K'
    
    cli
.hang:
    hlt
    jmp .hang




gdt_descriptor:
    dw gdt_end - gdt_start -1 ; size
    dd gdt_start








;________________________________________________________
;32 protected mod
;________________________________________________________


[bits 32]
start_protected_mode:

;setup paging for long mode



  ; copy from 0x10000 → 0x100000
  ;old way of moving binary into where i want to load
  ;  mov esi, 0x10000
  ;  mov edi, 0x100000
  ;  mov ecx, 64 * 512       ; same number of sectors * 512 bytes
  ;  rep movsb


PML4_TABLE equ 0x1000
PDPT_TABLE equ 0x2000
PD_TABLE   equ 0x3000

 
call load_elf ;loads elf
call setup_paging ; sets up paging
call enable_long_mode ; enables and jumps to long mode

;________________________________
;32 bit routinies
;________________________________
ELF_BASE equ 0x10000

load_elf:
    ; --- Verify ELF magic: bytes 0-3 should be 0x7F,'E','L','F'
    mov eax, dword [ELF_BASE]
    cmp eax, 0x464C457F     ; little-endian: 0x7F 'E' 'L' 'F'
    jne elf_error

    ; --- Read entry point from ELF header offset 0x18 (e_entry, 64-bit)
    ; For a 64-bit ELF, e_entry is at offset 0x18 and is 8 bytes.
    ; We only use the low 32 bits here (fine for addresses < 4GB)
    mov eax, dword [ELF_BASE + 0x18]
    mov [kernel_entry], eax         ; save for later

    ; --- Get program header offset (e_phoff at 0x20 in 64-bit ELF)
    mov eax, dword [ELF_BASE + 0x20]    ; e_phoff low 32 bits
    ; program header table starts at: ELF_BASE + e_phoff
    add eax, ELF_BASE
    mov esi, eax                        ; esi = pointer to first phdr

    ; --- Get number of program headers (e_phnum at 0x38 in 64-bit ELF)
    movzx ecx, word [ELF_BASE + 0x38]   ; e_phnum

    ; --- Get program header entry size (e_phentsize at 0x36)
    movzx ebx, word [ELF_BASE + 0x36]   ; e_phentsize (usually 0x38 = 56 bytes)

.ph_loop:
    test ecx, ecx
    jz .done

    ; Check p_type (offset 0 in phdr) == PT_LOAD (1)
    mov eax, dword [esi + 0x00]
    cmp eax, 1
    jne .next_ph

    ; p_offset (offset 0x08 in 64-bit phdr) — where in file
    mov eax, dword [esi + 0x08]         ; low 32 bits of p_offset

    ; p_paddr  (offset 0x18 in 64-bit phdr) — physical load address
    mov edi, dword [esi + 0x18]         ; destination in memory

    ; p_filesz (offset 0x20 in 64-bit phdr) — bytes to copy
    mov edx, dword [esi + 0x20]

    ; p_memsz  (offset 0x28 in 64-bit phdr) — total size in memory
    mov dword [tmp_memsz], edx          ; save filesz temporarily
    mov edx, dword [esi + 0x28]         ; memsz

    ; Copy p_filesz bytes from (ELF_BASE + p_offset) to p_paddr
    push ecx
    push esi
    mov esi, ELF_BASE
    add esi, eax                        ; source = ELF_BASE + p_offset
    mov ecx, dword [tmp_memsz]         ; count = filesz
    rep movsb                           ; copy to edi (p_paddr)

    ; Zero out (memsz - filesz) bytes — this covers BSS
    mov ecx, edx                        ; memsz
    sub ecx, dword [tmp_memsz]         ; memsz - filesz
    xor eax, eax
    rep stosb                           ; zero remaining bytes at edi
    pop esi
    pop ecx

.next_ph:
    add esi, ebx                        ; advance by e_phentsize
    dec ecx
    jmp .ph_loop

.done:
    ret

elf_error:
    mov edi, 0xB8000
    mov byte [edi],   'E'
    mov byte [edi+1], 0x4F   ; white on red — hard to miss
    mov byte [edi+2], 'L'
    mov byte [edi+3], 0x4F
    mov byte [edi+4], 'F'
    mov byte [edi+5], 0x4F
    cli
.hang:
    hlt
    jmp .hang

tmp_memsz: dd 0
kernel_entry: dd 0


setup_paging:
    ; Clear out the page tables memory (zero them)
    ; We'll zero 3 pages = 3 * 4096 bytes
    mov edi, PML4_TABLE
    mov ecx, 4096 * 3 / 4      ; number of dwords to clear
    xor eax, eax
    rep stosd

    ; ----------------------------
    ; PML4[0] = PDPT_TABLE | flags
    ; ----------------------------
    mov eax, PDPT_TABLE
    or eax, 0x3                ; Present + Writable
    mov dword [PML4_TABLE], eax
    mov dword [PML4_TABLE+4], 0

    ; ----------------------------
    ; PDPT[0] = PD_TABLE | flags
    ; ----------------------------
    mov eax, PD_TABLE
    or eax, 0x3                ; Present + Writable
    mov dword [PDPT_TABLE], eax
    mov dword [PDPT_TABLE+4], 0

    ; ----------------------------
    ; PD[0] = 2MB page mapping
    ; ----------------------------
    mov eax, 0x00000000
    or eax, 0x83               ; Present + Writable + PS (bit 7)
    mov dword [PD_TABLE], eax
    mov dword [PD_TABLE+4], 0

    ret


enable_long_mode:
    ; 1) Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5          ; set bit 5 (PAE)
    mov cr4, eax

    ; 2) Enable Long Mode in the EFER MSR
    mov ecx, 0xC0000080     ; EFER MSR
    rdmsr                   ; read into EDX:EAX
    or eax, 1 << 8          ; set LME bit (bit 8)
    wrmsr                   ; write back


    ; 3) Load CR3 with the address of the PML4 table
    mov eax, PML4_TABLE
    mov cr3, eax



    ; 4) Enable Paging in CR0
    mov eax, cr0
    or eax, 1 << 31         ; set PG bit (bit 31)
    mov cr0, eax



   
    ; 5) Far jump into 64-bit mode
    jmp code_seg64:long_mode_entry


;__________________________________________________
;64
;
;

[BITS 64]
long_mode_entry:
; Now reload the segment registers (CS, DS, SS, etc.) with the appropriate segment selectors...
 mov ax, data_seg64
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

  
        ; setup stack
    mov rsp, 0x90000
    and rsp, -16            ; 16-byte align (VERY important)

    mov rax, 0xb8000
    mov byte [rax],   'O'
    mov byte [rax+1], 0x0F
    mov byte [rax+2], 'K'
    mov byte [rax+3], 0x0F

      ; Load entry point saved by load_elf
    mov eax, dword [kernel_entry]   ; zero-extended into rax
    jmp rax

.hang:
    hlt
    jmp .hang




;______________________________________
;data
;______________________________________

section .data
;GDT
gdt_start:
   ; null_ descriptor:
        dd 0 ; four times 00000000 or 4 bytes of 0 
        dd 0
    code_descriptor:
        dw 0xffff
        dw 0 ; 16 bits of base 
        db 0 ; other 8 bits of base
        db 0b10011010; flags
        db 0b11001111; other and last four bits of limit
        db 0
     data_descriptor:
        dw 0xffff
        dw 0 ; 16 bits of base 
        db 0 ; other 8 bits of base
        db 0b10010010; flags
        db 0b11001111; other and last four bits of limit
        db 0
    code_descriptor64:
        dw 0x0000           ; limit ignored in 64-bit mode
        dw 0x0000
        db 0x00
        db 0b10011010        ; access: present, ring0, code, readable
        db 0b00100000        ; flags: gran=0, 32-bit=0, long=1
        db 0x00

    data_descriptor64:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0b10010010        ; access: present, ring0, data, writable
        db 0b11001111        ; flags okay (ignored mostly)
        db 0x00

    
gdt_end:

code_seg: equ code_descriptor - gdt_start
data_seg: equ data_descriptor - gdt_start
code_seg64: equ code_descriptor64 - gdt_start
data_seg64: equ data_descriptor64 - gdt_start



; Disk Address Packet (16 bytes)
dap:
    db 0x10             ; size of packet
    db 0
    dw 80               ; number of sectors to read (adjust if needed)
    dw 0x0000           ; offset
    dw 0x1000           ; segment (0x1000:0000 = 0x10000)
    dq 10                ; starting LBA (skip bootloader)

