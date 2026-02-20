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
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, 32 * 512       ; same number of sectors * 512 bytes
    rep movsb


PML4_TABLE equ 0x1000
PDPT_TABLE equ 0x2000
PD_TABLE   equ 0x3000

call setup_paging
call enable_long_mode





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



    ; jump to kernel entry (0x100000)
    mov rax, 0x100000

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
        db 0b10101111        ; flags: gran=1, 32-bit=0, long=1
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
    dw 32               ; number of sectors to read (adjust if needed)
    dw 0x0000           ; offset
    dw 0x1000           ; segment (0x1000:0000 = 0x10000)
    dq 10                ; starting LBA (skip bootloader)

