#ifndef SRLPKTCE_H
#define SRLPKTCE_H

#include <stddef.h>
#include <stdbool.h>

/*
	DEFINES A PACKETIZATION STANDARD FOR COMMUNICATION OVER THE SERIAL DEVICE.
	ALL REQUIRED SUBSYSTEMS ARE MANAGED INTERNALLY
 */

/*
	Defines for specifying the subsystem to enable for communication.
	Currently available are:
		(1) hardware serial device
		(2) CEmu pipe mode
	NET_MODE_CEMU_PIPE is a subsystem included to retain backwards compatability with the pipe branch of CEmu. It may eventually be replaced with serial emulation when that is stable (if that requires a separate subsystem at all)
	Other subsystems like any planned TCP/IP libraries may be added over time.
 */
enum _subsys_modes {
    NET_MODE_SERIAL,
    NET_MODE_CEMU_PIPE
};

typedef enum {
	PL_SUBSYS_NONE,
	PL_SUBSYS_UP,
	PL_SUBSYS_READY,
	PL_SERIAL_CONNECTED,
	PL_SUBSYS_INTERNAL_ERROR,
	PL_SUBSYS_USER_ERROR = 0xff
} subsys_status_t;

/*
	Structure denoting the address and length of a packet segment
	Meant to be passed in array to pl_PreparePacket()
*/
typedef struct _ps {
	uint8_t *addr;
	size_t len;
} ps_t;

typedef struct _subsys_config {
	uint8_t* buf; size_t buf_size;
} subsys_config_t;


/*
	Initializes the chosen subsystem internally
	
	# Inputs #
	<> subsys = defines the subsystem to initialize
	<> buf = pointer to a buffer to be used by the subsystem
	<> buf_size = the size of the buffer reserved
	<> ms_delay = milliseconds to wait for subsystem initialization before returning an error (false)
	
	# Output #
	True if able to successfully initialize the usb and serial devices
	False if an error occured
*/
bool pl_InitSubsystem(uint8_t srl_mode, subsys_config_t *sys_conf, size_t ms_delay);


/*
	Concats an array of packet segment specifiers into formed packet data segment
	
	# Inputs #
	<> pid = the packet id of the packet
	<> ps = pointer to an array of packet segment specifiers, each containing the address and length of a packet segment to concat
	<> arr_len = size of the `ps` array
	<> packet = pointer to a buffer to write the concatentated packet
	
	# Outputs #
	the size of the concatentated packet
 */
size_t pl_JoinPacketSegments(uint8_t pid, ps_t *ps, uint8_t arr_len, uint8_t *packet);

/*
	Sends a packet via the active subsystem (currently serial device/cemu pipe)
	
	# Inputs #
	<> data = pointer to data section of packet to send
	<> len = the size of the data section to send
	
	# Outputs #
	The number of bytes sent.
	Should be equal to the lesser of:
		data length OR
		max packet size minus the header (3 bytes)
 */
size_t pl_SendPacket(uint8_t *data, size_t len);


/*
	Sets a timeout for subsystem reads
	
	# Inputs #
	<> ms_delay = time in milliseconds to block the read for
		Set to 0 for non-blocking read
		Set to any non-zero value to block for the time in milliseconds
		Pass -1 to wait a long-ass time
 */
void pl_SetReadTimeout(size_t ms_delay);

/*
	Attempts to read a number of bytes from the active subsystem
	
	# Inputs #
	<> dest = pointer to a buffer to write the read bytes to
	<> read_size = number of bytes to attempt to read
	
	This function can be blocking or non-blocking, see pl_SetReadTimeout()
	In non-blocking mode, the subsystem is queried once and if the requested number of bytes are not available, 0 is returned. Otherwise the number of bytes read is returned (should be equal to read_size)
	In blocking mode, the subsystem is queried until the set timeout is reached. If the requested number of bytes are not available by the time the timeout expires, 0 is returned. If at any time the requested number of bytes are read, they are written to *dest, and the bytes read are returned and the function exits.
 */
size_t pl_ReadPacket(uint8_t *dest, size_t read_size);

subsys_status_t pl_GetDeviceStatus(void);
void pl_Shutdown(void);

#endif
