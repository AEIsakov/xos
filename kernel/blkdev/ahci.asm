
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

; AHCI ABAR Structure
AHCI_ABAR_CAP			= 0x0000
AHCI_ABAR_HOST_CONTROL		= 0x0004
AHCI_ABAR_INTERRUPT_STATUS	= 0x0008
AHCI_ABAR_PORTS			= 0x000C
AHCI_ABAR_VERSION		= 0x0010
AHCI_ABAR_COMMAND_CONTROL	= 0x0014
AHCI_ABAR_COMMAND_PORTS		= 0x0018
AHCI_ABAR_ENCLOSURE_LOCATION	= 0x001C
AHCI_ABAR_ENCLOSURE_CONTROL	= 0x0020
AHCI_ABAR_HOST_CAP		= 0x0024
AHCI_ABAR_HANDOFF		= 0x0028
AHCI_ABAR_RESERVED		= 0x002C
AHCI_ABAR_VENDOR_SPECIFIC	= 0x00A0
AHCI_ABAR_PORT_CONTROL		= 0x0100

; AHCI Port Structure
AHCI_PORT_COMMAND_LIST		= 0x0000
AHCI_PORT_FIS			= 0x0008
AHCI_PORT_IRQ_STATUS		= 0x0010
AHCI_PORT_IRQ_ENABLE		= 0x0014
AHCI_PORT_COMMAND		= 0x0018
AHCI_PORT_RESERVED0		= 0x001C
AHCI_PORT_TASK_FILE		= 0x0020
AHCI_PORT_SIGNATURE		= 0x0024
AHCI_PORT_SATA_STATUS		= 0x0028
AHCI_PORT_SATA_CONTROL		= 0x002C
AHCI_PORT_SATA_ERROR		= 0x0030
AHCI_PORT_SATA_ACTIVE		= 0x0034
AHCI_PORT_COMMAND_ISSUE		= 0x0038
AHCI_PORT_SATA_NOTIFICATION	= 0x003C
AHCI_PORT_FIS_CONTROL		= 0x0040
AHCI_PORT_RESERVED1		= 0x0044
AHCI_PORT_VENDOR_SPECIFIC	= 0x0070

; FIS Types
AHCI_FIS_H2D			= 0x27
AHCI_FIS_D2H			= 0x34

; Command Set
SATA_IDENTIFY			= 0xEC
SATA_READ_LBA28			= 0xC8
SATA_READ_LBA48			= 0x25
SATA_WRITE_LBA28		= 0xCA
SATA_WRITE_LBA48		= 0x35

pci_ahci_bus			db 0
pci_ahci_slot			db 0
pci_ahci_function		db 0

align 4
ahci_abar			dd 0
;ahci_port_count		db 0	; counts how many ports are present

; ahci_detect:
; Detects a AHCI controller

ahci_detect:
	mov esi, .starting_msg
	call kprint

	mov ax, 0x0106
	call pci_get_device_class

	cmp al, 0xFF
	je .no

	mov [pci_ahci_bus], al
	mov [pci_ahci_slot], ah
	mov [pci_ahci_function], bl

	mov esi, .found_msg
	call kprint

	mov al, [pci_ahci_bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ahci_slot]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ahci_function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; map the AHCI memory
	mov al, [pci_ahci_bus]
	mov ah, [pci_ahci_slot]
	mov bl, [pci_ahci_function]
	mov dl, 5		; bar5
	call pci_map_memory

	cmp eax, 0
	je .no_memory

	mov [ahci_abar], eax

	; enable MMIO, DMA, disable IRQs
	mov al, [pci_ahci_bus]
	mov ah, [pci_ahci_slot]
	mov bl, [pci_ahci_function]
	mov bh, PCI_STATUS_COMMAND
	call pci_read_dword

	or eax, 0x406
	;or eax, 6

	mov edx, eax
	mov al, [pci_ahci_bus]
	mov ah, [pci_ahci_slot]
	mov bl, [pci_ahci_function]
	mov bh, PCI_STATUS_COMMAND
	call pci_write_dword

	mov [.port], 0

.loop:
	mov bl, [.port]
	call ahci_identify

	inc [.port]
	cmp [.port], 31
	jg .finish

	jmp .loop

.finish:
	ret

.no:
	mov esi, .no_msg
	call kprint
	ret

.no_memory:
	mov esi, .no_memory_msg
	call kprint
	ret

.starting_msg			db "ahci: detecting AHCI controller...",10,0
.no_msg				db "ahci: AHCI controller not present.",10,0
.found_msg			db "ahci: found AHCI controller on PCI slot ",0
.colon				db ":",0
.no_memory_msg			db "ahci: insufficient memory.",10,0
.port				db 0

; ahci_disable_cache:
; Disables caching

ahci_disable_cache:
	wbinvd
	mov eax, cr0
	or eax, 0x60000000
	mov cr0, eax
	ret

; ahci_enable_cache:
; Enables caching

ahci_enable_cache:
	wbinvd
	mov eax, cr0
	and eax, not 0x60000000
	mov cr0, eax
	ret

; ahci_identify:
; Identifies an AHCI device
; In\	BL = Port Number
; Out\	Nothing

ahci_identify:
	mov [.port], bl

	call ahci_disable_cache

	mov cl, [.port]
	mov eax, 1
	shl eax, cl
	test dword[ahci_abar+AHCI_ABAR_PORTS], eax
	jz .quit

	movzx edi, [.port]
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

	mov eax, [edi+AHCI_PORT_SIGNATURE]
	cmp eax, 0x0101		; SATA?
	jne .quit

	; if it's SATA, identify the drive
	; clear all nescessary structures
	mov edi, ahci_command_list
	mov ecx, end_ahci_command_list - ahci_command_list
	xor al, al
	rep stosb

	mov edi, ahci_command_table
	mov ecx, end_ahci_command_table - ahci_command_table
	xor al, al
	rep stosb

	; make the command list
	mov [ahci_command_list.cfis_length], (end_ahci_command_fis-ahci_command_fis+3) / 4
	mov [ahci_command_list.prdt_length], 1
	mov dword[ahci_command_list.command_table], ahci_command_table

	; the command FIS
	mov [ahci_command_fis.fis_type], AHCI_FIS_H2D
	mov [ahci_command_fis.flags], 0x80
	mov [ahci_command_fis.command], SATA_IDENTIFY	; 0xEC
	;mov [ahci_command_fis.count], 1

	; the PRDT
	mov dword[ahci_prdt.base], sata_identify_data
	mov [ahci_prdt.count], 511

	; send the command to the device
	movzx edi, [.port]
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

	mov eax, [edi+AHCI_PORT_IRQ_STATUS]
	mov [edi+AHCI_PORT_IRQ_STATUS], eax

	and dword[edi+AHCI_PORT_COMMAND], not 1
	and dword[edi+AHCI_PORT_COMMAND_ISSUE], not 1
	mov dword[edi+AHCI_PORT_COMMAND_LIST], ahci_command_list
	mov dword[edi+AHCI_PORT_COMMAND_LIST+4], 0

.wait_bsy:
	sti
	hlt
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80
	jnz .wait_bsy

.send_command:
	or dword[edi+AHCI_PORT_COMMAND], 1
	or dword[edi+AHCI_PORT_COMMAND_ISSUE], 1

.loop:
	sti
	hlt
	test dword[edi+AHCI_PORT_COMMAND_ISSUE], 1
	jz .after_loop
	test dword[edi+AHCI_PORT_TASK_FILE], 0x01	; error
	jnz .error
	test dword[edi+AHCI_PORT_TASK_FILE], 0x20	; drive fault

	loop .loop
	jmp .error

.after_loop:
	; turn off the command execution
	and dword[edi+AHCI_PORT_COMMAND], not 1
	and dword[edi+AHCI_PORT_COMMAND_ISSUE], not 1

	;mov eax, [edi+AHCI_PORT_IRQ_STATUS]
	;mov [edi+AHCI_PORT_IRQ_STATUS], eax

	mov eax, [edi+AHCI_PORT_TASK_FILE]
	test al, 0x01		; error
	jnz .error

	test al, 0x20		; drive fault
	jnz .error

	cmp [ahci_command_list.prdt_byte_count], 512	; did the DMA transfer all the data?
	jne .error					; nope -- bail out

	mov esi, .sata_model_msg
	call kprint

	mov esi, sata_identify_data.model
	call swap_string_order
	call trim_string
	call kprint
	mov esi, .sata_model_msg2
	call kprint

	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; register the device
	mov al, BLKDEV_AHCI
	mov ah, BLKDEV_PARTITIONED
	movzx edx, [.port]
	call blkdev_register

.quit:
	call ahci_enable_cache
	ret

.error:
	mov esi, .error_msg
	call kprint

	call ahci_enable_cache
	ret

.port				db 0
.sata_model_msg			db "ahci: found SATA device '",0
.sata_model_msg2		db "' on AHCI port ",0
.error_msg			db "ahci: failed to receive identify information from SATA drive.",10,0

; ahci_read:
; Reads from an AHCI SATA device
; In\	EDX:EAX	= LBA sector
; In\	ECX = Sector count
; In\	BL = Port number
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device task file register

ahci_read:
	;;
	;; TO-DO: Check if the device is SATAPI, and then read it instead of SATA.
	;;

	mov [.port], bl
	mov dword[.lba], eax
	mov dword[.lba+4], edx
	mov [.count], ecx
	mov [.buffer], edi

	call ahci_disable_cache

	; ahci uses DMA so we need physical address
	mov eax, [.buffer]
	and eax, 0xFFFFF000
	call vmm_get_page
	test dl, PAGE_PRESENT	; the DMA is not aware of paging, so we need to do this for safety...
	jz .memory_error

	mov ebx, [.buffer]
	and ebx, 0xFFF
	add eax, ebx
	mov [.buffer_phys], eax

	; clear all nescessary structures
	mov edi, ahci_command_list
	mov ecx, end_ahci_command_list - ahci_command_list
	xor al, al
	rep stosb

	mov edi, ahci_command_table
	mov ecx, end_ahci_command_table - ahci_command_table
	xor al, al
	rep stosb

	; make the command list
	mov [ahci_command_list.cfis_length], 5
	mov [ahci_command_list.prdt_length], 1
	mov dword[ahci_command_list.command_table], ahci_command_table

	; the command FIS
	mov [ahci_command_fis.fis_type], AHCI_FIS_H2D
	mov [ahci_command_fis.flags], 0x80
	mov [ahci_command_fis.command], SATA_READ_LBA28
	mov [ahci_command_fis.device], 0xE0
	mov eax, [.count]
	mov [ahci_command_fis.count], ax

	; LBA...
	mov eax, dword[.lba]
	mov [ahci_command_fis.lba0], al
	shr eax, 8
	mov [ahci_command_fis.lba1], al
	shr eax, 8
	mov [ahci_command_fis.lba2], al
	shr eax, 8
	mov [ahci_command_fis.lba3], al

	;mov eax, dword[.lba+4]
	;mov [ahci_command_fis.lba4], al
	;shr eax, 8
	;mov [ahci_command_fis.lba5], al

	; the PRDT
	mov eax, [.buffer_phys]
	mov dword[ahci_prdt.base], eax
	mov eax, [.count]
	shl eax, 9	; mul 512
	dec eax
	mov [ahci_prdt.count], eax

	; send the command to the device
	movzx edi, [.port]
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

	mov eax, [edi+AHCI_PORT_IRQ_STATUS]
	mov [edi+AHCI_PORT_IRQ_STATUS], eax

	and dword[edi+AHCI_PORT_COMMAND], not 1
	and dword[edi+AHCI_PORT_COMMAND_ISSUE], not 1
	mov dword[edi+AHCI_PORT_COMMAND_LIST], ahci_command_list
	mov dword[edi+AHCI_PORT_COMMAND_LIST+4], 0

.wait_bsy:
	sti
	hlt
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80
	jnz .wait_bsy

.send_command:
	or dword[edi+AHCI_PORT_COMMAND], 1
	or dword[edi+AHCI_PORT_COMMAND_ISSUE], 1

.loop:
	sti
	hlt
	test dword[edi+AHCI_PORT_COMMAND_ISSUE], 1
	jz .after_loop
	test dword[edi+AHCI_PORT_TASK_FILE], 0x01	; error
	jnz .error
	test dword[edi+AHCI_PORT_TASK_FILE], 0x20	; drive fault

	loop .loop
	jmp .error

.after_loop:
	; turn off the command execution
	and dword[edi+AHCI_PORT_COMMAND], not 1
	and dword[edi+AHCI_PORT_COMMAND_ISSUE], not 1

	;mov eax, [edi+AHCI_PORT_IRQ_STATUS]
	;mov [edi+AHCI_PORT_IRQ_STATUS], eax

	mov eax, [edi+AHCI_PORT_TASK_FILE]
	test al, 0x01		; drive error?
	jnz .error

	test al, 0x20		; drive fault?
	jnz .error

	mov eax, [.count]
	mov ebx, [ahci_prdt.count]
	shl eax, 9
	cmp [ahci_command_list.prdt_byte_count], eax
	jne .error

	call ahci_enable_cache
	mov eax, 0
	ret

.error:
	movzx edi, [.port]
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

	mov ebx, [edi+AHCI_PORT_TASK_FILE]
	mov [.task_file], bl

	call ahci_enable_cache

	mov esi, .error_msg
	call kprint
	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, .error_msg2
	call kprint
	mov al, [.task_file]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	ret

.memory_error:
	call ahci_enable_cache

	mov esi, .memory_error_msg
	call kprint
	mov eax, [.buffer]
	call hex_dword_to_string
	call kprint
	mov esi, .memory_error_msg2
	call kprint

	mov ax, 0xFF01
	ret

.lba			dq 0
.port			db 0
.count			dd 0
.buffer			dd 0
.buffer_phys		dd 0
.task_file		db 0
.error_msg		db "ahci: hardware error on port ",0
.error_msg2		db "; task file 0x",0
.memory_error_msg	db "ahci: attempted to write to non-present page (0x",0
.memory_error_msg2	db ")",10,0

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; ahci_command_list:
; Names says^^
align 4096
ahci_command_list:
	.cfis_length		db (end_ahci_command_fis-ahci_command_fis) / 4
	.port_multiplier	db 0
	.prdt_length		dw 1

	.prdt_byte_count	dd 0

	.command_table		dq ahci_command_table

	times 4 dd 0
	times 31*8 dd 0

end_ahci_command_list:

; ahci_command_table:
; Name says again^^
align 4096
ahci_command_table:

ahci_command_fis:
	.fis_type		db AHCI_FIS_H2D
	.flags			db 0x80
	.command		db 0
	.feature_low		db 0

	.lba0			db 0
	.lba1			db 0
	.lba2			db 0
	.device			db 0

	.lba3			db 0
	.lba4			db 0
	.lba5			db 0
	.feature_high		db 0

	.count			dw 0
	.icc			db 0
	.control		db 0

	.reserved		dd 0

end_ahci_command_fis:

	times 0x80 - ($-ahci_command_table) db 0

ahci_prdt:
	.base			dq 0
	.reserved		dd 0
	.count			dd 0

end_ahci_command_table:

; sata_identify_data:
; Data returned from the SATA/SATAPI IDENTIFY command
align 16
sata_identify_data:
	.device_type		dw 0		; 0

	.cylinders		dw 0		; 1
	.reserved_word2		dw 0		; 2
	.heads			dw 0		; 3
				dd 0		; 4
	.sectors_per_track	dw 0		; 6
	.vendor_unique:		times 3 dw 0	; 7
	.serial_number:		times 20 db 0	; 10
				dd 0		; 11
	.obsolete1		dw 0		; 13
	.firmware_revision:	times 8 db 0	; 14
	.model:			times 40 db 0	; 18
	.maximum_block_transfer	db 0
				db 0
				dw 0

				db 0
	.dma_support		db 0
	.lba_support		db 0
	.iordy_disable		db 0
	.iordy_support		db 0
				db 0
	.standyby_timer_support	db 0
				db 0
				dw 0

				dd 0
	.translation_fields	dw 0
				dw 0
	.current_cylinders	dw 0
	.current_heads		dw 0
	.current_spt		dw 0
	.current_sectors	dd 0
				db 0
				db 0
				db 0
	.user_addressable_secs	dd 0
				dw 0
	times 512 - ($-sata_identify_data) db 0




