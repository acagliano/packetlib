/*
 *--------------------------------------
 * Program Name:
 * Author:
 * License:
 * Description:
 *--------------------------------------
*/

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include <tice.h>

#include <netpktce.h>
#include <fileioc.h>


#define CEMU_CONSOLE ((char*)0xFB0000)
#define SRL_BUF_SIZE (1024)
uint8_t srl_buf[SRL_BUF_SIZE];
uint8_t queue[SRL_BUF_SIZE>>1];
uint8_t packet[SRL_BUF_SIZE];
uint8_t *strbuf = "The lazy fox jumped over the dog";

int main(void)
{
	pl_DeviceConnect(NET_MODE_SERIAL, srl_buf, SRL_BUF_SIZE);
	pl_InitSendQueue(queue, SRL_BUF_SIZE>>1);
	
	printf("SubSys Init RV: %u\n", pl_GetDeviceStatus());
	
	os_GetKey();
	if(!(pl_GetDeviceStatus() == PL_NTWK_READY)) return 1;
	
	if(pl_ReadPacket(packet, 1)) printf("serial read sucessful");
	else printf("serial read failed");
	//pl_QueueSendPacketSegment(strbuf, strlen(strbuf));
	//pl_SendPacket(NULL, 0);
	//pl_ReadPacket(packet, 10);
	
	pl_Shutdown(1000);
	
    return 0;
    
}
