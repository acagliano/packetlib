/*
 *--------------------------------------
 * Program Name:
 * Author:
 * License:
 * Description:
 *--------------------------------------
 */

#include <srldrvce.h>
#include <netpktce.h>

#include <stdio.h>
#include <keypadc.h>
#include <stdbool.h>
#include <string.h>
#include <tice.h>

srl_device_t srl;

usb_device_t device = NULL;

bool has_srl_device = false;
bool pl_device_set = false;

uint8_t srl_buf[512];

static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data __attribute__((unused))){
    /* Enable newly connected devices */
    if(event == USB_DEVICE_CONNECTED_EVENT && !(usb_GetRole() & USB_ROLE_DEVICE)){
        usb_device_t device = event_data;
        printf("device connected\n");
        usb_ResetDevice(device);
    }
    if(event == USB_HOST_CONFIGURE_EVENT){
        usb_device_t host = usb_FindDevice(NULL, NULL, USB_SKIP_HUBS);
        if(host) device = host;
    }
    /* When a device is connected, or when connected to a computer */
    if((event == USB_DEVICE_ENABLED_EVENT && !(usb_GetRole() & USB_ROLE_DEVICE))){
        device = event_data;
    }
    if(event == USB_DEVICE_DISCONNECTED_EVENT){
        srl_Close(&srl);
        has_srl_device = false;
        device = NULL;
    }
    
    return USB_SUCCESS;
}

int main(void){
    os_ClrHome();
    const usb_standard_descriptors_t *desc = srl_GetCDCStandardDescriptors();
    /* Initialize the USB driver with our event handler and the serial device descriptors */
    usb_error_t usb_error = usb_Init(handle_usb_event, NULL, desc, USB_DEFAULT_INIT_FLAGS);
    if(usb_error){
        usb_Cleanup();
        printf("usb init error %u\n", usb_error);
        do kb_Scan(); while(!kb_IsDown(kb_KeyClear));
        return 1;
    }
    
    do {
        kb_Scan();
        
        usb_HandleEvents();
        
        if(device && !has_srl_device){
            //printf("device enabled\n");
            
            /* Initialize the serial library with the newly attached device */
            srl_error_t error = srl_Open(&srl, device, srl_buf, sizeof srl_buf, SRL_INTERFACE_ANY, 9600);
            
            if(error){
                /* Print the error code to the homescreen */
                printf("Error %u initting serial\n", error);
            }
            has_srl_device = true;
        }
        
        if(has_srl_device){
            uint8_t read[256];
            size_t read_size;
            if(!pl_device_set) pl_device_set = pl_SetDevice(DEVICE_SERIAL, &srl, 512);
            
            if((read_size = pl_ReadPacket(read))){
                printf("%s", read);
                pl_SendPacket(read, read_size);
            }
        }
        
    } while(!kb_IsDown(kb_KeyClear));
    
    usb_Cleanup();
    return 0;
}
