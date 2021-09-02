
#include <tice.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <debug.h>
#include <tice.h>
#include <string.h>
#include <usbdrvce.h>
#include <srldrvce.h>

enum net_mode_id {
    MODE_SERIAL,
    MODE_CEMU_PIPE
};

typedef enum {
	PL_SUBSYS_NONE,
	PL_SUBSYS_ENABLED,
	PL_SUBSYS_READY,
	PL_SUBSYS_INTERNAL_ERROR,
	PL_SUBSYS_USER_ERROR = 0xff
} subsys_status_t;

typedef struct _subsys_config {
	uint8_t* buf; size_t buf_size;
} subsys_config_t;

subsys_status_t device_status = PL_SUBSYS_NONE;

srl_device_t srl_device;
usb_device_t usb_device = NULL;

uint8_t *srl_buf = NULL;
size_t srl_buf_size = 0;
size_t srl_dbuf_size = 0;
size_t srl_bytes_read = 0;
uint32_t srl_read_timeout = 0;
uint32_t srl_write_timeout = 0;

#define CEMU_CONSOLE ((char*)0xFB0000)
#define TIMERCPU_TO_MS		48000

static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data);

typedef struct {
    uint8_t id;
    bool (*init)(void);
    void (*process)(void);
    bool (*read_to_size)(size_t size, uint8_t* out);
    void (*write)(void *data, size_t size);
} srl_callbacks_t;
srl_callbacks_t *srl_funcs;

bool init_usb(void);
bool usb_read_to_size(size_t size, uint8_t *out);
void usb_write(void *buf, size_t size);
void usb_process(void);

bool pipe_init(void);
size_t cemu_get(void *buf, size_t size);
bool pipe_read_to_size(size_t size, uint8_t* out);
void cemu_send(void *buf, size_t size);
void pl_SetTimeout(size_t ms_delay);

srl_callbacks_t srl_callbacks = {
        MODE_SERIAL,
        init_usb,
        usb_process,
        usb_read_to_size,
        usb_write
};
srl_callbacks_t pipe_callbacks = {
        MODE_CEMU_PIPE,
        pipe_init,
        NULL,
        pipe_read_to_size,
        cemu_send
};


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
				device_status = PL_SUBSYS_ENABLED;
			}
			break;
		case USB_HOST_CONFIGURE_EVENT:
		{
			srl_error_t srl_error;
			char dummy;
			usb_device_t host = usb_FindDevice(NULL, NULL, USB_SKIP_HUBS);
			if(host) usb_device = host;
			srl_error = srl_Open(&srl_device, usb_device, srl_buf, srl_buf_size, SRL_INTERFACE_ANY, 115200);
			if(srl_error) return USB_ERROR_FAILED;
			srl_Read(&srl_device, &dummy, 1);
			device_status = PL_SUBSYS_READY;
			break;
		}
		case USB_DEVICE_DISCONNECTED_EVENT:
			srl_Close(&srl_device);
			usb_device = NULL;
			break;
		default:
			break;
	}
    return USB_SUCCESS;
}

/* USB/SRL Subsystem */
bool usb_read_to_size(size_t size, uint8_t *out) {
    srl_bytes_read += srl_Read(&srl_device, &out[srl_bytes_read], size - srl_bytes_read);
    if(srl_bytes_read >= size) {srl_bytes_read = 0; return true;}
    else return false;
}

void usb_write(void *buf, size_t size) {
    srl_Write(&srl_device, buf, size);
}



void usb_process(void) {
    usb_HandleEvents();
}

bool init_usb(void) {
	char dummy;
	srl_error_t srl_error;
    usb_error_t usb_error = usb_Init(handle_usb_event, NULL, srl_GetCDCStandardDescriptors(), USB_DEFAULT_INIT_FLAGS);
    if(usb_error){ usb_Cleanup(); return false; }
    do {
		usb_HandleEvents();
		// else printf(error code)
	} while(device_status != PL_SUBSYS_READY);
    //srl_Read(&srl_device, &dummy, 1);
    return true;
}

/* Pipe Subsystem */
bool pipe_init(void) {
    device_status = PL_SUBSYS_READY;
    return true;
}

bool pipe_read_to_size(size_t size, uint8_t* out) {
    if(srl_bytes_read < size) {
        size_t recd;
        recd = cemu_get(&out[srl_bytes_read], size - srl_bytes_read);	// asm routine
        srl_bytes_read += recd;
    }

    if(srl_bytes_read > size) return false;
    if(srl_bytes_read == size) {
        srl_bytes_read = 0;
        return true;
    }

    return false;
}

void* pl_InitSubsystem(uint8_t srl_mode, subsys_config_t *sys_conf, size_t ms_delay){
	if(sys_conf==NULL) return 0;
	if(device_status) return 0;
	switch(srl_mode){
		case MODE_SERIAL:
		case MODE_CEMU_PIPE:
			if(srl_mode == MODE_SERIAL) srl_funcs = &srl_callbacks;
			if(srl_mode == MODE_CEMU_PIPE) srl_funcs = &pipe_callbacks;
			srl_buf = sys_conf->buf;
			srl_buf_size = sys_conf->buf_size;
			srl_dbuf_size = (srl_buf_size>>1);
			break;
		default:
			return false;
	}
	if(srl_funcs->init()) return srl_funcs->process;
	return NULL;
}

subsys_status_t pl_GetDeviceStatus(void){
	return device_status;
}

void pl_SetReadTimeout(size_t read){
	srl_read_timeout = (read * TIMERCPU_TO_MS);
}

typedef struct _packet_segments {
	uint8_t *addr;
	size_t len;
} ps_seg_t;

size_t pl_JoinPacketSegments(uint8_t pid, ps_seg_t *ps, uint8_t arr_len, uint8_t *out){
	size_t pos = 1;
	out[0] = pid;
	for(uint8_t i=0; i<arr_len; i++){
		uint8_t* addr = ps[i].addr;
		size_t len = ps[i].len;
		memcpy(&out[pos], addr, len);
		pos += len;
	}
	return pos;
}


#define MIN(x, y)	((x) < (y)) ? (x) : (y)
size_t pl_SendPacket(uint8_t *data, size_t len, size_t timeout){
	uint32_t start_time;
	uint32_t wait_time = ((uint32_t)timeout) * TIMERCPU_TO_MS;
	size_t packetlen = MIN(srl_dbuf_size-3, len);
	if(data==NULL) return 0;
	if(len==0) return 0;
	if(device_status != PL_SUBSYS_READY) return 0;
	srl_funcs->write(&packetlen, sizeof(size_t));
	srl_funcs->write(data, packetlen);
	
	start_time = usb_GetCycleCounter();
	do {
		if(srl_funcs->process) srl_funcs->process();
	} while((usb_GetCycleCounter() - start_time) < wait_time);
	return packetlen;
}

size_t pl_ReadPacket(uint8_t *dest, size_t read_size, size_t timeout){
	static size_t packet_size = 0;
	uint32_t start_time;
	uint32_t wait_time = ((uint32_t)timeout) * TIMERCPU_TO_MS;
	if(device_status != PL_SUBSYS_READY) return 0;
	if(dest == NULL) return 0;
	if(read_size == 0) return 0;
	start_time = usb_GetCycleCounter();
	do {
		if(srl_funcs->process) srl_funcs->process();
		if(packet_size){
			if(srl_funcs->read_to_size(packet_size, dest)) {
				packet_size = 0;
				return read_size;
			}
		}
		else
			if(srl_funcs->read_to_size(sizeof(packet_size), dest)) packet_size = *(size_t*)dest;
	} while((usb_GetCycleCounter() - start_time) < wait_time);
	return 0;
}

#define SRL_SEND_DONE \
	(srl_device.tx_buf.buf_start == srl_device.tx_buf.buf_end)
void pl_Shutdown(size_t timeout){
	switch(srl_funcs->id){
		case MODE_SERIAL:
		{
			uint32_t wait_time = ((uint32_t)timeout) * TIMERCPU_TO_MS;
			uint32_t start_time = usb_GetCycleCounter();
			do {
				if(srl_funcs->process) srl_funcs->process();
			} while((!SRL_SEND_DONE) &&
					(usb_GetCycleCounter() - start_time) < wait_time);
			srl_Close(&srl_device);
			usb_Cleanup();
			break;
		}
		default:
			break;
	}
	device_status = PL_SUBSYS_NONE;
}
