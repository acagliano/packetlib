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
uint8_t packet_buf[SRL_BUF_SIZE*2];

int main(void)
{
	ti_var_t f;
	size_t pk_len;
	uint8_t *pk_addr;
	
	ti_CloseAll();
	if(!(f = ti_Open("FILEIOC", "r"))) return 1;
	pk_addr = ti_GetDataPtr(f);
	pk_len = ti_GetSize(f);
	
	pl_InitSubsystem(NET_MODE_CEMU_PIPE, srl_buf, SRL_BUF_SIZE, 5000);
	pl_SetReadTimeout(5000);
	
	for(size_t l = 0; l < pk_len;)
		l += pl_SendPacket(0, &pk_addr[l], pk_len - l, 0);
	
	ti_Close(f);
    return 0;
    
}
