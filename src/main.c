
#include <tice.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <debug.h>
#include <tice.h>
#include <string.h>
#include <usbdrvce.h>
#include <srldrvce.h>

#define CEMU_CONSOLE ((char*)0xFB0000)
#define TIMERCPU_TO_MS		48000
#define SRL_SEND_DONE \
	(srl_device.tx_buf.buf_start == srl_device.tx_buf.buf_end)

enum net_mode_id {
    MODE_SERIAL,
    MODE_CEMU_PIPE
};

typedef enum {
	PL_NTWK_NONE,
	PL_NTWK_ENABLED,
	PL_NTWK_READY,
	PL_NTWK_INTERNAL_ERROR,
	PL_NTWK_USER_ERROR = 0xff
} device_status_t;
device_status_t device_status = PL_NTWK_NONE;

uint8_t *dev_buffer;
size_t dev_buffer_size;
size_t dev_buffer_half_size;
uint32_t blocking_read_timeout;
uint32_t async_write_timeout = (50 * TIMERCPU_TO_MS);


srl_device_t srl_device;
usb_device_t usb_device = NULL;
uint8_t *queue = NULL;
size_t queue_max = 0;
size_t queue_filled = 0;

size_t bytes_read = 0;


static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data);

typedef struct {
    uint8_t id;
    bool (*init)(void);
    void (*process)(bool block);
    bool (*read_to_size)(size_t size, uint8_t* out);
    void (*write)(void *data, size_t size);
} device_callbacks_t;
device_callbacks_t dev_funcs;

bool init_usb(void);
bool usb_read_to_size(size_t size, uint8_t *out);
void usb_write(void *buf, size_t size);
void usb_process(void);

bool pipe_init(void);
bool cemu_check(void);
size_t cemu_get(void *buf, size_t size);
bool pipe_read_to_size(size_t size, uint8_t* out);
void cemu_send(void *buf, size_t size);
void pl_SetTimeout(size_t ms_delay);


// SERIAL INTERFACE
static void async_srl_process(bool block){
	uint32_t timer_start = usb_GetCycleCounter();
	if(!block) { usb_HandleEvents(); return; }
	do {
		usb_HandleEvents();
	} while((!SRL_SEND_DONE) &&
			((usb_GetCycleCounter() - timer_start) < async_write_timeout));
}


static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data __attribute__((unused))) {
    switch(event){
		case USB_DEVICE_CONNECTED_EVENT:
			if(!(usb_GetRole() & USB_ROLE_DEVICE)){
				usb_device_t tmp_device = event_data;
				usb_ResetDevice(tmp_device);
			}
			break;
		case USB_DEVICE_ENABLED_EVENT:
			if(!(usb_GetRole() & USB_ROLE_DEVICE)){
				usb_device = event_data;
				device_status = PL_NTWK_ENABLED;
			}
			break;
		case USB_HOST_CONFIGURE_EVENT:
		{
			usb_device_t host = usb_FindDevice(NULL, NULL, USB_SKIP_HUBS);
			if(host) usb_device = host;
			device_status = PL_NTWK_READY;
			break;
		}
		case USB_DEVICE_DISCONNECTED_EVENT:
			srl_Close(&srl_device);
			usb_device = NULL;
			device_status = PL_NTWK_NONE;
			usb_Cleanup();
			break;
		default:
			break;
	}
    return USB_SUCCESS;
}

/* USB/SRL Subsystem */
bool srl_read_to_size(size_t size, uint8_t *out) {
    bytes_read += srl_Read(&srl_device, &out[bytes_read], size - bytes_read);
    if(bytes_read >= size) {bytes_read = 0; return true;}
    else return false;
}

void srl_send(void *buf, size_t size) {
	async_srl_process(true);
    srl_Write(&srl_device, buf, size);
}

bool srl_setup(void) {
	char dummy;
	srl_error_t srl_error;
	uint32_t start_time;
	uint32_t wait_time = (20 * async_write_timeout);
    usb_error_t usb_error = usb_Init(handle_usb_event, NULL, srl_GetCDCStandardDescriptors(), USB_DEFAULT_INIT_FLAGS);
    if(usb_error){ usb_Cleanup(); return false; }
    start_time = usb_GetCycleCounter();
    do {
		usb_HandleEvents();
	} while((device_status != PL_NTWK_ENABLED) &&
			((usb_GetCycleCounter() - start_time) < wait_time));
	srl_error = srl_Open(&srl_device, usb_device, dev_buffer, dev_buffer_size, SRL_INTERFACE_ANY, 115200);
	if(srl_error) return false;
    srl_Read(&srl_device, &dummy, 1);
    return true;
}

/* Pipe Subsystem */
bool pipe_setup(void) {
    device_status = PL_NTWK_READY;
    return true;
}

bool pipe_read_to_size(size_t size, uint8_t* out) {
    if(bytes_read < size) {
        size_t recd;
        recd = cemu_get(&out[bytes_read], size - bytes_read);	// asm routine
        bytes_read += recd;
    }

    if(bytes_read > size) return false;
    if(bytes_read == size) {
        bytes_read = 0;
        return true;
    }

    return false;
}


bool pl_DeviceConnect(uint8_t mode, uint8_t *buf, size_t buf_len){
	if( (buf == NULL) || (buf_len < 128) ) return false;
	switch(mode) {
		case MODE_SERIAL:
			dev_buffer = buf;
			dev_buffer_size = buf_len;
			dev_buffer_half_size = (buf_len>>1);
			if(cemu_check()){
				dev_funcs.id = mode;
				dev_funcs.init = pipe_setup;
				dev_funcs.process = NULL;
				dev_funcs.write = cemu_send;
				dev_funcs.read_to_size = pipe_read_to_size;
			
			}
			else{
				dev_funcs.id = mode;
				dev_funcs.init = srl_setup;
				dev_funcs.process = async_srl_process;
				dev_funcs.write = srl_send;
				dev_funcs.read_to_size = srl_read_to_size;
			}
			return dev_funcs.init();
			break;
		default:
			return false;
			
	}
}

device_status_t pl_GetDeviceStatus(void){
	return device_status;
}

void* pl_GetAsyncProcHandler(void){
	return dev_funcs.process;
}

bool pl_InitSendQueue(uint8_t *queue_buf, size_t queue_len){
	if(queue == NULL) return false;
	if(queue_len < (dev_buffer_half_size-3)) return false;
	queue = queue_buf;
	queue_max = queue_len;
	return true;
}

bool pl_QueueSendPacketSegment(uint8_t *data, size_t len){
	if((queue==NULL) || (data==NULL)) return false;
	if(len==0) return false;
	if((queue_filled + len) > queue_max) return false;
	memcpy(&queue[queue_filled], data, len);
	queue_filled += len;
	return true;
}


#define MIN(x, y)	((x) < (y)) ? (x) : (y)
size_t pl_SendPacket(uint8_t *data, size_t len){
	uint8_t *source = (data==NULL) ? queue : data;
	size_t packetlen = (data==NULL) ? queue_filled : MIN(dev_buffer_half_size-3, len);
	if (packetlen==0) return 0;
	if(device_status != PL_NTWK_READY) return 0;
	dev_funcs.write(&packetlen, sizeof(size_t));
	dev_funcs.write(source, packetlen);
	if(source==queue) queue_filled = 0;
	return packetlen;
}

size_t pl_ReadPacket(uint8_t *dest, size_t read_size){
	static size_t packet_size = 0;
	uint32_t start_time;
	uint32_t wait_time = (blocking_read_timeout * TIMERCPU_TO_MS);
	if(device_status != PL_NTWK_READY) return 0;
	if(dest == NULL) return 0;
	if(read_size == 0) return 0;
	start_time = usb_GetCycleCounter();
	do {
		if(dev_funcs.process) dev_funcs.process(false);
		if(packet_size){
			if(dev_funcs.read_to_size(packet_size, dest)) {
				packet_size = 0;
				return read_size;
			}
		}
		else
			if(dev_funcs.read_to_size(sizeof(packet_size), dest)) packet_size = *(size_t*)dest;
	} while((usb_GetCycleCounter() - start_time) < wait_time);
	return 0;
}


void pl_Shutdown(size_t timeout){
	switch(dev_funcs.id){
		case MODE_SERIAL:
		{
			uint32_t time_wait = (timeout * TIMERCPU_TO_MS);
			uint32_t time_start = usb_GetCycleCounter();
			do {
				if(dev_funcs.process) dev_funcs.process(false);
			} while ((!SRL_SEND_DONE) &&
					((usb_GetCycleCounter() - time_start) < time_wait));
			srl_Close(&srl_device);
			usb_Cleanup();
			break;
		}
		default:
			break;
	}
	device_status = PL_NTWK_NONE;
}
