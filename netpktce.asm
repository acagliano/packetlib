	
;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'NETPKTCE', 0

;-------------------------------------------------------------------------------
; Dependencies
;-------------------------------------------------------------------------------
include_library '../usbdrvce/usbdrvce.asm'
include_library '../srldrvce/srldrvce.asm'

;-------------------------------------------------------------------------------
; v0 functions (not final, subject to change!)
;-------------------------------------------------------------------------------
export pl_SetDevice
export pl_GetAsyncProcHandler
export pl_InitSendQueue
export pl_QueueSendPacketSegment
export pl_SendPacket
export pl_ReadPacket
export pl_SetAsyncTimeout
export pl_SetReadTimeout


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
	
_srl_read_to_size:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	iy, (ix + 9)
	ld	de, (_device)
	ld	bc, (_bytes_read)
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
	ld	iy, (_bytes_read)
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
	ld	(_bytes_read), hl
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
	
_srl_send:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	de, (ix + 9)
	ld	bc, (_device)
	push	de
	push	hl
	push	bc
	call	srl_Write
	ld	sp, ix
	pop	ix
	ret
	
_async_srl_process:
	ld	hl, -4
	call	ti._frameset
	call	usb_GetCycleCounter
	ld	c, 1
	ld	a, (ix + 6)
	xor	a, c
	bit	0, a
	jq	nz, .lbl_2
	ld	(ix + -4), e
	ld	(ix + -3), hl
.lbl_3:
	call	usb_HandleEvents
	ld	iy, (_device)
	ld	hl, (iy + 23)
	ld	de, (iy + 26)
	or	a, a
	sbc	hl, de
	jq	z, .lbl_5
	call	usb_GetCycleCounter
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	ti._lsub
	ld	bc, (_async_write_timeout)
	ld	a, (_async_write_timeout+3)
	call	ti._lcmpu
	jq	c, .lbl_3
	jq	.lbl_5
.lbl_2:
	call	usb_HandleEvents
.lbl_5:
	ld	sp, ix
	pop	ix
	ret
	
check_cmd = 2
send_cmd = 3
get_cmd = 4

dbgext = 0xFD0000

_cemu_check:
	xor	a,a
	ld	hl,dbgext
	ld	(hl),check_cmd
	ret

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


_pipe_read_to_size:
	call	ti._frameset0
	ld	bc, (ix + 6)
	ld	de, (_bytes_read)
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
	ld	iy, (_bytes_read)
	add	iy, de
	ld	(_bytes_read), iy
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
	ld	(_bytes_read), hl
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

pl_SetDevice:
	call	ti._frameset0
	ld	a, (ix + 6)
	ld	e, 0
	cp	a, 2
	jq	c, .lbl_1
	jq	.lbl_13
.lbl_1:
	ld	hl, (ix + 9)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_2
	jq	.lbl_13
.lbl_2:
	ld	iy, (ix + 12)
	ld	(_device), hl
	ld	(_device_type), a
	ld	(_buffer_len), iy
	ld	c, 1
	lea	hl, iy + 0
	call	ti._ishru
	ld	(_buffer_half_len), hl
	cp	a, 1
	jq	nz, .lbl_13
	call	_cemu_check
	bit	0, a
	jq	nz, .lbl_4
	ld	iy, _async_srl_process
	jq	.lbl_6
.lbl_4:
	ld	iy, 0
.lbl_6:
	bit	0, a
	jq	nz, .lbl_7
	ld	bc, _srl_send
	jq	.lbl_9
.lbl_7:
	ld	bc, _cemu_send
.lbl_9:
	bit	0, a
	jq	nz, .lbl_10
	ld	hl, _srl_read_to_size
	jq	.lbl_12
.lbl_10:
	ld	hl, _pipe_read_to_size
.lbl_12:
	ld	e, 1
	ld	(_dev_funcs), iy
	ld	(_dev_funcs+6), bc
	ld	(_dev_funcs+3), hl
.lbl_13:
	ld	a, e
	pop	ix
	ret

pl_GetAsyncProcHandler:
	ld	hl, (_dev_funcs)
	ret

pl_InitSendQueue:
	call	ti._frameset0
	xor	a, a
	ld	hl, (_queue)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_1
	jq	.lbl_3
.lbl_1:
	ld	de, (ix + 9)
	ld	bc, -3
	ld	hl, (_buffer_half_len)
	add	hl, bc
	push	hl
	pop	bc
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	jq	c, .lbl_3
	ld	hl, (ix + 6)
	ld	a, 1
	ld	(_queue), hl
	ld	(_queue_max), de
.lbl_3:
	pop	ix
	ret

pl_QueueSendPacketSegment:
	ld	hl, -3
	call	ti._frameset
	ld	bc, (ix + 9)
	xor	a, a
	push	bc
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_1
	jq	.lbl_5
.lbl_1:
	ld	de, (ix + 6)
	push	de
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_2
	jq	.lbl_5
.lbl_2:
	ld	iy, (_queue)
	lea	hl, iy + 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_3
	jq	.lbl_5
.lbl_3:
	ld	hl, (_queue_filled)
	ld	(ix + -3), hl
	add	hl, bc
	push	hl
	pop	bc
	ld	hl, (_queue_max)
	or	a, a
	sbc	hl, bc
	jq	c, .lbl_5
	ld	bc, (ix + -3)
	add	iy, bc
	ld	hl, (ix + 9)
	push	hl
	push	de
	push	iy
	call	ti._memcpy
	ld	a, 1
	pop	hl
	pop	hl
	pop	hl
	ld	hl, (_queue_filled)
	ld	de, (ix + 9)
	add	hl, de
	ld	(_queue_filled), hl
.lbl_5:
	pop	hl
	pop	ix
	ret

pl_SendPacket:
	ld	hl, -15
	call	ti._frameset
	ld	hl, (ix + 6)
	ld	iy, 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_2
	ld	a, 0
	jq	.lbl_3
.lbl_2:
	ld	a, 1
.lbl_3:
	ld	bc, (_queue)
	bit	0, a
	ld	(ix + -6), bc
	jq	nz, .lbl_5
	ld	(ix + -6), hl
.lbl_5:
	ld	hl, (ix + 9)
	bit	0, a
	jq	nz, .lbl_7
	ld	(ix + -9), hl
	jq	.lbl_8
.lbl_7:
	ld	de, (_queue_filled)
	ld	(ix + -9), de
.lbl_8:
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_10
	ld	l, 0
	jq	.lbl_11
.lbl_10:
	ld	l, 1
.lbl_11:
	or	a, l
	ld	l, a
	ld	a, (_device_type)
	ld	e, a
	ld	h, 1
	ld	a, l
	xor	a, h
	bit	0, a
	jq	nz, .lbl_14
	ld	hl, (ix + -6)
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_13
.lbl_14:
	ld	a, e
	or	a, a
	jq	nz, .lbl_16
.lbl_13:
	lea	bc, iy + 0
	jq	.lbl_27
.lbl_16:
	lea	bc, iy + 0
.lbl_17:
	push	bc
	pop	hl
	ld	de, (ix + 9)
	or	a, a
	sbc	hl, de
	jq	nc, .lbl_24
	ld	iy, (_buffer_half_len)
	ld	de, -3
	add	iy, de
	ld	hl, (ix + -9)
	or	a, a
	sbc	hl, bc
	push	hl
	pop	de
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	c, .lbl_20
	push	de
	pop	iy
.lbl_20:
	ld	(ix + -12), bc
	ld	(ix + -3), iy
	ld	hl, (_dev_funcs)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_22
	ld	de, 1
	push	de
	call	_indcallhl
	pop	hl
.lbl_22:
	ld	hl, (_dev_funcs+6)
	ld	de, 3
	push	de
	pea	ix + -3
	call	_indcallhl
	ld	(ix + -15), hl
	pop	hl
	pop	hl
	ld	iy, (_dev_funcs+6)
	ld	hl, (ix + -6)
	ld	de, (ix + -12)
	add	hl, de
	ld	de, (ix + -3)
	push	de
	push	hl
	call	_indcall
	pop	de
	pop	de
	ld	de, (ix + -15)
	add	hl, de
	ld	(ix + -15), hl
	ld	hl, (ix + -3)
	push	hl
	pop	iy
	ld	de, (ix + -12)
	add	iy, de
	ld	de, 3
	add	hl, de
	ex	de, hl
	ld	hl, (ix + -15)
	or	a, a
	sbc	hl, de
	lea	bc, iy + 0
	jq	z, .lbl_17
.lbl_24:
	ld	de, (_queue)
	ld	hl, (ix + -6)
	or	a, a
	sbc	hl, de
	jq	nz, .lbl_27
	ld	hl, (_queue_filled)
	or	a, a
	sbc	hl, bc
	ld	(_queue_filled), hl
.lbl_27:
	push	bc
	pop	hl
	ld	sp, ix
	pop	ix
	ret

pl_ReadPacket:
	ld	hl, -10
	call	ti._frameset
	ld	hl, (ix + 6)
	ld	de, 0
	ld	a, (_device_type)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	or	a, a
	jq	nz, .lbl_4
.lbl_1:
	ex	de, hl
	jq	.lbl_17
.lbl_4:
	call	usb_GetCycleCounter
	ld	(ix + -9), hl
	ld	(ix + -10), e
	or	a, a
	sbc	hl, hl
	ld	(ix + -3), hl
.lbl_5:
	ld	hl, (_dev_funcs)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_7
	ld	de, 0
	push	de
	call	_indcallhl
	pop	hl
.lbl_7:
	ld	hl, (_pl_ReadPacket.packet_size)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_10
	ld	hl, (_dev_funcs+3)
	ld	de, (ix + 6)
	push	de
	ld	de, 3
	push	de
	call	_indcallhl
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	ld	hl, (ix + -3)
	jq	nz, .lbl_15
	ld	hl, (ix + 6)
	ld	hl, (hl)
	ld	(_pl_ReadPacket.packet_size), hl
	jq	.lbl_15
.lbl_10:
	ld	de, (_buffer_half_len)
	ld	(ix + -6), hl
	or	a, a
	sbc	hl, de
	ld	bc, (ix + 6)
	jq	c, .lbl_12
	ld	(ix + -6), de
.lbl_12:
	ld	hl, (_dev_funcs+3)
	push	bc
	ld	de, (ix + -6)
	push	de
	call	_indcallhl
	pop	hl
	pop	hl
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, .lbl_14
	ld	hl, (_pl_ReadPacket.packet_size)
	ld	de, (ix + -6)
	or	a, a
	sbc	hl, de
	ld	(_pl_ReadPacket.packet_size), hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	ld	hl, (ix + -3)
	jq	z, .lbl_17
	jq	.lbl_15
.lbl_14:
	ld	hl, (ix + -3)
.lbl_15:
	ld	(ix + -3), hl
	call	usb_GetCycleCounter
	ld	bc, (ix + -9)
	ld	a, (ix + -10)
	call	ti._lsub
	ld	bc, (_blocking_read_timeout)
	ld	a, (_blocking_read_timeout+3)
	call	ti._lcmpu
	ld	hl, 0
	jq	c, .lbl_5
.lbl_17:
	ld	sp, ix
	pop	ix
	ret

	
pl_SetAsyncTimeout:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	bc, 48000
	xor	a, a
	ld	e, a
	call	ti._lmulu
	ld	a, e
	ld	(_async_write_timeout), hl
	ld	(_async_write_timeout+3), a
	pop	ix
	ret


pl_SetReadTimeout:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	bc, 48000
	xor	a, a
	ld	e, a
	call	ti._lmulu
	ld	a, e
	ld	(_blocking_read_timeout), hl
	ld	(_blocking_read_timeout+3), a
	pop	ix
	ret
	
	
_device_type:		rb 	1
_device:			rb	3
_buffer_len:		rb	3
_buffer_half_len:	rb	3

_blocking_read_timeout:		rb	4
_async_write_timeout:	dd	2400000

_queue:				rb	3
_queue_max:			rb	3
_queue_filled:		rb	3

_bytes_read:		rb	3

_dev_funcs:			rb	9
_pl_ReadPacket.packet_size:		rb	3


