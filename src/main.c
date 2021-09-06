
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
	(((srl_device_t*)device)->tx_buf.buf_start == ((srl_device_t*)device)->tx_buf.buf_end)

enum device_id {
	DEV_NONE,
    DEV_SERIAL,
    DEV_MAX=DEV_SERIAL
};

uint8_t device_type = DEV_NONE;
void* device = NULL;
size_t buffer_len = 0;
size_t buffer_half_len = 0;
uint32_t blocking_read_timeout = 0;
uint32_t async_write_timeout = (50 * TIMERCPU_TO_MS);

uint8_t *queue = NULL;
size_t queue_max = 0;
size_t queue_filled = 0;

size_t bytes_read = 0;



typedef struct {
    void (*process)(bool block);
    bool (*read_to_size)(size_t size, uint8_t* out);
    size_t (*write)(void *data, size_t size);
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
size_t cemu_send(void *buf, size_t size);
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

/* USB/SRL Subsystem */
bool srl_read_to_size(size_t size, uint8_t *out) {
    bytes_read += srl_Read(device, &out[bytes_read], size - bytes_read);
    if(bytes_read >= size) {bytes_read = 0; return true;}
    else return false;
}

size_t srl_send(void *buf, size_t size) {
    return srl_Write(device, buf, size);
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


bool pl_SetDevice(uint8_t mode, void *dev, size_t len){
	if(dev==NULL) return false;
	if(mode>DEV_MAX) return false;
	device = dev;
	device_type = mode;
	buffer_len = len;
	buffer_half_len = buffer_len>>1;
	switch(mode) {
		case DEV_SERIAL:
			if(cemu_check()){
				dev_funcs.process = NULL;
				dev_funcs.write = cemu_send;
				dev_funcs.read_to_size = pipe_read_to_size;
			
			}
			else{
				dev_funcs.process = async_srl_process;
				dev_funcs.write = srl_send;
				dev_funcs.read_to_size = srl_read_to_size;
			}
			break;
		default:
			return false;
			
	}
	return true;
}

void* pl_GetAsyncProcHandler(void){
	return dev_funcs.process;
}

bool pl_InitSendQueue(uint8_t *queue_buf, size_t queue_len){
	if(queue == NULL) return false;
	if(queue_len < (buffer_half_len-3)) return false;
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
	size_t sent = 0;
	uint8_t *source = (data==NULL) ? queue : data;
	size_t packetlen = (data==NULL) ? queue_filled : len;
	if((source!=queue) && ((data==NULL) || (len==0))) return 0;
	if(device_type == DEV_NONE) return 0;
	for(;sent<len;){
		size_t to_send = MIN(buffer_half_len-3, packetlen - sent), actually_sent = 0;
		if(dev_funcs.process) dev_funcs.process(true);
		actually_sent+=dev_funcs.write(&to_send, sizeof(to_send));
		actually_sent+=dev_funcs.write(&source[sent], to_send);
		sent += to_send;
		if(actually_sent != (to_send+3)) break;
	}
	if(source==queue) queue_filled -= sent;
	return sent;
}

bool pl_ReadPacket(uint8_t *dest){
	static size_t packet_size = 0;
	uint32_t start_time;
	if(dest == NULL) return false;
	if(device_type==DEV_NONE) return 0;
	start_time = usb_GetCycleCounter();
	do {
		if(dev_funcs.process) dev_funcs.process(false);
		if(packet_size){
			if(dev_funcs.read_to_size(packet_size, dest)) {
				packet_size = 0;
				return true;
			}
		}
		else
			if(dev_funcs.read_to_size(sizeof(packet_size), dest)) packet_size = *(size_t*)dest;
	} while((usb_GetCycleCounter() - start_time) < blocking_read_timeout);
	return false;
}

void pl_SetAsyncTimeout(size_t timeout){
	async_write_timeout = ((uint32_t)timeout * TIMERCPU_TO_MS);
}

void pl_SetReadTimeout(size_t timeout){
	blocking_read_timeout = ((uint32_t)timeout * TIMERCPU_TO_MS);
}
