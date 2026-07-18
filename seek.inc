;esi为条目名指针,eax为已加载的目录大小,ebx为目录加载地址,返回edi为找到的条目首指针.
;======================================================================================================================
[bits 32]
seek:
	push ebx
	push esi
	push ecx
	
	shl eax,9;乘512得到要搜索的字节长度
.SreachFile:
	mov edi,ebx
	mov ecx,11;11B文件名
	repe cmpsb
	jcxz .Found
	mov esi,[esp+4];复位
	add ebx,32
	sub eax,32
	test eax,eax
	jnz .SreachFile
	
	pop	ecx
	pop esi
	pop ebx
	mov eax,1
	ret

.Found:
	sub edi,11
	pop ecx
	pop esi
	pop ebx
	mov eax,0
	ret
