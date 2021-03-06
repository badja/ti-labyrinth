
;************************************************************
;
; Labyrinth v1.0
; ==============
; for SOS on the TI-83
;
; by badja
; 26 June 1999
;
; http://move.to/badja
; badja@alphalink.com.au
;
; ported to ION by Andrew Magness
;
; MirageOS port by Andrew Magness
;
;
;
; You may modify this source code for personal use only.
; You may NOT distribute the modified source or program file.
;
; The original maze-generation code was written in Basic and
; is copyright 1979 by Creative Computing, Morristown, NJ.
;
;************************************************************

#include	"ti83plus.inc"			;Standard TI-83 Plus include file
#include	"mirage.inc"			;Mirage include file

	.org $9d93				;Origin
	.db $BB,$6D				;Compiled AsmPrgm token
	ret						;Header Byte 1 -- So TIOS wont run
	.db	1					;Header Byte 2 -- Identifies as MirageOS prog
button:						;Button - should be a 15x15 graphic
	.db	%00110000,%11000000
	.db	%00110000,%11000000
	.db	%11111111,%11111100
	.db	%11111111,%11111100
	.db	%00000000,%00000000
	.db	%00000110,%00000000
	.db	%00000110,%00000000
	.db	%00000000,%00000000
	.db	%00111111,%11111110
	.db	%00111111,%11111110
	.db	%00110000,%11000000
	.db	%00110000,%11000000
	.db	%00110000,%11000000
	.db	%00110000,%11000000
	.db	%00110000,%11000000
desc:						;Description - zero terminated
	.db	"Labyrinth v1.0",0

;******** Symbolic constants ********
hSize	.equ	15			; horizontal size of maze
vSize	.equ	16			; vertical size of maze
plyHt	.equ	3			; height of player sprite
delS	.equ	$4000			; duration of short delay
delL	.equ	$0000			; duration of long delay (equivalent to $10000)


;******** IX offsets ********
temp	.equ	0			; 2 temporary bytes
C	.equ	temp+2		; maze generation variables
I	.equ	C+1
J	.equ	I+1
Q	.equ	J+1
R	.equ	Q+1
S	.equ	R+1
X	.equ	S+1
Z	.equ	X+1
xPos	.equ	Z+1			; player's x-position
yPos	.equ	xPos+1		; player's y-position
level	.equ	yPos+1		; current level
anti	.equ	level+1		; 1 if antimaze mode is on
arI	.equ	anti+1		; maze generation arrays
arJ	.equ	arI+((hSize+1)*(vSize+1))

progstart:					;Program code starts here
	ld	ix,saferam1	; initialise IX so we can use our offsets
	ld	(ix+anti),0
startProg:
	call	intro
menu:
	ld	de,52*256+7		; display 'maze'
	ld	hl,maze
	bit	0,(ix+anti)		; highlight maze?
	jr	nz,noHiLite1
	set	textinverse,(iy+textflags)
noHiLite1:
	call setvputs
	res	textinverse,(iy+textflags)
	ld	de,58*256+0		; display 'antimaze'
	ld	hl,antimaze
	bit	0,(ix+anti)		; highlight antimaze?
	jr	z,noHiLite2
	set	textinverse,(iy+textflags)
noHiLite2:
	call setvputs
	res	textinverse,(iy+textflags)

	call	lvlAddress		; display level number
	ld	a,(hl)
	inc	a
	bcall(_SETXXOP1)
	ld	bc,52*256+57
	ld	(PENCOL),bc
	ld	a,2
	push	ix
	bcall(_DISPOP1A)
	pop	ix
	ld	hl,spaces		; erase remnants of previous level number
	bcall(_vputs)
titleLoop:

	ld	a,$fe
	call directin
	cp	254			; down
	jr	z,down
	cp	247			; up
	jr	z,up

	ld	a,$fd
	call directin
	cp	191
	jr	z,quit

	ld	a,$bf
	call directin
	cp	223			; 2nd
	jr	z,game
	cp	127			; DEL
	jr	z,restart
	jr	titleLoop

quit:
	bcall(_clrlcdfull)
	ret

up:
	ld	(ix+anti),0
	jp	menu

down:
	ld	(ix+anti),1
	jp	menu

restart:				; restart current game
	call	lvlAddress
	ld	(hl),0
	jp	menu

game:
	call	lvlAddress		; initialise level
	ld	a,(hl)
	ld	(ix+level),a

	ld	b,hSize		; randomise entrance position
	call	iRandom
	inc	a
	ld	(ix+xPos),a		; initialise xPos
	call	generate
	call	display
keyLoop:

	ld	a,$fe
	call directin
	cp	254
	call	z,moveDown
	cp	253
	call	z,moveLeft
	cp	251
	call	z,moveRight
	cp	247
	call	z,moveUp

	ld	a,$fd
	call directin
	cp	191
	jp	z,startProg

	ld	a,(ix+yPos)		; check if player is at exit
	cp	vSize+1
	jr	z,atExit
	jr	keyLoop

atExit:
	ld	b,63
	call	scrollUp
	bcall(_GRBUFCLR)		; clear final line from screen
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen

	ld	a,(ix+level)	; check if last level
	cp	15
	jr	z,winGame
	inc	a			; increment level
	ld	(ix+level),a
	call	lvlAddress
	ld	(hl),a
	call	generate		; generate the next maze
	call	display		; and display it
	jr	keyLoop

winGame:
	ld	de,PLOTSSCREEN+(12*52)	; display title
	ld	hl,titlePic
	ld	bc,12*12
	ldir
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen
	ld	b,52			; scroll title up to top of screen
	call	scrollUp
	ld	bc,$0003		; display win message
	ld	(CURROW),bc
	ld	hl,winMsg
	bcall(_puts)
	bit	0,(ix+anti)		; check if antimaze mode is on
	jr	nz,antiMsg
	ld	bc,$0006		; display maze message
	ld	(CURROW),bc
	ld	hl,win1
	bcall(_puts)
	jr	winKey
antiMsg:
	ld	bc,$0006		; display antimaze message
	ld	(CURROW),bc
	ld	hl,win2
	bcall(_puts)
	ld	bc,$0107
	ld	(CURROW),bc
	bcall(_puts)
winKey:				; wait for 2nd

	ld	a,$bf
	call directin
	cp	223			; 2nd
	jp	z,startProg
	jr	winKey

moveDown:
	call	getBlock		; can only move down if on block 1 or 3
	bit	0,a
	ret	z
	inc	(ix+yPos)
	ld	a,(ix+yPos)
	cp	vSize+1
	ret	z
	call	display
	ld	bc,delS
	call	delay
	ret

moveLeft:
	ld	a,(ix+xPos)
	or a
	ret	z
	dec	(ix+xPos)
	call	getBlock		; can only move left if destination is block 2 or 3
	bit	1,a
	jr	z,noLeft
	call	display
	ld	bc,delS
	call	delay
	ret
noLeft:
	inc	(ix+xPos)
	ret

moveRight:				; can only move right if on block 2 or 3
	call	getBlock
	bit	1,a
	ret	z
	inc	(ix+xPos)
	call	display
	ld	bc,delS
	call	delay
	ret

moveUp:
	ld	a,(ix+yPos)
	cp	1
	ret	z
	dec	(ix+yPos)
	call	getBlock		; can only move up if destination is block 1 or 3
	bit	0,a
	jr	z,noUp
	call	display
	ld	bc,delS
	call	delay
	ret
noUp:
	inc	(ix+yPos)
	ret

getBlock:				; load A with block type beneath player
	ld	a,(ix+yPos)		; multiply yPos by 8
	add a,a
	add a,a
	add a,a
	ld	b,0			; load BC with result
	ld	c,a
	sla	c			; multiply BC by 2 to achieve multiplication by 16 (required
	rl	b			; since yPos could be 16 and result would not fit in A)
	ld	hl,saferam1+arI
	add	hl,bc
	ld	b,0
	ld	c,(ix+xPos)
	add	hl,bc			; HL points to correct element
	ld	a,(hl)
	ret

display:
	bcall(_GRBUFCLR)
	ld	c,0			; find x-position of viewport
	ld	a,(ix+xPos)
	cp	7
	jr	c,foundXView
	cp	hSize-5
	jr	c,endXView
	ld	c,hSize-11
	jr	foundXView
endXView:
	sub	6
	ld	c,a
foundXView:
	ld	b,0			; increase HL by that value
	ld	hl,saferam1+arI
	add	hl,bc
	push	bc			; remember x-position of viewport

	ld	c,0			; find y-position of viewport
	ld	a,(ix+yPos)
	cp	5
	jr	c,foundYView
	cp	vSize-3
	jr	c,endYView
	ld	c,vSize-7
	jr	foundYView
endYView:
	sub	4
	ld	c,a
foundYView:
	push	bc			; remember y-position of viewport
	sla	c			; increase HL by 16 times that value
	sla	c
	sla	c
	sla	c
	ld	b,0
	add	hl,bc
	ex	de,hl			; put pointer to start of display data in DE

	pop	bc			; recall y-position of viewport
	ld	a,(ix+yPos)		; subtract it from y-position of player
	sub	c
	add a,a
	add a,a
	add a,a
	ld	hl,plOffsets	; find offset of player sprite relative to block
	ld	b,0
	ld	c,(ix+level)
	add	hl,bc
	add	a,(hl)		; add this to the y-coordinate
	ld	l,a			; put result in L
	pop	bc			; recall x-position of viewport
	push	hl			; remember the y-coordinate of the player
	ld	a,(ix+xPos)		; subtract it from x-position of player
	sub	c
	add a,a
	add a,a
	add a,a
	ld	hl,plOffsets	; find offset of player sprite relative to block
	ld	b,0
	ld	c,(ix+level)
	add	hl,bc
	add	a,(hl)		; add this to the x-coordinate
	pop	hl			; recall the y-coordinate of the player
	ld	b,plyHt		; load B with height of player sprite
	push	ix			; draw player
	ld	ix,player
	push	de
	call	isprite
	pop	de
	pop	ix

	ld	(ix+I),0		; I and J hold current pixel-position
	ld	(ix+J),0
	ld	b,8			; loop 8 times (down screen)
dispY:
	push	bc
	ld	b,12			; loop 12 times (across screen)
dispX:
	push	bc
	ld	hl,blocks		; make HL point to start of block data
	ld	a,(de)		; get type of block
	bit	0,(ix+anti)		; check if antimaze mode is on
	jr	z,notAnti
	xor	%00000011		; if so, invert the type of block (0 <-> 3 and 1 <-> 2)
notAnti:
	add a,a
	add a,a
	add a,a
	ld	b,0
	ld	c,a
	add	hl,bc			; increase HL according to type of block
	ld	b,0			; multiply level number by 32
	ld	c,(ix+level)
	sla	c
	sla	c
	sla	c
	sla	c
	sla	c
	rl	b			; required since the final doubling may exceed 255
	add	hl,bc			; add to HL to get correct block style
	ld	a,(ix+I)		; get coordinates of sprite
	ld	b,(ix+J)
	push	ix			; load IX with address of sprite
	ld	(saferam1+temp),hl
	ld	ix,(saferam1+temp)
	push	de
	push	hl
	ld	l,b			; load L with y-coordinate

	call	putsprite8		; draw sprite
	pop	hl
	pop	de
	pop	ix
	ld	a,(ix+I)		; move across 8 pixels
	add	a,8
	ld	(ix+I),a
	inc	de			; move to next byte of data
	pop	bc
	djnz	dispX

	inc	de			; move to start of next row of data
	inc	de
	inc	de
	inc	de
	ld	(ix+I),0		; adjust x- and y-coordinates
	ld	a,(ix+J)
	add	a,8
	ld	(ix+J),a
	pop	bc
	djnz	dispY

	bcall(_GRBUFCPY)		; copy the graph buffer to the screen
	ret

generate:
	call	initArrays
	ld	(ix+Q),0
	ld	(ix+Z),0

	ld	hl,saferam1+arI	; create entrance in array I
	ld	b,0
	ld	c,(ix+xPos)
	add	hl,bc
	ld	(hl),1
	dec	hl
	ld	(hl),0
	ld	a,c				; if xPos is 0, sprite 1 should be at the top-left
	cp	1
	jr	nz,xNot0
	ld	(hl),1
xNot0:
	ld	(ix+yPos),1			; initialise yPos

	ld	(ix+X),a
	ld	(ix+C),1
	ld	a,(ix+C)
	ld	b,(ix+X)
	ld	c,1
	call	storeJ
	inc	(ix+C)
	ld	a,(ix+X)
	ld	(ix+R),a
	ld	(ix+S),1
	jp	lbl7
lbl3:
	ld	a,(ix+R)
	cp	hSize
	jp	nz,lbl5
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl4
	ld	(ix+R),1
	ld	(ix+S),1
	jp	lbl6
lbl4:
	ld	(ix+R),1
	inc	(ix+S)
	jp	lbl6
lbl5:
	inc	(ix+R)
lbl6:
	ld	a,(ix+R)
	ld	b,(ix+S)
	call	getJ
	or a
	jp	z,lbl3
lbl7:
	ld	a,(ix+R)
	cp	1
	jp	z,lbl20
	ld	a,(ix+R)
	dec	a
	ld	b,(ix+S)
	call	getJ
	cp	1
	jp	nc,lbl20
	ld	a,(ix+S)
	cp	1
	jp	z,lbl12
	ld	a,(ix+R)
	ld	b,(ix+S)
	dec	b
	call	getJ
	or a
	jp	nz,lbl12
	ld	a,(ix+R)
	cp	hSize
	jp	z,lbl8
	ld	a,(ix+R)
	inc	a
	ld	b,(ix+S)
	call	getJ
	cp	1
	jp	nc,lbl8
	ld	b,3
	call	irandom

	cp	1
	jp	z,lbl36
	cp	2
	jp	z,lbl37
	or  a
	jp	z,lbl35
lbl8:
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl9
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl11
	ld	(ix+Q),1
	jp	lbl10
lbl9:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl11
lbl10:
	ld	b,3
	call	irandom

	cp	1
	jp	z,lbl36
	cp	2
	jp	z,lbl40
	or a
	jp	z,lbl35
lbl11:
	ld	b,2
	call	irandom

	cp	1
	jp	z,lbl36
	or a
	jp	z,lbl35
lbl12:
	ld	a,(ix+R)
	cp	hSize
	jp	z,lbl16
	ld	a,(ix+R)
	inc	a
	ld	b,(ix+S)
	call	getJ
	cp	1
	jp	nc,lbl16
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl13
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl15
	ld	(ix+Q),1
	jp	lbl14
lbl13:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl15
lbl14:
	ld	b,3
	call	irandom

	cp	1
	jp	z,lbl37
	cp	2
	jp	z,lbl40
	or a
	jp	z,lbl35
lbl15:
	ld	b,2
	call	irandom

	cp	1
	jp	z,lbl37
	or a
	jp	z,lbl35
lbl16:
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl17
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl35
	ld	(ix+Q),1
	jp	lbl18
lbl17:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl35
lbl18:
	ld	b,2
	call	irandom
	or a
	jp	z,lbl35
	cp	1
	jp	z,lbl40
	jp	lbl35
lbl20:
	ld	a,(ix+S)
	cp	1
	jp	z,lbl28
	ld	a,(ix+R)
	ld	b,(ix+S)
	dec	b
	call	getJ
	cp	1
	jp	nc,lbl28
	ld	a,(ix+R)
	cp	hSize
	jp	z,lbl24
	ld	a,(ix+R)
	inc	a
	ld	b,(ix+S)
	call	getJ
	cp	1
	jp	nc,lbl24
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl21
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl23
	ld	(ix+Q),1
	jp	lbl22

lbl21:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl23
lbl22:
	ld	b,3
	call	irandom

	cp	1
	jp	z,lbl37
	cp	2
	jp	z,lbl40
	or a
	jp	z,lbl36
lbl23:
	ld	b,2
	call	irandom

	cp	1
	jp	z,lbl37
	or a
	jp	z,lbl36
lbl24:
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl25
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl36
	ld	(ix+Q),1
	jp	lbl26
lbl25:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl36
lbl26:
	ld	b,2
	call	irandom

	cp	1
	jp	z,lbl40
	or a
	jp	z,lbl36
	jp	lbl36
lbl28:
	ld	a,(ix+R)
	cp	hSize
	jp	z,lbl32
	ld	a,(ix+R)
	inc	a
	ld	b,(ix+S)
	call	getJ
	cp	1
	jp	nc,lbl32
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl29
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl37
	ld	(ix+Q),1
	jp	lbl30
lbl29:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl37
lbl30:
	ld	b,2
	call	irandom

	cp	1
	jp	z,lbl40
	or  a			;???!?!?!?!?
	jp	z,lbl37
	jp	lbl37
lbl32:
	ld	a,(ix+S)
	cp	vSize
	jp	nz,lbl33
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl3
	ld	(ix+Q),1
	jp	lbl40
lbl33:
	ld	a,(ix+R)
	ld	b,(ix+S)
	inc	b
	call	getJ
	cp	1
	jp	nc,lbl3
	jp	lbl40
lbl35:
	ld	a,(ix+C)
	ld	b,(ix+R)
	dec	b
	ld	c,(ix+S)
	call	storeJ
	inc	(ix+C)
	ld	a,2
	ld	b,(ix+R)
	dec	b
	ld	c,(ix+S)
	call	storeI
	dec	(ix+R)
	ld	a,(ix+C)
	cp	hSize*vSize+1
	jp	z,lbl45
	ld	(ix+Q),0
	jp	lbl7
lbl36:
	ld	a,(ix+C)
	ld	b,(ix+R)
	ld	c,(ix+S)
	dec	c
	call	storeJ
	inc	(ix+C)
	ld	a,1
	ld	b,(ix+R)
	ld	c,(ix+S)
	dec	c
	call	storeI
	dec	(ix+S)
	ld	a,(ix+C)
	cp	hSize*vSize+1
	jp	z,lbl45
	ld	(ix+Q),0
	jp	lbl7
lbl37:
	ld	a,(ix+C)
	ld	b,(ix+R)
	inc	b
	ld	c,(ix+S)
	call	storeJ
	inc	(ix+C)
	ld	a,(ix+R)
	ld	b,(ix+S)
	call	getI
	or a
	jp	z,lbl38
	ld	a,3
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
	jp	lbl39
lbl38:
	ld	a,2
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
lbl39:
	inc	(ix+R)
	ld	a,(ix+C)
	cp	hSize*vSize+1
	jp	z,lbl45
	ld	(ix+Q),0
	jp	lbl20
lbl40:
	ld	a,(ix+Q)
	cp	1
	jp	z,lbl43
	ld	a,(ix+C)
	ld	b,(ix+R)
	ld	c,(ix+S)
	inc	c
	call	storeJ
	inc	(ix+C)
	ld	a,(ix+R)
	ld	b,(ix+S)
	call	getI
	or a
	jp	z,lbl41
	ld	a,3
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
	jp	lbl42
lbl41:
	ld	a,1
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
lbl42:
	inc	(ix+S)
	ld	a,(ix+C)
	cp	hSize*vSize+1
	jp	z,lbl45
	jp	lbl7
lbl43:
	ld	(ix+Z),1
	ld	a,(ix+R)
	ld	b,(ix+S)
	call	getI
	or a
	jp	z,lbl44
	ld	a,3
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
	ld	(ix+Q),0
	jp	lbl3
lbl44:
	ld	a,1
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
	ld	(ix+Q),0
	ld	(ix+R),1
	ld	(ix+S),1
	jp	lbl6
lbl45:
	ld	a,(ix+Z)
	cp	1
	jp	z,lbl72
	ld	b,hSize
	call	irandom
	inc	a
	ld	(ix+R),a
	ld	(ix+S),vSize
	ld	a,(ix+R)
	ld	b,(ix+S)
	call	getI
	inc	a
	ld	b,(ix+R)
	ld	c,(ix+S)
	call	storeI
lbl72:
	ld	(ix+J),1
loop2:
	ld	(ix+I),1
loop3:
	ld	a,(ix+I)
	ld	b,(ix+J)
	call	getI
	ld	(ix+Z),a
	inc	(ix+I)
	ld	a,(ix+I)
	cp	hSize+1
	jr	nz,loop3
	ld	(ix+I),1
loop4:
	ld	a,(ix+I)
	ld	b,(ix+J)
	call	getI
	ld	(ix+Z),a
	inc	(ix+I)
	ld	a,(ix+I)
	cp	hSize+1
	jr	nz,loop4
	inc	(ix+J)
	ld	a,(ix+J)
	cp	vSize+1
	jp	nz,loop2
	ret

initArrays:
	ld	hl,saferam1+arI
	ld	(hl),3	; make top-left corner or array I a block 3
	inc	hl
	ld	b,hSize
initLoop1:
	ld	(hl),2	; fill the top row with 2's
	inc	hl
	djnz	initLoop1
	ld	b,vSize
initLoop2:
	push	bc
	ld	(hl),1	; put 1's in the left column
	inc	hl
	ld	b,hSize
initLoop3:
	ld	(hl),0	; and 0's in the rest
	inc	hl
	djnz	initLoop3
	pop	bc
	djnz	initLoop2

	ld	b,hSize*vSize
clearJ:
	ld	(hl),0	; fill array J with 0's
	inc	hl
	djnz	clearJ
	ret

getI:				; load A with element (A,B) from array I
	dec	b
	sla	b
	sla	b
	sla	b
	sla	b
	add	a,b
	ld	b,0
	ld	c,a
	ld	hl,saferam1+arI+hSize+1
	add	hl,bc
	ld	a,(hl)
	ret

getJ:					; load A with element (A,B) from array J
	dec	a
	dec	b
	ld	c,a
	ld	a,b
	add a,a
	add a,a
	add a,a
	add a,a
	sub	b
	add	a,c
	ld	b,0
	ld	c,a
	ld	hl,saferam1+arJ
	add	hl,bc
	ld	a,(hl)
	ret

storeI:				; store A into element (B,C) of array I
	push	af
	dec	c
	sla	c
	sla	c
	sla	c
	sla	c
	ld	a,b
	add	a,c
	ld	b,0
	ld	c,a
	ld	hl,saferam1+arI+hSize+1
	add	hl,bc
	pop	af
	ld	(hl),a
	ret

storeJ:				; store A into element (B,C) of array J
	push	af
	dec	b
	dec	c
	ld	a,c
	add a,a
	add a,a
	add a,a
	add a,a
	sub	c
	add	a,b
	ld	b,0
	ld	c,a
	ld	hl,saferam1+arJ
	add	hl,bc
	pop	af
	ld	(hl),a
	ret

intro:
	ld	hl,ratPic+(12*18) ; draw bottom of rat picture
	call	dblPic
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen
	ld	bc,delL		; long delay
	call	delay
	ld	bc,12*17		; scroll up 17 double-lines
scrollRat:
	push	bc
	ld	hl,ratPic		; find start of required picture data
	add	hl,bc
	call	dblPic		; draw that part of the picture
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen
	pop	hl
	ld	a,h			; check if at top of picture yet
	or	l
	jr	z,endScroll
	ld	bc,-12		; if not, start next frame 1 line up
	add	hl,bc
	ld	b,h
	ld	c,l
	jr	scrollRat
endScroll:
	ld	bc,delL		; long delay
	call	delay

	ld	hl,PLOTSSCREEN+(12*26)	; draw horizontal line
	ld	b,12
titleLine:
	ld	(hl),$ff
	inc	hl
	djnz	titleLine

	ld	bc,12*37		; clear bottom section of screen
clearTitle:
	ld	(hl),0
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,clearTitle

	ld	de,PLOTSSCREEN+(12*28)	; display title
	ld	hl,titlePic
	ld	bc,12*12
	ldir
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen

	ld	de,39*256+11	; display URL
;	ld	(PENCOL),bc
	ld	hl,url
;	bcall(_vputs)
	call setvputs
	ld	de,45*256+7		; display email address
;	ld	(PENCOL),bc
	ld	hl,email
	call setvputs
;	bcall(_vputs)
	ld	de,52*256+36	; display 'level'
;	ld	(PENCOL),bc

	ld	hl,lvl
	call setvputs
;	bcall(_vputs)
	ld	de,58*256+36	; display message
;	ld	(PENCOL),bc

	ld	hl,message
	call setvputs
;	bcall(_vputs)
	ret

dblPic:				; draw picture with data from HL using double vertical-pixels
	ld	de,PLOTSSCREEN
	ld	b,32
dblLoop:
	push	bc
	ld	bc,12
	ldir
	ld	bc,-12
	add	hl,bc
	ld	bc,12
	ldir
	pop	bc
	djnz	dblLoop
	ret

delay:				; delay of duration BC
	dec	bc
	ld	a,b
	or	c
	or a
	jr	nz,delay
	ret

lvlAddress:				; load HL with address of levelNorm or levelAnti
	ld	b,0
	ld	c,(ix+anti)
	ld	hl,levelNorm
	add	hl,bc
	ret

scrollUp:				; scroll screen up B lines
	ld	hl,63*12
scrollLoop:
	push	bc
	push	hl
	ld	b,h
	ld	c,l
	ld	de,PLOTSSCREEN
	ld	hl,PLOTSSCREEN+12
	ldir
	ld	b,12			; clear bottom line each time
	xor a
clearLine:

	ld	(de),a
	inc	de
	djnz	clearLine
	bcall(_GRBUFCPY)		; copy the graph buffer to the screen
	pop	hl
	ld	bc,-12		; decrease number of lines to copy by 1
	add	hl,bc
	pop	bc
	djnz	scrollLoop
	ret


;******** Data ********

plOffsets:
	.db	1, 1, 2, 1, 0, 1, 1, 1, 1, 1, 1, 0, -1, 2, -1, -1

player:
	.db	%11100000
	.db	%11100000
	.db	%11100000

blocks:
;medium
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%11111111
	.db	%11111111
	.db	%11111111

	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111111
	.db	%11111111
	.db	%11111111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000111
	.db	%00000111
	.db	%00000111

;dither
	.db	%00000101
	.db	%00000010
	.db	%00000101
	.db	%00000010
	.db	%00000101
	.db	%10101010
	.db	%01010101
	.db	%10101010

	.db	%00000101
	.db	%00000010
	.db	%00000101
	.db	%00000010
	.db	%00000101
	.db	%00000010
	.db	%00000101
	.db	%00000010

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%10101010
	.db	%01010101
	.db	%10101010

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000010
	.db	%00000101
	.db	%00000010

;thin
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%11111111

	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001
	.db	%00000001

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000001

;3d
	.db	%00000110
	.db	%00000101
	.db	%00000110
	.db	%00000101
	.db	%00000110
	.db	%11111101
	.db	%10101010
	.db	%01010101

	.db	%00000110
	.db	%00000101
	.db	%00000110
	.db	%00000101
	.db	%00000110
	.db	%00000101
	.db	%00000110
	.db	%00000101

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111111
	.db	%10101010
	.db	%01010101

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000111
	.db	%00000110
	.db	%00000101

;bricks
	.db	%00010001
	.db	%00011111
	.db	%00000100
	.db	%11111111
	.db	%00010001
	.db	%11111111
	.db	%01000100
	.db	%11111111

	.db	%00010001
	.db	%00011111
	.db	%00000100
	.db	%00011111
	.db	%00010001
	.db	%00011111
	.db	%00000100
	.db	%00011111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111111
	.db	%00010001
	.db	%11111111
	.db	%01000100
	.db	%11111111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00011111
	.db	%00010001
	.db	%00011111
	.db	%00000100
	.db	%00011111

;pipes
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%11111101
	.db	%00000001
	.db	%11111111

	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101
	.db	%00000101

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111111
	.db	%00000000
	.db	%11111111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000111
	.db	%00000100
	.db	%00000101

;fuzzy
	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%10101010
	.db	%11111111
	.db	%10101010

	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%00000010
	.db	%00000111
	.db	%00000010

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%10101010
	.db	%11111111
	.db	%10101010

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000010
	.db	%00000111
	.db	%00000010

;wavy
	.db	%00000001
	.db	%00000010
	.db	%00000100
	.db	%00000100
	.db	%00000010
	.db	%00110010
	.db	%01001001
	.db	%10000111

	.db	%00000001
	.db	%00000010
	.db	%00000010
	.db	%00000100
	.db	%00000100
	.db	%00000010
	.db	%00000010
	.db	%00000001

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00011000
	.db	%01100110
	.db	%10000001

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000001

;inverted
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%00000000
	.db	%00000000
	.db	%00000000

	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000
	.db	%11111000

	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%00000000
	.db	%00000000
	.db	%00000000

	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%11111000
	.db	%11111000
	.db	%11111000

;cards
	.db	%00000100
	.db	%00000110
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%11111111
	.db	%01111111
	.db	%00111111

	.db	%00000100
	.db	%00000110
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000111
	.db	%00000011
	.db	%00000001

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%11111100
	.db	%01111110
	.db	%00111111

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000

;rail map
	.db	%01110000
	.db	%10001000
	.db	%10001000
	.db	%10001000
	.db	%01110000
	.db	%00000000
	.db	%00000000
	.db	%00000000

	.db	%01110000
	.db	%10001000
	.db	%10001000
	.db	%10001000
	.db	%01110000
	.db	%01110000
	.db	%01110000
	.db	%01110000

	.db	%01110000
	.db	%10001111
	.db	%10001111
	.db	%10001111
	.db	%01110000
	.db	%00000000
	.db	%00000000
	.db	%00000000

	.db	%01110000
	.db	%10001111
	.db	%10001111
	.db	%10001111
	.db	%01110000
	.db	%01110000
	.db	%01110000
	.db	%01110000

;eyes
	.db	%00000100
	.db	%00000100
	.db	%00000100
	.db	%00001110
	.db	%00010001
	.db	%11110101
	.db	%00010001
	.db	%00001110

	.db	%00000100
	.db	%00000100
	.db	%00000100
	.db	%00001110
	.db	%00010001
	.db	%00010101
	.db	%00010001
	.db	%00001110

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00001110
	.db	%00010001
	.db	%11110101
	.db	%00010001
	.db	%00001110

	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00001110
	.db	%00010001
	.db	%00010101
	.db	%00010001
	.db	%00001110

;boulders
	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%11111111
	.db	%01111111
	.db	%00111110
	.db	%00011100

	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%01111111
	.db	%01111111
	.db	%00111110
	.db	%00011100

	.db	%00000000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%11111111
	.db	%01111111
	.db	%00111110
	.db	%00011100

	.db	%00000000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%01111111
	.db	%01111111
	.db	%00111110
	.db	%00011100

;option button
	.db	%00111000
	.db	%01000100
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%01000100
	.db	%00111000
	.db	%00000000

	.db	%00111000
	.db	%01000100
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%01000100
	.db	%00111000
	.db	%00111000

	.db	%00111000
	.db	%01000100
	.db	%10000011
	.db	%10000011
	.db	%10000011
	.db	%01000100
	.db	%00111000
	.db	%00000000

	.db	%00111000
	.db	%01000100
	.db	%10000011
	.db	%10000011
	.db	%10000011
	.db	%01000100
	.db	%00111000
	.db	%00111000

;diamonds
	.db	%00001000
	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%11111111
	.db	%00111110
	.db	%00011100
	.db	%00001000

	.db	%00001000
	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%00111110
	.db	%00011100
	.db	%00001000

	.db	%00000000
	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%11111111
	.db	%00111110
	.db	%00011100
	.db	%00001000

	.db	%00000000
	.db	%00001000
	.db	%00011100
	.db	%00111110
	.db	%01111111
	.db	%00111110
	.db	%00011100
	.db	%00001000

;rooms
	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%11111111
	.db	%00001000
	.db	%00001000
	.db	%00001000

	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%01111111
	.db	%00001000
	.db	%00001000
	.db	%00001000

	.db	%00000000
	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%11111111
	.db	%00001000
	.db	%00001000
	.db	%00001000

	.db	%00000000
	.db	%00001000
	.db	%00001000
	.db	%00001000
	.db	%01111111
	.db	%00001000
	.db	%00001000
	.db	%00001000
 
url:
	.db	"http://move.to/badja"

ratPic:
.db %00000000,%00000001,%00100010,%00000001,%10001000,%01010010,%01101001,%00000001,%00010000,%10001000,%00000000,%00000000
.db %00000000,%00000000,%00001111,%00110001,%00110001,%11111100,%10011111,%00110110,%10000011,%11000001,%00000000,%00000000
.db %00000000,%00011110,%11111000,%11111001,%11111110,%00111111,%11110000,%11001111,%10110000,%01001100,%00000000,%00000000
.db %00000101,%01100000,%00001000,%00001110,%00000010,%00100000,%00011100,%10110000,%01101110,%11110001,%11010100,%00000000
.db %00000000,%00000011,%11111111,%11011111,%11111111,%00101111,%00010111,%11111111,%11110000,%00011110,%00000000,%00000000
.db %00000000,%01101010,%00001110,%01010000,%00001111,%00111001,%00010010,%00000000,%11001111,%11111000,%11110100,%00000000
.db %00001011,%10100010,%00111000,%01110000,%01111001,%00111111,%11111111,%11111111,%11001000,%00000111,%00000000,%00000000
.db %00110000,%00100011,%11000000,%01010011,%11000001,%10100000,%00000000,%00000000,%01001000,%00000000,%01111001,%00000000
.db %00000001,%11111111,%11111111,%11111011,%11111111,%10100000,%00000000,%01111111,%11111111,%11111111,%00100011,%00000000
.db %00000001,%00000000,%00000000,%00000000,%00000110,%10100000,%00000000,%01011100,%00000000,%00000001,%00100000,%00000000
.db %00101111,%11111111,%11000000,%00000000,%00011000,%11100000,%00000000,%01000111,%00000000,%00111111,%11111110,%10000000
.db %00000000,%01111100,%01000000,%00000000,%01110000,%11100000,%00000000,%01000001,%11000000,%00100000,%00000000,%00000000
.db %00001111,%10000000,%01000000,%00000000,%01010000,%11100000,%00000000,%01000001,%01000000,%00100000,%00000000,%00000000
.db %01010000,%00000001,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111110,%00000000,%00000000
.db %00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000010,%00000000,%00000000
.db %00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000010,%00000000,%00000000
.db %11111111,%11111111,%11111111,%11100000,%00000000,%00000000,%00000000,%00000000,%00000111,%11111111,%11111111,%11111111
.db %00000000,%00000000,%00000111,%01100000,%00000000,%00000000,%00000000,%00000000,%00000110,%11100000,%00000000,%00000000
.db %00000000,%00000000,%00011100,%01100000,%00000000,%00000000,%00000000,%00000000,%00000110,%00111000,%00000000,%00000000
.db %00000000,%00000000,%01110000,%01100000,%00000000,%11111000,%01111100,%00000000,%00000110,%00001110,%00000000,%00000000
.db %00000000,%00000001,%11000000,%01100000,%00000001,%00000100,%11000110,%00000000,%00000110,%00000011,%10000000,%00000000
.db %00000000,%00000111,%00000000,%01100000,%00000001,%10000111,%11000010,%00000000,%00000110,%00000000,%11100000,%00000000
.db %00000000,%00011100,%00000000,%01100000,%00000000,%11100001,%01100110,%00000000,%00000110,%00000000,%00111000,%00000000
.db %00000000,%01110000,%00000000,%01100000,%00000001,%10100000,%01001100,%00000000,%00000110,%00000000,%00001110,%00000000
.db %00000001,%11000000,%00000000,%01100000,%00001110,%00000000,%00100100,%00000000,%00000110,%00000000,%00000011,%10000000
.db %00000111,%00000000,%00000000,%01100000,%00000011,%11000111,%00011011,%11111000,%00000110,%00000000,%00000000,%11100000
.db %00011100,%00000000,%00000000,%01100000,%00000000,%00111000,%00000101,%10000110,%00000110,%00000000,%00000000,%00111000
.db %01110000,%00000000,%00000000,%01100000,%00000001,%11000000,%00001000,%11111011,%00000110,%00000000,%00000000,%00001110
.db %10000000,%00000000,%00000000,%01100000,%00000111,%00000000,%00000010,%00100100,%10000110,%00000000,%00000000,%00000001
.db %00000000,%00000000,%00000000,%01100000,%00011000,%00110000,%00000100,%00110111,%10000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00110011,%11011000,%00000001,%00010000,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00101010,%00011000,%00000010,%00011000,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00000000,%00111100,%00000000,%00001000,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01111111,%11111111,%11100000,%00000000,%00001111,%11111110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00000001,%10000000,%00000000,%00001000,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%11100011,%00000011,%00001100,%00101100,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%10010100,%00011111,%11011110,%01000100,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%11001001,%11110000,%11111111,%11100010,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%01100111,%00000000,%00111100,%00110010,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00111110,%00000000,%01111000,%00011010,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%01100000,%00000000,%00000001,%11110000,%01101011,%00000110,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%11000000,%00000000,%00011111,%11000000,%01110011,%00000011,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000000,%11000000,%00000111,%11111110,%00000000,%00011110,%00000011,%00000000,%00000000,%00000000
.db %00000000,%00000000,%00000001,%10000001,%11111110,%00000000,%00000000,%00000000,%00000001,%10000000,%00000000,%00000000
.db %00000000,%00000000,%00000001,%10001111,%10000000,%00000000,%00000000,%00000000,%00000001,%10000000,%00000000,%00000000
.db %00000000,%00000000,%00000011,%00011100,%00000000,%00000000,%00000000,%00000000,%00000000,%11000000,%00000000,%00000000
.db %00000000,%00000000,%00000011,%00011110,%00000000,%00000000,%00000000,%00000000,%00000000,%11000000,%00000000,%00000000
.db %00000000,%00000000,%00000110,%00000111,%11110000,%00000000,%00000000,%00000000,%00000000,%01100000,%00000000,%00000000
.db %00000000,%00000000,%00000110,%00000000,%01111111,%11100000,%00000000,%00000000,%00000000,%01100000,%00000000,%00000000
.db %00000000,%00000000,%00001100,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00110000,%00000000,%00000000

titlePic:
.db %11110000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
.db %01100000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00100000,%00010000,%00000000
.db %01100000,%00000001,%11100001,%11111111,%10111100,%11111111,%11111100,%11110111,%10000011,%11111111,%11111111,%00001111
.db %01100000,%00000001,%11000000,%11111111,%11011100,%11100111,%11111110,%01100011,%10000001,%10111111,%11110110,%00000110
.db %01100000,%00000001,%11100000,%11000000,%11001100,%11000110,%00000110,%01100011,%11100001,%10100011,%00010110,%00000110
.db %01100000,%00000011,%01100000,%11111111,%10000111,%10000110,%00000110,%01100011,%11110001,%10000011,%00000111,%11111110
.db %01100000,%00000011,%00110000,%11111111,%11000111,%10000111,%11111110,%01100011,%00111001,%10000011,%00000111,%11111110
.db %01100000,%00000111,%11111000,%11000000,%11000011,%00000111,%11111100,%01100011,%00011111,%10000011,%00000110,%00000110
.db %01100000,%01000111,%11111000,%11000000,%11000011,%00000110,%00111000,%01100011,%00001111,%10000011,%00000110,%00000110
.db %01111111,%11001100,%00001100,%11111111,%11000011,%00000110,%00011100,%01100011,%00000011,%10000011,%00000110,%00000110
.db %11111111,%11011110,%00011111,%11111111,%10000111,%10001111,%00011111,%11110111,%10000011,%11000111,%10001111,%00001111
.db %00000000,%01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

email:
	.db	"badja@alphalink.com.au",0
maze:
	.db	"Maze",0
antimaze:
	.db	"Antimaze",0
lvl:
	.db	"Level",0
message:
	.db	"DEL: Restart game",0
spaces:
	.db	"   ",0
winMsg:
	.db	"Congratulations!",0
win1:
	.db	"Now try antimaze",0
win2:
	.db	"You have escaped",0
	.db	"the Labyrinth!",0

levelNorm:
	.db	0
levelAnti:
	.db	0

.end
