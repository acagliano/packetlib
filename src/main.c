
#include <stddef.h>
#include <stdint.h>
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
    bool (*read_to_size)(size_t size);
    void (*write)(void *data, size_t size);
} net_mode_t;
net_mode_t srl_config;

typedef struct {
	uint8_t srl_mode;
	size_t srl_buf_size;
	uint8_t packet_limit;
} net_cfg_t;
net_cfg_t net_config;
size_t buf_seg_size;
size_t srl_bytes_read = 0;

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

    if(srl_bytes_read > size) {
        dbg_sprintf(dbgerr, "Pipe buffer in illegal state\n");
    }

    if(srl_bytes_read == size) {
        net_buf_size = 0;
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

enum _srl_modes {
	SRL_MODE_SERIAL,
	SRL_MODE_CEMU
};
bool pl_InitSubsystem(uint8_t *srl_buf, net_cfg_t *cfg, void* (*malloc)(size_t)){
	if(srl_buf == NULL) return false;
	if((srl_mode>SRL_MODE_CEMU) || (srl_mode<SRL_MODE_SERIAL)) return false;
	switch(srl_mode){
		case SRL_MODE_SERIAL:
			srl_config = {
				MODE_SERIAL,
				init_usb,
				usb_process,
				usb_read_to_size,
				usb_write
			};
			break;
		
		case SRL_MODE_CEMU:
			srl_config = {
				MODE_CEMU_PIPE,
				pipe_init,
				NULL,
				pipe_read_to_size,
				cemu_send		// asm routine
			};
			break;
	}
	srl_buf = malloc(cfg->srl_buf_size);
	memcpy(&net_config, cfg, sizeof(net_cfg_t));
	buf_seg_size = net_config.srl_buf_size>>1;
	return srl_config.init();
}

typedef struct _packet_segments {
	uint8_t *addr,
	size_t len
} ps_seg_t;
size_t pl_PreparePacket(uint8_t ctl, ps_seg_t *ps, uint8_t arr_len, uint8_t *packet){
	size_t pos = 1;
	packet[0] = ctl;
	for(uint8_t i=0; i<arr_len; i++){
		uint8_t* addr = ps[i]->addr;
		size_t len = ps[i]->len;
		if((pos + len) > buf_seg_size) return pos;
		memcpy(&packet[pos], addr, len);
		pos += len;
	}
}

size_t pl_SendPacket(const uint8_t *data, size_t len){
	if(data==NULL) return 0;
	if(len > buf_seg_size) return 0;
	srl_config->write(data, len);
}

size_t pl_ReadPacket(uint8_t *dest, size_t read_size, bool blocking){
	static size_t packet_size = 0;
	bool got_packet = false;
	if(srl_config->process) mode->process();
	if(!device_connected) return 0;
	while(!got_packet){
		if(packet_size){
			if(srl_config->read_to_size(packet_size, dest)) {
				packet_size = 0;
				return read_size;
				break;
			}
		}
		else
			if(srl_config->read_to_size(sizeof(packet_size), dest)) packet_size = *(size_t*)dest;
		if(!blocking) break;
	}
	return 0;
}

bool pl_Shutdown(void){
	free(srl_buf);
	return true;
}
