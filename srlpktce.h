#ifndef SRLPKTCE_H
#define SRLPKTCE_H

#include <stddef.h>
#include <stdbool.h>

/*
	Toggles between serial hardware and CEmu pipe mode.
	CEmu pipes emulate the serial device, but use an entirely different subsystem.
	If you are using this on the CEmu pipe branch, use NET_MODE_CEMU_PIPE
	Otherwise, use NET_MODE_SERIAL.
 */
enum _net_modes {
    NET_MODE_SERIAL,
    NET_MODE_CEMU_PIPE
};

/*
	Structure denoting the address and length of a packet segment
	Meant to be passed in array to pl_PreparePacket()
*/
typedef struct _ps {
	uint8_t *addr;
	size_t len;
} pl_psdata_t;

/*
	Standard packet format
	Includes a 2-byte header containing the following metadata:
		[] uint8_t => packet id
		[] uint8_t => flags (8-bits of arbitrary flagspace for users)
		packet data
*/
typedef struct _packet {
	uint8_t pid;
	uint8_t pflags;
	uint8_t data[1];
} packet_t;


bool pl_InitSubsystem(uint8_t srl_mode, uint8_t *buf, size_t srl_buf_size, size_t ms_delay);
void pl_SetReadTimeout(size_t ms_delay);
size_t pl_JoinPacketSegments(pl_psdata_t *ps, uint8_t arr_len, uint8_t *packet);
size_t pl_SendPacket(uint8_t pid, uint8_t *data, size_t len, uint8_t flags);
size_t pl_ReadPacket(uint8_t *dest, size_t read_size);


#endif
