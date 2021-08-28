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
#define SRL_BUF_SIZE (1024*4)
uint8_t srl_buf[SRL_BUF_SIZE];
uint8_t packet_buf[SRL_BUF_SIZE];
uint8_t *strbuf = "The lazy fox jumped over the dog";

int main(void)
{
	pl_psdata_t pk = {strbuf, strlen(strbuf)};
	packet_t* packet = (packet_t*)packet_buf;
	size_t pk_len;
	
	pl_InitSubsystem(NET_MODE_CEMU_PIPE, srl_buf, SRL_BUF_SIZE, 5000);
	pl_SetReadTimeout(5000);
	
	pk_len = pl_JoinPacketSegments(&pk, 1, packet);
	pl_SendPacket(0, packet, pk_len, 0);
	
    return 0;
    
}
