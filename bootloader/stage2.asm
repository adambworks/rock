;detect memory map (INT 15h e820)

;enable A20 line (so you can access > 1MB memory)

;set up a GDT

;switch to protected mode (32-bit)

;set up paging + long mode (64-bit)

;load kernel ELF into memory

;jump into kernel entry point


[BITS 16]
[ORG 0x8000]




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

in al, 0x92
call print_hex16
;should see 0002 for a20 enabled




;move to / protected mode
cli
lgdt[gdt_descriptor]
;change last bit of cr0 to 1
mov eax, cr0
or eax, 1
mov cr0, eax ; 32 bit mode

jmp code_seg:start_protected_mode











; -----------------------------
; print_hex16
; Prints AX as 4 hex digits
; Uses BIOS int 10h teletype
; -----------------------------
print_hex16:
    pusha               ; save registers

    mov bx, ax          ; copy AX into BX (so we can shift it)

    mov cx, 4           ; 4 hex digits
.hex_loop:
    mov ax, bx
    shr ax, 12          ; top nibble into low bits (bits 12-15)

    call print_nibble

    shl bx, 4           ; shift next nibble into top position
    loop .hex_loop

    popa
    ret


; -----------------------------
; print_nibble
; input: AL = value 0-15
; prints one hex digit
; -----------------------------
print_nibble:
    and al, 0x0F        ; keep only bottom 4 bits

    cmp al, 9
    jbe .digit

    add al, 55          ; 'A' - 10 = 65 - 10 = 55
    jmp .print

.digit:
    add al, '0'

.print:
    mov ah, 0x0E
    int 0x10
    ret


gdt_descriptor:
    dw gdt_end - gdt_start -1 ; size
    dd gdt_start

code_seg: equ code_descriptor - gdt_start
data_seg: equ data_descriptor - gdt_start





;________________________________________________________
;32 protected mod
;________________________________________________________


[bits 32]
start_protected_mode:
   
call clear_screen
mov eax, 0xDEADBEEF
call write_reg

 

mov al, 'A'
    mov ah, 0x0f
    mov [0x000B87D0], ax

hlt

;setup paging for long mode


PML4_TABLE equ 0x1000
PDPT_TABLE equ 0x2000
PD_TABLE   equ 0x3000

call setup_paging






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
    jmp CODE64_SEL:long_mode_entry



clear_screen:
pusha
mov al, ' '        
mov ah, 0x07  
mov ebx, 0xb8000
mov ecx, 2000
.clear_loop
    mov [ebx], ax
    add ebx, 2
    loop .clear_loop   
popa
ret


write_reg:
; input: EAX
pusha




mov ecx, 8            ; 8 hex digits
mov ebx, 0xb8000      ; vga fram buffer
.print_nibble_loop:
    mov edx, eax
    shr edx, 28       ; top nibble in lower 4 bits
    call print_hex_nibble
    ;mov [ebp -8],ebx 
    shl eax, 4        ; shift next nibble into top
    loop .print_nibble_loop

popa    
ret

print_hex_nibble:
    and dl, 0x0F
    cmp dl, 9
    jbe .digit
    add dl, 'A' - 10
    jmp .done
.digit:
    add dl, '0'
.done:
    mov dh, 0x07
    mov [ebx], dx
    add ebx, 2
    ret


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
gdt_end:

