	
;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'SRLPKTCE', 0

;-------------------------------------------------------------------------------
; Dependencies
;-------------------------------------------------------------------------------
include_library '../usbdrvce/usbdrvce.asm'
include_library '../srldrvce/srldrvce.asm'

;-------------------------------------------------------------------------------
; v0 functions (not final, subject to change!)
;-------------------------------------------------------------------------------
export pl_InitSubsystem
export pl_SetReadTimeout
export pl_JoinPacketSegments
export pl_SendPacket
export pl_ReadPacket


_indcallhl:
	jp	(hl)
	
_indcall   := 00015Ch

_atomic_load_increasing_32:
	pop	hl
	ex	(sp),iy			; iy = p
	push	hl
	ld	a,i
	di
	ld	de,(iy)			;         2R
	ld	c,(iy+3)		;  + 3F + 1R
	ld	hl,(iy)			;  + 3F + 3R
	ld	a,(iy+3)		;  + 3F + 1R
					; == 9F + 7R
					; == 57 cc
					;  + 9 * 19 cc = 171 cc (worst-case DMA)
					; = 228 cc
	jp	po,no_ei
	ei
no_ei:
	or	a,a
	sbc	hl,de
	sbc	a,c			; auhl = second value read
					;         - first value read
	ex	de,hl
	ld	e,c			; euhl = first value read
	ret

no_swap:
	add	hl,de
	adc	a,c
	ld	e,a			; euhl = second value read
	ret

_usb_read_to_size:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	iy, (ix + 9)
	ld	de, _srl
	ld	bc, (_srl_bytes_read)
	add	iy, bc
	or	a, a
	sbc	hl, bc
	push	hl
	push	iy
	push	de
	call	srl_Read
	push	hl
	pop	de
	pop	hl
	pop	hl
	pop	hl
	ld	iy, (_srl_bytes_read)
	add	iy, de
	ld	de, (ix + 6)
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	lea	hl, iy + 0
	jq	c, .lbl_2
	or	a, a
	sbc	hl, hl
.lbl_2:
	ld	(_srl_bytes_read), hl
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	nc, .lbl_3
	ld	a, 0
	jq	.lbl_5
.lbl_3:
	ld	a, 1
.lbl_5:
	pop	ix
	ret

_usb_write:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	de, (ix + 9)
	ld	bc, _srl
	push	de
	push	hl
	push	bc
	call	srl_Write
	ld	sp, ix
	pop	ix
	ret

_usb_process	:= usb_HandleEvents
;	jp	usb_HandleEvents
	
_init_usb:
	call	srl_GetCDCStandardDescriptors
	ld	de, 12
	push	de
	push	hl
	ld	hl, 0
	push	hl
	ld	hl, _handle_usb_event
	push	hl
	call	usb_Init
	pop	de
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	ld	a, 0
	ret
.lbl_1:
	ld	a, 1
	ret

_handle_usb_event:
	ld	hl, -1
	call	ti._frameset
	ld	iy, (ix + 6)
	xor	a, a
	ld	de, 0
	ld	bc, 1
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_7
	ld	bc, 2
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_4
	call	usb_GetRole
	ld	de, 0
	ld	a, l
	bit	4, a
	jq	z, .lbl_5
	jq	.lbl_8
.lbl_4:
	ld	bc, 8
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_8
.lbl_5:
	ld	de, _srl
	ld	iy, 3
	ld	bc, (_srl_buf)
	ld	hl, -1
	push	hl
	push	iy
	push	bc
	ld	hl, (ix + 9)
	push	hl
	push	de
	call	srl_Init
	ld	de, 0
	pop	hl
	pop	hl
	pop	hl
	pop	hl
	pop	hl
	or	a, a
	jq	nz, .lbl_8
	ld	hl, 115200
	push	hl
	ld	hl, _srl
	push	hl
	call	srl_SetRate
	pop	hl
	pop	hl
	ld	hl, 1
	push	hl
	pea	ix + -1
	ld	hl, _srl
	push	hl
	call	srl_Read
	ld	de, 0
	pop	hl
	pop	hl
	pop	hl
	ld	a, 1
.lbl_7:
	ld	(_device_connected), a
.lbl_8:
	ex	de, hl
	inc	sp
	pop	ix
	ret

_pipe_init:
	ld	a, 1
	ld	l, 1
	ld	(_device_connected), a
	ld	a, l
	ret

_pipe_read_to_size:
	call	ti._frameset0
	ld	bc, (ix + 6)
	ld	de, (_srl_bytes_read)
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	jq	nc, .lbl_8
	ld	iy, (ix + 9)
	add	iy, de
	push	bc
	pop	hl
	or	a, a
	sbc	hl, de
	push	hl
	push	iy
	call	_cemu_get
	ld	bc, (ix + 6)
	push	hl
	pop	de
	pop	hl
	pop	hl
	ld	iy, (_srl_bytes_read)
	add	iy, de
	ld	(_srl_bytes_read), iy
	jq	.lbl_2
.lbl_8:
	push	de
	pop	iy
.lbl_2:
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_4
	or	a, a
	sbc	hl, hl
	ld	(_srl_bytes_read), hl
.lbl_4:
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_5
	ld	a, 0
	jq	.lbl_7
.lbl_5:
	ld	a, 1
.lbl_7:
	pop	ix
	ret

check_cmd = 2
send_cmd = 3
get_cmd = 4

dbgext = 0xFD0000

_cemu_send:
	pop	de
	pop	hl
	pop	bc
	push	bc
	push	hl
	push	de
	ld	a,send_cmd
	ld	(dbgext),a
	push	bc
	pop	hl

	ret

_cemu_get:
	pop	hl
	pop	de
	pop	bc
	push	bc
	push	de
	push	hl
	ld	a,get_cmd
	ld	(dbgext),a
	push	bc
	pop	hl
	ret


pl_InitSubsystem:
	ld	hl, -9
	call	ti._frameset
	ld	iy, (ix + 9)
	ld	b, 0
	lea	hl, iy + 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_1
	jq	.lbl_11
.lbl_1:
	ld	hl, (ix + 12)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_2
	jq	.lbl_11
.lbl_2:
	ld	c, (ix + 6)
	ld	a, c
	or	a, a
	jq	nz, .lbl_4
	ld	de, _init_usb
	ld	(ix + -6), de
	ld	de, _usb_process
	ld	(ix + -3), de
	ld	de, _usb_read_to_size
	ld	(ix + -9), de
	ld	de, _usb_write
	jq	.lbl_6
.lbl_4:
	ld	a, c
	cp	a, 1
	jq	nz, .lbl_11
	ld	bc, 0
	ld	(ix + -3), bc
	inc	c
	ld	de, _pipe_init
	ld	(ix + -6), de
	ld	de, _pipe_read_to_size
	ld	(ix + -9), de
	ld	de, _cemu_send
.lbl_6:
	ld	a, c
	ld	(_srl_funcs), a
	ld	bc, (ix + -6)
	ld	(_srl_funcs+1), bc
	ld	bc, (ix + -3)
	ld	(_srl_funcs+4), bc
	ld	bc, (ix + -9)
	ld	(_srl_funcs+7), bc
	ld	(_srl_funcs+10), de
	ld	(_srl_buf), iy
	ld	c, 1
	call	ti._ishru
	ld	(_srl_dbuf_size), hl
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	ld	(ix + -3), hl
	ld	(ix + -6), e
	pop	hl
.lbl_7:
	ld	hl, (_srl_funcs+1)
	call	_indcallhl
	ld	b, a
	bit	0, b
	jq	nz, .lbl_11
	ld	(ix + -9), b
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	pop	bc
	ld	bc, (ix + -3)
	ld	a, (ix + -6)
	call	ti._lsub
	ld	bc, (ix + 15)
	xor	a, a
	call	ti._lcmpu
	ld	a, 1
	jq	c, .lbl_10
	ld	a, 0
.lbl_10:
	bit	0, a
	ld	b, (ix + -9)
	jq	nz, .lbl_7
.lbl_11:
	ld	a, b
	ld	sp, ix
	pop	ix
	ret
	
	
	
pl_SetReadTimeout:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	(_srl_read_timeout), hl
	pop	ix
	ret


pl_JoinPacketSegments:
	ld	hl, -12
	call	ti._frameset
	ld	a, (ix + 6)
	ld	iy, (ix + 9)
	ld	hl, (ix + 15)
	ld	de, 1
	ld	(ix + -3), de
	ld	(hl), a
	ld	bc, 0
	ld	a, (ix + 12)
	ld	c, a
.lbl_1:
	push	bc
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_2
	ld	hl, (iy)
	ld	(ix + -9), hl
	ld	hl, (iy + 3)
	ld	(ix + -6), hl
	ld	hl, (ix + 15)
	ld	de, (ix + -3)
	add	hl, de
	ld	de, (ix + -6)
	push	de
	ld	de, (ix + -9)
	push	de
	push	hl
	ld	(ix + -9), iy
	ld	(ix + -12), bc
	call	ti._memcpy
	ld	bc, (ix + -12)
	ld	iy, (ix + -9)
	pop	hl
	pop	hl
	pop	hl
	ld	hl, (ix + -6)
	ld	de, (ix + -3)
	add	hl, de
	dec	bc
	lea	iy, iy + 6
	ld	(ix + -3), hl
	jq	.lbl_1
.lbl_2:
	ld	hl, (ix + -3)
	ld	sp, ix
	pop	ix
	ret
	
	
pl_SendPacket:
	ld	hl, -3
	call	ti._frameset
	ld	hl, (ix + 9)
	ld	bc, -3
	ld	de, 0
	ld	iy, (_srl_dbuf_size)
	add	iy, bc
	push	hl
	pop	bc
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	c, .lbl_2
	push	bc
	pop	iy
.lbl_2:
	ld	(ix + -3), iy
	ld	hl, (ix + 6)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_3
	jq	.lbl_7
.lbl_3:
	push	bc
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_7
	ld	de, 3
	ld	hl, (_srl_funcs+10)
	push	de
	pea	ix + -3
	call	_indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+10)
	ld	de, (ix + -3)
	push	de
	ld	de, (ix + 6)
	push	de
	call	_indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_6
	call	_indcallhl
.lbl_6:
	ld	de, (ix + -3)
.lbl_7:
	ex	de, hl
	ld	sp, ix
	pop	ix
	ret
	
	
pl_ReadPacket:
	ld	hl, -4
	call	ti._frameset
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	ld	(ix + -3), hl
	ld	(ix + -4), e
	pop	hl
	ld	e, 1
.lbl_1:
	ld	hl, (_srl_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_3
	call	_indcallhl
	ld	e, 1
.lbl_3:
	ld	a, (_device_connected)
	xor	a, e
	bit	0, a
	jq	nz, .lbl_10
	ld	hl, (_pl_ReadPacket.packet_size)
	ld	iy, (_srl_funcs+7)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_7
	ld	hl, (ix + 6)
	push	hl
	ld	hl, 3
	push	hl
	call	_indcall
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, .lbl_8
	ld	hl, (ix + 6)
	ld	hl, (hl)
	ld	(_pl_ReadPacket.packet_size), hl
	jq	.lbl_8
.lbl_7:
	ld	de, (ix + 6)
	push	de
	push	hl
	call	_indcall
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	z, .lbl_11
.lbl_8:
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	pop	bc
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	ti._lsub
	ld	bc, (_srl_read_timeout)
	xor	a, a
	call	ti._lcmpu
	ld	e, 1
	jq	c, .lbl_1
.lbl_10:
	or	a, a
	sbc	hl, hl
.lbl_12:
	ld	sp, ix
	pop	ix
	ret
.lbl_11:
	or	a, a
	sbc	hl, hl
	ld	(_pl_ReadPacket.packet_size), hl
	ld	hl, (ix + 9)
	jq	.lbl_12
	
_srl_buf:
	rb	3

_device_connected:
	rb	1

_srl_bytes_read:
	rb	3

_srl_read_timeout:
	rb	3

_srl:
	rb	40

_srl_funcs:
	rb	13

_srl_dbuf_size:
	rb	3

_pl_ReadPacket.packet_size:
	rb	3
	
_pl_SendPacket.bytes_sent:
	rb	3

_srl_buf_size:
	rb	3
