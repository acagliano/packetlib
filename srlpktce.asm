	
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

export pl_GetDeviceStatus
export pl_Shutdown

os_GetKey	:= $21D38

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

_usb_init:
	ld	hl, -2
	call	ti._frameset
	ld	hl, _handle_usb_event
	ld	de, 0
	ld	bc, 36106
	xor	a, a
	ld	(ix + -2), a
	push	bc
	push	de
	push	de
	push	hl
	call	usb_Init
	pop	de
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_4
	ld	hl, 1
	ld	de, 115200
	ld	(_device_status), hl
	ld	iy, (_usb_device)
	ld	bc, (_srl_buf)
	ld	hl, (_srl_buf_size)
	push	de
	ld	de, -1
	push	de
	push	hl
	push	bc
	push	iy
	ld	hl, _srl_device
	push	hl
	call	srl_Open
	pop	de
	pop	de
	pop	de
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_3
	ld	hl, 2
	ld	a, 1
	ld	(ix + -2), a
	ld	(_device_status), hl
	dec	hl
	push	hl
	pea	ix + -1
	ld	hl, _srl_device
	push	hl
	call	srl_Read
	pop	hl
	pop	hl
	pop	hl
	jq	.lbl_3
.lbl_4:
.lbl_3:
	ld	a, (ix + -2)
	ld	sp, ix
	pop	ix
	ret
	
_usb_process:
	jp	usb_HandleEvents

_usb_read_to_size:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	iy, (ix + 9)
	ld	de, _srl_device
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
	ld	bc, _srl_device
	push	de
	push	hl
	push	bc
	call	srl_Write
	ld	sp, ix
	pop	ix
	ret
	

_handle_usb_event:
	call	ti._frameset0
	or	a, a
	sbc	hl, hl
	pop	ix
	ret
	
	
_pipe_init:
	ld	hl, 3
	ld	a, 1
	ld	(_device_status), hl
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
	ld	e, (ix + 6)
	ld	c, 0
	ld	a, e
	cp	a, 2
	jq	nc, .lbl_14
	ld	iy, (ix + 9)
	lea	hl, iy + 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_15
	ld	hl, (_device_status)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_13
	ld	a, e
	or	a, a
	jq	nz, .lbl_5
	ld	hl, _srl_callbacks
	jq	.lbl_7
.lbl_14:
	jq	.lbl_13
.lbl_15:
.lbl_13:
	ld	a, c
	ld	sp, ix
	pop	ix
	ret
.lbl_5:
	ld	a, e
	cp	a, 1
	jq	nz, .lbl_8
	ld	hl, _pipe_callbacks
.lbl_7:
	ld	(_srl_funcs), hl
.lbl_8:
	ld	hl, (iy)
	ld	(_srl_buf), hl
	ld	hl, (iy + 3)
	ld	(_srl_buf_size), hl
	ld	c, 1
	call	ti._ishru
	ld	(_srl_dbuf_size), hl
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	ld	(ix + -3), hl
	ld	(ix + -4), e
	pop	hl
	xor	a, a
	ld	bc, (ix + 12)
	call	ti._ultof
	ld	hl, 201327
	ld	e, 66
	call	ti._fmul
	ld	(ix + -7), bc
	ld	(ix + -8), a
.lbl_9:
	ld	iy, (_srl_funcs)
	ld	hl, (iy + 1)
	call	_indcallhl
	ld	c, a
	bit	0, c
	jq	nz, .lbl_13
	ld	(ix + -9), c
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	pop	bc
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	ti._lsub
	push	hl
	pop	bc
	ld	a, e
	call	ti._ultof
	push	bc
	pop	hl
	ld	e, a
	ld	bc, (ix + -7)
	ld	a, (ix + -8)
	call	ti._fcmp
	ld	a, 1
	jq	m, .lbl_12
	ld	a, 0
.lbl_12:
	bit	0, a
	ld	c, (ix + -9)
	jq	nz, .lbl_9
	jq	.lbl_13
	
	
pl_GetDeviceStatus:
	ld	hl, (_device_status)
	ret
	
pl_SetReadTimeout:
	ld	bc, (ix + 6)
	ld	hl, 201327
	ld	e, 66
	xor	a, a
	call	ti._ultof
	call	ti._fmul
	call	ti._ftol
	ld	(_srl_read_timeout), bc
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
	ld	bc, (ix + 6)
	ld	hl, (ix + 9)
	ld	de, -3
	ld	iy, (_srl_dbuf_size)
	add	iy, de
	ex	de, hl
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	c, .lbl_2
	push	de
	pop	iy
.lbl_2:
	ld	(ix + -3), iy
	push	bc
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	ex	de, hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	ld	hl, (_device_status)
	ld	de, 2
	or	a, a
	sbc	hl, de
	ld	hl, 0
	jq	nz, .lbl_10
	ld	de, 3
	ld	iy, (_srl_funcs)
	ld	hl, (iy + 10)
	push	de
	pea	ix + -3
	call	_indcallhl
	pop	hl
	pop	hl
	ld	iy, (_srl_funcs)
	ld	hl, (iy + 10)
	ld	de, (ix + -3)
	push	de
	ld	de, (ix + 6)
	push	de
	call	_indcallhl
	pop	hl
	pop	hl
	ld	iy, (_srl_funcs)
	ld	hl, (iy + 4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_7
	call	_indcallhl
.lbl_7:
	ld	hl, (ix + -3)
	jq	.lbl_10
.lbl_9:
	or	a, a
	sbc	hl, hl
.lbl_10:
	ld	sp, ix
	pop	ix
	ret
	
	
pl_ReadPacket:
	ld	hl, -4
	call	ti._frameset
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	push	hl
	pop	iy
	pop	hl
	ld	hl, (ix + 9)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	ld	hl, (ix + 6)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_4
.lbl_1:
	or	a, a
	sbc	hl, hl
.lbl_16:
	ld	sp, ix
	pop	ix
	ret
.lbl_4:
	ld	hl, (_device_status)
	ld	bc, 2
	or	a, a
	sbc	hl, bc
	ld	hl, 0
	jq	nz, .lbl_16
	ld	(ix + -4), e
	ld	(ix + -3), iy
.lbl_7:
	ld	iy, (_srl_funcs)
	ld	hl, (iy + 4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	call	_indcallhl
.lbl_9:
	ld	hl, (_pl_ReadPacket.packet_size)
	ld	iy, (_srl_funcs)
	ld	iy, (iy + 7)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_12
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
	jq	nz, .lbl_13
	ld	hl, (ix + 6)
	ld	hl, (hl)
	ld	(_pl_ReadPacket.packet_size), hl
	jq	.lbl_13
.lbl_12:
	ld	de, (ix + 6)
	push	de
	push	hl
	call	_indcall
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	z, .lbl_15
.lbl_13:
	ld	hl, -917472
	push	hl
	call	_atomic_load_increasing_32
	pop	bc
	ld	iy, (ix + -3)
	lea	bc, iy + 0
	ld	a, (ix + -4)
	call	ti._lsub
	ld	bc, (_srl_read_timeout)
	xor	a, a
	call	ti._lcmpu
	ld	hl, 0
	jq	c, .lbl_7
	jq	.lbl_16
.lbl_15:
	or	a, a
	sbc	hl, hl
	ld	(_pl_ReadPacket.packet_size), hl
	ld	hl, (ix + 9)
	jq	.lbl_16
	
pl_Shutdown:
	ld	de, 0
	ld	hl, (_srl_funcs)
	ld	a, (hl)
	or	a, a
	jq	nz, .lbl_2
	ld	hl, _srl_device
	push	hl
	call	srl_Close
	pop	hl
	call	usb_Cleanup
	ld	de, 0
.lbl_2:
	ld	(_device_status), de
	ret
	
	
_srl_device:			rb 39
_usb_device:			rb 3
_srl_buf:				rb 3
_srl_buf_size:			rb 3
_srl_dbuf_size:			rb 3
_device_status:			rb 3
_srl_bytes_read:		rb 3
_srl_read_timeout:		rb 3
_srl_funcs: 			rb 13

_srl_callbacks:
	db	0
	dl	_usb_init
	dl	_usb_process
	dl	_usb_read_to_size
	dl	_usb_write
	
_pipe_callbacks:
	db	1
	dl	_pipe_init
	dl	0
	dl	_pipe_read_to_size
	dl	_cemu_send

_pl_ReadPacket.packet_size:		rb 3
_pl_SendPacket.bytes_sent:		rb 3

