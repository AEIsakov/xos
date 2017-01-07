
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use16
org 0x1000

	jmp 0x0000:kmain16

	kernel_version			db "xOS32 v0.07 (7 January 2017)",0
	copyright_str			db "Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.",0
	newline				db 10,0

	align 16
	stack16:			rb 3072

; kmain16:
; 16-bit stub before kernel

kmain16:
	cli
	cld
	mov ax, 0
	mov es, ax

	mov di, boot_partition
	mov cx, 16
	rep movsb

	mov ax, 0
	mov ss, ax
	mov ds, ax
	mov fs, ax
	mov gs, ax
	mov sp, stack16+2048

	mov [bios_boot_device], dl

	sti
	nop

	;mov ax, 3
	;int 0x10

	mov si, newline
	call print16
	mov si, kernel_version
	call print16
	mov si, newline
	call print16
	mov si, copyright_str
	call print16
	mov si, newline
	call print16
	mov si, newline
	call print16

	; save control registers state by BIOS
	; probably needed if we return to real mode later for video mode switches
	mov eax, cr0
	mov [bios_cr0], eax
	mov eax, cr4
	mov [bios_cr4], eax

	; enable SSE2
	mov eax, 1
	cpuid
	;test edx, 1 shl 25
	test edx, 1 shl 26	; movdqa is an SSE2 instruction; SSE support without SSE2 makes undefined opcode
	jz no_sse

	mov eax, 0x600
	mov cr4, eax

	mov eax, cr0
	and eax, 0xFFFFFFFB
	or eax, 2
	mov cr0, eax

	; do things that are easier to do with BIOS
	call detect_memory
	call enable_a20
	call check_a20
	call do_vbe

	; prepare to go to pmode
	; disable NMI
	mov al, 0x80
	out 0x70, al
	out 0x80, al
	out 0x80, al
	in al, 0x71

	; notify the BIOS we're going to work in pmode
	mov eax, 0xEC00
	mov ebx, 1
	int 0x15

	; save PIC masks
	in al, 0x21
	mov [bios_pic1_mask], al
	in al, 0xA1
	mov [bios_pic2_mask], al

	; disable the PIC
	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	; wait for queued IRQs to be handled
	mov ecx, 0xFF

.pic_wait:
	sti
	out 0x80, al
	out 0x80, al
	loop .pic_wait

	mov al, 0x20
	out 0x20, al
	out 0xA0, al

	; disable NMI
	mov al, 0x80
	out 0x70, al
	out 0x80, al
	out 0x80, al
	in al, 0x71

	cli
	lgdt [gdtr]
	lidt [idtr]

	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp 0x08:kmain32	; kernel code descriptor

no_sse:
	mov si, .msg
	call print16
	cli
	hlt

.msg				db "Boot error: CPU doesn't support SSE2.",0

use32

; kmain32:
; 32-bit kernel entry point
align 16
kmain32:
	mov ax, 0x10	; kernel data descriptor
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	movzx esp, sp	; temporarily use the 16-bit stack
			; after that, the system idle process will automatically use newly allocated stack --
			; -- which will be allocated in mm_init

	; prepare screen so that we can draw stuff
	mov eax, [screen.height]
	mov ebx, [screen.bytes_per_line]
	mul ebx
	mov [screen.screen_size], eax
	shr eax, 7
	mov [screen.screen_size_dqwords], eax
	call use_front_buffer
	call unlock_screen

	; set IOPL to zero and reset all flags
	push 0x00000002
	popfd

	; initialize the math coprocessor
	finit
	fwait

	; enable PMC in userspace
	mov eax, cr4
	or eax, 0x100
	mov cr4, eax

	; names of functions say enough of what they do ;)
	call com1_detect
	call install_exceptions
	call mm_init
	call pic_init
	call pit_init
	call ps2_init
	call syscall_init
	call tasking_init
	call acpi_init
	call acpi_aml_init
	;call apic_init
	call pci_init
	call blkdev_init
	call xfs_detect
	call wm_init
	call use_back_buffer
	call unlock_screen

	mov esi, test_task
	call create_task

	mov esi, test_task2
	call create_task

	mov esi, test_task3
	call create_task

	call yield

test_task		db "hello.exe",0
test_task2		db "draw.exe",0
test_task3		db "button.exe",0

; idle_process:
; The only process on the system which runs in ring 0
; All it does is keep the CPU halted until it's time for a task switch or IRQ
; This cools down the CPU and is needed on overclocked laptops to prevent overheating
align 32
idle_process:
	sti
	hlt
	call yield

	;
	; END OF MAIN KERNEL CODE
	; INCLUDE KERNEL STUFF
	;

	;==================================================
	;==================================================

	; x86 stuff
	include "kernel/x86/early.asm"		; early routines that depends on bios
	include "kernel/x86/modes.asm"		; TSS, GDT, IDT
	include "kernel/x86/pic.asm"		; PIC driver
	include "kernel/x86/apic.asm"		; APIC driver

	; Firmware
	include "kernel/firmware/vbe.asm"	; VBE 2.0 driver
	include "kernel/firmware/pit.asm"	; PIT driver
	include "kernel/firmware/pci.asm"	; PCI driver

	; ACPI
	include "kernel/acpi/tables.asm"	; ACPI table functions
	include "kernel/acpi/aml.asm"		; ACPI AML functions
	include "kernel/acpi/sleep.asm"		; ACPI sleeping code

	; Miscellaneous Stuff
	include "kernel/misc/kprint.asm"	; debugging stuff
	include "kernel/misc/string.asm"	; string manipulation
	include "kernel/misc/panic.asm"		; kernel panic & exceptions

	; Memory Manager
	include "kernel/mm/mm.asm"		; MM initialization code
	include "kernel/mm/pmm.asm"		; physical memory manager
	include "kernel/mm/vmm.asm"		; virtual memory manager
	include "kernel/mm/heap.asm"		; malloc() and free()
	include "kernel/mm/mtrr.asm"		; MTRR manager

	; I/O Device Drivers
	include "kernel/iodev/ps2.asm"		; PS/2 keyboard/mouse driver

	; Block Device Drivers
	include "kernel/blkdev/blkdev.asm"	; Generic storage device interface
	include "kernel/blkdev/ata.asm"		; ATA driver
	include "kernel/blkdev/ahci.asm"	; AHCI driver

	; Graphics
	include "kernel/gui/gdi.asm"		; Graphics library
	;include "kernel/gui/desktop.asm"	; Desktop
	include "kernel/gui/wm.asm"		; Window manager
	include "kernel/gui/canvas.asm"		; Window canvas functions

	; Multitasking Stuff
	include "kernel/tasking/tasking.asm"	; Main scheduler code
	include "kernel/tasking/syscalls.asm"	; System calls table and handler

	; Filesystem
	include "kernel/fs/xfs.asm"		; XFS
	;include "kernel/fs/iso9660.asm"	; ISO9660 will be here someday

	; Default mouse cursor
	cursor:
	;file "kernel/gui/themes/cursor_black.bmp"	; choose whichever cursor you like
	file "kernel/gui/themes/cursor_white.bmp"	; or even make your own; in Paint and GIMP use a 24-bit bitmap
	; Default bitmap font
	font:
	file "kernel/fonts/term.bin"
	;file "kernel/fonts/alotware.bin"
	;file "kernel/fonts/cp437.bin"
	;include "kernel/fonts/glaux-mono.asm"






