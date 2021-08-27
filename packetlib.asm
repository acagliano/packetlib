	
;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'PACKLIB', 0

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
export pl_PreparePacket
export pl_SendPacket
export pl_ReadPacket


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
	jq	c, BB0_2
	or	a, a
	sbc	hl, hl
BB0_2:
	ld	(_srl_bytes_read), hl
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	nc, BB0_3
	ld	a, 0
	jq	BB0_5
BB0_3:
	ld	a, 1
BB0_5:
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

_usb_process:
	jp	usb_HandleEvents
	
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
	jq	z, BB3_1
	ld	a, 0
	ret
BB3_1:
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
	jq	z, BB4_7
	ld	bc, 2
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, BB4_4
	call	usb_GetRole
	ld	de, 0
	ld	a, l
	bit	4, a
	jq	z, BB4_5
	jq	BB4_8
BB4_4:
	ld	bc, 8
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, BB4_8
BB4_5:
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
	jq	nz, BB4_8
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
BB4_7:
	ld	(_device_connected), a
BB4_8:
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
	jq	nc, BB6_8
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
	jq	BB6_2
BB6_8:
	push	de
	pop	iy
BB6_2:
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	nz, BB6_4
	or	a, a
	sbc	hl, hl
	ld	(_srl_bytes_read), hl
BB6_4:
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	z, BB6_5
	ld	a, 0
	jq	BB6_7
BB6_5:
	ld	a, 1
BB6_7:
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
	ld	hl, -12
	call	ti._frameset
	ld	de, (ix + 9)
	ld	b, 0
	push	de
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB7_10
	ld	hl, (ix + 12)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB7_10
	ld	c, (ix + 6)
	ld	a, c
	or	a, a
	jq	nz, BB7_6
	ld	hl, _init_usb
	ld	(ix + -9), hl
	ld	iy, _usb_process
	ld	(ix + -3), iy
	ld	hl, _usb_read_to_size
	ld	(ix + -6), hl
	ld	hl, _usb_write
	jq	BB7_8
BB7_6:
	ld	a, c
	cp	a, 1
	jq	nz, BB7_10
	ld	bc, 0
	ld	(ix + -3), bc
	inc	c
	ld	hl, _pipe_init
	ld	(ix + -9), hl
	ld	iy, _pipe_read_to_size
	ld	(ix + -6), iy
	ld	hl, _cemu_send
BB7_8:
	ld	(ix + -12), hl
	ld	a, c
	ld	(_srl_funcs), a
	ld	iy, (ix + -9)
	ld	(_srl_funcs+1), iy
	ld	bc, (ix + -3)
	ld	(_srl_funcs+4), bc
	ld	hl, (ix + -6)
	ld	(_srl_funcs+7), hl
	ld	hl, (ix + -12)
	ld	(_srl_funcs+10), hl
	ld	(_srl_buf), de
	ld	c, 1
	ld	hl, (ix + 12)
	call	ti._ishru
	ld	(_srl_dbuf_size), hl
	call	ti._indcall
	ld	b, a
BB7_10:
	ld	a, b
	ld	sp, ix
	pop	ix
	ret
	
pl_PreparePacket:
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
BB8_1:
	push	bc
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB8_2
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
	jq	BB8_1
BB8_2:
	ld	sp, ix
	pop	ix
	ret
	
	
pl_SetReadTimeout:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	(_srl_read_timeout), hl
	pop	ix
	ret


pl_SendPacket:
	ld	hl, -8
	call	ti._frameset
	ld	c, (ix + 6)
	ld	hl, (ix + 9)
	ld	de, (ix + 12)
	xor	a, a
	ld	(ix + -1), c
	ld	(ix + -4), de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, BB10_1
	jq	BB10_9
BB10_1:
	ex	de, hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB10_9
	ld	de, 3
	ld	hl, (_srl_funcs+10)
	push	de
	pea	ix + -4
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	de, (ix + -4)
	push	de
	pop	bc
	inc	bc
	ld	hl, (_srl_dbuf_size)
	or	a, a
	sbc	hl, bc
	jq	nc, BB10_3
	ld	a, 1
	ld	iy, 0
	ld	bc, 1
	ld	l, 0
BB10_5:
	ld	(ix + -5), l
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	nc, BB10_10
	ld	hl, (_srl_funcs+10)
	push	bc
	pea	ix + -1
	ld	(ix + -8), iy
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+10)
	ld	de, 1
	push	de
	pea	ix + -5
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	bc, (ix + -8)
	ld	iy, (ix + 9)
	add	iy, bc
	ld	de, (_srl_dbuf_size)
	ld	hl, (ix + -4)
	or	a, a
	sbc	hl, bc
	push	hl
	pop	bc
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	jq	c, BB10_8
	push	bc
	pop	de
BB10_8:
	ld	hl, (_srl_funcs+10)
	push	de
	push	iy
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	de, (_srl_dbuf_size)
	ld	iy, (ix + -8)
	ld	bc, -2
	add	iy, bc
	add	iy, de
	ld	l, (ix + -5)
	inc	l
	ld	de, (ix + -4)
	ld	a, 1
	ld	bc, 1
	jq	BB10_5
BB10_3:
	ld	hl, (_srl_funcs+10)
	ld	de, 0
	ld	a, (ix + 6)
	ld	e, a
	ld	bc, 1
	push	bc
	push	de
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+10)
	ld	de, (ix + -4)
	push	de
	ld	de, (ix + 9)
	push	de
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	a, 1
	jq	BB10_9
BB10_10:
BB10_9:
	ld	sp, ix
	pop	ix
	ret
	
pl_ReadPacket:
	ld	hl, -4
	call	ti._frameset
	ld	hl, -917472
	push	hl
	call	ti._atomic_load_increasing_32
	ld	(ix + -3), hl
	ld	(ix + -4), e
	pop	hl
	ld	e, 1
BB11_1:
	ld	hl, (_srl_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB11_3
	call	ti._indcallhl
	ld	e, 1
BB11_3:
	ld	a, (_device_connected)
	xor	a, e
	bit	0, a
	jq	nz, BB11_10
	ld	hl, (_pl_ReadPacket.packet_size)
	ld	iy, (_srl_funcs+7)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, BB11_7
	ld	hl, (ix + 6)
	push	hl
	ld	hl, 3
	push	hl
	call	ti._indcall
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, BB11_8
	ld	hl, (ix + 6)
	ld	hl, (hl)
	ld	(_pl_ReadPacket.packet_size), hl
	jq	BB11_8
BB11_7:
	ld	de, (ix + 6)
	push	de
	push	hl
	call	ti._indcall
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	z, BB11_11
BB11_8:
	ld	hl, -917472
	push	hl
	call	ti._atomic_load_increasing_32
	pop	bc
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	__lsub
	push	hl
	pop	bc
	ld	a, e
	ld	hl, (_srl_read_timeout)
	ld	e, 0
	call	ti._lcmpu
	ld	e, 1
	jq	c, BB11_1
BB11_10:
	or	a, a
	sbc	hl, hl
BB11_12:
	ld	sp, ix
	pop	ix
	ret
BB11_11:
	or	a, a
	sbc	hl, hl
	ld	(_pl_ReadPacket.packet_size), hl
	ld	hl, (ix + 9)
	jq	BB11_12
	
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

_srl_buf_size:
	rb	3
