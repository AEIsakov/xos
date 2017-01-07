
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

MAXIMUM_FUNCTION		= 0x0012

; Function Table ;)
align 16
api_table:
	dd wm_create_window	; 0x0000
	dd yield		; 0x0001
	dd wm_pixel_offset	; 0x0002
	dd wm_redraw		; 0x0003
	dd wm_read_event	; 0x0004
	dd wm_read_mouse	; 0x0005
	dd wm_get_window	; 0x0006
	dd wm_draw_text		; 0x0007
	dd wm_clear		; 0x0008
	dd malloc		; 0x0009
	dd free			; 0x000A
	dd xfs_open		; 0x000B
	dd xfs_close		; 0x000C
	dd xfs_seek		; 0x000D
	dd xfs_tell		; 0x000E
	dd xfs_read		; 0x000F
	dd 0;xfs_write		; 0x0010
	dd wm_render_char	; 0x0011
	dd wm_kill		; 0x0012

; syscall_init:
; Installs the kernel API interrupt vector

syscall_init:
	mov al, 0x60		; int 0x60
	mov ebp, kernel_api
	call install_isr

	mov al, 0x60
	mov dl, 0xEE		; set interrupt privledge to userspace
	call set_isr_privledge

	ret

; kernel_api:
; INT 0x60 Handler
; In\	EBP = Function code
; In\	All other registers = Depends on function input
; Out\	All registers = Depends on function output; all undefined registers destroyed
align 32
kernel_api:
	cmp ebp, MAXIMUM_FUNCTION
	jg .done

	sti

	shl ebp, 2	; mul 4
	add ebp, api_table
	mov ebp, [ebp]
	call ebp

.done:
	iret




