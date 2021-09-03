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
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

#include <tice.h>

#include <srlpktce.h>
#include <fileioc.h>


#define CEMU_CONSOLE ((char*)0xFB0000)
#define SRL_BUF_SIZE (1024)
uint8_t srl_buf[SRL_BUF_SIZE];
uint8_t packet[SRL_BUF_SIZE];
uint8_t *strbuf = "The lazy fox jumped over the dog";

int main(void)
{
	ps_t pk = {strbuf, strlen(strbuf)};
	size_t pk_len;
	subsys_config_t cfg = {srl_buf, SRL_BUF_SIZE};
	
	pl_InitSubsystem(NET_MODE_SERIAL, &cfg, 2000);
	printf("SubSys Init RV: %u\n", pl_GetDeviceStatus());
	os_GetKey();
	pl_SetWriteTimeout(5000);
	if(!(pl_GetDeviceStatus() == PL_SUBSYS_READY)) return 1;
	
	
	pk_len = pl_JoinPacketSegments(1, &pk, 1, packet);
	pl_SendPacket(packet, pk_len);
	
	pl_Shutdown();
	
    return 0;
    
}
