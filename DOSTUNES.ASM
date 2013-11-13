TITLE dostunes

; DOSTUNES.ASM
; Duo Gong
; Fall 2012

INCLUDE Irvine16.inc
.386

.data
badread BYTE "Error: The file could not be read!", 0
badopen BYTE "Error: The file could not be opened or does not exist!", 0
needfile BYTE "Error: There was no file to be opened!", 0
cmdline BYTE 200 DUP(0)
buffer BYTE "ABC", 0
trash BYTE "AB", 0
argc BYTE 0
argv WORD 200 DUP(0)
handle WORD ?
num1 WORD 0
mega BYTE "Megaman 2 Soundtrack", 0
theme BYTE "Dr.Wily Stage 1/2", 0

.code
HUNDRED DWORD 100
count WORD 0
oldtime BYTE 0
clockspeed DWORD 1193280
Orig08 DWORD ?
index WORD 0
octave WORD 0
space WORD 0
Speedup WORD 32 ; CHANGE THE TEMPO HERE!!! -------------------TEMPO
oldpos WORD 0
xpos BYTE 0
ypos BYTE 0
num BYTE 0
char BYTE 0
scale BYTE "CDEFGAB", 0
weird BYTE 0
ten WORD 10
attrib BYTE 0
charging BYTE 1

EVENSCALE LABEL DWORD
DWORD 209300 ; C7
DWORD 221746 ; C#7
DWORD 234932 ; D7
DWORD 248902 ; D#7
DWORD 263702 ; E7
DWORD 279383 ; E#7
DWORD 279383 ; F7
DWORD 295996 ; F#7
DWORD 313596 ; G7
DWORD 332244 ; G#7
DWORD 352000 ; A7
DWORD 372931 ; A#7
DWORD 395107 ; B7
DWORD 418601 ; B#7
DWORD 418601 ; C8

handle08 PROC
	push ax
	push dx

	inc WORD PTR cs:[count]

done:	pop dx
	pop ax

	pushf
	call cs:[Orig08]	; call the original interrupt handler

	iret
handle08 ENDP

InstallHandler PROC
	push ax
	push bx
	push dx
	push ds
	push es	       

	mov ax,3508h ; read interrupt vector
	int 21h
	mov WORD PTR cs:Orig08,bx
	mov WORD PTR cs:Orig08+2,es ; saving original value
	
	mov dx,OFFSET handle08
	push cs
	pop ds
	mov ax,2508h
	int 21h

	pop es
	pop ds
	pop dx
	pop bx
	pop ax

	ret
InstallHandler ENDP

UnInstallHandler PROC
	push ax
	push dx
	push ds
	
	mov ax,2508h
	mov dx,WORD PTR cs:Orig08
	mov ds,WORD PTR cs:Orig08+2
	int 21h
	
	pop ds
	pop dx
	pop ax
	ret
UnInstallHandler ENDP

newline PROC
	pushf
	push ax
	push dx

	mov ah,0Eh
	mov al,0Dh
	int 10h

	mov ah,0Eh
	mov al,0Ah
	int 10h

	pop dx
	pop ax
	popf
	ret
newline ENDP

S_On PROC
	push ax
	in al,97
	or al,3
	out 97,al

	pop	ax
	ret
S_On ENDP

S_Off PROC
	push ax
	in al,97
	and al,0fch
	out	97,al
	pop	ax
	ret
S_Off ENDP

adjustOctave PROC
;***************************************************
; IN: eax is centihertz
; OUT: eax is adjusted to correct octave
;***************************************************
	push cx
	pushf

	mov cx,7
	sub cx,cs:octave
	shr eax,cl

	popf
	pop cx
	ret
adjustOctave ENDP

readCMDLine PROC
;*******************************************************************
; Reads in and stores characters from the command line into
; the command line buffer
;*******************************************************************
	pushf			; Save regs
	push cx
	push dx
	push si
	push di

	mov si,82h		; start of actual command line
	mov di,OFFSET cmdline	; destination setup
	mov cx,0
	mov cl,es:[80h]		; cx: number of chars in command line
	cmp cx,0		; if no command line args at all...
	jz done			; don't do anything at all
	dec cx			; otherwise skip first space and proceed
again:  cmp cx,0
	jz done
	mov dl,es:[si]		; copy one char from PSP
	mov [di],dl		; to my buffer
	inc di			; increment the pointers
	inc si
	dec cx
	jmp again
done:	mov BYTE PTR [di],0	; null-terminate the whole thing!
	pop di			; Restore regs
	pop si
	pop dx
	pop cx
	popf 
	ret
readCMDLine ENDP

parseCMDLine PROC
;**********************************************************************
; Splits the commands from the command line at the spaces
; Does not include/ignores extra spaces
; Returns an array of all the "words" from the command line
;**********************************************************************
.data
inArg BYTE ?

.code
	pushf
	push dx
	push si
	push di

	mov inArg,0
	mov si, OFFSET cmdline		; pointer into buffer
	mov di, OFFSET argv		; pointer into argv
	mov argc, 0
again:
	mov dl,[si]	 		; load next char from buffer
	cmp dl,0	 		; is this the end?
	jz finished			; no
	cmp dl,' '
	jz space1

	;-- handle non-space
	cmp inArg,1			; are we already in an argument
	jz continue
	inc argc			; no.. new arg!  yay!!
	mov [di],si			; store starting location
	add di,2
	mov inArg,1
	jmp continue

space1:	;-- handle space
	mov inArg,0			; no longer in an argument 
	mov BYTE PTR [si],0		; null terminate 
continue:
	inc si				; go to next character
	jmp again			; and repeat
finished:
	pop di
	pop si
	pop dx
	popf
	ret
parseCMDLine ENDP

toDecimal PROC
;****************************************************************
; IN: bx points to a ASCIZ string
;     containing the characters of a signed decimal number
;     example bx->'7','8','3',0
; OUT: ax contains the integer, in this example, 783 (030Fh)
;      if this number is too large or too small to fit a word,
;      ax is unspecified, and the overflow flag is set.
;****************************************************************
	push bx
	push cx
	push dx			; dx saved/restored because imul uses it.
	xor ax,ax		; clear ax and overflow flag

top:	mov ch,0		; clear high bits of cx
	mov cl,[bx]		; get the next character
	cmp cl,0		; are we done?
	jz done
	sub cl,'0'		; turn the digit to a number in 0..9
	imul cs:ten	
	jo done			; quit if overflow
	add ax,cx		; add the number
	jo done			; quit if overflow (again)
	inc bx			; go to next character in the string
	jmp top

done:	pop dx			; restore registers
	pop cx
	pop bx
	ret
toDecimal ENDP

speed PROC
	push bp
	mov bp,sp

	push ax
	push bx
	push cx
	push dx

	mov ax,0FFFFh
	mov bx,[bp+4]
	mov dx,0
	div bx

	mov cx,ax

	mov al,00111100b
	out 43h,al
	mov al,cl
	out 40h,al
	mov al,ch
	out 40h,al

	pop dx
	pop cx
	pop bx
	pop ax

	mov sp,bp
	pop bp
	ret 2
speed ENDP

getLine PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	; this reads in 3 characters from the file
	mov ah,3Fh
	mov bx,handle
	mov cx,3
	mov dx,OFFSET buffer
	int 21h

	; ignore endline
	mov ah,3Fh
	mov bx,handle
	mov cx,2
	mov dx,OFFSET trash
	int 21h

	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
getLine ENDP

SetClockCount PROC
;**************************************************************
; IN: ax is the count to set on clock
;**************************************************************
	push ax
	push cx

	mov cx,ax
	mov al,182
	out 67,al
	mov ax,cx

	out 66,al
	mov al,ah
	out 66,al

	pop cx
	pop ax
	ret
SetClockCount ENDP

SetFreq PROC
	push bp
	mov bp,sp

	push ax
	push bx
	push dx

	mov eax,cs:CLOCKSPEED
	mov edx,0
	mov ebx,0
	mov bx,[bp+4]
	div ebx

	call SetClockCount
	
	pop dx
	pop bx
	pop ax

	mov sp,bp
	pop bp
	ret 2
SetFreq ENDP

getCursor PROC
	push ax
	push bx
	push cx

	mov ah,3
	mov bh,0
	int 10h

	pop cx
	pop bx
	pop ax
	ret
getCursor ENDP

setCursor PROC
	push ax
	push bx
	push cx

	mov ah,2
	mov bh,0
	int 10h

	pop bx
	pop ax
	pop cx
	ret
setCursor ENDP

drawPiano PROC
;--------------------------------------------------DRAWS PIANO KEYS
	push ax
	push bx
	push cx
	push dx
	pushf

	;----------------------------------------CURSOR SAVED---------
	call getCursor
	mov cs:oldpos,dx
	
	;---------------------------------------BORDERS---------------
	mov cs:xpos,0
	mov cs:ypos,0
	call drawLine

	mov cs:xpos,0
	mov cs:ypos,8
	call drawLine
	;-------------------------------------------------------------
	
	;------------------------------MAKE KEYS----------------------
	call DrawKeys
	mov cs:space,0
	
	;-----------------------------LABEL NOTES---------------------
	mov cs:xpos,1
	mov cs:ypos,0
	call labelNotes
	
	mov cs:xpos,1
	mov cs:ypos,8
	call labelNotes
	;-------------------------------------------------------------
	
	mov cs:space,0

	mov dx,cs:oldpos
	call setCursor

	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
;---------------------------------------------------------PIANO DRAW---	
drawPiano ENDP

drawKeys PROC
	push dx
	pushf
	
	mov dh,1
	mov dl,0
keys:	call drawVert
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawVert
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	cmp dl,80
	jge done
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	jmp keys

done:	popf
	pop dx
	ret
drawKeys ENDP

labelNotes PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	mov cs:num,'C'
L1:	cmp dl,80
	jge done
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,00011011b	; yellow text on blue
	int 10h

	mov ah,9
	mov al,cs:num
	mov cx,1
	int 10h

	inc cs:num
	cmp cs:num,'H'
	jnz sev
	mov cs:num,'A'

sev:	mov dh,cs:ypos
	add cs:xpos,2
	mov dl,cs:xpos
	call setCursor
	jmp L1
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
labelNotes ENDP

drawBlack PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,4
	jge next	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Fh	; blue
	int 10h
	
	mov ah,9
	mov al,' '
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
next:	mov cs:space,0

L2:	cmp cs:space,3
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; blue
	int 10h
	
	mov ah,9
	mov al,179
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L2
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawBlack ENDP

drawBack PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,4
	jge next	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Ah	; cyan highlight
	int 10h
	
	mov ah,9
	mov al,219
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
next:	mov cs:space,0

L2:	cmp cs:space,3
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; blue
	int 10h
	
	mov ah,9
	mov al,179
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L2
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawBack ENDP

drawWhite PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,7
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; white
	int 10h
	
	mov ah,9
	mov al,' '
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawWhite ENDP

drawYell PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,7
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Ah	; red on red
	int 10h
	
	mov ah,9
	mov al,219
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawYell ENDP

drawVert PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,7
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,01110000b	; blue
	int 10h
	
	mov ah,9
	mov al,179
	mov cx,1
	int 10h
	
	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawVert ENDP

drawLine PROC
	push ax
	push bx
	push cx
	push dx
	pushf		

	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

L1:	cmp cs:space,80
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,11h	; blue
	int 10h
	
	mov ah,9
	mov al,' '
	mov cx,1
	int 10h

	mov dh,cs:ypos
	inc cs:xpos
	mov dl,cs:xpos
	call setCursor
	
	inc cs:space
	jmp L1
	
done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawLine ENDP

hNOTE PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	;-----------------------------REGISTER GUIDE-------------
	;-----------------------------CX: OCTAVE-----------------
	;-----------------------------BX: INDEX------------------

	; DETERMINE WHICH OCTAVE THE NOTE WILL GO IN
	mov cx,cs:octave
	sub cx,2
	
	; DETERMINE EXACT PLACEMENT
	mov bx,cs:index
	
here:	add bx,14
	loop here

	mov dh,1
	mov dl,bl
	inc dl

	cmp cs:weird,1
	jz crazy
	call drawYell
	jmp done
crazy:	call drawBack

done:	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
hNOTE ENDP

ERASE PROC
	push ax	
	push bx
	push cx
	push dx
	pushf

	;-----------------------------REGISTER GUIDE-------------
	;-----------------------------CX: OCTAVE-----------------
	;-----------------------------BX: INDEX------------------

	; DETERMINE WHICH OCTAVE THE NOTE WILL GO IN
	mov cx,cs:octave
	sub cx,2
	
	; DETERMINE EXACT PLACEMENT
	mov bx,cs:index
	
here:	add bx,14
	loop here

	mov dh,1
	mov dl,bl
	inc dl

	cmp cs:weird,1
	jz crazy
	call drawWhite
	jmp done
crazy:	call drawBlack

done:	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
ERASE ENDP

drawp PROC
	push ax
	push bx
	push cx
	push dx
	pushf

top:	cmp cs:num,0
	jz done
	call SetCursor
	mov bl,cs:attrib
	mov ah,9
	mov al,219
	mov cx,1
	int 10h
	inc dx
	call SetCursor
	mov bl,cs:attrib
	mov ah,9
	mov al,219
	mov cx,1
	int 10h
	inc dx
	dec cs:num
	jmp top

done:	mov cs:num,1
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawp ENDP

drawl PROC
	push ax
	push bx
	push cx
	pushf

	call SetCursor
	mov bl,cs:attrib
	mov ah,9
	mov al,219
	mov cx,1
	int 10h

	popf
	pop cx
	pop bx
	pop ax
	ret
drawl ENDP

drawC PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	;---------------------------------------------------------START CYAN
	mov cs:attrib,03h
	mov dx,0B1Ah
	mov cs:num,2
	call drawp	;------------------------------------------LINE 2

	mov dx,0C1Ch
	mov cs:num,2
	call drawp	;------------------------------------------LINE 3

	mov dx,0E1Eh
	mov cs:num,2
	call drawp	;--------------------------------------LINE 5

	mov dx,0F10h
	call drawp	;-------------LINE 6

	mov dx,1010h
	call drawp	;-----------------LINE 7

	mov dx,110Ah
	mov cs:num,2
	call drawp
	mov dx,1110h
	call drawp	;--------------------LINE 8

	mov dx,1206h
	mov cs:num,5
	call drawp 	;------------------LINE 9

	mov dx,1306h
	mov cs:num,5
	call drawp	;-----------------LINE 10

	mov dx,140Ah
	call drawp
	mov dx,140Eh
	mov cs:num,2
	call drawp
	mov dx,1426h
	mov cs:num,2
	call drawp
	mov dx,142Eh
	mov cs:num,3
	call drawp
	mov dx,1436h
	call drawp	;-----------------LINE 11
	
	mov dx,1510h
	mov cs:num,2
	call drawp
	mov dx,1522h
	mov cs:num,4
	call drawp	;---------------------LINE 12

	mov dx,1612h
	mov cs:num,2
	call drawp
	mov dx,1620h	
	mov cs:num,5
	call drawp	;---------------------LINE 13

	mov dx,1712h
	mov cs:num,7
	call drawp	;------------LINE 14

	mov dx,1810h
	mov cs:num,7
	call drawp	;------------------LINE 15
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawC ENDP

drawB PROC
	push dx
	pushf

	;--------------------------------------------------START BLUE
	mov cs:attrib,09h
	mov dx,0C14h
	mov cs:num,3
	call drawp	;------LINE 3

	mov dx,0D12h
	mov cs:num,5
	call drawp	;-----LINE 4
	
	mov dx,0E12h
	mov cs:num,5
	call drawp	
	mov dx,0E22h
	call drawp	;------LINE 5

	mov dx,0F12h
	mov cs:num,6
	call drawp
	mov dx,0F22h
	call drawp	;---LINE 6

	mov dx,1012h
	mov cs:num,2
	call drawp
	mov dx,101Eh
	mov cs:num,2
	call drawp	;-----LINE 7

	mov dx,1112h
	call drawp	;----LINE 8

	mov dx,1212h
	call drawp	;----LINE 9

	mov dx,1304h
	call drawp
	mov dx,1312h
	call drawp
	mov dx,132Ch
	mov cs:num,4
	call drawp	;---LINE 10

	mov dx,1404h
	mov cs:num,3
	call drawp
	mov dx,1414h
	call drawp
	mov dx,142Ch
	call drawp	;---LINE 11

	mov dx,1504h
	mov cs:num,3
	call drawp
	mov dx,150Ch
	call drawp
	mov dx,152Ch
	mov cs:num,4
	call drawp
	mov dx,1536h
	call drawp	;--LINE 12

	mov dx,1606h
	mov cs:num,2
	call drawp
	mov dx,160Ch
	mov cs:num,2
	call drawp
	mov dx,162Ch
	mov cs:num,3
	call drawp	;--LINE 13

	mov dx,1708h
	mov cs:num,4
	call drawp	;---LINE 14

	mov dx,180Ah
	mov cs:num,2
	call drawp	;---LINE 15
	
	popf
	pop dx
	ret
drawB ENDP

drawSkin PROC
	push dx
	pushf

	;------------------------------------------START SKIN----
	mov cs:attrib,06h
	mov dx,1016h
	call drawp	;----LINE

	mov dx,1114h
	call drawp
	mov dx,111Eh
	call drawp	;-----LINE

	mov dx,1214h
	call drawp
	mov dx,121Eh
	call drawp	;-----LINE

	mov dx,1314h
	mov cs:num,2
	call drawp
	mov dx,131Eh
	call drawp
	mov dx,1322h
	call drawp	;--LINE

	mov dx,1416h
	call drawp
	mov dx,1420h
	call drawp	;-LINE

	mov dx,1516h
	mov cs:num,5
	call drawp	;-LINE
	
	popf
	pop dx 
	ret
drawSkin ENDP

drawI PROC
	push dx
	pushf

	mov cs:attrib,0Fh
	mov dx,1018h
	mov cs:num,3
	call drawp
	mov dx,1022h
	call drawp		;--LINE

	mov dx,1116h
	mov cs:num,2
	call drawp
	mov dx,1122h
	call drawp		;--LINE

	mov dx,1216h
	mov cs:num,2
	call drawp
	mov dx,1222h
	call drawp		;--LINE

	mov dx,1318h
	mov cs:num,3
	call drawp
	mov dx,1320h
	call drawp

	popf
	pop dx
	ret
drawI ENDP

drawG PROC
	push dx
	pushf

	mov cs:attrib,08h
	mov dx,0A18h
	mov cs:num,3
	call drawp		;--LINE

	mov dx,0B14h
	mov cs:num,3
	call drawp		
	mov dx,0B1Eh
	call drawp		;--LINE

	mov dx,0C12h
	call drawp
	mov dx,0C1Ah
	call drawp
	mov dx,0C20h
	call drawp		;LINE

	mov dx,0D10h
	call drawp
	mov dx,0D1Ch
	mov cs:num,4
	call drawp		;LINE

	mov dx,0E10h
	call drawp
	mov dx,0E1Ch
	call drawp
	mov dx,0E24h
	call drawp		;LINE

	mov dx,0F0Eh
	call drawp
	mov dx,0F1Eh
	mov cs:num,2	
	call drawp
	mov dx,0F24h
	call drawp		;LINE

	mov dx,100Ah
	mov cs:num,3
	call drawp
	mov dx,1024h
	call drawp		;LINE

	mov dx,1106h
	mov cs:num,2
	call drawp
	mov dx,110Eh
	call drawp
	mov dx,1124h
	call drawp		;LINE

	mov dx,1204h
	call drawp
	mov dx,1210h
	call drawp
	mov dx,1224h
	call drawp	
	mov dx,122Ch
	mov cs:num,4
	call drawp		;LINE

	mov dx,1302h
	call drawp
	mov dx,1310h
	call drawp
	mov dx,1324h
	mov cs:num,4
	call drawp
	mov dx,1334h
	mov cs:num,2
	call drawp		;LINE

	mov dx,1402h
	call drawp
	mov dx,140Ch
	call drawp
	mov dx,1412h
	call drawp
	mov dx,1422h
	mov cs:num,2
	call drawp
	mov dx,142Ah
	call drawp
	mov dx,1434h
	call drawp
	mov dx,1438h
	call drawp		;LINE

	mov dx,1502h
	call drawp
	mov dx,150Ah
	call drawp
	mov dx,150Eh
	call drawp
	mov dx,1514h
	call drawp
	mov dx,1520h
	call drawp
	mov dx,152Ah
	call drawp
	mov dx,1534h
	call drawp
	mov dx,1538h
	call drawp		;LINE

	mov dx,1604h
	call drawp
	mov dx,160Ah
	call drawp
	mov dx,1610h
	call drawp
	mov dx,1616h
	mov cs:num,5
	call drawp
	mov dx,162Ah
	call drawp
	mov dx,1632h
	mov cs:num,3
	call drawp		;LINE

	mov dx,1706h
	call drawp
	mov dx,1710h
	call drawp
	mov dx,1720h
	mov cs:num,5
	call drawp
	mov dx,172Ch
	mov cs:num,4
	call drawp		;LINE

	mov dx,1808h
	call drawp
	mov dx,180Eh
	call drawp
	mov dx,181Eh
	call drawp

	popf	
	pop dx
	ret
drawG ENDP

drawShot PROC
	push dx
	pushf

	mov cs:attrib,0Ah
	mov dx,133Dh
	mov cs:num,2
	call drawp
	mov dx,143Ch
	mov cs:num,3
	call drawp
	mov dx,153Dh
	mov cs:num,2
	call drawp		;END BALL

	mov dx,1039h
	call drawl
	mov dx,113Ah
	call drawl
	mov dx,123Bh
	call drawl
	
	mov dx,1044h
	call drawl
	mov dx,1143h
	call drawl
	mov dx,1242h
	call drawl

	mov dx,163Bh
	call drawl
	mov dx,173Ah
	call drawl
	mov dx,1839h
	call drawl

	mov dx,1642h
	call drawl
	mov dx,1743h
	call drawl
	mov dx,1844h
	call drawl

	popf
	pop dx
	ret 
drawShot ENDP

drawMM PROC
	push dx

	call getCursor
	mov cs:oldpos,dx

	call drawC
	call drawB
	call drawSkin
	call drawI
	call drawG

	call drawShot

	mov cs:attrib,01h
	mov dx,0A2Dh
	mov cs:num,14
	call drawp
	mov dx,0B2Dh
	call drawp
	mov dx,0B47h
	call drawp
	mov dx,0C2Dh
	call drawp
	mov dx,0C47h
	call drawp
	mov dx,0D2Dh
	call drawp
	mov dx,0D47h
	call drawp
	mov dx,0E2Dh
	mov cs:num,14
	call drawp

	mov dx,0B31h
	call SetCursor
	mov dx,OFFSET mega
	call WriteString

	mov dx,0D32h
	call SetCursor
	mov dx,OFFSET theme
	call WriteString

	mov dx,cs:oldpos
	call setCursor

	pop dx
	ret
drawMM ENDP

playSong PROC
	push ax
	push bx
	push cx
	push dx
	push si
	pushf

	;#########################################################IMPORTANT
	;------------------START OF A SINGLE NOTE--------------------------
	
	;----------------------------------------SET UP HANDLER WITH SPEED-
	call InstallHandler
	push cs:Speedup
	call speed	
	;CHECKED HERE
	;----LOOP BEGINS HERE DO NOT CHANGE!!!-----------------------------
	;----------------------------------------GET NOTE------------------
new:	mov cs:count,0
	call getLine
	cmp buffer,'Z'
	jz done
	cmp buffer,'R'
	jnz norm
	call GetLine
	mov bx,OFFSET buffer
	call toDecimal
	mov cx,ax
	jmp rest	

	;----------------------------------------INDEX OF NOTE (1)---------
norm:	mov ax,0
	mov al,buffer
	cmp al,'A'
	jz deala
	cmp al,'B'
	jz dealb
	sub al,'C'
	shl ax,1
	jmp dino
deala:	mov al,10
	jmp dino
dealb:	mov al,12
dino:	mov cs:index,ax

	;----------------------------------------SHARP/FLAT (2)------------
	mov cs:weird,0
	cmp [buffer+1],'n'
	jz none
	cmp [buffer+1],'#'
	jnz minus
	inc cs:index
	mov cs:weird,1
	jmp none	
minus:	dec cs:index
	mov cs:weird,1

	;----------------------------------------OCTAVE (3)----------------
none:	mov ax,0
	mov al,[buffer+2]
	sub al,'0'
	mov cs:octave,ax
	
	;------------------------------------------HIGHLIGHT NOTE----------
	call hNOTE

	;-----------------------------------------SHOT CHARGE--------------
	mov dx,143Eh
	cmp cs:charging,1	
	jz blk
	mov cs:attrib,0Ah
	inc cs:charging
	jmp L99
blk:	mov cs:attrib,0
	dec cs:charging
L99:	call drawp

	;---------------------------------------GET DURATION---------------
	call getLine
	mov bx,OFFSET buffer
	call toDecimal
	mov cx,ax	

	mov si,index
	shl si,2
	mov eax,[cs:EVENSCALE + si]
	call adjustOctave

	mov edx,0
	div cs:HUNDRED
	push ax	
	call setFreq
	call S_on
	jmp here

rest:	call S_off
here:	mov bx,cs:count
	
	cmp bx,cx
	jl here
	
	call S_Off

	call ERASE
	jmp new

done:	popf
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret
playSong ENDP

main PROC
	mov ax,@data
	mov ds,ax

	; ----------------------------------------------------------OPEN FILE
	; CMD line stuff
	call readCMDLine
	call parseCMDLine
	
	; check for file
	cmp argc,0
	jz nofile

	; open file
	mov al,0
	mov ah,3Dh
	mov dx,argv[0]
	int 21h
	jc bado
	mov handle,ax

	;---------------------------------------------DRAWING SCREEN-------
	;-------------------------TEXT MODE HERE---------------------------
	mov ah,0
	mov al,2
	int 10h
	
	call DrawPiano
	call drawMM
	;--------------------------------------------------PLAY NOTES------
	call playSong
	jmp close
	
	;-------------------------POSSIBLE ERRORS--------------------------
badr:	mov dx,OFFSET badread
	call WriteString	
	
close:	call UninstallHandler
	mov ax,1
	push ax
	call speed
	mov bx,handle
	mov ah,3Eh
	int 21h
	jmp done
	
bado:	mov dx,OFFSET badopen
	call WriteString
	jmp done
	
nofile:	mov dx,OFFSET needfile
	call WriteString
	jmp done
	;------------------------------------------------------------------
	
done:	mov ax, 4C00h
	int 21h
main ENDP
END main

