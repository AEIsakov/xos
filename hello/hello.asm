
; Hello World Application for xOS
; Simply creates a window and prints Hello World on it

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

main:
	; create the window
	mov ebp, 0		; create window function
	mov ax, 350		; X pos
	mov bx, 192		; Y pos
	mov si, 256		; width
	mov di, 130		; height
	mov dx, 0		; flags -- undefined for now, must be zero
	mov ecx, title		; titlebar text
	int 0x60		; call kernel

	; eax = window handle
	mov [window_handle], eax

	mov ebp, 7		; draw text in window
	mov eax, [window_handle]; window handle
	mov esi, text		; pointer to text
	mov cx, 8		; X pos
	mov dx, 16		; Y pos
	mov ebx, 0		; color
	int 0x60		; call kernel

.hang:
	mov ebp, 1		; give control to next task
	int 0x60
	jmp .hang

	title			db "Hello world",0
	text			db "Welcome to the Hello World ",10
				db "application!",10
				db "If you are reading this, xOS",10
				db "can load applications from",10
				db "disk!",0
	window_handle		dd 0




