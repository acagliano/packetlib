
#include <tice.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <debug.h>
#include <tice.h>
#include <string.h>
#include <usbdrvce.h>
#include <srldrvce.h>


srl_device_t srl;
uint8_t *srl_buf = NULL;
size_t srl_buf_size;
static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data);
bool device_connected = false;

typedef struct {
    uint8_t id;
    bool (*init)(void);
    void (*process)(void);
    bool (*read_to_size)(size_t size, uint8_t* out);
    void (*write)(void *data, size_t size);
} srl_callbacks_t;
srl_callbacks_t srl_funcs;

size_t srl_dbuf_size;
size_t srl_bytes_read = 0;
size_t srl_read_timeout = 0;


bool cemu_check(void);
size_t cemu_get(void *buf, size_t size);
void cemu_send(void *buf, size_t size);

/* USB/SRL Subsystem */
bool usb_read_to_size(size_t size, uint8_t *out) {
    srl_bytes_read += srl_Read(&srl, &out[srl_bytes_read], size - srl_bytes_read);
    if(srl_bytes_read >= size) {srl_bytes_read = 0; return true;}
    else return false;
}

void usb_write(void *buf, size_t size) {
    srl_Write(&srl, buf, size);
}

void usb_process(void) {
    usb_HandleEvents();
}

bool init_usb(void) {
    usb_error_t usb_error;
    usb_error = usb_Init(handle_usb_event, NULL, srl_GetCDCStandardDescriptors(), USB_DEFAULT_INIT_FLAGS);
    return !usb_error;
}

/* Pipe Subsystem */
bool pipe_init() {
    device_connected = true;
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




/* Handle USB events */
static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data) {
    /* When a device is connected, or when connected to a computer */
    if((event == USB_DEVICE_CONNECTED_EVENT && !(usb_GetRole() & USB_ROLE_DEVICE)) || event == USB_HOST_CONFIGURE_EVENT) {
        usb_device_t device = event_data;
        char dummy;
        srl_error_t srl_error = srl_Init(&srl, device, srl_buf, sizeof(srl_buf), SRL_INTERFACE_ANY);
        if(!srl_error) srl_SetRate(&srl, 115200);
        if(!srl_error) srl_Read(&srl, &dummy, 1);
        if(!srl_error) {
            device_connected = true;
        }
    }

    /* When a device is disconnected */
    if(event == USB_DEVICE_DISCONNECTED_EVENT) {
        device_connected = false;
    }

    return USB_SUCCESS;
}

enum net_mode_id {
    MODE_SERIAL,
    MODE_CEMU_PIPE
};
bool pl_InitSubsystem(uint8_t srl_mode, uint8_t *buf, size_t srl_buf_size){
	if(buf==NULL) return 0;
	if(srl_buf_size==0) return false;
	switch(srl_mode){
		case MODE_SERIAL:
			srl_funcs.id = MODE_SERIAL;
			srl_funcs.init = init_usb;
			srl_funcs.process = usb_process;
			srl_funcs.read_to_size = usb_read_to_size;
			srl_funcs.write = usb_write;
			break;
		
		case MODE_CEMU_PIPE:
			srl_funcs.id = MODE_CEMU_PIPE;
			srl_funcs.init = pipe_init;
			srl_funcs.process = NULL;
			srl_funcs.read_to_size = pipe_read_to_size;
			srl_funcs.write = cemu_send;
			break;
		default:
			return false;
	}
	srl_buf = buf;
	srl_dbuf_size = (srl_buf_size>>1);
	return srl_funcs.init();
}

void pl_SetReadTimeout(size_t ms_delay){
	srl_read_timeout = ms_delay;
}

typedef struct _packet_segments {
	uint8_t *addr;
	size_t len;
} ps_seg_t;
typedef struct _pk_ctx {
	size_t pkt_len;
	uint8_t pkt_id;
	uint8_t pkt_count;
	uint8_t pkt_flags;
	uint8_t data[1];
} packet_t;



void pl_PreparePacket(uint8_t ctl, ps_seg_t *ps, uint8_t arr_len, uint8_t pk_flags, packet_t *packet){
	size_t pos = 0;
	for(uint8_t i=0; i<arr_len; i++){
		uint8_t* addr = ps[i].addr;
		size_t len = ps[i].len;
		memcpy(&packet->data[pos], addr, len);
		pos += len;
	}
	pos += 3;
	packet->pkt_id = ctl;
	packet->pkt_len = pos;
	packet->pkt_count = (pos / srl_dbuf_size) + 1;
	packet->pkt_flags = pk_flags;
}


#define MIN(x, y)	((x) < (y)) ? (x) : (y)
bool pl_SendPacket(packet_t *packet){
	size_t pos = 0;
	uint8_t *pk_data =  (uint8_t*)packet;
	size_t pk_len = packet->pkt_len;
	if(packet==NULL) return false;
	if(pk_len < 3) return false;
	
	do {
		size_t this_len = MIN(srl_dbuf_size, pk_len - pos);
		srl_funcs.write(&this_len, sizeof(size_t));
		srl_funcs.write(&pk_data[pos], this_len);
	} while(pos < pk_len);
	
	return true;
}

size_t pl_ReadPacket(uint8_t *dest, size_t read_size){
	static size_t packet_size = 0;
	uint32_t start_time = timer_GetSafe(3, TIMER_UP);
	do {
		if(srl_funcs.process) srl_funcs.process();
		if(!device_connected) return 0;
		if(packet_size){
			if(srl_funcs.read_to_size(packet_size, dest)) {
				packet_size = 0;
				return read_size;
			}
		}
		else
			if(srl_funcs.read_to_size(sizeof(packet_size), dest)) packet_size = *(size_t*)dest;
	} while((timer_GetSafe(3, TIMER_UP) - start_time) > srl_read_timeout);
	return 0;
}
