	
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
	ld	hl, -9
	call	ti._frameset
	ld	iy, (ix + 9)
	ld	b, 0
	lea	hl, iy + 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, BB7_1
	jq	BB7_11
BB7_1:
	ld	hl, (ix + 12)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, BB7_2
	jq	BB7_11
BB7_2:
	ld	c, (ix + 6)
	ld	a, c
	or	a, a
	jq	nz, BB7_4
	ld	de, _init_usb
	ld	(ix + -6), de
	ld	de, _usb_process
	ld	(ix + -3), de
	ld	de, _usb_read_to_size
	ld	(ix + -9), de
	ld	de, _usb_write
	jq	BB7_6
BB7_4:
	ld	a, c
	cp	a, 1
	jq	nz, BB7_11
	ld	bc, 0
	ld	(ix + -3), bc
	inc	c
	ld	de, _pipe_init
	ld	(ix + -6), de
	ld	de, _pipe_read_to_size
	ld	(ix + -9), de
	ld	de, _cemu_send
BB7_6:
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
	call	ti._atomic_load_increasing_32
	ld	(ix + -3), hl
	ld	(ix + -6), e
	pop	hl
BB7_7:
	ld	hl, (_srl_funcs+1)
	call	ti._indcallhl
	ld	b, a
	bit	0, b
	jq	nz, BB7_11
	ld	(ix + -9), b
	ld	hl, -917472
	push	hl
	call	ti._atomic_load_increasing_32
	pop	bc
	ld	bc, (ix + -3)
	ld	a, (ix + -6)
	call	ti._lsub
	ld	bc, (ix + 15)
	xor	a, a
	call	ti._lcmpu
	ld	a, 1
	jq	c, BB7_10
	ld	a, 0
BB7_10:
	bit	0, a
	ld	b, (ix + -9)
	jq	nz, BB7_7
BB7_11:
	ld	a, b
	ld	sp, ix
	pop	ix
	ret
	
pl_PreparePacket:
	ld	hl, -12
	call	ti._frameset
	ld	de, (ix + 9)
	push	de
	pop	iy
	ld	a, (ix + 12)
	ld	bc, 0
	or	a, a
	sbc	hl, hl
	ld	l, a
BB9_1:
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB9_2
	ld	(ix + -9), hl
	ld	de, (iy)
	ld	hl, (iy + 3)
	ld	(ix + -3), hl
	ld	(ix + -6), iy
	ld	iy, (ix + 18)
	lea	hl, iy + 6
	ld	(ix + -12), bc
	add	hl, bc
	ld	bc, (ix + -3)
	push	bc
	push	de
	push	hl
	call	ti._memcpy
	ld	hl, (ix + -9)
	ld	bc, (ix + -6)
	pop	de
	pop	de
	pop	de
	ld	iy, (ix + -3)
	ld	de, (ix + -12)
	add	iy, de
	lea	de, iy + 0
	dec	hl
	push	bc
	pop	iy
	lea	iy, iy + 6
	push	de
	pop	bc
	jq	BB9_1
BB9_2:
	ld	de, 3
	push	bc
	pop	hl
	add	hl, de
	ex	de, hl
	ld	a, (ix + 6)
	ld	iy, (ix + 18)
	ld	(iy + 3), a
	ld	hl, (ix + 18)
	ld	(hl), de
	ld	bc, (_srl_dbuf_size)
	ex	de, hl
	call	ti._idivu
	ld	a, l
	inc	a
	ld	iy, (ix + 18)
	ld	(iy + 4), a
	ld	a, (ix + 15)
	ld	(iy + 5), a
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
	ld hl, -6
	call	ti._frameset
	ld	hl, (ix + 6)
	xor	a, a
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB10_9
	ld	hl, (hl)
	ld	de, 3
	ld	(ix + -6), hl
	or	a, a
	sbc	hl, de
	jq	nc, BB10_2
BB10_9:
	ld	sp, ix
	pop	ix
	ret
BB10_2:
BB10_3:
	ld	de, (_srl_dbuf_size)
	push	de
	pop	hl
	ld	bc, (ix + -6)
	or	a, a
	sbc	hl, bc
	jq	c, BB10_5
	ld	de, (ix + -6)
BB10_5:
	ld	(ix + -3), de
	ld	hl, (_srl_funcs+10)
	ld	de, 3
	push	de
	pea	ix + -3
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB10_7
	call	ti._indcallhl
BB10_7:
	ld	hl, (_srl_funcs+10)
	ld	de, (ix + -3)
	push	de
	ld	de, (ix + 6)
	push	de
	call	ti._indcallhl
	pop	hl
	pop	hl
	ld	hl, (_srl_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, BB10_3
	call	ti._indcallhl
	jq	BB10_3
	
	
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
	call	ti._lsub
	ld	bc, (_srl_read_timeout)
	xor	a, a
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
