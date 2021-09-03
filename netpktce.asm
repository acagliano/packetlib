	
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
export pl_DeviceConnect
export pl_GetDeviceStatus
export pl_GetAsyncProcHandler
export pl_InitSendQueue
export pl_QueueSendPacketSegment
export pl_SendPacket
export pl_ReadPacket
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
	
_srl_read_to_size:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	iy, (ix + 9)
	ld	de, _srl_device
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
	ld	hl, 1
	push	hl
	call	_async_srl_process
	pop	hl
	ld	hl, (ix + 9)
	push	hl
	ld	hl, (ix + 6)
	push	hl
	ld	hl, _srl_device
	push	hl
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
	ld	hl, (_srl_device+23)
	ld	de, (_srl_device+26)
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
	
_srl_setup:
	ld	hl, -9
	call	ti._frameset
	ld	bc, 20
	ld	d, 0
	ld	hl, (_async_write_timeout)
	ld	a, (_async_write_timeout+3)
	ld	e, a
	ld	a, d
	call	ti._lmulu
	ld	(ix + -4), hl
	ld	(ix + -5), e
	call	srl_GetCDCStandardDescriptors
	ld	de, 36106
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
	jq	nz, .lbl_1
	call	usb_GetCycleCounter
	ld	(ix + -8), hl
	ld	(ix + -9), e
.lbl_3:
	call	usb_HandleEvents
	ld	hl, (_device_status)
	ld	de, 1
	or	a, a
	sbc	hl, de
	jq	z, .lbl_5
	call	usb_GetCycleCounter
	ld	bc, (ix + -8)
	ld	a, (ix + -9)
	call	ti._lsub
	ld	bc, (ix + -4)
	ld	a, (ix + -5)
	call	ti._lcmpu
	jq	c, .lbl_3
.lbl_5:
	ld	iy, (_usb_device)
	ld	de, (_dev_buffer)
	ld	bc, (_dev_buffer_size)
	ld	hl, 115200
	push	hl
	ld	hl, -1
	push	hl
	push	bc
	push	de
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
	ld	a, 0
	jq	nz, .lbl_7
	ld	hl, 1
	push	hl
	pea	ix + -1
	ld	hl, _srl_device
	push	hl
	call	srl_Read
	pop	hl
	pop	hl
	pop	hl
	ld	a, 1
	jq	.lbl_7
.lbl_1:
	call	usb_Cleanup
	xor	a, a
.lbl_7:
	ld	sp, ix
	pop	ix
	ret
	
_handle_usb_event:
	call	ti._frameset0
	ld	hl, (ix + 6)
	ld	iy, 0
	ld	de, 1
	or	a, a
	sbc	hl, de
	push	hl
	pop	de
	ld	bc, 8
	or	a, a
	sbc	hl, bc
	jq	nc, .lbl_1
	ld	bc, 0
	ld	hl, .usb_handler_switch
	add	hl, de
	add	hl, de
	add	hl, de
	ld	hl, (hl)
	jp	(hl)
.lbl_3:
	ld	hl, _srl_device
	push	hl
	call	srl_Close
	pop	hl
	ld	hl, 0
	ld	(_usb_device), hl
	ld	(_device_status), hl
	call	usb_Cleanup
	jq	.lbl_9
.lbl_4:
	call	usb_GetRole
	ld	a, l
	bit	4, a
	ld	hl, (ix + 9)
	push	hl
	call	z, usb_ResetDevice
	pop	hl
	jq	.lbl_9
.lbl_6:
	ld	hl, 8
	push	hl
	push	bc
	push	bc
	call	usb_FindDevice
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_8
	ld	(_usb_device), hl
.lbl_8:
	ld	hl, 2
	ld	(_device_status), hl
.lbl_9:
	ld	iy, 0
.lbl_1:
	lea	hl, iy + 0
	pop	ix
	ret
.lbl_10:
	call	usb_GetRole
	ld	de, (ix + 9)
	ld	iy, 0
	ld	a, l
	bit	4, a
	jq	nz, .lbl_1
	ld	(_usb_device), de
	ld	hl, 1
	ld	(_device_status), hl
	jq	.lbl_1	
.usb_handler_switch:
	dl	.lbl_3
	dl	.lbl_4
	dl	.lbl_1
	dl	.lbl_10
	dl	.lbl_1
	dl	.lbl_1
	dl	.lbl_1
	dl	.lbl_6


_pipe_setup:
	ld	hl, 2
	ld	a, 1
	ld	(_device_status), hl
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

pl_DeviceConnect:
	call	ti._frameset0
	ld	a, (ix + 6)
	ld	c, 0
	or	a, a
	jq	nz, .lbl_8
	ld	de, (ix + 9)
	push	de
	pop	hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	ld	iy, (ix + 12)
	ld	bc, 128
	lea	hl, iy + 0
	or	a, a
	sbc	hl, bc
	jq	c, .lbl_10
	ld	(_dev_buffer), de
	ld	(_dev_buffer_size), iy
	ld	c, 1
	lea	hl, iy + 0
	call	ti._ishru
	ld	(_dev_buffer_half_size), hl
	call	_cemu_check
	bit	0, a
	jq	z, .lbl_5
	ld	iy, 0
	ld	hl, _pipe_setup
	ld	bc, _cemu_send
	ld	de, _pipe_read_to_size
	jq	.lbl_6
.lbl_8:
	jq	.lbl_7
.lbl_9:
	jq	.lbl_7
.lbl_10:
	ld	c, 0
	jq	.lbl_7
.lbl_5:
	ld	hl, _srl_setup
	ld	iy, _async_srl_process
	ld	bc, _srl_send
	ld	de, _srl_read_to_size
.lbl_6:
	xor	a, a
	ld	(_dev_funcs), a
	ld	(_dev_funcs+1), hl
	ld	(_dev_funcs+4), iy
	ld	(_dev_funcs+10), bc
	ld	(_dev_funcs+7), de
	call	_indcallhl
	ld	c, a
.lbl_7:
	ld	a, c
	pop	ix
	ret

pl_GetDeviceStatus:
	ld	hl, (_device_status)
	ret

pl_GetAsyncProcHandler:
	ld	hl, (_dev_funcs+4)
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
	ld	hl, (_dev_buffer_half_size)
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
	ld	hl, -6
	call	ti._frameset
	ld	hl, (ix + 6)
	ld	bc, 0
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	ld	(ix + -6), hl
	jq	.lbl_3
.lbl_1:
	ld	de, (_queue)
	ld	(ix + -6), de
.lbl_3:
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_5
	ld	hl, (_queue_filled)
	jq	.lbl_8
.lbl_5:
	ld	de, (ix + 9)
	ld	bc, -3
	ld	iy, (_dev_buffer_half_size)
	add	iy, bc
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	c, .lbl_7
	push	de
	pop	iy
.lbl_7:
	lea	hl, iy + 0
	ld	bc, 0
.lbl_8:
	ld	(ix + -3), hl
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_14
	ld	hl, (_device_status)
	ld	de, 2
	or	a, a
	sbc	hl, de
	jq	nz, .lbl_15
	ld	de, 3
	ld	hl, (_dev_funcs+10)
	push	de
	pea	ix + -3
	call	_indcallhl
	pop	hl
	pop	hl
	ld	hl, (_dev_funcs+10)
	ld	de, (ix + -3)
	push	de
	ld	de, (ix + -6)
	push	de
	call	_indcallhl
	pop	hl
	pop	hl
	ld	de, (_queue)
	ld	hl, (ix + -6)
	or	a, a
	sbc	hl, de
	jq	nz, .lbl_12
	or	a, a
	sbc	hl, hl
	ld	(_queue_filled), hl
.lbl_12:
	ld	bc, (ix + -3)
	jq	.lbl_13
.lbl_14:
	jq	.lbl_13
.lbl_15:
.lbl_13:
	push	bc
	pop	hl
	ld	sp, ix
	pop	ix
	ret

pl_ReadPacket:
	ld	hl, -8
	call	ti._frameset
	ld	bc, 48000
	ld	d, 0
	ld	hl, (_blocking_read_timeout)
	ld	a, (_blocking_read_timeout+3)
	ld	e, a
	ld	a, d
	call	ti._lmulu
	push	hl
	pop	iy
	ld	hl, (ix + 9)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	ld	hl, (ix + 6)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_1
	ld	hl, (_device_status)
	ld	bc, 2
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_1
	ld	(ix + -4), e
	ld	(ix + -3), iy
	call	usb_GetCycleCounter
	ld	(ix + -7), hl
	ld	(ix + -8), e
.lbl_7:
	ld	hl, (_dev_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	ld	de, 0
	push	de
	call	_indcallhl
	pop	hl
.lbl_9:
	ld	hl, (_pl_ReadPacket.packet_size)
	ld	iy, (_dev_funcs+7)
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
	call	usb_GetCycleCounter
	ld	bc, (ix + -7)
	ld	a, (ix + -8)
	call	ti._lsub
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	ti._lcmpu
	jq	c, .lbl_7
.lbl_1:
	or	a, a
	sbc	hl, hl
.lbl_16:
	ld	sp, ix
	pop	ix
	ret
.lbl_15:
	or	a, a
	sbc	hl, hl
	ld	(_pl_ReadPacket.packet_size), hl
	ld	hl, (ix + 9)
	jq	.lbl_16

pl_Shutdown:
	ld	hl, -7
	call	ti._frameset
	or	a, a
	sbc	hl, hl
	ld	a, (_dev_funcs)
	or	a, a
	jq	nz, .lbl_7
	ld	hl, (ix + 6)
	ld	bc, 48000
	call	ti._imulu
	ld	(ix + -3), hl
	call	usb_GetCycleCounter
	ld	(ix + -6), hl
	ld	(ix + -7), e
.lbl_2:
	ld	hl, (_dev_funcs+4)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_4
	ld	de, 0
	push	de
	call	_indcallhl
	pop	hl
.lbl_4:
	ld	hl, (_srl_device+23)
	ld	de, (_srl_device+26)
	or	a, a
	sbc	hl, de
	jq	z, .lbl_6
	call	usb_GetCycleCounter
	ld	bc, (ix + -6)
	ld	a, (ix + -7)
	call	ti._lsub
	ld	bc, (ix + -3)
	xor	a, a
	call	ti._lcmpu
	jq	c, .lbl_2
.lbl_6:
	ld	hl, _srl_device
	push	hl
	call	srl_Close
	pop	hl
	call	usb_Cleanup
	or	a, a
	sbc	hl, hl
.lbl_7:
	ld	(_device_status), hl
	ld	sp, ix
	pop	ix
	ret
	
_device_status:		rb	3

_usb_device:		rb	3

_queue:				rb	3

_queue_max:			rb	3

_queue_filled:		rb	3

_bytes_read:		rb	3

_srl_device:		rb	39

_async_write_timeout:	dd	2400000

_dev_buffer:		rb	3

_dev_buffer_size:	rb	3

_dev_buffer_half_size:	rb	3

_dev_funcs:			rb	13

_pl_ReadPacket.packet_size:		rb	3

_blocking_read_timeout:		rb	4
