
; struct directory_t
; {
;	u8 name[32];	// 0x00
;	u32 lba;	// 0x20
;	u32 size_sects;	// 0x24
;	u32 size_bytes;	// 0x28
;	u8 time[2];	// 0x2C
;	u8 date[2];	// 0x2E
;	u16 year;	// 0x30
;	u8 flags;	// 0x32
;	u8 reserved[13];// 0x33
; }

kernel:
	.name		db "kernel32.sys",0
			times 32 - ($-.name) db 0

	.lba		dd 200
	.size_sects	dd 400
	.size_bytes	dd 400*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

shell:
	.name		db "shell.exe",0
			times 32 - ($-.name) db 0

	.lba		dd 4020
	.size_sects	dd 20
	.size_bytes	dd 20*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

shellcfg:
	.name		db "shell.cfg",0
			times 32 - ($-.name) db 0

	.lba		dd 4040
	.size_sects	dd 1
	.size_bytes	dd 1*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

wp1:
	.name		db "wp1.bmp",0
			times 32 - ($-.name) db 0

	.lba		dd 1000
	.size_sects	dd 2813
	.size_bytes	dd 1440138
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

hello:
	.name		db "hello.exe",0
			times 32 - ($-.name) db 0

	.lba		dd 4000
	.size_sects	dd 1
	.size_bytes	dd 1*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

draw:
	.name		db "draw.exe",0
			times 32 - ($-.name) db 0

	.lba		dd 4001
	.size_sects	dd 1
	.size_bytes	dd 1*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

buttontest:
	.name		db "buttontest.exe",0
			times 32 - ($-.name) db 0

	.lba		dd 4002
	.size_sects	dd 5
	.size_bytes	dd 5*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

calc:
	.name		db "calc.exe",0
			times 32 - ($-.name) db 0

	.lba		dd 4010
	.size_sects	dd 10
	.size_bytes	dd 10*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0

