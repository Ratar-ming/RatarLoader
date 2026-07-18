;这里的代码已经以LGPL全部开源
[org 0100h]
%include "..\include\Protect\protect.inc"
mov ax,cs
cmp ax,0x410
jnz	.cs_mistake
jmp LABEL_BEGIN

.cs_mistake:
	mov si,ax
	shl si,4
	mov ax,0
	mov ds,ax
	mov es,ax
	mov di,0x4200
	mov cx,1536;3KB
	cld
	rep movsw
	jmp 0x410:0x100
[SECTION .gdt]
LABEL_GDT: Descriptor 0,0,0                ; 空描述符
LABEL_DESC_CODE32: Descriptor 0,SegCode32Len-1,DA_C+DA_32;   非一致代码段,32位
Data: Descriptor 0,0xffffffff,DA_DRW+DA_32+DA_LIMIT_4K;   4GB
Global_Code32:		Descriptor 0,0xffffffff,DA_C+DA_32+DA_LIMIT_4K

GdtLen	equ $-LABEL_GDT
GdtPtr	dw GdtLen-1
	dd 0

SelectorCode32	equ	LABEL_DESC_CODE32	-LABEL_GDT
SelectorData	equ	Data	-LABEL_GDT
SelectorGlobal_Code32	equ	Global_Code32 - LABEL_GDT

pdir	equ 0x101000
PG_UALLOC	EQU  PG_RW|PG_S
[section .data]
_MemSize dd 0
MemSize	equ _MemSize+0x4100

_VMODE db 0
VMODE	equ _VMODE+0x4100

_SCRNX dw 0
SCRNX	equ _SCRNX+0x4100

_SCRNY dw 0
SCRNY	equ _SCRNY+0x4100

_VRAM dd 0xA000
VRAM equ _VRAM+0x4100

_addr_desc dw 0
addr_desc	equ		_addr_desc+0x4100

_FileName db "KERNEL  SYS",0
_DirName  db "RATAR      ",0
_BMPName  db "LOGO    BMP",0
FileName	equ	_FileName+0x4100
DirName		equ	_DirName+0x4100
BMPName		equ _BMPName+0x4100
MemInfoBuf	equ 0x9FB0
Paletter:
	db 0x00, 0x00, 0x00
	db 0xff, 0x00, 0x00
	db 0x00, 0xff, 0x00
	db 0xff, 0xff, 0x00
	db 0x00, 0x00, 0xff
	db 0xff, 0x00, 0xff
	db 0x00, 0xff, 0xff
	db 0xff, 0xff, 0xff
	db 0xc6, 0xc6, 0xc6
	db 0x84, 0x00, 0x00
	db 0x00, 0x84, 0x00
	db 0x84, 0x84, 0x00
	db 0x00, 0x00, 0x84
	db 0x84, 0x00, 0x84
	db 0x00, 0x84, 0x84
	db 0x84, 0x84, 0x84

%include '..\include\Files\BPB.inc'
[SECTION .s16]
[bits 16]
LABEL_BEGIN:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 05000h
	mov eax,0
	mov esi,eax
	mov edi,eax
	
;下面开始初始化设备
	pushad
	mov ax,0xE801
	int 0x15
	jc errors
	movzx eax,bx
	mov ebx,0x10000
	mul ebx
	add eax,0x1000000;加上未检测的16M
	mov [_MemSize],eax;字节数

;检查VBE是否存在
	MOV AX,0x9000
	MOV ES,AX
	MOV DI,0
	MOV AX,0x4f00
	INT 0x10
	jc errors
	CMP AX,0x004f
	JNE scrn320
;检查VBE版本
	MOV AX,[ES:DI+4]
	CMP AX,0x0200
	JB scrn320
;检查模式是否可用
	MOV CX,0x107
	MOV AX,0x4f01
	INT 0x10
	jc errors
	CMP AX,0x004f
	JNE scrn320
;确认模式信息
	CMP BYTE [ES:DI+0x19],8
	JNE scrn320
	CMP BYTE [ES:DI+0x1b],4
	JNE scrn320
	MOV AX,[ES:DI+0x00]
	AND AX,0x0080
	JZ scrn320
;进入对应模式
	MOV BX,0x107+0x4000
	MOV AX,0x4f02
	INT 0x10
	jc errors
	MOV BYTE [_VMODE],8
	MOV AX,[ES:DI+0x12]
	MOV [_SCRNX],AX
	MOV AX,[ES:DI+0x14]
	MOV [_SCRNY],AX
	MOV EAX,[ES:DI+0x28]
	MOV [_VRAM],EAX
	JMP SetPal

scrn320:
	MOV AL,0x13
	MOV AH,0x00
	INT 0x10
	jc errors
	MOV BYTE [_VMODE],8
	MOV WORD [_SCRNX],320
	MOV WORD [_SCRNY],200
	MOV DWORD [_VRAM],0xa0000

SetPal:
	push es
	pushfd
	mov dx,0x03c8
	mov bx,Paletter
	mov ax,cs
	mov es,ax
	mov ax,0
	out dx,al
	inc dx
	mov cx,48
.loop:
	mov al,[es:bx]
	out dx,al
	inc bx
	loop .loop

	popfd
	pop es

;初始化完成
exit:
	popad

;开始准备内存分布信息，这十分重要
	pushad;0x27e
	xor esi,esi
.call:
	mov ebx,0
	mov ax,MemInfoBuf
	mov es,ax
	mov eax,0xe820
	mov di,0;放在物理地址0x9fb00开始的256字节的区域
	mov ecx,20
	mov edx,0x534d4150
	int 0x15
	jc errors
	inc esi
.loop:
	mov eax,0xe820
	mov ecx,20
	mov edx,0x534d4150
	int 0x15
	jc .loop
	add di,20
	inc esi
	test ebx,ebx
	jne .loop
	mov [_addr_desc],si;保存地址结构数
.done:
	popad
	
;下面准备进入保护模式
	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, LABEL_SEG_CODE32
	mov word [LABEL_DESC_CODE32+2], ax
	shr eax, 16
	mov byte [LABEL_DESC_CODE32+4], al
	mov byte [LABEL_DESC_CODE32+7], ah

	xor eax, eax
	mov ax, ds
	shl eax, 4
	add eax, LABEL_GDT
	mov dword [GdtPtr+2], eax

	lgdt [GdtPtr]

	cli

	in al, 92h
	or al, 00000010b
	out 92h, al

	mov eax, cr0
	or eax, 1
	mov cr0, eax

	jmp dword SelectorCode32:0;0x32a

errors:
	cli
	hlt
;=======================此处已进入保护模式,上方的都只能是数据=========================================
[SECTION .code32]
[bits 32]
LABEL_SEG_CODE32:
	mov ax,SelectorData
	mov gs,ax
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov ss,ax
	mov esp,0x9f00

	call draw
	
	
	
;===========================================================================================
	xor eax,eax
	movzx eax,byte [BPB_NumFATs];数量
	mov ebp,[BPB_FATSz32];FAT大小
	mul ebp
	movzx ebp,word [BPB_RsvdSecCnt]
	add eax,ebp;得到起始地址
	mov ebp,eax
	
	mov eax,[BPB_RootClusNum];根目录簇号
	mov ebx,0;根目录加载地址
.loadFile:
	mov edi,eax;备份簇号
	sub eax,2
	add eax,ebp
	mov ecx,1
	inc esi
	call ReadSector
	
	mov eax,edi;恢复簇号
	mov ecx,128;每个FAT都有128个FAT项
	mov edx,eax
	shr edx,16;32位除法，高位放dx，低位放ax
	
	div ecx;计算目标FAT的偏移扇区。ax为扇区偏移，dx为项偏移
	movzx edi,dx;转移
	movzx eax,ax;清理高位
	
	movzx edx,word [BPB_RsvdSecCnt]
	add eax,edx;得到绝对FAT扇区号
	
	mov cx,1
	mov edx,ebx;备份
	mov ebx,0x4000;FAT加载缓存
	call ReadSector;读FAT
	
	mov ebx,edx;恢复ebx
	mov eax,[0x4000+edi*4];读取下一个簇号
	cmp eax,0x0fffffff;看读完了没
	jc .loadFile;小于这个数说明没有，继续
	;这里已完成
	
;===============================================================================
	xor ebx,ebx;目录地址
	mov eax,esi;根目录扇区数量
	mov esi,BMPName
	call seek;在根目录寻找logo
	cmp eax,0
	jnz .Error
	
	mov ebx,0xb21000;在内核地址加载，以后可以覆盖掉
	call load;加载logo

	pushad
	mov edi,0xe0000000
	mov esi,0xb21000;因为后续加载内核时间可能比较长，先画出来先，免得干等不知所措
	call draw_BMP;绘制开机画面
	cmp ax,0
	jnz .Error
	popad
;==============================================================================	
	mov ebx,0;目录地址
	mov eax,ecx
	mov esi,DirName
	call seek;在根目录寻找文件夹
	cmp eax,0
	jnz .Error
	
	mov ebx,0
	call load;加载文件夹
	
	mov ebx,0
	mov eax,esi;目录扇区数量
	mov esi,FileName;内核文件名
	call seek;在根目录寻找文件
	cmp eax,0
	jnz .Error
	
	mov ebx,0x2d21000
	call load;加载内核文件
	
	
	jmp ELFLoad

.Error:
	int 0x98

ELFLoad:
	xor eax,eax
	xor ebx,ebx
	xor ecx,ecx
	xor edx,edx
	mov esi,0x2d21000
	
	mov eax,0x7F454c46
	call lit_to_big
	cmp [esi],eax
	jnz PELoad
	xor eax,eax
	
	mov dx,[0x2d21000+42]
	mov ebx,[0x2d21000+28]
	add ebx,0x2d21000
	mov cx,[0x2d21000+44]
	
.each_seg:
	cmp byte [ebx+0],0
	je .PTNULL
	
	push dword [ebx+16];size
	push dword [ebx+8];dst
	mov eax,[ebx+4]
	add eax,0x2d21000
	push eax
	
	call memcopy
	add esp,12
.PTNULL:
	add ebx,edx
	loop .each_seg
	
.JmpToKernel:
	push SelectorGlobal_Code32
	push dword [0x2d21000+0x18];eip
	
	xor eax,eax
	mov ebx,[VRAM]
	mov ecx,[MemSize]
	mov edx,[SCRNX]
	mov esi,[SCRNY]
	movzx edi,word [addr_desc]
	
	retf
;================================================================================
PELoad:
	mov esi,0x2d21000;file load addr
	cmp word [esi],0x5a4d;check mz
	jnz .error
	
	mov eax,[esi+0x3c]
	add esi,eax
	
	cmp dword [esi],0x00004550;check pe..
	jnz .error
	
	cmp word [esi+4],0x14c;check x86
	jnz .error
	
	mov eax,[esi+0x28];压入入口地址,此处有误
	call lit_to_big
	push eax
	
	push dword [esi+0x34];压入装入地址
	push word [esi+6]
	
	mov ax,[esi+0x14]
	movzx eax,ax
	add esi,eax
	add esi,0x18
	xor ecx,ecx
	pop cx
	pop ebx
	
.loadSection:
	push dword [esi+8];size
	
	mov eax,[esi+0xc];加载段偏移
	call lit_to_big
	add eax,ebx;kernel addr space
	push eax
	
	mov eax,[esi+0x14];src
	add eax,0x2d21000
	push eax
	
	call memcopy
	add esi,0x28
	add esp,12
	loop .loadSection
	
	pop eax
	add ebx,eax
	
	push SelectorGlobal_Code32;cs
	push ebx;eip
	
	mov eax,0
	mov ebx,[VRAM]
	mov ecx,[MemSize]
	mov edx,[SCRNX]
	mov esi,[SCRNY]
	
	retf;跳入内核

.error:
	hlt
	jmp .error
;===========下面是函数区==================================================================================================
draw:
	mov ebx,[ds:VRAM]
	mov ecx,786432
.loop:
	mov byte [ebx],7
	inc ebx
	loop .loop
	ret
;==========================
draw_BMP:
	pushad
	push esi
	
	mov ax,[esi]
	cmp ax,0x4d42
	jnz .error
	
	add esi,0x1c
	mov ax,[esi]
	cmp ax,4
	jnz .error
	
	add esi,2
	mov eax,[esi]
	cmp eax,0
	jnz .error
	
	add esi,4
	mov ecx,[esi]
	
	pop esi
	push esi
	add esi,0x36
	push ecx
	mov ecx,16
	mov dx,0x3c8
	mov al,16
	out dx,al
.SetPaletter:
	mov dx,0x3c9
	mov eax,[esi]
	out dx,al;R
	shr eax,8
	out dx,al;G
	shr eax,8
	out dx,al;B
	add esi,4
	loop .SetPaletter
	
	pop ecx
	xor eax,eax
	mov ebp,0
	add edi,785408
	pop esi
	add esi,54+64
.Todraw:
	xor eax,eax
	mov al,[esi]
	inc esi
	shl ax,4
	shr al,4
	add ax,0x1010
	xchg ah,al
	mov word [edi],ax
	add ebp,2
	add edi,2
	cmp ebp,1024
	jz .Nextline
.conuite:
	loop .Todraw
	popad
	mov ax,0
	ret
	
.Nextline:
	mov ebp,0
	sub edi,2048
	jmp .conuite
.error:
	pop esi
	popad
	mov ax,1
	ret
;===============================================================
memcopy:
	cld
	push ebp
	mov ebp,esp
	push ecx
	push esi
	
	mov esi,[ebp+8]
	mov edi,[ebp+12]
	mov ecx,[ebp+16]
	rep movsb
	
	pop esi
	pop ecx
	pop ebp
	ret
;================================================================
lit_to_big:
	push ebx
	mov ebx,eax
	and ebx,0xffff
	shr eax,16
	xchg ah,bl
	xchg al,bh
	shl eax,16
	mov ax,bx
	pop ebx
	ret
	
;=====================================================================

;==========================================================================
%include '.\load.inc'
%include '.\seek.inc'
%include '.\LBARead.inc'
SegCode32Len equ $-LABEL_SEG_CODE32
