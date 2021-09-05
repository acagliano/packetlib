#ifndef NETPKTCE_H
#define NETPKTCE_H

#include <stddef.h>
#include <stdbool.h>
#include <srldrvce.h>

/*********************************************************************************************************************************************
 *	@file netpktce.h
 *	@brief Defines the implementation of TI-ONP
 *
 *	TI-ONP is an acronym for TI Open Networking Protocol.
 *	It is a bare-bones protocol for sending packets to a connected host using some networking device.
 *
 *	Provides an implementation of a basic packetization standard for the TI-84+ CE.
 *	The "standard" is simply:
 *		- 3-byte size word indicating frame length (cannot be larger than the max packet size specified during Initialization)
 *		- The data section of arbitrary (but bounded) length.
 *
 *	@author Anthony @e ACagliano Cagliano
 **********************************************************************************************************************************************/
 
/**************************************************************************************************************************************
 * @enum Networking Modes
 *
 * Specifies the subsystem (device) to enable for networking. As of now, only options are @b NET_MODE_SERIAL.
 **************************************************************************************************************************************/
enum _device_types {
    NET_MODE_SERIAL,		/**< species the Serial/USB subsystem to be used for networking. */
};

/************************************************************************************************
 * @enum Packetlib error codes
 *
 * Error codes indicating if the subsystem initialized properly or if an error occurred.
 *************************************************************************************************/
typedef enum {
	PL_NTWK_NONE,				/**< No device. Generally doesn't mean anything bad, just that you haven't initialized. */
	PL_NTWK_ENABLED,			/**< Indicates that the subsystem is initialized, but not ready to send data.
									If this is the device status after calling pl_DeviceConnect(), this is an error. */
	PL_NTWK_READY,				/**< Indicates that the subsystem is initialized and ready to send data.
									This is a success code. */
	PL_NTWK_INTERNAL_ERROR,		/**< Indicates that something internal prevented the device from working.
									This is likely a bug in the chosen subsystem code. Report it! */
	PL_NTWK_USER_ERROR = 0xff	/**< Sorry, pal. This one is on you. */
} device_status_t;


/***************************************************************************************************************************
 * @brief Initializes the selected subsystem.
 *
 * @param device Specifies the subsystem to set up. Use the values from @b enum @b _device_types.
 * @param buf Pointer to a buffer to use for the subsystem internally.
 * @param buf_len Size of the pointed buffer @b buf.
 ***************************************************************************************************************************/
bool pl_DeviceConnect(uint8_t device, uint8_t *buf, size_t buf_len);

/***************************************************************************************************************************************
 * @brief Returns a pointer to the internal device events handler.
 *
 * Due to lack of interrupt support on the TI-84+ CE, in some cases you may be required to call an
 * event handler stub in a tick-loop. In this case, return a function pointer like so:
 * @code
 * void (*handler)(bool block) = pl_GetAsyncProcHandler();
 * handler(true|false)
 * @endcode
 * @note The handler parameter specifies if the call to the async process handler should be blocking or non-blocking.
 * 		Non-blocking runs once and then returns. Blocking runs for the set timeout (default of 50ms).
 * @returns Pointer to the internal asyncronous subsystem event handler that can be run in blocking or non-blocking mode.
 * 		For USB/Serial, a pointer a function that loops usb_HandleEvents() (either once or for a timeout).
 *****************************************************************************************************************************************/
void* pl_GetAsyncProcHandler(void);

/******************************************************************************************************
 * @brief Initializes an optional send queue for outgoing messages.
 *
 * @param queue_buf Pointer to a buffer to use as the outgoing message queue.
 * @param queue_len Length of the @b queue_buf.
 * @note Assert @b queue_len >= (( @b buf_len / 2 ) - 3). @see pl_DeviceConnect().
 *******************************************************************************************************/
bool pl_InitSendQueue(uint8_t *queue_buf, size_t queue_len);

/**
 * @brief Writes a packet segment to the send queue.
 *
 * @param data Pointer to the data to write to the queue.
 * @param len Length of @b data.
 * @returns True if success. False if failure.
 * @note The queue is used to contruct a single packet, not to queue multiple packets.
 * 		When you have queued all segments of a packet, then do:
 * 		@code
 * 		pl_SendPacket(NULL, 0);
 * 		@endcode
 * 		to send the queue. It will empty out the queue, reset its length to 0,
 * 		and await new packet segments.
 */
bool pl_QueueSendPacketSegment(uint8_t *data, size_t len);

/**
 * @brief Sends a packet or sends the the contents of the send queue.
 *
 * @param data Pointer to the buffer containing the packet to send. Alternatively, @b NULL to send the queue.
 * @param len The length of the packet at @b data. Can be 0 if @b data is NULL.
 * @returns The length of the packet sent. May not equal @b len if @b len is greater than the send buffer length.
 */
size_t pl_SendPacket(uint8_t *data, size_t len);

/**
 * @brief Reads a number of bytes from the subsystem.
 *
 * @param dest Pointer to a buffer to read bytes to. Must be large enough to hold the largest
 * 		packet your use case uses..
 * @note This function defaults to a non-blocking read, meaning it checks if there is @b read_size+3 bytes
 * 		available in the receive buffer. Either way, it returns immediately.
 * 		You may set this to a blocking read by using the pl_SetReadTimeout() function.
 * @returns True if a packet is available. False if not.
 * @note Because the header contains a size word, there is no need to pass a read size.
 * 		The protocol will alternate between attempting to read a @b size_t (3 bytes) and
 * 		attempting to read that size..
 */
bool pl_ReadPacket(uint8_t *dest);

/**
 * @brief Shuts down the connected subsystem.
 *
 * @param timeout Time, in milliseconds to wait, to let and processing device events complete, after which the device will be closed.
 */
void pl_Shutdown(size_t timeout);

/**
 * @brief Returns the status of the connected device.
 * @returns The status of the device. @see device_status_t.
 */
device_status_t pl_GetDeviceStatus(void);

/**
 * @brief Sets the timeout for the Async device process handler.
 * @note The async handler is invoked once when pl_SendPacket() is called.
 * 		It can also be invoked by the user after returning pl_GetAsyncProcHandler().
 * @param timeout The timeout to set, in milliseconds. Pass 0 to set non-blocking.
 */
void pl_SetAsyncTimeout(size_t timeout);

/**
 * @brief Sets the timeout for reading a packet.
 * @note The async handler is invoked once when pl_SendPacket() is called.
 * 		It can also be invoked by the user after returning pl_GetAsyncProcHandler().
 * @param timeout The timeout to set, in milliseconds. Pass 0 to set non-blocking.
 */
void pl_SetReadTimeout(size_t timeout);

#endif
