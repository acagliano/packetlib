#ifndef NETPKTCE_H
#define NETPKTCE_H

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
enum _device_types {
    NET_MODE_SERIAL,
    NET_MODE_CEMU_PIPE
};

typedef enum {
	PL_NTWK_NONE,
	PL_NTWK_ENABLED,
	PL_NTWK_READY,
	PL_NTWK_INTERNAL_ERROR,
	PL_NTWK_USER_ERROR = 0xff
} device_status_t;


/*
	Initializes the chosen subsystem internally
	
	# Inputs #
	<> device = defines the device mode to initialize
	<> buf = pointer to a buffer to be used by the subsystem
	<> buf_len = the size of the buffer reserved
	
	# Output #
	True if able to successfully initialize the usb and serial devices
	False if an error occured
*/
bool pl_DeviceConnect(uint8_t device, uint8_t *buf, size_t buf_len);


// returns a pointer to the internal device process handler, in case the user needs
// to call it async.
void* pl_GetAsyncProcHandler(void);


// initializes a queue to write segments of packets into before sending
// segments go onto the queue in the order they are passed by calling this
// function repeatedly.
// queue length should at 3 less than the buf_len passed in pl_DeviceConnect at minimum
bool pl_InitSendQueue(uint8_t *queue_buf, size_t queue_len);


// writes the passed packet segment to the queue.
// if the segment would overflow the queue's size, false is returned
bool pl_QueueSendPacketSegment(uint8_t *data, size_t len);


// sends a packet of len at data
// if data is null, sends the queue instead.
size_t pl_SendPacket(uint8_t *data, size_t len);


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

// disconnects and disables the active device
// for serial mode, continues processing usb events until the given timeout expires, then
// forcibly closes the serial and calls usb_Cleanup().
void pl_Shutdown(size_t timeout);

#endif
