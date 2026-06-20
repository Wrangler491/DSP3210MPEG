/**************************************************************************
	DSP3210.c
	Support routines for the DSP - code file
	Copyright (C) 2025 Wrangler

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <proto/exec.h>
#include <exec/types.h>
#include <exec/memory.h>
#include <exec/execbase.h>

#include <hardware/cia.h>
#include <hardware/intbits.h>
//#define DEBUG	1

#ifdef DEBUG
#include "clib/debug_protos.h"
#endif

#include <exec/interrupts.h>

#include <time.h>
#include <devices/timer.h>
#include <clib/timer_protos.h>


/* DSP shared data variables */

ULONG DSP_forcemono;
ULONG DSP_mono;
ULONG DSP_outbuffer0;
ULONG DSP_outbuffer1;
ULONG DSP_translate;
ULONG DSP_jsbound;
ULONG DSP_inbuf;
ULONG DSP_volR;
ULONG DSP_volL;
ULONG DSP_freq_div;
ULONG DSP_modext;
ULONG DSP_freq_idx;


ULONG DSP_routine;	//code for routine to jump to
ULONG DSP_status;	//shows DSP status
ULONG DSP_usage;
ULONG DSP_registers;

/* Defines for Flag */
#define DSP3210_OK		0xC0FFEE
#define DSP3210_RUN		0xD0FEED
#define DSP3210_READY	0xD1DFEED
#define DSP3210_FAIL	0xDEADDEAD

/* Defines for DSP control registers */
#define DSP3210_RREG	0x00dd005C
#define DSP3210_WREG	0x00dd0080

#define DSP3210_NORM	0xCF	//0xFF	//note, Int2 and 6 from DSP enabled
#define DSP3210_RSET	0x4F	//0x7F
#define DSP3210_INT1	0xCD	//0xFD
#define DSP3210_INT0	0xCE	//0xFE

/* DSP control registers. */

ULONG * volatile dsp_read = (void *) DSP3210_RREG;
UBYTE * volatile dsp_write = (void *) DSP3210_WREG;
ULONG * volatile zero = NULL;

struct CIA __far ciaa;

void SetCtrl(ULONG val);
BOOL WakeupWait(ULONG dspcode);

ULONG dspcode;
int IMDCT_count = 0;
int antialias_count = 0;
int window_count = 0;
int filter_count = 0;
int layer_count = 0;

ULONG signr;
extern void DSPIntServer2();
void *chipmem;

//**************************************************************************
//	Incbins            ".incbin \"" file "\"\n" \
//**************************************************************************

#define INCBIN(name, file) \
	__asm("\tpushsection\n\tdata\n" \
        "\tcnop\t0,4\n\txdef\t_incbin_" #name "_start\n" \
        "_incbin_" #name "_start:\n\tincbin\t\"" #file "\"\n" \
        "\txdef\t_incbin_" #name "_end\n" \
        "_incbin_" #name "_end:\n\tdc.b\t0\n\tpopsection"); \
  extern const char incbin_ ## name ## _start[]; \
  extern const char incbin_ ## name ## _end[]



#ifdef DEBUG
void memdump()
{
	ULONG cachelen = 24*4;
	int i;

	CachePostDMA(&dspcode, &cachelen, 0);
	for(i=0; i<24; i++)
	{
		KPrintF("\tMem offset: 0x%02lx = value: 0x%08lx\n",i<<2, *(int *)(dspcode+(i<<2)));
	}
	return;
}
#endif

void SetCtrl(ULONG val) 
{
	short i;
	ULONG mask = 0x4c;

	do {
		*dsp_write = (UBYTE)(val & 0xff);

		for (i = 0; i<256; ++i);
		if ((*dsp_read & mask) == (val & mask)) break;
	} while (TRUE);
}

#define BASICWAIT 100000
#define RETRYTHRESHOLD 10

BOOL WakeupWait(ULONG dspcode) 
{
	ULONG count;
	short tcnt = 0;

	do {
		count = 0;
		do {
			if (*zero != (ULONG)dspcode) break;
			++count;
		} while (count < BASICWAIT);
		if (*zero != (ULONG)dspcode) return TRUE;

		if (++tcnt > RETRYTHRESHOLD) return FALSE;
	} while (TRUE);
}

void DSP_init(int codec) {
	long i, j, k;
	ULONG dsplocation;
	ULONG cachelen = 4;
	struct Task *mytask;

#ifdef DEBUG
	int v1 = 4;
	KPrintF("DSPmpeg v1.%ld\n",v1);
#endif

	INCBIN(DSP_asm_mp2, mpeg-DSP-mp2.o);		//ensure DSP code loaded to data section
	INCBIN(DSP_asm_mp3, mpeg-DSP-mp3.o);
	switch (codec) {
	case 2:
		dspcode = (ULONG)incbin_DSP_asm_mp2_start;
		dsplocation = dspcode + 8;
		*(ULONG *)dsplocation = dspcode;	//fill in dspcode of DSP_data
		CachePreDMA(&dsplocation, &cachelen, 0);	//make sure address written to RAM

		DSP_forcemono	= dspcode + 0x0C;
		DSP_mono		= dspcode + 0x10;
		DSP_outbuffer0	= dspcode + 0x14;
		DSP_outbuffer1	= dspcode + 0x18;
		DSP_translate	= dspcode + 0x1C;
		DSP_jsbound		= dspcode + 0x20;
		DSP_inbuf		= dspcode + 0x24;
		DSP_volR		= dspcode + 0x28;
		DSP_volL		= dspcode + 0x2C;
		DSP_freq_div	= dspcode + 0x30;

		DSP_routine		= dspcode + 0x34;
		DSP_status		= dspcode + 0x38;
		DSP_usage		= dspcode + 0x3C;
		DSP_registers	= dspcode + 0x40;
		break;

	case 3:
		dspcode = (ULONG)incbin_DSP_asm_mp3_start;
		dsplocation = dspcode + 8;
		*(ULONG *)dsplocation = dspcode;	//fill in dspcode of DSP_data
		CachePreDMA(&dsplocation, &cachelen, 0);	//make sure address written to RAM

		DSP_forcemono	= dspcode + 0x0C;
		DSP_mono		= dspcode + 0x10;
		DSP_outbuffer0	= dspcode + 0x14;
		DSP_outbuffer1	= dspcode + 0x18;
		DSP_translate	= dspcode + 0x1C;
		DSP_jsbound		= dspcode + 0x20;
		DSP_inbuf		= dspcode + 0x24;
		DSP_volR		= dspcode + 0x28;
		DSP_volL		= dspcode + 0x2C;
		DSP_freq_div	= dspcode + 0x30;
		DSP_modext		= dspcode + 0x34;
		DSP_freq_idx	= dspcode + 0x38;

		DSP_routine		= dspcode + 0x3C;
		DSP_status		= dspcode + 0x40;
		DSP_usage		= dspcode + 0x44;
		DSP_registers	= dspcode + 0x48;
		break;

	default:
		KPrintF("Illegal codec\n");
		return;
	}

	mytask = FindTask("DSPmeter");
	if(mytask)
		*(ULONG *)DSP_usage = (ULONG)mytask->tc_UserData;	//copy ptr to usage count into DSP prog
	else
		*(ULONG *)DSP_usage = 0;


	for(k=0;k<10;k++) {
		*zero = (LONG) dspcode; /* dsp reads PC addr from here after int1 */

		SetCtrl(DSP3210_RSET); /* Set up for DSP in reset */

		for (i = 0; i < 1000; i++) 
			j = ciaa.ciapra;

		SetCtrl(DSP3210_NORM); /* Take DSP out of reset */
		SetCtrl(DSP3210_INT1); /* cause int1 on dsp */

		if (WakeupWait(dspcode)) { /* Wait for DSP to wake up */
			SetCtrl(DSP3210_NORM); /* Take DSP out of reset */			
			cachelen = 4;
			CachePostDMA(&dsplocation, &cachelen, 0);	//make sure address written to RAM
			return;
		}
	}

		#ifdef DEBUG
		KPrintF("*** DSP failed to initialise"); // and return magic number: 0x%08lx\n",*(int *)DSP_status);
		#endif

	return;
}

void DSP_exit() 
{
	SetCtrl(DSP3210_NORM);
	return;
}

void DSP_int0(ULONG input, ULONG inputlen) 
{	
	ULONG cachelen = 4;
	CachePreDMA(&DSP_status,&cachelen,0);
	CachePreDMA(&input,&inputlen,0);
	SetCtrl(DSP3210_INT0); /* cause int0 on dsp */
	return;
}

void DSP_int1() 
{	
	ULONG cachelen = (DSP_usage - DSP_forcemono + 4);
	CachePreDMA((APTR)DSP_forcemono, &cachelen, 0);		//ensure all shared mem is written
	SetCtrl(DSP3210_INT1); /* cause int1 on dsp */
	return;
}

int DSP_waitready(ULONG output, ULONG outputlen) 
{
	int i, iter;
	long j;
	iter = 0;
	//volatile long v;
	ULONG cachelen = 4;
	CachePostDMA(&DSP_status,&cachelen,0); //clear read cache for flag

	if(*(int *)DSP_status ==  DSP3210_OK) {
		#ifdef DEBUG
		KPrintF("DSP3210_OK\n");
		#endif
		return 0; //got initialised signal 
	}

	for(i=0; i<BASICWAIT/100; i++) {
		cachelen = 4;
		CachePostDMA(&DSP_status,&cachelen,0); //clear read cache for flag

		switch(*(int *)DSP_status) {
			case DSP3210_READY:
			case DSP3210_OK:
				cachelen = outputlen;
				if(output)
					CachePostDMA(&output,&cachelen,0);	//clear entire data area
				return 0; //got ready signal
		
			case DSP3210_RUN:
				break;

			default:
				#ifdef DEBUG
				KPrintF("********** DSP3210 exception! **********\n");
				KPrintF("dspcode is 0x%08lx\n",(ULONG)dspcode);
				ULONG except_r,exc_inner;
				for(except_r=0; except_r<19;) {
					for(exc_inner = 0; exc_inner<4 ; except_r++, exc_inner++) {
						if(except_r > 19) break;
						KPrintF("r%ld: 0x%08lx ",except_r+1, *(int *)(DSP_registers+(except_r*4)));
					}
					KPrintF("\n");
				}
				KPrintF("****************************************\n");

				KPrintF("\n");

				for(except_r=0; except_r<8;) {
					for(exc_inner = 0; exc_inner<4 ; except_r++, exc_inner++) {
						KPrintF("0x%08lx ", *(int *)((dspcode + 0x8c84)+(except_r*4)));
					}
					KPrintF("\n");
				}

				#endif
				return -1; //failure
		}
		cachelen = 4;
		CachePreDMA(&DSP_status,&cachelen,0); //clear read cache for flag
		j = ciaa.ciapra;
	}

	return 1;
}

