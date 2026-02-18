; stage1.asm
; BIOS loads this at 0x7C00 and jumps to it
; Must be exactly 512 bytes with signature 0x55AA at the end

[BITS 16]
[ORG 0x7C00]

start:
    cli                     ; disable interrupts while setting up

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; stack grows downward, put it safely here

    sti                     ; re-enable interrupts

    ; Print message
    mov si, msg_stage1
    call print_string

    ; Load stage2 into memory at 0x0000:0x8000
    ; TODO load with LBA istead of chs
    mov bx, 0x8000          ; offset
    mov dh, 4               ; number of sectors to read (adjust later)
    call load_stage2

    ; Jump to stage2
    jmp 0x0000:0x8000


; ----------------------------
; print_string
; Prints a null-terminated string pointed to by SI
; ----------------------------
print_string:
    pusha
.print_loop:
    lodsb                   ; loads byte from [SI] into AL, increments SI
    cmp al, 0
    je .done
    mov ah, 0x0E            ; BIOS teletype function
    mov bh, 0x00            ; page number
    mov bl, 0x07            ; text attribute (light gray)
    int 0x10
    jmp .print_loop
.done:
    popa
    ret


; ----------------------------
; load_stage2
; Loads DH sectors starting at sector 2 into ES:BX
; Uses BIOS int 13h (CHS mode)
;
; ES:BX = destination buffer
; DH = number of sectors
; ----------------------------
load_stage2:
    pusha

    mov ah, 0x02            ; BIOS read sectors function
    mov al, dh              ; number of sectors to read
    mov ch, 0x00            ; cylinder 0
    mov dh, 0x00            ; head 0
    mov cl, 0x02            ; sector 2 (sector 1 is this boot sector)
    mov dl, 0x80            ; drive number (0x80 = first hard disk)

    int 0x13
    jc disk_error           ; carry flag means error

    popa
    ret


disk_error:
    mov si, msg_disk_error
    call print_string
    cli
.hang:
    hlt
    jmp .hang


msg_stage1 db "Stage 1 loaded", 13, 10, 0
msg_disk_error db "Disk read error!", 13, 10, 0


; Pad boot sector to 510 bytes
times 510 - ($ - $$) db 0

; Boot signature
dw 0xAA55
