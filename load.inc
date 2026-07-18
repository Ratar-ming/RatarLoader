;edi应指向目标文件条目开头,ebx应为目标加载地址,es是目标加载地址的段.返回时esi变。这是为fat32设计的
load:
	push eax
	push ebx
	push ecx
	push edx
	push ebp
	push edi
	mov esi,0
	
	movzx eax,byte [BPB_NumFATs];数量
	mov ebp,[BPB_FATSz32];FAT大小
	mul ebp
	movzx ebp,word [BPB_RsvdSecCnt]
	add eax,ebp;得到起始地址
	mov ebp,eax
	
	mov ax,[edi+0x14];簇号的高位
	shl eax,16
	mov ax,[edi+0x1a];簇号的低位
	;现在有了簇号和数据区起始地址
	
	
.loadFile:
	mov edi,eax;备份
	sub eax,2
	add eax,ebp
	mov ecx,1
	inc esi
	call ReadSector;读取一个扇区
	
	mov eax,edi;恢复簇号
	mov ecx,128;每个FAT都有128个FAT项
	mov edx,eax
	shr edx,16;32位除法，高位放dx，低位放ax
	
	div ecx;计算目标FAT的偏移扇区。ax为扇区偏移，dx为项偏移
	movzx edi,dx;备份偏移
	movzx eax,ax;清理高位
	
	movzx ecx,word [BPB_RsvdSecCnt]
	add eax,ecx;得到绝对FAT扇区号
	
	mov cx,1
	mov edx,ebx;备份原加载位置
	mov ebx,0x4000;FAT缓存地址
	call ReadSector;读FAT
	
	mov ebx,edx;恢复原先加载地址
	mov eax,[0x4000+edi*4];读取下一个簇号
	cmp eax,0x0fffffff;看读完了没
	jc .loadFile;小于这个数说明没有，继续
	
	;这里可以终止了
	pop edi
	pop ebx
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
