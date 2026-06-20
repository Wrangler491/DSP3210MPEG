
//  MPEG 1 layers II and III decoding routines for the DSP3210
//  Copyright © Wrangler 2024, all rights reserved

//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

/* Defines for DSP_routine */
#define DSP3210_volume		1
#define DSP3210_decodeMP2	2
#define DSP3210_decodeMP3	3



/* Defines for DSP_status */
#define DSP3210_OK		0x00C0FFEE
#define DSP3210_RUN		0x00D0FEED
#define DSP3210_READY	0x0D1DFEED
#define DSP3210_FAIL	0xDEADDEAD

/* Defines for DSP onboard RAM */
#define DSP3210_RAM0	0x5003F000
#define DSP3210_RAM1	0x5003E000

// Macro for PC relative addressing. 
#define AddressPR(LAB) pc + LAB - (.+8)   

DSP_origin:
DSP_start equ DSP_origin + 0x8000	//offset to access full 64k small data area
pcgoto DSP_code	//can call initial address but jump past data
emr = (short)r0

DSP_location:	long 0	//this will get filled in with the absolute address of DSP_start

//the following variables need to exist in shared fast mem


DSP_forcemono:			long 0			//1 if forcemono, otherwise 0
DSP_mono:				long 0			//1 if mono, 0 if stereo
DSP_outbuffer0:			long 0			//output buffer for ch 0, each one needs to be 96*12*2 bytes = 1152 words = 2304 bytes
DSP_outbuffer1:			long 0			//output buffer for ch 1
DSP_translate:			long 0			//translate for sblimit, bitalloc, quantization
DSP_jsbound:			long 0			//jsbound
DSP_inbuf:				long 0			//ptr to inbuffer
DSP_volR:				long 32767
DSP_volL:				long 32767
DSP_freq_div:			long 0
DSP_modext:				long 0
DSP_freq_idx:			long 0

DSP_routine:		long 0	//code for routine to jump to
DSP_status:		long 0	//shows DSP status
DSP_usage:				long 0
DSP_registers:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


//**********************************************************************
// Initialisation to set up vector table and wait for int
//
//**********************************************************************
DSP_code:
	r1 = AddressPR(DSP_location)
	r1 = *r1				//address of start of shared data area that M68K can also access
	r2 = (ushort24) 0x8000
	r1 = r1 + r2
	r3 = AddressPR(DSP_data_address)
	*r3 = r1	//fill in the address

	r1 = DSP3210_RAM1		//RAM1
	r2 = AddressPR(RAM_start)	//first long to copy
	r3 = AddressPR(RAM_end)

Copyloop:
	r4 = *r2++
	nop
	*r1++ = r4
	r2 - r3
	if(le) pcgoto Copyloop	//copy the prog to RAM1
	nop

	r1 = AddressPR(DSP_usage)
	r1 = *r1
	r2 = AddressPR(DSP_registers)
	r1 - r0
	if(eq) r1 = r2	//used as a dummy address
	r2 = r0 //*r1

	r3 = AddressPR(DSP_status)
	r4 = DSP3210_OK			//how else to get started?
	r22 = AddressPR(Vec_tab) 	//set our exception vector table pointer
	*r3 = r4				//signal done

	r4 = DSP3210_RAM1 + wait_routine - RAM_start
	goto r4					//jump to on-chip "wait and count loop"
	nop 



//**********************************************************************
// Exception vector table -- so we can redirect interrupts to our code
//
//**********************************************************************

Vec_tab:	
	if(true) pcgoto trap_reset	//reset
	r4 = DSP3210_OK
	if(true) pcgoto trap_restart	//bus err
	r4 = 1
	if(true) pcgoto trap_illegal	//illegal instr
	*(reg_store - RAM_start + 0xE00) = r10	//save r10
	if(true) pcgoto trap_restart	//reserved
	r4 = 3
	if(true) pcgoto trap_restart	//addr err
	r4 = 4
	if(true) pcgoto trap_restart	//DAU over/underflow
	r4 = 5
	if(true) pcgoto trap_restart	//NaN
	r4 = 6
	if(true) pcgoto trap_restart	//reserved
	r4 = 7
	ireturn					//Int 0 v74
	nop
	if(true) pcgoto trap_restart	//Timer
	r4 = 9
	if(true) pcgoto trap_restart	//reserved
	r4 = 10
	if(true) pcgoto trap_restart	//Boot ROM
	r4 = 11
	if(true) pcgoto trap_restart	//reserved
	r4 = 12
	if(true) pcgoto trap_restart	//reserved
	r4 = 13
	if(true) pcgoto trap_restart	//reserved
	r4 = 14
	if(true) pcgoto int1	//Int 1
	emr = (short) r0			//mask further ints




//**********************************************************************
// Reset triggered by software
//
//**********************************************************************

trap_illegal:
	r10 = AddressPR(DSP_data_address)
	r10 = *r10
	nop
	r10 = r10 + (DSP_registers - DSP_start)
	*r10++ = r1
	*r10++ = r2
	r1 = r10
	r10 = *(reg_store - RAM_start + 0xE000)		//###come back to this as it won't work!
	*r1++ = r3
	*r1++ = r4
	*r1++ = r5
	*r1++ = r6
	*r1++ = r7
	*r1++ = r8
	*r1++ = r9
	*r1++ = r10
	*r1++ = r11
	*r1++ = r12
	*r1++ = r13
	*r1++ = r14
	*r1++ = r15
	*r1++ = r16
	*r1++ = r17
	*r1++ = r18
	*r1++ = r19
	*r1++ = r20
	r4 = 2

	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r1 = r1 + (DSP_status - DSP_start)
	*r1 = r4
	r1 = (ushort24) 0x8000
	emr = (short) r1		//enable Int 1
	iret:
	ireturn
	nop						//technically, not needed
	pcgoto iret

trap_reset:
trap_restart:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r1 = r1 + (DSP_status - DSP_start)
	*r1 = r4

trap_wait:
	r1 = (ushort24) 0x8000
	emr = (short) r1		//enable Int 1
	ireturn
	nop						//technically, not needed

trap_int0:  
	pcgoto trap_illegal
	nop


//**********************************************************************
// Interrupt-driven processing
//
//**********************************************************************

int1:				//called when there is an int and this is where it all happens
	*0xE000 = r1
	*0xE004 = r2		//stack registers used in waitloop
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	r4 = DSP3210_RUN 
	r3 = r1 + (DSP_status - DSP_start)    
	*r3 = r4				//signal started interrupt routine

	
	//******************************************
	//* Decode MP3 main entry point            *
	//******************************************

MPEG_decodeMP3:

	//r1 = *(DSP_data_address - RAM_start + 0xE000)
	//r3 = AddressPR(channels)
	r8 = r1 + (DSP_mono - DSP_start)
	r8 = *r8
	r4 = 2
	r8 - 0
	if(eq) pcgoto MP3_wasstereo
	nop
	r4 = 1
MP3_wasstereo:
	//*r3 = r4
	 *(channels - RAM_start + 0xE000) = r4

	//*(pcm_offset - RAM_start + 0xE000) = r0						//clear pcm_offset
	r2 = r1 + (pcm_offset - DSP_start)
	*r2 = r0

	r2 = r1 + (DSP_freq_div - DSP_start)		//set freq_div and pcm_count
	r2 = *r2
	
	r5 = 8
	//*(freq_div - RAM_start + 0xE000) = r2
	r2 - 4
	if(eq) pcgoto pcmc_set
	nop
	r5 = 16
pcmc_set:
	//*(pcm_count - RAM_start + 0xE000) = r5
	r2 = r1 + (pcm_count - DSP_start)
	*r2 = r5

	r5 = r1 + (DSP_inbuf - DSP_start)
	r2 = *r5
	call AddressPR(getbits_init) (r18)
	
	nop
	r12 = r1 + (DSP_freq_idx - DSP_start)
	r12 = *r12
	r3 = r1 + (sfbands_tab - DSP_start)
	r12 = r12 << 2			//count longs
	r5 = r3 + r12
	r5 = *r5
	r6 = r1 + (sfbands_p - DSP_start)
	r5 = r5 + r3
	*r6 = r5
	r3 = r1 + (sfbandl_tab - DSP_start)
	r5 = r3 + r12
	r5 = *r5
	r6 = r1 + (sfbandl_p - DSP_start)
	r5 = r5 + r3
	*r6 = r5


	//get side info
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = channels -2 for loop counter      *
	//* r4 = number of channels                *
	//* r5 = side info struct ptr ptr          *
	//* r6 = bitpos, updated                   *
	//* r7 = current bs longword               *
	//* r8 = granule counter                   *
	//* r9 = scratch register                  *
	//* r10 = number of bits for getbits       *
	//* r11 = bits read by getbits             *
	//* r12 = side info struc ptr              *
	//* r13 = scratch register                 *
	//* r14 = scratch register                 *
	//* r15 = scratch register                 *
	//******************************************

	//on entry, r8 = mono flag, r4 = number of channels
	
	r5 = 3 + 9
	r10 = 5 + 9
	r8 - r0
	if(eq) r10 = r5	//r10 = mono?5:3 + 9
	call AddressPR(getbits0) (r18)
	nop
	
	//read scalefactor selection info
	r9 = r1 + (granule1_sfsi - DSP_start)
	r5 = 8-2
	r6 = 4-2
	r8 - r0
	if(eq) r6 = r5	//r6 = mono?4:8 pre-decremented
	
read_sfsi:
	call AddressPR(getbits0) (r18)
	r10 = 1
	*r9++ = r11
	if(r6-- >= 0) pcgoto read_sfsi
	nop

	//read granule side info
	r5 = r1 + (si_tab - DSP_start)
	r6 = 0			//bitpos
	r8 = 0			//granule_counter

read_grsi_loop_head:
	r3 = r4 - 2

read_grsi_loop:
	r12 = *r5++
	r9 = r1 + (si0 - DSP_start)
	r12 = r12 + r9		//r12 = pointer to si_struct

	call AddressPR(getbits0) (r18)
	r10 = 12
	*r12++ = r6			//si.grstart=bitpos
	r6 = r6 + r11
	*r12++ = r6		//si.grend=bitpos_new

	call AddressPR(getbits0) (r18)
	r10 = 9
	r11 = r11 + r11
	*r12++ = r11		//si.regionend2 = twice bits read
	r15 = r11			//save regionend2

	call AddressPR(getbits0) (r18)
	r10 = 8
	*r12++ = r11		//si.globalgain

	call AddressPR(getbits0) (r18)
	r10 = 4
	*r12++ = r11		//si.sfcompress

	call AddressPR(getbits0) (r18)
	r10 = 1
	r11 - r0
	if(eq) pcgoto read_grsi_block0
	nop

	call AddressPR(getbits0) (r18)
	r10 = 2
	*r12++ = r11		//si.blocktype

	call AddressPR(getbits0) (r18)
	r10 = 1
	*r12++ = r11		//si.mixedblock

	call AddressPR(getbits0) (r18)
	r10 = 5
	*r12++ = r11		//si.tabsel0

	call AddressPR(getbits0) (r18)
	r10 = 5
	*r12++ = r11		//si.tabsel1
	*r12++ = r0			//si.tabsel2

	r13 = 3-2
read_grsi_sbg_loop:
	call AddressPR(getbits0) (r18)
	r10 = 3
	r11 = r11 << 3		//*8
	if(r13-- >= 0) pcgoto(read_grsi_sbg_loop)
	*r12++ = r11		//si.subblockgain012 * 8

	r11 = 36
	*r12 = r11			//si.regionend0
	pcgoto read_grsi_block0e
	r13 = 576			//si.regionend1

read_grsi_block0:
	*r12++ = r0			//si.blocktype = 0
	*r12++ = r0			//si.mixedblock = 0

	r13 = 3-2
read_grsi_tabsel_loop:
	call AddressPR(getbits0) (r18)
	r10 = 5
	if(r13-- >= 0) pcgoto read_grsi_tabsel_loop
	*r12++ = r11		//si.tabsel012

	do 0,2
		*r12++ = r0		//si.subblockgain012

	call AddressPR(getbits0) (r18)
	r10 = 4
	r14 = r11
	r11 = r11 + 1	
	r13 = r1 + (sfbandl_p - DSP_start)
	r13 = *r13
	r11 = r11 << 2		//longs
	r11 = r11 + r13
	*r12 = a0 = *r11	//si.region0count

	call AddressPR(getbits0) (r18)
	r10 = 3
	r11 = r11 + 2
	r11 = r11 + r14
	r11 = r11 << 2
	r13 = r13 + r11
	r13 = *r13			//si.regionend1

read_grsi_block0e:
	r14 = *r12			//si.regionend0
	nop
	r14 - r15			//si.regionend0 - si.regionend2
	if(pl) r14 = r15
	*r12++ = r14		//si.regionend0 = min[end0, end2]
	r13 - r15
	if(pl) r13 = r15
	*r12++ = r13		//si.regionend1 = min[end1, end2]
	call AddressPR(getbits0) (r18)
	r10 = 1
	*r12++ = r11		//si.preflag
	call AddressPR(getbits0) (r18)
	r10 = 1
	r11 = r11 + 1
	*r12++ = r11		//si.sfshift + 1

	call AddressPR(getbits0) (r18)
	r10 = 1
	r10 = 33
	r11 - r0
	if(eq) r10 = r10 - 1
	

	if(r3-- >= 0) pcgoto read_grsi_loop			//channel loop
	*r12++ = r10		//si.tabsel3

	if(r8-- >= 0) pcgoto read_grsi_loop_head	//granule loop
	r5 = r1 + (si_tab - DSP_start) + 2*4		//si_tab+2 - second granule even if mono

	r4 = (DSP3210_RAM1 + DSP_codestart - RAM_start)		//jump to cache RAM
	goto r4
	nop

RAM_start:
reg_store:
	long 0, 0				//stack for registers
wait_routine:
	r4 = (ushort24) 0x8000	
	emr = (short) r4		//enable Int 1
wait_loop:
	r2 = r2 + 1
	*r1 = r2

	do 0, 2047				//killing time to allow for interrupt(s)
		r0 = r0 + r0		//while staying off the bus

	r2 = *r1
	pcgoto wait_loop
	nop


DSP_codestart:

	//decode 2 granules
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = channels -2 for loop counter      *
	//* r4 = number of channels                *
	//* r5 = side info struct ptr              *
	//* r6 = bitpos, updated                   *
	//* r7 = current bs longword               *
	//* r8 = granule counter                   *
	//* r9 = bitcount, b0                      *
	//* r10 = number of bits for getbits       *
	//* r11 = bits read by getbits             *
	//* r12 = side info struc ptr              *
	//* r13 = scratch register                 *
	//* r14 = scratch register                 *
	//* r15 = scratch register                 *
	//******************************************

	r5 = r1 + (si_tab - DSP_start)
	r9 = r1 + (granule0_sfsi - DSP_start)
	r8 = r0					//granule counter

decode_granule_loop:
	r3 = r1 + (si_granule_tab_p - DSP_start)
	*r3 = r5				//set granule si ptr
	r3 = r1 + (sfsi_p - DSP_start)
	*r3 = r9
	r3 = r1 + (granule_counter - DSP_start)
	*r3 = r8

	r3 = r1 + (scalefac0 - DSP_start)	//r3
	//r4 = AddressPR(channels)
	//r4 = *r4					//note this is 1 or 2
	r4 = *(channels - RAM_start + 0xE000)
	r6 = r1 + (xr0 - DSP_start)

	//at this point on first entry:
	//r5 = si_tab
	//r9 = granule0_sfsi
	//r8 = 0	//granule counter

	//si_granule_tab_p = si_tab
	//sfsi_p = granule0_sfsi
	//granule_counter = 0

	//r3 = scalefac0
	//r4 = number of channels
	//r6 = xr0

scale_channel_loop:
	r10 = r1 + (si_tab_p - DSP_start)
	*r10 = r5
	r10 = r1 + (xr_p - DSP_start)
	*r10 = r6
	//r10 = AddressPR(curr_chann)
	//*r10 = r4					//current channel
	*(curr_chann - RAM_start + 0xE000) = r4
	r10 = r1 + (scalefac_p - DSP_start)
	*r10 = r3

	//on first entry also now:
	//si_tab_p = si_tab
	//xr_p = xr0
	//curr_chann = number of channels
	//scalefac_p = scalefac0

	//move bitstream pointer to si.grstart
	//first move in words then use getbits to read past any remaining bits
	r2 = r1 + (DSP_inbuf - DSP_start)
	r2 = *r2
	r5 = *r5
	r15 = r1 + (si0 - DSP_start)
	r5 = r5 + r15				//r5 = si_struct
	r9 = *r5					//si.grstart
	r2 = r2 + 32				//magic 32 byte offset

	r10 = r9
	r10 = r10 >> 5
	r10 = r10 << 2
	r2 = r2 + r10
	call AddressPR(getbits_init) (r18)
	r9 = r9 & 0x1F

	r9 - r0
	if(eq) pcgoto no_read
	nop

	call AddressPR(getbits0) (r18)
	r10 = r9

no_read:
	//by here r5 = siN:grstart where N depends on where we are in si_tab
	r20 = *r5							//correct the bitcounter to s.grstart


//*****************************************************************************
//*** read scalefactors
//*****************************************************************************
	
	r6 = r5 + (sfcompress - si0)		//si.sfcompress n2 (r5 = r1)
	r6 = *r6
	
	r12 = r1 + (slentab0 - DSP_start)	//r2
	r13 = r1 + (newslen - DSP_start)	//r0
	r6 = r6 << 2				//longs

	r12 = r12 + r6
	r14 = *r12					//a
	r12 = r1 + (slentab1 - DSP_start)	//r2
	*r13++ = r14				//newslen0 = slentab0[si.sfcompress]
	*r13++ = r14				//newslen1 = slentab0[si.sfcompress]
	
	r12 = r12 + r6
	r14 = *r12					//a
	nop
	//r12 = blocktype - si0		//n1
	*r13++ = r14				//newslen2 = slentab1[si.sfcompress]
	*r13++ = r14				//newslen3 = slentab1[si.sfcompress]

	

	//select sfbtab
	r6 = r5 + (blocktype - si0)			//si.blocktype, a
	r6 = *r6
	nop
	r6 - 2
	if(ne) pcgoto read_sf_ne2
	r6 = r1 + (sfbtab0 - DSP_start)	//blocktype!=2?sftab0:..., r2

	//blocktype 2
	r12 = r5 + (mixedblock - si0)	//si.mixedblock	//n1
	r6 = r1 + (sfbtab1 - DSP_start)	//x0
	//r12 = r12 + r5				//si.mixedblock
	r12 = *r12
	r14 = r1 + (sfbtab2 - DSP_start)
	r12 - r0
	if(ne) r6 = r14				//r6=(si.mixedblock?sftab2:sfbtab1), r2

read_sf_ne2:
	//if(si.blocktype!=2) r6 = sfbtab0 elseif(si.mixedblock==0) r6 = sfbtab1 else r6 sfbtab2
	r5 = r1 + (sfsi_p - DSP_start)	//r1
	r5 = *r5					//initially, granul0_sfsi which are always 0
	r13 = r1 + (newslen - DSP_start)	//r0=newslen, r3=sfp (scalefac0/1)

	//read scalefactors
	r14 = 4 - 2
read_sf_loop0:
	r12 = *r6++					//sfb[i], x0
	r15 = *r6					//sfb[i+1], a
	r16 = *r5++					//sfsi[i], a
	r15 = r15 - r12				//n3 = sfb[i+1]-sfb[i]
	r17 = r15 - 2				//predec for loop
	r10 = *r13++				//newslen[i]
	r16 - r0
	if(ne) pcgoto read_sf_skip	//if(!sfsi[i])
	r15 = r15 << 2				//longs
	r19 = r10					//store number of bits
read_sf_loop1:
	r10 - r0
	if(eq) pcgoto read_sf_l1_eq
	r11 = r0					//if zero bits to read, store 0
	call AddressPR(getbits0) (r18)
	nop
read_sf_l1_eq:
	*r3++ = r11					//*sfp++ = getbits(newslen[i])
	if(r17-- >= 0) pcgoto read_sf_loop1
	r10 = r19					//reset bit count

	r3 = r3 - r15				//reduce sfp as it will get restored in a mo
read_sf_skip:
	if(r14-- >= 0) pcgoto read_sf_loop0
	r3 = r3 + r15				//else sfp+=sfb[i+1]-sfb[i]

	do 0, 2
		*r3++ = r0				//set final three to zero
	r17 = r1 + (sfsi_p - DSP_start)
	*r17 = r5					//save sfsi pointer


	//*****************************************************************************
	//*** read huffman
	//*****************************************************************************
	r3 = r1 + (si_tab_p - DSP_start)
	r3 = *r3					//r3 = si_tab+N
	r8 = r1 + (si0 - DSP_start)
	r3 = *r3
	r6 = r1 + (xr_p - DSP_start)
	r3 = r3 + r8				//r3 = si_struct, r1

	//read region0
	r6 = *r6					//r6 = xr (output), r3
	r8 = r3 + (regionend0 - si0)
	r8 = *r8					//r8 = si.regionend0
	r5 = r1 + (pow43tab - DSP_start)	//r5 = pow43tab, r4
	r9 = r3 + (tabsel0 - si0)
	r9 = *r9					//r9 = si.tabsel0
	r12 = r8
	r8 = r8 $>> 1				//asr - huff_count>>1, loop_count, n3
	if(le) pcgoto huff_readregion1
	nop
	call AddressPR(huff_region012) (r19)
	nop

	//read region1
huff_readregion1:
	r11 = r3 + (regionend1 - si0)
	r11 = *r11
	r9 = r3 + (tabsel1 - si0)
	r9 = *r9					//r9 = si.tabsel1
	r8 = r11 - r12
	r8 = r8 $>> 1				//loop_count, n3
	if(le) pcgoto huff_readregion2
	nop
	call AddressPR(huff_region012) (r19)
	nop

	//read region2
huff_readregion2:
	r8 = r3 + (regionend2 - si0)
	r8 = *r8
	r11 = r3 + (regionend1 - si0)
	r11 = *r11
	r9 = r3 + (tabsel2 - si0)
	r9 = *r9					//r9 = si.tabsel1
	r8 = r8 - r11
	r8 = r8 $>> 1				//loop_count, n3
	if(le) pcgoto huff_region012_end
	nop
	call AddressPR(huff_region012) (r19)
	nop
	pcgoto huff_region012_end
	nop

huff_region012:
	//r5 = pow43tab, r4; r6 = xr, r3
	//r8 = loop_count, n3; r9 = si.tabselN, n0; r3 = si.struct, r1
	r9 = r9 << 2				//longs
	r14 = r1 + (htablinbits - DSP_start)
	r14 = r14 + r9
	r14 = *r14					//r14 = linbits, n2
	r15 = r1 + (htabs - DSP_start)
huff_region012_loopstart:
	r16 = r15 + r9
	r16 = *r16
	nop
	r16 = r16 + r15				//r13 = htab, n5

huff_dec012_end:
	r13 = *r16++
	nop
	r13 - r0
	if(ge) pcgoto huff_next_step
	nop
	call AddressPR(getbits1) (r18)	//get 1 bit
	r13 = r13 << 2				//longs
	r11 - r0
	if(ne) r16 = r16 - r13		//tab-=v, (r0)-n0
	pcgoto huff_dec012_end
	nop
huff_next_step:
	r13 = r13 >> 4				//x=v>>4
	if(eq) pcgoto huff_r012_zero_0
	r16 = r16 - 4
	r13 - 15
	if(ne) pcgoto huff_r012_ne15_0
	nop
	r14 - r0					//linbits=0?
	if(eq) pcgoto huff_r012_skip_gbits
	r11 = r0
	call AddressPR(getbits0) (r18)
	r10 = r14					//getbits(linbits)
huff_r012_skip_gbits:
	r13 = r11 + 15				//+15
huff_r012_ne15_0:	
	r13 = r13 << 2				//convert r13 to longs
	r13 = r5 + r13
	
	call AddressPR(getbits1) (r18)	//get 1 bit
	a0 = *r13					//v=pow43tab[x]
	r11 - r0
	if(ne) pcgoto huff_r012_ne15_nv
	nop
	*r6++ = a0
	pcgoto huff_r012_z_0
	nop
huff_r012_ne15_nv:
	*r6++ = a0 = -a0			//if(getbit1) v=-v
	pcgoto huff_r012_z_0
	nop	
huff_r012_zero_0:
	*r6++ = r0 //float32(r13)		//xr[i+0]=v==0
huff_r012_z_0:
	r13 = *r16++
	nop
	r13 = r13 & 15				//r13 = y
	if(eq) pcgoto huff_r012_zero_1
	nop
	r13 - 15
	if(ne) pcgoto huff_r012_ne15_1
	nop
	r14 - r0					//ie r14-0
	if(eq) pcgoto huff_r012_skip_gbits_1
	r11 = r0					//ie r11=0
	call AddressPR(getbits0) (r18)
	r10 = r14					//getbits(linbits)
huff_r012_skip_gbits_1:
	r13 = r11 + 15
huff_r012_ne15_1:
	r13 = r13 << 2				//convert r16 to longs
	r13 = r5 + r13
	
	call AddressPR(getbits1) (r18)	//get 1 bit
	a0 = *r13					//v=pow43tab[x]
	r11 - r0
	if(ne) pcgoto huff_r012_ne151_nv
	nop
	*r6++ = a0
	pcgoto huff_loop012
	nop
huff_r012_ne151_nv:
	*r6++ = a0 = -a0			//if(getbit1) v=-v
	pcgoto huff_loop012
	nop	
huff_r012_zero_1:
	*r6++ = r0 //float32(r13)		//xr[i+1]=v
huff_loop012:
	r8 = r8 - 1
	if(gt) pcgoto huff_region012_loopstart
	nop
	return (r19)
	nop

huff_region012_end:
	
	//read region3
	//r5 = pow43tab, r4; !!r6 = xr, r3
	//r9 = si.tabsel3, n0; r3 = si.struct, r1
	//Free regs: r8, r12-17

	r8 = r3 + (regionend2 - si0)
	r8 = *r8					//si.regionend2, x0
	r11 = 576
	r9 = r3 + (tabsel3 - si0)
	r9 = *r9					//r9 = si.tabsel3, n0
	r12 = r3 + (grend - si0)
	r12 = *r12					//r12 = si.grend, x1
	r8 = r11 - r8
	if(le) pcgoto huff_region3_end
	r8 = r8 $>>2				//loop_count
	r9 = r9 << 2				//longs
	r15 = r1 + (htabs - DSP_start)
	r9 = r15 + r9
	r9 = *r9					//r15 = htab, n1
	nop
	r9 = r9 + r15
	r15 = 0x8000007F			//=-1f  should be 0x8000007F
	r4 = r9

huff_loop3:

	r12 - r20
	if(le) pcgoto huff_region3_end
	r9 = r4
	r17 = *r9++					//r17 = v = *tab++
	r10 = 1
	r17 = r17 << 2				//longs
	call AddressPR(getbits1) (r18)	//get a single bit
	r17 = r9 - r17
	r11 - r0
	if(ne) r9 = r17				//if(bit) tab-=v
	
huff_dec3:
	r17 = *r9++
	nop
	r17 = r17 << 2				//longs
	if(ge) pcgoto huff_dec3_end	//if(v>=0) return v
	r10 = 1
	call AddressPR(getbits1) (r18)
	r17 = r9 - r17
	r11 - r0
	if(ne) r9 = r17				//if(bit) tab -=v
	pcgoto huff_dec3
	nop

huff_dec3_end:
	r17 & (8*4)
	if(eq) pcgoto huff_r3_zero_3	//if(x=(v>>3)&1)
	r13 = 0							//preset 0
	call AddressPR(getbits1) (r18)
	//r10 = 1
	r13 = (short) 0x80				//will become (short) 0x80 = 1f
	r11 - r0
	if(ne) r13 = r15				//if(bit) x=-1	
huff_r3_zero_3:
	*r6++ = r13						//xr[i+0] = 0, 1, -1

	r17 & (4*4)
	if(eq) pcgoto huff_r3_zero_2	//if(x=(v>>2)&1)
	r13 = 0
	call AddressPR(getbits1) (r18)
	//r10 = 1
	r13 = (short) 0x80
	r11 - r0
	if(ne) r13 = r15
huff_r3_zero_2:
	*r6++ = r13						//xr[i+1]= 0, 1, -1
	
	r17 & (2*4)
	if(eq) pcgoto huff_r3_zero_1	//if(x=(v>>1)&1)
	r13 = 0
	call AddressPR(getbits1) (r18)
	//r10 = 1
	r13 = (short) 0x80
	r11 - r0
	if(ne) r13 = r15
huff_r3_zero_1:
	*r6++ = r13						//xr[i+2]=0, 1, -1


	r17 & (1*4)
	if(eq) pcgoto huff_r3_zero_0	//if(x=v&1)
	r13 = 0
	call AddressPR(getbits1) (r18)
	//r10 = 1
	r13 = (short) 0x80
	r11 - r0
	if(ne) r13 = r15
huff_r3_zero_0:
	*r6++ = r13						//xr[i+3]=0, 1, -1

	r8 = r8 - 1
	if(gt) pcgoto huff_loop3
	nop

huff_region3_end:
	//from now on we can use all registers again
	//because 'getbits' is no longer active (r2, r7, r10, r11)
	r2 = r1 + (xr_p - DSP_start)
	r2 = *r2
	r7 = r1 + (xr_zero_p - DSP_start)
	r2 = r2 + 576*4
	r2 = r2 - r6
	if(le) pcgoto huff_clear_loop
	*r7 = r6								//xr_zero_p points to first 0
	r2 = r2 >> 2							//count longs
	r2 = r2 - 1
	do	0, r2
		*r6++ = r0

huff_clear_loop:
//--INTENSITY STEREO-- find last non-zero sample
	r6 = r1 + (DSP_modext - DSP_start)
	r6 = *r6
	nop
	r6 & 1
	if(eq) pcgoto is_skip_zero				//skip if not intensity stereo
	nop
	//r6 = AddressPR(curr_chann)
	//r6 = *r6
	r6 = *(curr_chann - RAM_start + 0xE000)
	nop
	r6 - 2									//ie skip if doing 1st channel
	if(eq) pcgoto is_skip_zero
	r13 = r1 + (x_is_nonzero - DSP_start)
	r6 = r1 + (xr1 - DSP_start + 576*4 - 4)		//ie final entry in xr1
	r7 = 576*4
is_find_zero:
	r10 = *r6--
	r7 = r7 - 4
	r10 - r0
	if(eq) pcgoto is_find_zero
	nop
	r7 - r0
	if(mi) r7 = r0
	*r13 = r7								//count from 0 to last non-zero in xr1

is_skip_zero:

	//*****************************************************************************
	//*** scale samples
	//*****************************************************************************

	r2 = r1 + (si_tab_p - DSP_start)
	r2 = *r2								//r2 = si_struct, r1
	r5 = r1 + (si0 - DSP_start)
	r2 = *r2
	r6 = 13									//s_min=13 (blocktype!=2)
	r2 = r2 + r5
	
	//****** number of LONG and SHORT bands
	r3 = r2 + (blocktype - si0)
	r5 = *r3
	r7 = 22									//l_max=22 (blocktype!=2)
	r5 - 2
	if(ne) pcgoto scale_ne2
	nop

	r3 = r2 + (mixedblock - si0)
	r5 = *r3
	r6 = 3									//s_min=3 (mixedblock)
	r7 = 8									//l_max=8 (mixedblock)
	r5 - r0
	if(eq) r6 = r0							//s_min=0 (!mixedblock), n5
	r5 - r0
	if(eq) r7 = r0							//l_max=0 (!mixedblock)

scale_ne2:
	r3 = r2 + (globalgain - si0)
	r8 = *r3								//r8 = si.globalgain, n6
	r3 = r2 + (sfshift - si0)
	r9 = *r3								//r9 = si.sfshift (+1 = 1 or 2), n2
	r16 = r1 + (pretab - DSP_start)			//r16 = pretab, r4
	r17 = r1 + (scalefac_p - DSP_start)
	r17 = *r17								//r17 = sfp, r2
	r18 = r1 + (quantab - DSP_start)

	r10 = r1 + (xr_p - DSP_start)
	r10 = *r10								//r10 = xr, r0

	//****** scale LONG bands
	r7 - r0
	if(eq) pcgoto scale_l_loop0
	nop
	r11 = r2 + (preflag - si0)
	r11 = *r11								//r11 = preflag, n0
	r13 = r1 + (xr_zero_p - DSP_start)
	r13 = *r13								//r13 = xr_zero_p, n1, ptr to first non-entry
	r15 = r1 + (sfbandl_p - DSP_start)
	r15 = *r15								//r15 = sfbandl, r5

scale_l_loop0_head:
	r13 - r10
	if(le) pcgoto scale_l_loop0
	r14 = r0								//r14 = updated preflag
	r12 = *r16++
	r11 - r0
	if(ne) r14 = r12						//r14 = (preflag ? pretab[j] : 0)
	r12 = *r17++
	r2 = r10
	r12 = r12 + r14
	r12 = r12 << r9							//r12<<=shshift (1 or 2)
	r12 = r8 - r12							//r12=globalgain-r12
	if(mi) r12 = r0
	//convert to single precision
	r12 = r12 << 2							//convert to longs
	r14 = *r15++							//r14 = bil[j], x1
	r4  = *r15								//r4  = bil[j+1]
	
	r12 = r18 + r12							//quantab[globalgain - (sf+pre)<<shift]
	r4 = r4 - r14							//bil[j+1] - bil[j]
	r4 = r4 - 1

	//single precision
	//for(i=bil[j]; i<bil[j+1]; i++)
	do 0, r4
		*r2++ = a0 = *r10++ * *r12

scale_l_skip:
	r7 = r7 - 1
	if(gt) pcgoto scale_l_loop0_head
	nop

scale_l_loop0:

	//****** scale SHORT bands
	r16 = 13
	r16 = r16 - r6							//smashes pretab
	if(le) pcgoto scale_s_loop0
	nop
	r10 = r1 + (xr_p - DSP_start)
	r10 = *r10								//r10 = xr, r0
	r15 = r1 + (sfbands_p - DSP_start)
	r15 = *r15								//r15 = sfbands, r5
	r6 = r6 << 2							//longs
	r15 = r15 + r6							//r15+=smin=>&bis[s_min]
	r11 = *r15								//r11 = bis[s_min], n0
	r6 = r1 + (y_reorder - DSP_start)		//r6 = &reorder[0], n7
	r7 = r6									//r7 = &reorder[0], r4
	r19 = 3*4
	r11 = r11 << 2							//longs
	r5 = r1 + (xr_zero_p - DSP_start)
	r5 = *r5								//r5 = xr_zero_p, b
	r10 = r10 + r11							//r10 = &xr[bis[s_min]], r0
	
	//for(j=s_min; j<13; j++)
	//requires r1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 16
	//uses r4, 11, 12, 13, 14, 15, 17, 18, 19
scale_s_loop0_head:
	r5 - r10
	if(le) pcgoto scale_s_loop0
	r3 = r10
	r4 = *r15++								//r4 = bis[j], x1
	r14 = *r15								//r14 = bis[j+1]
	r11 = 3 - 2
	r14 = r14 - r4							//bis[j+1] - bis[j]
	//r14 divided by 3!!
	
	r14 = r14 - 1							//for do loop	
	r4 = r2 + (subblockgain0 - si0)			//si.subblockgain0, r6

	//for (k=0; k<3; k++)
scale_s_loop1_head:
	r12 = *r17++							//r17=scalefactor
	r13 = *r4++								//r13=si.subblockgain[k] *8
	r12 = r12 << r9							//r12<<=shshift (1 or 2)
	r6 = r7									//reset r6
	r12 = r12 + r13							//r12+=sbg
	r12 = r8 - r12							//r12=globalgain-r12
	if(mi) r12 = r0
	r12 = r12 << 2							//convert to longs
	r12 = r18 + r12							//quantab[globalgain - sf<<shift -sbg]

	//for(i=bis[j]; i<bis[j+1]; i+=3)
	do 0, r14
		*r6++r19 = a0 = *r10++ * *r12
	
	if(r11-- >= 0) pcgoto scale_s_loop1_head
	r7 = r7 + 4

	r7 = r1 + (y_reorder - DSP_start)		//r7 = &reorder[0], r4
	r10 = r3								//reset r10 to &xr[bis[j]]
	
	r13 = r14 + r14							//r14 is predecremented
	r13 = r13 + r14							//3*r14
	r13 = r13 + 2							//-1*3 + 2 = -1 for do loop
	do 0, r13
		*r10++ = a0 = *r7++					//copy reorder back to xr

scale_s_skip:
	r16 = r16 - 1
	if(gt) pcgoto scale_s_loop0_head
	r7 = r1 + (y_reorder - DSP_start)		//r7 = &reorder[0], r4

scale_s_loop0:

	//// channel loop end
	r10 = r1 + (si_tab_p - DSP_start)
	r5 = *r10
	r3 = r1 + (scalefac1 - DSP_start)		//r3
	
	//r10 = AddressPR(curr_chann)
	//r4 = *r10								//current channel
	r4 = *(curr_chann - RAM_start + 0xE000)
	r6 = r1 + (xr1 - DSP_start)
	r4 = r4 - 1
	if(ne) pcgoto scale_channel_loop		
	r5 = r5 + 4
	

	//*****************************************************************************
	//*** joint-stereo processing
	//*****************************************************************************
	//IGNORED FOR NOW!

	//*****************************************************************************
	//*** hybrid filter
	//*****************************************************************************

	//antialias
	//Apply the antialiasing butterflies on a granule
	//inputs MPEGAUD_FRACT_TYPE *xr, INT16 sblimit

	r4 = r1 + (xr0 - DSP_start)				//r4 = xrN[0]
	r13 = r1 + (si_granule_tab_p - DSP_start)
	r13 = *r13
	r15 = *(channels - RAM_start + 0xE000)
	r11 = r1 + (blocktyp - DSP_start)

antialias_channel_loop:				
	r5 = r1 + (si0 - DSP_start)
	r2 = *r13
	r6 = 32									//sblimit=32 (blocktype!=2)
	r2 = r2 + r5							//r2 pts to si struct
	
	r3 = r2 + (blocktype - si0)
	r5 = *r3
	*r11++ = a0 = *r3						//store blocktype for IMDCT
	r5 - 2
	if(ne) pcgoto hybrid_block_ne2
	r7 = 0
	r3 = r2 + (mixedblock - si0)
	r5 = *r3
	r6 = 2									//sblimit=2 (blocktype==2, mixedblock==1)
	r5 - r0
	if(eq) r6 = r7							//sblimit=0 (blocktype==2, mixedblock==0)

hybrid_block_ne2:
	*r11++ = r6								//store sblimit for IMDCT
	r6 = r6 - 1
	if(lt) pcgoto antialias2
	r5 = 18*4 - 1*4			//i = SSLIMIT - 1

antialias1:
	r9 = AddressPR(csi)
	r10 = AddressPR(cai)
	r8 = r4 + r5			//xr[i] = bu
	r7 = r8 + 1*4			//bd
	r5 = r5 + 18*4			//i += SSLIMIT

	do 6,7		//do 7 instructions 8 times	
		a1 = *r8				//bu
		a2 = *r7				//bd
		nop
		a0 = a1 * *r9			//bu * csi
		a3 = a1 * *r10			//bu * cai
		*r8-- = a0 = a0 - a2 * *r10++	//bu-- = bu * csi - bd * cai++
		*r7++ = a0 = a3 + a2 * *r9++	//bd++ = bu * cai + bd * csi++

	r6 = r6 - 1
	if(gt) pcgoto antialias1
	nop
antialias2:
	
	r4 = r1 + (xr1 - DSP_start)				//xr1
	r15 = r15 - 1
	if(ne) pcgoto antialias_channel_loop		
	r13 = r13 + 4								//next si ptr
antialias_end:

//at this point xr0 and xr1 are antialiased for both channels

//IMDCT
MPEGIMDCT_hybrid:
	//main entry point for IMDCT
	//note that parameters are slightly different to the C version (but match the 060 version)
	//inputs: 
	//r17 float* in array
	//r2 float* out array
	//r4 float* prev block
	//block/mixed/sb_max parameters

	//r4 = AddressPR(pcm_offset)
	r4 = r1 + (pcm_offset - DSP_start)
	//r6 = AddressPR(pcm_store)
	r6 = r1 + (pcm_store - DSP_start)
	*r6 = a0 = *r4					//save pcm_offset to reset for second channel

	//r6 = AddressPR(channels)		//1 or 2
	//r4 = AddressPR(curr_chann)
	//*r4 = r0						//curr_chann = 0 to begin with
	
	r17 = r1 + (xr0 - DSP_start)	//input -> update for channel 1
	*(curr_chann - RAM_start + 0xE000) = r0	//curr_chann = 0 to begin with
	r6 = r1 + (blocktyp - DSP_start)	//blocktype and sbmax
	r4 = r1 + (prev0 - DSP_start)	//prev0

	//channel loopstart here
IMDCT_channel_loop:
	r21 = AddressPR(temp_stack)
	r2 = r1 + (decoder_fraction - DSP_start)	//output

	r7 = *r6++			//blocktype
	r6 = *r6			//sblimit
	r5 = r0				//sb

	r6 - 2
	if(ne) pcgoto MPEGIMDF_imd0	//jump if not mixed block
	nop
	//mixed block (long block, win = 0)
	call AddressPR(imdct_l) (r19)
	r3 = AddressPR(imdct_e_win0)
	//r3 = r1 + (imdct_e_win0 - DSP_start)
	
	r17 = r17 + 18*4			//in += SSLIMIT
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE
		
	call AddressPR(imdct_l) (r19)
	//r3 = AddressPR(imdct_o_win0)
	r3 = r1 + (imdct_o_win0 - DSP_start)

	r17 = r17 + 18*4			//in += SSLIMIT
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE
	//drop into shorts

MPEGIMDF_imd0:
	r6 - 32
	if(eq) pcgoto MPEGIMDF_imd5	//long blocks only
	nop
MPEGIMDF_imd1:
	//short blocks
	r6 = 32 - r6				//ie 30 short blocks remaining if mixed, o/w 32
MPEGIMDF_imd1a:	
	call AddressPR(imdct_s) (r19)
	r3 = AddressPR(imdct_e_win2)
	//r3 = r1 + (imdct_e_win2 - DSP_start)
	
	
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE
	r17 = r17 + 18*4			//in += SSLIMIT
		
	call AddressPR(imdct_s) (r19)
	//r3 = AddressPR(imdct_o_win2)
	r3 = r1 + (imdct_o_win2 - DSP_start)
	
	
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE
	r17 = r17 + 18*4			//in += SSLIMIT

	r5 = r5 + 2
	r5 - r6						//sb vs sbmax
	if(lt) pcgoto MPEGIMDF_imd1a
	nop
	pcgoto MPEGIMDF_imd9
	nop

MPEGIMDF_imd5:
	//long blocks, r7 = block_type on entry
	r7 = r7 << 2				//measure in longs
	//r3 = AddressPR(imdct_e_win)
	r3 = r1 + (imdct_e_win - DSP_start)
	r3 = r3 + r7				//offset into table
	r10 = *r3
	r3 = AddressPR(imdct_e_win0)
	//r3 = r1 + (imdct_e_win0 - DSP_start)
	r3 = r3 + r10				//even window ptr based on block type
	//r8 = AddressPR(imdct_o_win0)
	r8 = r1 + (imdct_o_win0 - DSP_start)
	r8 = r8 + r10				//odd window ptr based on block type

MPEGIMDF_imd5a:
	call AddressPR(imdct_l) (r19)
	*r21++ = r8					//stack odd window ptr (even autostacked)

	r21 = r21 - 4
	r8 = *r21					//restore odd win ptr

	r17 = r17 + 18*4				//in += SSLIMIT
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE

	*r21++ = r3					//stack even win ptr
	call AddressPR(imdct_l) (r19)
	r3 = r8						//activate odd win ptr

	r8 = r3						//restore odd ptr
	r21 = r21 - 4
	r3 = *r21					//restore even ptr

	r17 = r17 + 18*4			//in += SSLIMIT
	r4 = r4 + 18*4				//prev += SSLIMIT
	r2 = r2 + 4					//out += DSIZE
	r5 = r5 + 2
	r5 - r6						//sb vs sbmax
	if(lt) pcgoto MPEGIMDF_imd5a
	nop

MPEGIMDF_imd9:
	r15 = 32*4
MPEGIMDF_imd91:
	r5 - 32				//test sb against SBLIMIT
	if(ge) pcgoto MPEGIMDF_imde
	nop
	//this lot shouldn't be necessary
	//r10 = AddressPR(zero)
	do 1,17				//loop 2 instrs 18 times
		*r2++r15 = a0 = *r4	//out[32N] = prev[N]
		*r4++ = a1 = a2 - a2	//*r10	//prev[N]=0

	r2 = r2 + 4			//out++
	pcgoto MPEGIMDF_imd91
	r5 = r5 + 1

MPEGIMDF_imde:
	//now call synthesis 18 times before looping for channel, then granule
	//r10 = AddressPR(curr_chann)
	//r10 = *r10
	r10 = *(curr_chann - RAM_start + 0xE000)
	r14 = r1 + (DSP_outbuffer0 - DSP_start)
	r15 = r1 + (DSP_outbuffer1 - DSP_start)
	r10 - r0
	if(ne) r14 = r15				//ptr switch if curr_chan==1
	
	r10 = 0
synthesis_loop:
	*r21++ = r14
	*r21++ = r10
	r4 = r1 + (decoder_fraction - DSP_start)
	r10 = r10 << (5+2)				//gr * MPA_SBLIMIT * 4 (float)
	//r3 = AddressPR(fraction_ptr)
	r3 = r1 + (fraction_ptr - DSP_start)
	r4 = r4 + r10					//mps->fraction[0][gr][0]
	*r3++ = r4						//set ptr to input, curr_chann already set
	//r3 = r3 + 8						//pt to pcm_out
	//r5 = AddressPR(pcm_offset)
	//r5 = *r5
	//r5 = *(pcm_offset - RAM_start + 0xE000)
	r5 = r1 + (pcm_offset - DSP_start)
	r5 = *r5
	r4 = *r14
	r5 = r5 << 1					//int16
	r4 = r4 + r5					//&pcm[0][pcm_offset]
	call AddressPR(MPEGSUBF_filter_band) (r19)
	*r3 = r4

	//r5 = AddressPR(pcm_offset)
	r5 = r1 + (pcm_offset - DSP_start)
	r4 = *r5						//r4 = pcm_offset
	//r2 = AddressPR(pcm_count)
	//r2 = *r2						//r2 = pcm_count
	//r2 = *(pcm_count - RAM_start + 0xE000)
	r2 = r1 + (pcm_count - DSP_start)
	r2 = *r2
	nop
	r4 = r4 + r2					//r4 = pcm_offset+=pcm_count
	*r5 = r4
	
	r21 = r21 - 4
	r10 = *r21--
	r14 = *r21
	r10 = r10 + 1
	r10 - 18
	if(ne) pcgoto synthesis_loop
	nop

synthesis_return:
	//if there is a second channel to process then...
	//r1 = AddressPR(DSP_data_address)		//can guarantee r1
	//r1 = *r1
	r1 = *(DSP_data_address - RAM_start + 0xE000)

	//r4 = AddressPR(channels)
	//r4 = *r4
	r4 = *(channels - RAM_start + 0xE000)
	r6 = AddressPR(curr_chann)
	r4 - 1
	if(eq) pcgoto granule_loop_end	//exit if mono ###check forcemono too?
	nop
	r4 = *r6						//current channel
	r17 = r1 + (xr1 - DSP_start)	//input -> update for channel 1
	r4 = r4 + 1
	r4 - 2
	if(ge) pcgoto granule_loop_end
	//pcgoto granule_loop_end
	*r6 = r4						//save curr_chan = 1
	//r4 = AddressPR(pcm_offset)
	r4 = r1 + (pcm_offset - DSP_start)
	//r6 = AddressPR(pcm_store)
	r6 = r1 + (pcm_store - DSP_start)
	*r4 = a0 = *r6					//restore pcm_offset for second channel
	r6 = r1 + (blocktyp - DSP_start + 8)	//blocktyp[1], sbmax[1]
	pcgoto IMDCT_channel_loop		//and loop
	r4 = r1 + (prev1 - DSP_start)	//prev1

	//// granule loop end
granule_loop_end:
	r3 = r1 + (granule_counter - DSP_start)
	r5 = r1 + (si_tab - DSP_start + 8)		//second granule
	r8 = *r3
	r9 = r1 + (granule1_sfsi - DSP_start)
	r8 - r0
	if(eq) pcgoto decode_granule_loop
	r8 = r8 + 1

	r3 = r1 + (DSP_status - DSP_start)
	r2 = DSP3210_READY
	*r3 = r2				//mark DSP as finished

	r1 = *0xE000
	r2 = *0xE004				//unstack registers used in waitloop

	r4 = (ushort24) 0x8000
	emr = (short) r4		//enable Int 1
	ireturn
	nop						//technically, not needed


imdct_l:
	//IMDCT for long blocks
				
	//r1 = input array *float
	//r2 = output array *float
	//r3 = window array *float
	//r4 = prev block *float

	*r21 = r6

	r7 = r17 + 17*4		//in[17]
	r6 = r17 + 16*4		//in[16]
	do 0,16
		*r7-- = a0 = *r7 + *r6--


	r15 = (short) -2*4
	r7 = r17 + 17*4		//in[17]
	r6 = r17 + 15*4		//in[15]
	do 0,7
		*r7++r15 = a0 = *r7 + *r6++r15		//in[17]+=in[15]
		
	r6 = AddressPR(ta33)
	//r6 = r1 + (ta33 - DSP_start)
	r7 = r17 + 6*4		//in[6]
	r15 = 6*4
	r16 = (short) -5*4
	r8 = AddressPR(c3)
	//r8 = r1 + (c3 - DSP_start)
	*r6++ = a0 = *r8++ * *r7++r15		//ta33 = c[3] x in[6]
	*r6++ = a0 = *r8-- * *r7++r16		//ta66 = c[6] x in[12]
	*r6++ = a0 = *r8++ * *r7++r15		//tb33 = c[3] x in[7]
	*r6++ = a0 = *r8-- * *r7			//tb66 = c[6] x in[13]

	//step 1
		
	r7 = AddressPR(tmp1a)
	//r7 = r1 + (tmp1a - DSP_start)
	r6 = AddressPR(ta33)
	//r6 = r1 + (ta33 - DSP_start)

	r8 = AddressPR(c1)
	//r8 = r1 + (c1 - DSP_start)
	r9 = r17 + 1*2*4
	r10 = r17 + (1*2+1)*4
	r15 = 4*2*4
	r16 = 2*4
	a0 = *r6++r16						//ta33
	a1 = *r6--							//tb33
	a0 = a0 + *r9++r15 * *r8			//+ in[2] x c1
	a1 = a1 + *r10++r15 * *r8++			//+ in[3] x c1
	r15 = 2*2*4
	a0 =  a0 + *r9++r15 * *r8			//+ in[10] x c5
	a1 =  a1 + *r10++r15 * *r8++		//+ in[11] x c5
	*r7++ = a0 =  a0 + *r9 * *r8		//+ in[14] x c7 ->tmp1a
	*r7++ = a1 =  a1 + *r10 * *r8		//+ in[15] x c7 ->tmp1b

	r8 = AddressPR(c2)
	//r8 = r1 + (c2 - DSP_start)
	r9 = r17
	r10 = r17 + 1*4
	r15 = 2*2*4
	a0 = *r6++r16 + *r9++r15			//ta66 + in[0]
	a1 = *r6      + *r10++r15			//tb66 + in[1]
	a0 = a0 + *r9++r15 * *r8			//+in[4] x c2
	a1 = a1 + *r10++r15 * *r8++			//+in[5] x c2
	r15 = 4*2*4
	a0 = a0 + *r9++r15 * *r8			//+in[8] x c4
	a1 = a1 + *r10++r15 * *r8++			//+in[9] x c4
	*r7++ = a0 = a0 + *r9 * *r8			//+in[16] x c8
	*r7   = a1 = a1 + *r10 * *r8		//+in[17] x c8


	r9 = AddressPR(cost36_0)
	//r9 = r1 + (cost36_0 - DSP_start)
	call AddressPR(ST1) (r18)
	r10 = r0							//0*4

	r9 = AddressPR(cost36_8)
	//r9 = r1 + (cost36_8 - DSP_start)
	call AddressPR(ST2) (r18)
	r10 = 8*4

	//step 2
		
	r7 = AddressPR(tmp1a)
	//r7 = r1 + (tmp1a - DSP_start)
	r8 = AddressPR(c3)
	//r8 = r1 + (c3 - DSP_start)
	r9 = r17 + 1*2*4
	r10 = r17 + (1*2+1)*4
	r15 = 4*2*4

	a0 = *r9++r15 * *r8					//a0 = I0(1) * const
	a1 = *r10++r15 * *r8
	r15 = 2*2*4
	a0 = a0 - *r9++r15 * *r8			//a0 = [I0(1)-I0(5)] * const
	a1 = a1 - *r10++r15 * *r8
	r15 = (short) -5*2*4
	*r7++ = a0 = a0 - *r9++r15 * *r8	//a0 = [I0(1)-I0(5)-I0(7)] * const
	*r7++ = a1 = a1 - *r10++r15 * *r8++

	r15 = 2*2*4
	a0 = *r9++r15 * *r8					//a0 = I0(2) * const
	a1 = *r10++r15 * *r8
	r15 = 4*2*4
	a0 = a0 - *r9++r15 * *r8			//a0 = [I0(2)-I0(4)] * const
	a1 = a1 - *r10++r15 * *r8
	r15 = (short) -8*2*4
	a0 = a0 - *r9++r15 * *r8			//a0 = [I0(2)-I0(4)-I0(8)] * const
	a1 = a1 - *r10++r15 * *r8
	r15 = 6*2*4

	a0 = a0 + *r9++r15					//a0 = [I0(2)-I0(4)-I0(8)] * const + I0[0]
	a1 = a1 + *r10++r15

	*r7++ = a0 = a0 - *r9				//a0 = [I0(2)-I0(4)-I0(8)] * const + I0[0]-I0[6]
	*r7 = a1 = a1 - *r10

	r9 = AddressPR(cost36_1)
	//r9 = r1 + (cost36_1 - DSP_start)
	call AddressPR(ST1) (r18)
	r10 = 1*4

	r9 = AddressPR(cost36_7)
	//r9 = r1 + (cost36_7 - DSP_start)
	call AddressPR(ST2) (r18)
	r10 = 7*4
		
	//step 3
	r6 = AddressPR(ta33)
	//r6 = r1 + (ta33 - DSP_start)
	r7 = AddressPR(tmp1a)
	//r7 = r1 + (tmp1a - DSP_start)

	r8 = AddressPR(c5)
	//r8 = r1 + (c5 - DSP_start)
	r9 = r17 + 1*2*4
	r10 = r17 + (1*2+1)*4
	r15 = 4*2*4
	r16 = 2*4
	r18 = (short) -2*4
	a0 = -*r6++r16						//-ta33
	a1 = -*r6--							//-tb33
	a0 = a0 + *r9++r15 * *r8			//+ in[2] x c5
	a1 = a1 + *r10++r15 * *r8++			//+ in[3] x c5
	r15 = 2*2*4
	a0 =  a0 - *r9++r15 * *r8			//- in[10] x c7
	a1 =  a1 - *r10++r15 * *r8++r18		//- in[11] x c7
	r15 = (short) -7*2*4
	*r7++ = a0 =  a0 + *r9++r15 * *r8	//+ in[14] x c1 ->tmp1a
	*r7++ = a1 =  a1 + *r10++r15 * *r8	//+ in[15] x c1 ->tmp1b

	r8 = AddressPR(c8)
	//r8 = r1 + (c8 - DSP_start)
	r15 = 2*2*4
	a0 = *r6++r16 + *r9++r15			//ta66 + in[0]
	a1 = *r6      + *r10++r15			//tb66 + in[1]
	a0 = a0 - *r9++r15  * *r8			//-in[4] x c8
	a1 = a1 - *r10++r15 * *r8++r18		//-in[5] x c8
	r15 = 4*2*4
	a0 = a0 - *r9++r15  * *r8			//-in[8] x c2
	a1 = a1 - *r10++r15 * *r8++			//-in[9] x c2
	*r7++ = a0 = a0 + *r9  * *r8		//+in[16] x c4
	*r7   = a1 = a1 + *r10 * *r8		//+in[17] x c4

	r9 = AddressPR(cost36_2)
	//r9 = r1 + (cost36_2 - DSP_start)
	call AddressPR(ST1) (r18)
	r10 = 2*4

	r9 = AddressPR(cost36_6)
	//r9= r1 + (cost36_6 - DSP_start)
	call AddressPR(ST2) (r18)
	r10 = 6*4

	//step 4
	r6 = AddressPR(ta33)
	//r6 = r1 + (ta33 - DSP_start)
	r7 = AddressPR(tmp1a)
	//r7 = r1 + (tmp1a - DSP_start)

	r8 = AddressPR(c7)
	//r8 = r1 + (c7 - DSP_start)
	r9 = r17 + 1*2*4
	r10 = r17 + (1*2+1)*4
	r15 = 4*2*4
	r16 = 2*4
	r18 = (short) -2*4
	a0 = -*r6++r16						//-ta33
	a1 = -*r6--							//-tb33
	a0 = a0 + *r9++r15  * *r8			//+ in[2] x c7
	a1 = a1 + *r10++r15 * *r8++r18		//+ in[3] x c7
	r15 = 2*2*4
	a0 =  a0 + *r9++r15  * *r8			//+ in[10] x c1
	a1 =  a1 + *r10++r15 * *r8++		//+ in[11] x c1
	r15 = (short) -7*2*4
	*r7++ = a0 =  a0 - *r9++r15  * *r8	//- in[14] x c5 ->tmp1a
	*r7++ = a1 =  a1 - *r10++r15 * *r8	//- in[15] x c5 ->tmp1b

	r8 = AddressPR(c4)
	//r8 = r1 + (c4 - DSP_start)
	r15 = 2*2*4
	a0 = *r6++r16 + *r9++r15			//ta66 + in[0]
	a1 = *r6      + *r10++r15			//tb66 + in[1]
	a0 = a0 - *r9++r15  * *r8			//-in[4] x c4
	a1 = a1 - *r10++r15 * *r8++			//-in[5] x c4
	r15 = 4*2*4
	a0 = a0 + *r9++r15  * *r8			//+in[4] x c8
	a1 = a1 + *r10++r15 * *r8++r18		//+in[5] x c8
	*r7++ = a0 = a0 - *r9  * *r8		//-in[8] x c2
	*r7   = a1 = a1 - *r10 * *r8		//-in[9] x c2

	r9 = AddressPR(cost36_3)
	//r9 = r1 + (cost36_3 - DSP_start)
	call AddressPR(ST1) (r18)
	r10 = 3*4

	r9 = AddressPR(cost36_5)
	//r9 = r1 + (cost36_5 - DSP_start)
	call AddressPR(ST2) (r18)
	r10 = 5*4

	//step 5
	r9  = r17 + 0*2*4
	r10 = r17 + (0*2+1)*4
	r15 = 2*2*4

	a0 = *r9++r15						//I0[0]
	a1 = *r10++r15
	a0 = a0 - *r9++r15					//I0[0]-I0[2]
	a1 = a1 - *r10++r15
	a0 = a0 + *r9++r15					//I0[0]-I0[2]+I0[4]
	a1 = a1 + *r10++r15
	a0 = a0 - *r9++r15					//I0[0]-I0[2]+I0[4]-I0[6]
	a1 = a1 - *r10++r15
	a1 = a1 + *r10++r15					//promoted to avoid multiplier latency
	a0 = a0 + *r9++r15					//I0[0]-I0[2]+I0[4]-I0[6]+I0[8]

	r9 = AddressPR(cost36_4)
	//r9 = r1 + (cost36_4 - DSP_start)
	a1 = a1 * *r9

	call AddressPR(ST_PAIR) (r18)
	r10 = 4*4

	return (r19)
	r6 = *r21

ST1:	
	//inputs: r9 ptr to const, r10 = const*4
	//r2 = output, r3 = window, r4 = prev
	//smashes r7, r8, r11, r12, r13, r14, r17, r18, a0, a1, a2, a3
	//return addr r18
	
	//r7 = r1 + (tmp1a - DSP_start + 4)
	//r8 = r1 + (tmp2a - DSP_start + 4)
	r7 = AddressPR(tmp1b)
	r8 = AddressPR(tmp2b)
	a1 = *r7-- + *r8--					//sum0 = tmp1a + tmp2a
	a0 = *r7   + *r8 
	pcgoto ST_PAIR
	a1 = a1 * *r9						//sum1 = (tmp1b + tmp2b) *const

ST2:	
	//inputs: r9 ptr to const, r10 = const*4
	//r2 = output, r3 = window, r4 = prev
	//smashes r7, r8, r11, r12, r13, r14, r18, a0, a1, a2, a3
	//return addr r18
	
	//r7 = r1 + (tmp1a - DSP_start + 4)
	//r8 = r1 + (tmp2a - DSP_start + 4)
	r7 = AddressPR(tmp1b)
	r8 = AddressPR(tmp2b)
	a1 = *r8-- - *r7--	
	a0 = *r8   - *r7  					//sum0 = tmp2a - tmp1a
	nop
	a1 = a1 * *r9						//sum1 = (tmp2b - tmp1b) *const
	

ST_PAIR:
	//inputs: a0 = sum0, a1 = sum1, r10 = const*4
	//r2 = output, r3 = window, r4 = prev
	//smashes r11, r12, r13, r14, a0, a2, a3
	//return addr r19

	a2 = a1 + a0						//tmp = sum0 + sum1
	a0 = -a1 + a0						//sum0 - sum1 - this way round to avoid latency
	r11 = 8*4
	r11 = r11 - r10						//offset = (8-v)*4

	r12 = r3 + r11						//win+offset
	r13 = r4 + r11						//prev+offset
	r11 = r11 << 5						//offset*32
	r14 = r2 + r11						//ts+offset*32
	*r14 = a3 = *r13 + a0 * *r12		//ts[offset*32] = prev[offset] + win[offset] x sum0
		
	r12 = r3 + 26*4 
	r12 = r12 - r10						//offset = (26-v)*4
	*r13 = a3 = a2 * *r12				//prev[offset] = tmp x win[offset]

	r11 = r10 + 9*4						//(9+v)*4

	r12 = r3 + r11						//win+offset
	r13 = r4 + r11						//prev+offset
	r11 = r11 << 5						//offset*32
	r14 = r2 + r11						//ts+offset*32
	*r14 = a3 = *r13 + a0 * *r12		//ts[offset*32] = prev[offset] + win[offset] x sum0
		
	r12 = r3 + 27*4 
	r12 = r12 + r10						//offset = (27+v)*4
	return (r18)	
	*r13 = a3 = a2 * *r12				//prev[offset] = tmp x win[offset]


imdct_s:
	//IMDCT for short blocks
				
	//r17 = input array *float
	//r2 = output array *float
	//r3 = window array *float
	//r4 = prev block *float

	*r21++ = r17	//stack inputs
	*r21   = r6

	r6 = r2
	r7 = r4
	r15 = 32*4
	do 0,5
		*r6++r15 = a0 = *r7++		//ts[N*32]=prev[N] for N=0 to 5

	//STEP 1
	call AddressPR(DCT12_PART1) (r18)
	nop

	r6 = r2 + 16*32*4		//ts[16*SBLIMIT]
	r7 = r3 + 10*4			//win[10]
	r8 = r4 + 16*4			//prev[16]
	r15 = (short) -3*32*4
	r16 = (short) -3*4

	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[16*SBLIMIT] = prev[16] + WIN_MULT(tmp0,10)
	r15 = (short) -6*32*4
	r16 = (short) -6*4
	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[13*SBLIMIT] = prev[13] + WIN_MULT(tmp0,7)
	r15 = 3*32*4
	r16 = 3*4
	*r6++r15 = a2 = *r8++r16 + a1 * *r7++r16	//ts[7*SBLIMIT]  = prev[7]  + WIN_MULT(tmp1,1)
	*r6      = a2 = *r8      + a1 * *r7     	//ts[10*SBLIMIT] = prev[10] + WIN_MULT(tmp1,4)

	call AddressPR(DCT12_PART2) (r18)
	nop

	//2*nop
	//r6 = AddressPR(in2)
	r6 = r1 + (in2 - DSP_start)
	a0 = *r6--				//in2
	a1 = *r6				//in3

	r6 = r2 + 17*32*4		//ts[17*SBLIMIT]
	r7 = r3 + 11*4			//win[11]
	r8 = r4 + 17*4			//prev[17]
	r15 = (short) -5*32*4
	r16 = (short) -5*4

	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[17*SBLIMIT] = prev[17] + WIN_MULT(in2,11)
	r15 = 2*32*4
	r16 = 2*4
	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[12*SBLIMIT] = prev[12] + WIN_MULT(in2,6)
	r15 = 1*32*4
	*r6++r15 = a2 = *r8++    + a1 * *r7++   	//ts[14*SBLIMIT] = prev[14] + WIN_MULT(in3,8)
	*r6      = a2 = *r8      + a1 * *r7     	//ts[15*SBLIMIT] = prev[15] + WIN_MULT(in3,9)

	//r6 = AddressPR(in0)
	r6 = r1 + (in0 - DSP_start)
	a0 = *r6				//in0
	//r6 = AddressPR(in4)
	r6 = r1 + (in4 - DSP_start)
	a1 = *r6				//in4

	r6 = r2 + 6*32*4		//ts[6*SBLIMIT]
	r7 = r3 + 0*4			//win[0]
	r8 = r4 + 6*4			//prev[6]
	r15 = 5*32*4
	r16 = 5*4

	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[6*SBLIMIT]  = prev[6]  + WIN_MULT(in0,0)
	r15 = (short) -3*32*4
	r16 = (short) -3*4
	*r6++r15 = a2 = *r8++r16 + a0 * *r7++r16	//ts[11*SBLIMIT] = prev[11] + WIN_MULT(in0,5)
	r15 = 1*32*4
	*r6++r15 = a2 = *r8++    + a1 * *r7++   	//ts[8*SBLIMIT]  = prev[8]  + WIN_MULT(in4,2)
	*r6      = a2 = *r8      + a1 * *r7     	//ts[9*SBLIMIT]  = prev[9]  + WIN_MULT(in4,3)

	//STEP 2
	r17 = r17 + 4				//line 305

	call AddressPR(DCT12_PART1) (r18)
	nop

	r6 = r2 + 13*32*4		//ts[13*SBLIMIT]
	r7 = r3 + 10*4			//win[10]
	r8 = r4 + 4*4			//prev[4]
	r15 = 3*32*4
	r16 = (short) -3*4

	*r8++r16 = a2 = a0 * *r7++r16		//prev[4] = WIN_MULT(tmp0,10)
	r16 = (short) -6*4
	*r8      = a2 = a0 * *r7++r16		//prev[1] = WIN_MULT(tmp0,7)
	r16 = 3*4
	*r6++r15 = a2 = *r6 + a1 * *r7++r16	//ts[13*SBLIMIT] += WIN_MULT(tmp1,1) 
	*r6      = a2 = *r6 + a1 * *r7     	//ts[16*SBLIMIT] += WIN_MULT(tmp1,4) 

	call AddressPR(DCT12_PART2) (r18)	//line 325
	nop

	//2*nop
	//r6 = AddressPR(in2)
	r6 = r1 + (in2 - DSP_start)
	a0 = *r6--				//in2
	a1 = *r6				//in3

	r7 = r3 + 11*4			//win[11]
	r8 = r4 + 5*4			//prev[5]
	r16 = (short) -5*4

	*r8++r16 = a2 = a0 * *r7++r16	//prev[5] = WIN_MULT(in2,11)
	r16 = 2*4
	*r8++r16 = a2 = a0 * *r7++r16	//prev[0] = WIN_MULT(in2,6)
	*r8++    = a2 = a1 * *r7++   	//prev[2] = WIN_MULT(in3,8)
	*r8      = a2 = a1 * *r7     	//prev[3] = WIN_MULT(in3,9)

	//r6 = AddressPR(in0)
	r6 = r1 + (in0 - DSP_start)
	a0 = *r6				//in0
	//r6 = AddressPR(in4)
	r6 = r1 + (in4 - DSP_start)
	a1 = *r6				//in4

	r6 = r2 + 12*32*4		//ts[12*SBLIMIT]
	r7 = r3 + 0*4			//win[0]
	r15 = 5*32*4
	r16 = 5*4

	*r6++r15 = a2 = *r6 + a0 * *r7++r16	//ts[12*SBLIMIT] += WIN_MULT[in0,0]
	r15 = (short) -3*32*4
	r16 = (short) -3*4
	*r6++r15 = a2 = *r6 + a0 * *r7++r16	//ts[17*SBLIMIT] += WIN_MULT[in0,5]
	r15 = 1*32*4
	*r6++r15 = a2 = *r6 + a1 * *r7++   	//ts[14*SBLIMIT] += WIN_MULT[in4,2]
	*r6      = a2 = *r6 + a1 * *r7     	//ts[15*SBLIMIT] += WIN_MULT[in4,3]

	//STEP 3
	r17 = r17 + 4				//line 338

	r8 = r4 + 12*4			//prev[12]
	//r7 = AddressPR(zero)

	do 0,5
		*r8++ = a0 = a1 - a1	//*r7	//prev[12..17]=0

	call AddressPR(DCT12_PART1) (r18)	//line 344
	nop

	r7 = r3 + 10*4			//win[10]
	r8 = r4 + 10*4			//prev[10]
	r16 = (short) -3*4

	*r8++r16 = a2 = a0 * *r7++r16	//prev[10] = WIN_MULT(tmp0,10)
	r16 = (short) -6*4
	*r8++r16 = a2 = a0 * *r7++r16	//prev[7]  = WIN_MULT(tmp0,7)
	r16 = 3*4
	*r8++r16 = a2 = *r8 + a1 * *r7++r16	//prev[1] += WIN_MULT(tmp1,1)
	*r8      = a2 = *r8 + a1 * *r7     	//prev[4] += WIN_MULT(tmp1,4)

	call AddressPR(DCT12_PART2) (r18)	//line 359
	nop

	//2*nop
	//r6 = AddressPR(in2)
	r6 = r1 + (in2 - DSP_start)
	a0 = *r6--				//in2
	a1 = *r6				//in3

	r7 = r3 + 11*4			//win[11]
	r8 = r4 + 11*4			//prev[11]
	r16 = (short) -5*4

	*r8++r16 = a2 = a0 * *r7++r16	//prev[11] = WIN_MULT(in2,11)
	r16 = 2*4
	*r8++r16 = a2 = a0 * *r7++r16	//prev[6] = WIN_MULT(in2,6)
	*r8++    = a2 = a1 * *r7++   	//prev[8] = WIN_MULT(in3,8)
	*r8      = a2 = a1 * *r7     	//prev[9] = WIN_MULT(in3,9)

	//r6 = AddressPR(in0)
	r6 = r1 + (in0 - DSP_start)
	a0 = *r6				//in0
	//r6 = AddressPR(in4)
	r6 = r1 + (in4 - DSP_start)
	a1 = *r6				//in4

	r7 = r3 + 0*4			//win[0]
	r8 = r4 + 0*4			//prev[0]
	r16 = 5*4

	*r8++r16 = a2 = *r8 + a0 * *r7++r16	//prev[0] += WIN_MULT(in0,0)
	r16 = (short) -3*4
	*r8++r16 = a2 = *r8 + a0 * *r7++r16	//prev[5] += WIN_MULT(in0,5)
	*r8++    = a2 = *r8 + a1 * *r7++   	//prev[2] += WIN_MULT(in4,2)
	*r8      = a2 = *r8 + a1 * *r7     	//prev[3] += WIN_MULT(in4,3)

	r6 = *r21--
	return (r19)
	r17 = *r21
	nop					//assembler craziness

DCT12_PART1:
	// support routine, return addr in r18
	// returns with a0 = tmp 0, a1 = tmp1
	r6 = r17 + 5*3*4
	r7 = r17 + 4*3*4
	r8 = AddressPR(in5)
	//r8 = r1 + (in5 - DSP_start)
	r15 = (short) -1*3*4

	do 0,4					//inN = in[N*3] + in[(N-1)*3]
		*r8++ = a0 = *r6++r15 + *r7++r15
	*r8   = a3 = *r6		//in0 = in[0*3]

	r7 = AddressPR(in5)
	//r7 = r1 + (in5 - DSP_start)
	r8 = AddressPR(in3)
	//r8 = r1 + (in3 - DSP_start)
	*r7 = a0 = *r7 + *r8	//in5+=in3
	r7 = AddressPR(in1)
	//r7 = r1 + (in1 - DSP_start)
	*r8 = a1 = *r8 + *r7--	//in3+=in1
		
	r8 = AddressPR(c3)
	//r8 = r1 + (c3 - DSP_start)
	*r7-- = a0 = *r7 * *r8	//in2 = in2 * const
	*r7   = a0 = a1  * *r8	//in3 = in3 * const

	//move straight into calc_temp
	r7 = AddressPR(in1)
	//r7 = r1 + (in1 - DSP_start)
	r8 = AddressPR(in5)
	//r8 = r1 + (in5 - DSP_start)

	a0 = *r7++ - *r8++	//in1 - in5
	a1 = *r7   - *r8  	//tmp1 = in0 - in4	
	//r8 = AddressPR(cost36_4)
	r8 = r1 + (cost36_4 - DSP_start)
	a2 = a0 * *r8		//tmp2 = (in1 - in5) x const
	a0 = a2 + a1	//tmp0 = tmp2 + tmp1
	return (r18)
	a1 = -a2 + a1	//tmp1 = tmp1 - tmp2

DCT12_PART2:
	//support routine, return addr in r18
	r6 = AddressPR(in0)
	r7 = AddressPR(in4)
	r8 = AddressPR(c6)
	//r6 = r1 + (in0 - DSP_start)
	//r7 = r1 + (in4 - DSP_start)
	//r8 = r1 + (c6 - DSP_start)

	a2 = *r7--						//a2 = in4
	a3 = *r7++						//a3 = in5
	r9 = AddressPR(in2)				//here to avoid multiplier latency
	//r9 = r1 + (in2 - DSP_start)

		    a0 = *r6 + a2 * *r8		//in0 += in4 * cos6_2
	*r7-- = a1 = a0 + *r9			//in4 = in0 + in2
	*r6-- = a0 = a0 - *r9--			//in0 = in0 - in2			###write latency!! all through here
		    a1 = *r6 + a3 * *r8		//in1 += in5 * cos6_2

	a3 = *r9						//a3 = in3, a0 = in0, a1 = in1, a2 = in4
	r8 = AddressPR(cost36_1)
	//r8 = r1 + (cost36_1 - DSP_start)
	a2 = a1 * *r8					//in1 * const
	*r7++ = a2 = a2 + a3 * *r8		//in5 = ditto + in3 * const. a2 = in5
	r8 = AddressPR(cost36_7)
	//r8 = r1 + (cost36_7 - DSP_start)
	a1 = a1 * *r8					//in1 * const
	*r6++ = a1 = a1 - a3 * *r8		//in1 = ditto - in3 * const, a1 = in1
	
	*r9++ = a3 = *r7 + a2			//in3 = in4 + in5
	*r7   = a3 = *r7 - a2			//in4 = in4 - in5

	*r9 = a3 = a0 + a1				//in2 = in0 + in1
	return (r18)
	*r6 = a3 = a0 - a1				//in0 = in0 - in1




	//*****************************************************************************
	//*** synthesis (polyphase filter)
	//*****************************************************************************

//MPEGIMDCT_hybrid		- main decoder routine
//MPEGSUBF_antialias	- Apply the antialiasing butterflies on a granule
//MPEGSUBF_filter_band	- Apply the FAST synthesis filter to a sub band
//MPEGSUBF_window_band	- Window a sub band filtered sample


MPEGSUBF_filter_band:
		//Apply the FAST synthesis filter to a sub band
		//Generate full frequency sample
		//inputs:
		//bandPtr (=fraction) (float *) samples
		//out_filter_buffer 0 (float *)	sy0
		//out_filter_buffer 1 (float *)	sy1
		//freq_div

		//r1 = AddressPR(DSP_data_address)
		//r1 = *r1	
		r1 = *(DSP_data_address - RAM_start + 0xE000)
		r4 = AddressPR(curr_chann)
		r5 = r1 + (bb - DSP_start)	//bb, default to bb[0][0]
		
		r2 = *r4					//channel number, either 0 or 1
		r4 = r1 + (fraction_ptr - DSP_start)
		r7 = *r4					//samples aka bandPtr aka fraction_ptr

		//r13 = AddressPR(b_offset_ch)
		r13 = r1 + (b_offset_ch - DSP_start)
		r2 & 1
		if(eq) pcgoto offset0
		r3 = (short) *r13++
		r5 = r5 + 4096				//bb[1][0]
		r3 = (short) *r13
		
offset0:
		//at this stage, r3 = b_offset[ch], r5 = bb[ch]
		//r6 = AddressPR(b_offset)
		r6 = r1 + (b_offset - DSP_start)
		*r6++ = r3			//store for window filter
		r3 & 1
		if(eq) pcgoto boffset_even
		r3 = r3 << 2		//b_offset in floats

		r3 = r5 + r3		//buf1 = bb[ch][b_offset]
		r2 = r3 + 512*4		//buf0 = bb[ch][MPA_HANNING_SIZE + b_offset]
		r5 = r5 + 512*4		//bufptr = bb[ch][MPA_HANNING_SIZE]
		pcgoto storebufptr
		nop

boffset_even:
		r2 = r5 + r3		//buf0 = bb[ch][b_offset]						sy0
		r3 = r2 + 512*4		//buf1 = bb[ch][MPA_HANNING_SIZE + b_offset]	sy1
							//bufptr remains as bb[ch][0]

storebufptr:
		*r6 = r5			//store bufptr

		//r4 = *(freq_div - RAM_start + 0xE000)
		//r4 = r1 + (DSP_freq_div - DSP_start)
		//r4 = *r4

		r5 = r7				//x1
		r6 = r7 + 31*4		//x2
		r7 = AddressPR(p)	//d

		//r4 - 4
		//if(ne) pcgoto filter_band1
		//nop

		do 0,7
			*r7++ = a0 = *r5++

		//sub_half_dct
		r8 = AddressPR(pp)	//d1 = pp[0]
		r9 = r8 + 4*4		//d2 = pp[4]
		r10 = AddressPR(p)	//s1 = p[0]
		r11 = r10 + 8*4 - 1*4	//s2 = p[8-1] ie pre-decrement
		r12 = AddressPR(cos1_16)	//cos1_16

		do 5, 1
			a1 = *r10 - *r11
			*r8++ = a3 = *r10++ + *r11--
			a2 = *r10 - *r11
			*r9++ = a3 = a1 * *r12++
			*r8++ = a3 = *r10++ + *r11--
			*r9++ = a3 = a2 * *r12++
		
		r8 = AddressPR(p)	//d1 = p[0]
		r9 = r8 + 2*4		//d2 = p[2]
		r10 = AddressPR(pp)	//s1 = pp[0]
		r11 = r10 + 4*4 - 1*4	//s2 = pp[4-1] ie pre-decrement
		r12 = AddressPR(cos1_8)	//cos1_8

		a1 = *r10 - *r11
		*r8++ = a3 = *r10++ + *r11--
		a2 = *r10 - *r11
		*r9++ = a3 = a1 * *r12++
		*r8++ = a3 = *r10++ + *r11--
		*r9++ = a3 = a2 * *r12++

		r8 = AddressPR(p)	//  r8 = r9 would be quicker
		r8 = r8 + 4*4		//d1 = p[4]
		r9 = r8 + 2*4		//d2 = p[6]
		r10 = AddressPR(pp)
		r10 = r10 + 4*4			//s1 = pp[4]
		r11 = r10 + 4*4 - 1*4	//s2 = pp[8-1] ie pre-decrement
		r12 = AddressPR(cos1_8)	//cos1_8

		a1 = *r10 - *r11
		*r8++ = a3 = *r10++ + *r11--
		a2 = *r10 - *r11
		*r9++ = a3 = a1 * *r12++
		*r8++ = a3 = *r10++ + *r11--
		*r9++ = a3 = a2 * *r12++

		r8 = AddressPR(p)	//d1 = p[0]
		r10 = r8			//p[0]
		r11 = r8 + 1*4		//p[1]
		r12 = AddressPR(cos1_4)	//cos1_4
		
		r15 = 2*4

		a1 = *r10 - *r11
		*r8++ = a3 = *r10++r15 + *r11++r15
		a2 = *r10 - *r11
		*r8++ = a3 = a1 * *r12
		*r8++ = a3 = *r10++r15 + *r11++r15
		*r8++ = a3 = a2 * *r12

		a1 = *r10 - *r11
		*r8++ = a3 = *r10++r15 + *r11++r15
		a2 = *r10 - *r11
		*r8++ = a3 = a1 * *r12
		*r8++ = a3 = *r10++r15 + *r11++r15
		*r8++ = a3 = a2 * *r12

		//end of sub_half_dct
		nop
		r8 = r2				//sy0 = S0(0)
		r9 = r3				//sy1 = S1(0)
		r5 = AddressPR(p)	//p[0]
		r10 = r5 + 1*4		//p[1]
		r11 = r2 + 28*4*16	//S0(28)

		r15 = 4*4*16		//index S0 upwards
		r16 = (short) -4*4*16		//index S0 downwards
		r17 = (short) -2*4
		
		*r8++r15 = a0 = *r10	//S0(0)= p[1]
		*r9++r15 = a1 = -*r10	//S1(0) = -p[1]		r9 now S1(4)

		r10 = r5 + 5*4		//p[5]
		r2  = r5 + 7*4
		*r8++r15  = a1 = *r10 + *r2		//S0(4) = p[5] + p[7]
		*r11++r16 = a1 = -*r10++r17 - *r2	//S0(28) = -p[5] - p[7]

		*r8++r15 = a1 = *r10	//S0(8) = p[3]
		*r11++r16 = a1 = -*r10	//S0(24) = -p[3]

		a0 = -*r2				//for later
		*r8++r15 = a1 = *r2		//S0(12) = p[7],	r10 now p[6]
		*r11++r16 = a1 = -*r2--	//S0(20) = -p[7]

		a0 = *r2-- - a0				//p[6] + p[7],	r10 now p[5]
		r11 = r3 + 28*4*16			//S1(28)
		*r8 = r0					//S0(16) = 0
		*r9++r15  = a2 = -a0 - *r2	//S1(4) = -p[5] -p[6] -p[7], r9 now S1(8)
		*r11++r16 = a2 = -a0 - *r2

		r8  = r5 + 2*4		//p[2]
		*r9++r15  = a2 = -*r10 - *r8	//S1(8) = -p[2] - p[3]
		*r11++r16 = a2 = -*r10++ - *r8	//S1(24) = ditto
		*r9++r15  = a2 = -a0 - *r10		//S1(12) = -p[6] - p[7] -p[4]
		*r11++r16 = a2 = -a0 - *r10		//S1(20) = ditto	

		//pcgoto MPEGSUBF_window_band 
		*r9 = a0 = -*r5		//S1(16) = p[0]

MPEGSUBF_window_band:
		//Window a sub band filtered sample

		//out_filter_buffer (float *)
		//out_sample_buffer (float *)
		//dewindow (float *) (##2)
		//buffer offset
		//w_begin  (#1)
		//w_width  (#1)
		//freq_div (#1)
		//-> a1 = out_sample_buffer + out_sample_length

		r1 = *(DSP_data_address - RAM_start + 0xE000)
		//r4 = AddressPR(b_offset)
		r6 = 0				//*r3++			//w_begin quality = 2: 0; 1: 4; 0: 6
		r4 = r1 + (b_offset - DSP_start)

		//r2 = AddressPR(pcm_out)
		r2 = r1 + (pcm_out - DSP_start)
		r2 = *r2		//sample_buffer
		//r2 = *(pcm_out - RAM_start + 0xE000)
		
		r5 = *r4++		//b_offset
		
		//r3 = AddressPR(freq_div)
		r3 = r1 + (DSP_freq_div - DSP_start)
		r8 = *r3++			//freq_div
		r3 = r1 + (pcm_count - DSP_start)
		
		r7 = 16				//*r3++			//w_width quality = 2: 16; 1: 8; 0: 4
		r3 = *r3			//pcm_count

		r11 = AddressPR(dewindow)
		//r11 = r1 + (dewindow - DSP_start)
		r13 = *r4		//filter_buffer = buf_ptr //derived //moved as it smashes r1

		r9 = r6 + r6
		r9 = r9 + r9	//w_begin * 4
		r9 = r11 + r9

		r3 = r3 - 2	//1		//pre-dec pcm_count
		
		r6 = r6 + r5
		r6 = r6 & 15	//r6 = start

		r10 = r6 + r6
		r10 = r10 + r10
		r10 = r10 + r13	//r10 = buf1

		r11 = r6 + r7	//r11 = start + width = top
		r11 - 16
		if(le) pcgoto window_band1
		nop
		r11 = 16
window_band1:
		r11 = r11 - r6	//cnt1 = top - start
		r12 = r7 - r11	//cnt0 = width - cnt1

		r8  = r8 << 4	//freq_div * 16

		r16 = r8 - r11	//off1 = freq_div * 16 - cnt1
		r16 = r16 << 2	//count longs

		r15 = r8 - r12	//off0 = freq_div * 16 - cnt0
		r15 = r15 << 2	//count longs

		r17 = r8 - r7	//offd = freq_div * 16 - width
		r17 = r17 << 2	//count longs

		r8 = *(curr_chann - RAM_start + 0xE000)
		r7 = r1 + (DSP_volR - DSP_start)	//volume multiplier
		//r7 = AddressPR(vol_multR)
		r8 - r0
		if(eq) pcgoto right_chan
		nop
		r7 = r1 + (DSP_volL - DSP_start)
		//r7 = AddressPR(vol_multL)
right_chan:
		a3 = float32(*r7)

		//register usage:
		//buf0			r13
		//off0			r15
		//buf1			r10
		//off1			r16
		//dewindow		r9
		//offd			r17
		//cnt0			r12
		//cnt1			r11
		//sample		r2
		//pcm_loops		r3
		//volume mul pt	r7

		//line 963
		//r4 = AddressPR(zero)
		r4 = r1 + (zero - DSP_start)
		r11 = r11 - 1
		if(mi) pcgoto winloop1
		r12 = r12 - 1		//pre dec cnt1, cnt0
		if(mi) pcgoto winloop2

winloop:
		a0 = *r4			//zero sum

		//r11 - r0
		//if(mi) pcgoto winskip1
		//nop
		do 0, r11
			a0 = a0 + *r10++ * *r9++	//sum += *buf1++ * dewindow++

winskip1:
		//r12 - r0
		//if(mi) pcgoto winskip2
		//nop
		do 0, r12
			a0 = a0 + *r13++ * *r9++	//sum += *buf0++ * dewindow++

winskip2:
		//STORE
		r10 = r10 + r16		//buf1+=off1
		r13 = r13 + r15		//buf0+=off0
		a0 = a0 * a3	//*r7
		r9 = r9 + r17		//dewindow+=offd		
	
		//r3 = r3 - 1
		//if(ge) pcgoto winloop		//pcm_loops = j-- (address is sign-extended)
		if(r3-- >= 0) pcgoto winloop	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store		



window_end:
		//r1 = *(DSP_data_address - RAM_start + 0xE000)
		//r6 = AddressPR(b_offset)
		r6 = r1 + (b_offset - DSP_start)
		r2 = *(curr_chann - RAM_start + 0xE000)
		r3 = *r6			//b_offset
		//r11 = AddressPR(b_offset_ch)
		r11 = r1 + (b_offset_ch - DSP_start)
		r3 = r3 - 1
		r3 = r3 & 15
		r2 & 1
		if(eq) pcgoto store_b_offset
		nop
		r11 = r11 + 2

store_b_offset:
		return (r19)
		*r11 = (short)r3

winloop1:
		a0 = *r4			//zero sum

		do 0, r12			//as r11=0, r12 can't be
			a0 = a0 + *r13++ * *r9++	//sum += *buf0++ * dewindow++

		//STORE
		r10 = r10 + r16		//buf1+=off1
		r13 = r13 + r15		//buf0+=off0
		a0 = a0 * a3	//*r7
		r9 = r9 + r17		//dewindow+=offd		
	
		//r3 = r3 - 1
		//if(ge) pcgoto winloop1		//pcm_loops = j-- (address is sign-extended)
		if(r3-- >= 0) pcgoto winloop1	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store
		pcgoto window_end
		nop

winloop2:
		a0 = *r4			//zero sum

		do 0, r11
			a0 = a0 + *r10++ * *r9++	//sum += *buf1++ * dewindow++

		//STORE
		r10 = r10 + r16		//buf1+=off1
		r13 = r13 + r15		//buf0+=off0
		a0 = a0 * a3	//*r7
		r9 = r9 + r17		//dewindow+=offd		
	
		//r3 = r3 - 1
		//if(ge) pcgoto winloop2		//pcm_loops = j-- (address is sign-extended)
		if(r3-- >= 0) pcgoto winloop2	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store
		pcgoto window_end
		nop

	//******************************************
	//* Registers used:                        *
	//* r2 = inbuffer, updated                 *
	//* r7 = long of unread bits from bs       *
	//* r10 = number of bits to read (<=32)    *
	//* r11 = outbits from bs, 0 on entry      *
	//* r18 = return address from call         *
	//*	r20 = bit count                        *
	//* r21 = available bits in buffer         *
	//* All other regs preserved               *
	//******************************************
getbits0:	
	r21 = r21 - r10		//test if need to fetch
	if(le) pcgoto getbits_getmore
	r20 = r20 + r10		//update bitcount

	//OK, we already have enough in r7
	r11 = 32
	r11 = r11 - r10
	r11 = r7 >> r11		//if msb=0
	return (r18)
	r7 = r7 << r10		//remove r10 bits to prepare buffer for next time

getbits_getmore:
	r10 = 32 - r10
	r11 = r7 >> r10
	
	r21 = r21 + 32
	r21 - 32
	if(eq) goto r18		//if we had emptied buffer, return
	r7 = *r2++			//get next long word
	
	nop
	r10 = r7 >> r21
	r11 = r11 | r10
	r10 = r21
	r10 = 32 - r10
	return (r18)
	r7 = r7 << r10

getbits1:
	r11 = 1
	r7 = r7 + r7
	if(cc) r11 = r0
	r21 = r21 - 1
	if(ne) goto r18
	r20 = r20 + 1
	r7 = *r2++
	return (r18)
	r21 = 32


	//reset getbits with r2 as pointer to bitstream
	//automatically sets r7 = intialiser value
	//r20 = count, r21 = avail
getbits_init:
	r21 = 32
	r7 = *r2++					//initialise
	return (r18)
	r20 = 0


p:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//16 floats
pp:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//16 floats

temp_stack:		long 0, 0, 0, 0		//, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0 ,0	//16 longs of stack

 cos1_64:		float 0.50060299823520
 cos3_64:		float 0.50547095989754
 cos5_64:		float 0.51544730992262
 cos7_64:		float 0.53104259108978
 cos9_64:		float 0.55310389603444
 cos11_64:		float 0.58293496820613
 cos13_64:		float 0.62250412303566
 cos15_64:		float 0.67480834145501
 cos17_64:		float 0.74453627100230
 cos19_64:		float 0.83934964541553
 cos21_64:		float 0.97256823786196
 cos23_64:		float 1.16943993343288
 cos25_64:		float 1.48416461631417
 cos27_64:		float 2.05778100995341
 cos29_64:		float 3.40760841846872
 cos31_64:		float 10.1900081235480
 cos1_32:		float 0.50241928618816
 cos3_32:		float 0.52249861493969
 cos5_32:		float 0.56694403481636
 cos7_32:		float 0.64682178335999
 cos9_32:		float 0.78815462345125
 cos11_32:		float 1.06067768599035
 cos13_32:		float 1.72244709823833
 cos15_32:		float 5.10114861868917
 cos1_16:		float 0.50979557910416
 cos3_16:		float 0.60134488693505
 cos5_16:		float 0.89997622313642
 cos7_16:		float 2.56291544774151
 cos1_8:		float 0.54119610014620
 cos3_8:		float 1.30656296487638
 cos1_4:		float 0.70710678118655

cai:	float	-0.514495730, -0.471731961, -0.313377440, -0.181913197
		float	-0.094574191, -0.040965579, -0.014198568, -0.003699975
csi:	float	0.857492924, 0.881741941, 0.949628592, 0.983314574
		float	0.995517790, 0.999160528, 0.999899149, 0.999993145

DSP_data_address:	long 0

curr_chann:		long 0
channels:		long 0

ta33:	long 0
ta66:	long 0
tb33:	long 0
tb66:	long 0

tmp1a:	long 0
tmp1b:	long 0
tmp2a:	long 0
tmp2b:	long 0

c3:	float 8.660254038e-1		//cos (pi/18*3)
c6:	float 0.5					//cos (pi/18*6) aka a half!

c1: float 9.848077530e-1
c5:	float 6.427876097e-1
c7: float 3.420201433e-1

c2: float 9.396926208e-1
c4: float 7.660444431e-1
c8: float 1.736481777e-1

cost36_0:	float 5.019099188e-1		//0.5/cos(pi/36*(2i+1)) i=0
cost36_1:	float 5.176380902e-1
cost36_2:	float 5.516889595e-1
cost36_3:	float 6.103872944e-1
cost36_4:	float 7.071067812e-1
cost36_5:	float 8.717233978e-1
cost36_6:	float 1.183100792
cost36_7:	float 1.931851653
cost36_8:	float 5.736856623			//i=8

in5:	long 0
in4:	long 0
in3:	long 0
in2:	long 0
in1:	long 0
in0:	long 0

dewindow:
   float +0.000000000, -0.000442505, +0.003250122, -0.007003784, +0.031082153, -0.078628540, +0.100311279, -0.572036743, +1.144989014, +0.572036743, +0.100311279, +0.078628540, +0.031082153, +0.007003784, +0.003250122, +0.000442505
   float -0.000015259, -0.000473022, +0.003326416, -0.007919312, +0.030517578, -0.084182739, +0.090927124, -0.600219727, +1.144287109, +0.543823242, +0.108856201, +0.073059082, +0.031478882, +0.006118774, +0.003173828, +0.000396729
   float -0.000015259, -0.000534058, +0.003387451, -0.008865356, +0.029785156, -0.089706421, +0.080688477, -0.628295898, +1.142211914, +0.515609741, +0.116577148, +0.067520142, +0.031738281, +0.005294800, +0.003082275, +0.000366211
   float -0.000015259, -0.000579834, +0.003433228, -0.009841919, +0.028884888, -0.095169067, +0.069595337, -0.656219482, +1.138763428, +0.487472534, +0.123474121, +0.061996460, +0.031845093, +0.004486084, +0.002990723, +0.000320435
   float -0.000015259, -0.000625610, +0.003463745, -0.010848999, +0.027801514, -0.100540161, +0.057617188, -0.683914185, +1.133926392, +0.459472656, +0.129577637, +0.056533813, +0.031814575, +0.003723145, +0.002899170, +0.000289917
   float -0.000015259, -0.000686646, +0.003479004, -0.011886597, +0.026535034, -0.105819702, +0.044784546, -0.711318970, +1.127746582, +0.431655884, +0.134887695, +0.051132202, +0.031661987, +0.003005981, +0.002792358, +0.000259399
   float -0.000015259, -0.000747681, +0.003479004, -0.012939453, +0.025085449, -0.110946655, +0.031082153, -0.738372803, +1.120223999, +0.404083252, +0.139450073, +0.045837402, +0.031387329, +0.002334595, +0.002685547, +0.000244141
   float -0.000030518, -0.000808716, +0.003463745, -0.014022827, +0.023422241, -0.115921021, +0.016510010, -0.765029907, +1.111373901, +0.376800537, +0.143264771, +0.040634155, +0.031005859, +0.001693726, +0.002578735, +0.000213623
   float -0.000030518, -0.000885010, +0.003417969, -0.015121460, +0.021575928, -0.120697021, +0.001068115, -0.791213989, +1.101211548, +0.349868774, +0.146362305, +0.035552979, +0.030532837, +0.001098633, +0.002456665, +0.000198364
   float -0.000030518, -0.000961304, +0.003372192, -0.016235352, +0.019531250, -0.125259399, -0.015228271, -0.816864014, +1.089782715, +0.323318481, +0.148773193, +0.030609131, +0.029937744, +0.000549316, +0.002349854, +0.000167847
   float -0.000030518, -0.001037598, +0.003280640, -0.017349243, +0.017257690, -0.129562378, -0.032379150, -0.841949463, +1.077117920, +0.297210693, +0.150497437, +0.025817871, +0.029281616, +0.000030518, +0.002243042, +0.000152588
   float -0.000045776, -0.001113892, +0.003173828, -0.018463135, +0.014801025, -0.133590698, -0.050354004, -0.866363525, +1.063217163, +0.271591187, +0.151596069, +0.021179199, +0.028533936, -0.000442505, +0.002120972, +0.000137329
   float -0.000045776, -0.001205444, +0.003051758, -0.019577026, +0.012115479, -0.137298584, -0.069168091, -0.890090942, +1.048156738, +0.246505737, +0.152069092, +0.016708374, +0.027725220, -0.000869751, +0.002014160, +0.000122070
   float -0.000061035, -0.001296997, +0.002883911, -0.020690918, +0.009231567, -0.140670776, -0.088775635, -0.913055420, +1.031936646, +0.221984863, +0.151962280, +0.012420654, +0.026840210, -0.001266479, +0.001907349, +0.000106812
   float -0.000061035, -0.001388550, +0.002700806, -0.021789551, +0.006134033, -0.143676758, -0.109161377, -0.935195923, +1.014617920, +0.198059082, +0.151306152, +0.008316040, +0.025909424, -0.001617432, +0.001785278, +0.000106812
   float -0.000076294, -0.001480103, +0.002487183, -0.022857666, +0.002822876, -0.146255493, -0.130310059, -0.956481934, +0.996246338, +0.174789429, +0.150115967, +0.004394531, +0.024932861, -0.001937866, +0.001693726, +0.000091553
   float -0.000076294, -0.001586914, +0.002227783, -0.023910522, -0.000686646, -0.148422241, -0.152206421, -0.976852417, +0.976852417, +0.152206421, +0.148422241, +0.000686646, +0.023910522, -0.002227783, +0.001586914, +0.000076294
   float -0.000091553, -0.001693726, +0.001937866, -0.024932861, -0.004394531, -0.150115967, -0.174789429, -0.996246338, +0.956481934, +0.130310059, +0.146255493, -0.002822876, +0.022857666, -0.002487183, +0.001480103, +0.000076294
   float -0.000106812, -0.001785278, +0.001617432, -0.025909424, -0.008316040, -0.151306152, -0.198059082, -1.014617920, +0.935195923, +0.109161377, +0.143676758, -0.006134033, +0.021789551, -0.002700806, +0.001388550, +0.000061035
   float -0.000106812, -0.001907349, +0.001266479, -0.026840210, -0.012420654, -0.151962280, -0.221984863, -1.031936646, +0.913055420, +0.088775635, +0.140670776, -0.009231567, +0.020690918, -0.002883911, +0.001296997, +0.000061035
   float -0.000122070, -0.002014160, +0.000869751, -0.027725220, -0.016708374, -0.152069092, -0.246505737, -1.048156738, +0.890090942, +0.069168091, +0.137298584, -0.012115479, +0.019577026, -0.003051758, +0.001205444, +0.000045776
   float -0.000137329, -0.002120972, +0.000442505, -0.028533936, -0.021179199, -0.151596069, -0.271591187, -1.063217163, +0.866363525, +0.050354004, +0.133590698, -0.014801025, +0.018463135, -0.003173828, +0.001113892, +0.000045776
   float -0.000152588, -0.002243042, -0.000030518, -0.029281616, -0.025817871, -0.150497437, -0.297210693, -1.077117920, +0.841949463, +0.032379150, +0.129562378, -0.017257690, +0.017349243, -0.003280640, +0.001037598, +0.000030518
   float -0.000167847, -0.002349854, -0.000549316, -0.029937744, -0.030609131, -0.148773193, -0.323318481, -1.089782715, +0.816864014, +0.015228271, +0.125259399, -0.019531250, +0.016235352, -0.003372192, +0.000961304, +0.000030518
   float -0.000198364, -0.002456665, -0.001098633, -0.030532837, -0.035552979, -0.146362305, -0.349868774, -1.101211548, +0.791213989, -0.001068115, +0.120697021, -0.021575928, +0.015121460, -0.003417969, +0.000885010, +0.000030518
   float -0.000213623, -0.002578735, -0.001693726, -0.031005859, -0.040634155, -0.143264771, -0.376800537, -1.111373901, +0.765029907, -0.016510010, +0.115921021, -0.023422241, +0.014022827, -0.003463745, +0.000808716, +0.000030518
   float -0.000244141, -0.002685547, -0.002334595, -0.031387329, -0.045837402, -0.139450073, -0.404083252, -1.120223999, +0.738372803, -0.031082153, +0.110946655, -0.025085449, +0.012939453, -0.003479004, +0.000747681, +0.000015259
   float -0.000259399, -0.002792358, -0.003005981, -0.031661987, -0.051132202, -0.134887695, -0.431655884, -1.127746582, +0.711318970, -0.044784546, +0.105819702, -0.026535034, +0.011886597, -0.003479004, +0.000686646, +0.000015259
   float -0.000289917, -0.002899170, -0.003723145, -0.031814575, -0.056533813, -0.129577637, -0.459472656, -1.133926392, +0.683914185, -0.057617188, +0.100540161, -0.027801514, +0.010848999, -0.003463745, +0.000625610, +0.000015259
   float -0.000320435, -0.002990723, -0.004486084, -0.031845093, -0.061996460, -0.123474121, -0.487472534, -1.138763428, +0.656219482, -0.069595337, +0.095169067, -0.028884888, +0.009841919, -0.003433228, +0.000579834, +0.000015259
   float -0.000366211, -0.003082275, -0.005294800, -0.031738281, -0.067520142, -0.116577148, -0.515609741, -1.142211914, +0.628295898, -0.080688477, +0.089706421, -0.029785156, +0.008865356, -0.003387451, +0.000534058, +0.000015259
   float -0.000396729, -0.003173828, -0.006118774, -0.031478882, -0.073059082, -0.108856201, -0.543823242, -1.144287109, +0.600219727, -0.090927124, +0.084182739, -0.030517578, +0.007919312, -0.003326416, +0.000473022, +0.000015259
 

imdct_e_win0:
               float    3.22824270e-2,1.07206352e-1,2.01414257e-1,3.25616330e-1,   5.00000000e-1,7.67774701e-1
               float    1.24122286,2.33195114,7.74415016,-8.45125675,-3.03905797,-1.94832957
               float    -1.47488141,-1.20710671,-1.03272307,-9.08520997e-1,-8.14313114e-1,-7.39389181e-1
               float    -6.77525342e-1,-6.24844432e-1,-5.78791738e-1,-5.37601590e-1,-4.99999970e-1,-4.65028346e-1
               float    -4.31934267e-1,-4.00099576e-1,-3.68989855e-1,-3.38116914e-1,-3.07007194e-1,-2.75172472e-1
               float    -2.42078424e-1,-2.07106769e-1,-1.69505134e-1,-1.28315032e-1,-8.22623298e-2,-2.95813959e-2
imdct_e_win1:
               float    3.22824270e-2,1.07206352e-1,2.01414257e-1,3.25616330e-1,   5.00000000e-1,7.67774701e-1
               float    1.24122286,2.33195114,7.74415016,-8.45125675,-3.03905797,-1.94832957
               float    -1.47488141,-1.20710671,-1.03272307,-9.08520997e-1,-8.14313114e-1,-7.39389181e-1
               float    -6.78170800e-1,-6.30236149e-1,-5.92844486e-1,-5.63690960e-1,-5.41196048e-1,-5.24264514e-1
               float    -5.07758319e-1,-4.65925813e-1,-3.97054553e-1,-3.04670691e-1,-1.92992792e-1,-6.68476522e-2
               float       0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000
imdct_e_win2:
               float    1.07206352e-1,   5.00000000e-1,2.33195114,-3.03905797,-1.20710671,-8.14313114e-1
               float    -6.24844432e-1,-4.99999970e-1,-4.00099576e-1,-3.07007194e-1,-2.07106769e-1,-8.22623298e-2
imdct_e_win3:
               float       0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000
               float    3.01530272e-1,1.46592581,6.97810602,-9.09404469,-3.53905797,-2.29034972
               float    -1.66275465,-1.30656290,-1.08284020,-9.30579484e-1,-8.21339786e-1,-7.40093589e-1
               float    -6.77525342e-1,-6.24844432e-1,-5.78791738e-1,-5.37601590e-1,-4.99999970e-1,-4.65028346e-1
               float    -4.31934267e-1,-4.00099576e-1,-3.68989855e-1,-3.38116914e-1,-3.07007194e-1,-2.75172472e-1
               float    -2.42078424e-1,-2.07106769e-1,-1.69505134e-1,-1.28315032e-1,-8.22623298e-2,-2.95813959e-2

RAM_end:

//The following constants and variables remain in FastRAM

zero:			long 0

b_offset:		long 0, 0	//will store b_offset and buf_ptr

fraction_ptr:	long 0		//aka bandPtr

pcm_out:		long 0

pcm_offset:		long 0

b_offset_ch:	short 0, 0	//b_offset[ch]
//freq_div:		long 4
pcm_count:		long 8		//32/freq_div


pcm_store:			long 0

blocktyp:		long 0
sblimit:		long 0, 0, 0	//blocktype and sblimit for channels 0 and 1



imdct_o_win0:
               float    3.22824270e-2,-1.07206352e-1,2.01414257e-1,-3.25616330e-1,   5.00000000e-1,-7.67774701e-1
               float    1.24122286,-2.33195114,7.74415016,8.45125675,-3.03905797,1.94832957
               float    -1.47488141,1.20710671,-1.03272307,9.08520997e-1,-8.14313114e-1,7.39389181e-1
               float    -6.77525342e-1,6.24844432e-1,-5.78791738e-1,5.37601590e-1,-4.99999970e-1,4.65028346e-1
               float    -4.31934267e-1,4.00099576e-1,-3.68989855e-1,3.38116914e-1,-3.07007194e-1,2.75172472e-1
               float    -2.42078424e-1,2.07106769e-1,-1.69505134e-1,1.28315032e-1,-8.22623298e-2,2.95813959e-2
imdct_o_win1:
               float    3.22824270e-2,-1.07206352e-1,2.01414257e-1,-3.25616330e-1,   5.00000000e-1,-7.67774701e-1
               float    1.24122286,-2.33195114,7.74415016,8.45125675,-3.03905797,1.94832957
               float    -1.47488141,1.20710671,-1.03272307,9.08520997e-1,-8.14313114e-1,7.39389181e-1
               float    -6.78170800e-1,6.30236149e-1,-5.92844486e-1,5.63690960e-1,-5.41196048e-1,5.24264514e-1
               float    -5.07758319e-1,4.65925813e-1,-3.97054553e-1,3.04670691e-1,-1.92992792e-1,6.68476522e-2
               float       0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000
imdct_o_win2:
               float    1.07206352e-1,  -5.00000000e-1,2.33195114,3.03905797,-1.20710671,8.14313114e-1
               float    -6.24844432e-1,4.99999970e-1,-4.00099576e-1,3.07007194e-1,-2.07106769e-1,8.22623298e-2
imdct_o_win3:
               float       0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000,   0.00000000
               float    3.01530272e-1,-1.46592581,6.97810602,9.09404469,-3.53905797,2.29034972
               float    -1.66275465,1.30656290,-1.08284020,9.30579484e-1,-8.21339786e-1,7.40093589e-1
               float    -6.77525342e-1,6.24844432e-1,-5.78791738e-1,5.37601590e-1,-4.99999970e-1,4.65028346e-1
               float    -4.31934267e-1,4.00099576e-1,-3.68989855e-1,3.38116914e-1,-3.07007194e-1,2.75172472e-1
               float    -2.42078424e-1,2.07106769e-1,-1.69505134e-1,1.28315032e-1,-8.22623298e-2,2.95813959e-2

imdct_e_win:   long     imdct_e_win0 - imdct_e_win0
               long     imdct_e_win1 - imdct_e_win0
               long     imdct_e_win2 - imdct_e_win0
               long     imdct_e_win3 - imdct_e_win0

imdct_o_win:   long     imdct_o_win0 - imdct_o_win0
               long     imdct_o_win1 - imdct_o_win0
               long     imdct_o_win2 - imdct_o_win0
               long     imdct_o_win3 - imdct_o_win0  



sfsi_p:		long 0
granule0_sfsi:	long 0, 0, 0, 0, 0, 0, 0, 0	//4*2	;always zero
//	dc	"***sfsi01***"
granule1_sfsi:	long 0, 0, 0, 0, 0, 0, 0, 0 //4*2	;4 values for each channel

si_granule_tab_p:	long 0
si_tab_p:	long 0

si_tab:	long si0-si0, si1-si0, si2-si0, si3-si0
si0:
grstart:	long 0
grend:		long 0
regionend2:	long 0
globalgain:	long 0
sfcompress:	long 0
blocktype:	long 0
mixedblock:	long 0
tabsel0:	long 0
tabsel1:	long 0
tabsel2:	long 0
subblockgain0:	long 0
subblockgain1:	long 0
subblockgain2:	long 0
regionend0:	long 0
regionend1:	long 0
preflag:	long 0
sfshift:	long 0
tabsel3:	long 0
//	dc	"***si1***"
si1:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
//	dc	"***si2***"
si2:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
// dc	"***si3***"
si3:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
//	dc	"***si.***"

granule_counter:	long 0
scalefac_p:	long 0
scalefac0:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//39
			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

scalefac1:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//39
			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

sfbands_p:		long 0
sfbands_tab:	long sfbands_44100-sfbands_tab,sfbands_48000-sfbands_tab,sfbands_32000-sfbands_tab
//pre-divided by 3
sfbands_44100:	//long 0,12,24,36,48,66,90,120,156,198,252,318,408,576
				long 0,4,8,12,16,22,30,40,52,66,84,106,136,192
sfbands_48000:	//long 0,12,24,36,48,66,84,114,150,192,240,300,378,576
				long 0,4,8,12,16,22,28,38,50,64,80,100,126,192
sfbands_32000:	//long 0,12,24,36,48,66,90,126,174,234,312,414,540,576
				long 0,4,8,12,16,22,30,42,58,78,104,138,180,192
sfbandl_p:		long 0
sfbandl_tab:	long sfbandl_44100-sfbandl_tab,sfbandl_48000-sfbandl_tab,sfbandl_32000-sfbandl_tab
sfbandl_44100:	long 0,4,8,12,16,20,24,30,36,44,52,62,74,90,110,134,162,196,238,288,342,418,576
sfbandl_48000:	long 0,4,8,12,16,20,24,30,36,42,50,60,72,88,106,128,156,190,230,276,330,384,576
sfbandl_32000:	long 0,4,8,12,16,20,24,30,36,44,54,66,82,102,126,156,194,240,296,364,448,550,576

pretab:
				long 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,3,2,0

sfbtab0:		long	0,6,11,16,21
sfbtab1:		long	0,9,18,24,36
sfbtab2:		long	0,8,17,23,35

slentab0:		long	0,0,0,0,3,1,1,1,2,2,2,3,3,3,4,4
slentab1:		long	0,1,2,3,0,1,2,3,1,2,3,1,2,3,2,3
newslen:		long	0,0,0,0

//	dc	"***xr.***"
xr_p:		long 0
xr_zero_p:	long 0

//	dc	"***xr0***"
xr0:			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //32*18 = 576
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
//	dc	"***xr1***"
				long	1,1,1	//safety (for INTENSITY STEREO)
xr1:			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //32*18 = 576
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


htablinbits:
		long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,4,6,8,10,13,4,5,6,7,8,9,11,13,0,0
htabs:
		long htab00-htabs,htab01-htabs,htab02-htabs,htab03-htabs,htab04-htabs,htab05-htabs,htab06-htabs,htab07-htabs,htab08-htabs,htab09-htabs
		long htab10-htabs,htab11-htabs,htab12-htabs,htab13-htabs,htab14-htabs,htab15-htabs,htab16-htabs,htab16-htabs,htab16-htabs,htab16-htabs
		long htab16-htabs,htab16-htabs,htab16-htabs,htab16-htabs,htab24-htabs,htab24-htabs,htab24-htabs,htab24-htabs,htab24-htabs,htab24-htabs
		long htab24-htabs,htab24-htabs,htaba -htabs,htabb -htabs

htab00:
htab04:
htab14:
 long    0
htab01:
 long   -5,  -3,  -1,  17,   1,  16,   0
htab02:
 long  -15, -11,  -9,  -5,  -3,  -1,  34,   2,  18,  -1,  33,  32,  17,  -1,   1
 long   16,   0
htab03:
 long  -13, -11,  -9,  -5,  -3,  -1,  34,   2,  18,  -1,  33,  32,  16,  17,  -1
 long    1,   0
htab05:
 long  -29, -25, -23, -15,  -7,  -5,  -3,  -1,  51,  35,  50,  49,  -3,  -1,  19
 long    3,  -1,  48,  34,  -3,  -1,  18,  33,  -1,   2,  32,  17,  -1,   1,  16
 long    0
htab06:
 long  -25, -19, -13,  -9,  -5,  -3,  -1,  51,   3,  35,  -1,  50,  48,  -1,  19
 long   49,  -3,  -1,  34,   2,  18,  -3,  -1,  33,  32,   1,  -1,  17,  -1,  16
 long    0
htab07:
 long  -69, -65, -57, -39, -29, -17, -11,  -7,  -3,  -1,  85,  69,  -1,  84,  83
 long   -1,  53,  68,  -3,  -1,  37,  82,  21,  -5,  -1,  81,  -1,   5,  52,  -1
 long   80,  -1,  67,  51,  -5,  -3,  -1,  36,  66,  20,  -1,  65,  64, -11,  -7
 long   -3,  -1,   4,  35,  -1,  50,   3,  -1,  19,  49,  -3,  -1,  48,  34,  18
 long   -5,  -1,  33,  -1,   2,  32,  17,  -1,   1,  16,   0
htab08:
 long  -65, -63, -59, -45, -31, -19, -13,  -7,  -5,  -3,  -1,  85,  84,  69,  83
 long   -3,  -1,  53,  68,  37,  -3,  -1,  82,   5,  21,  -5,  -1,  81,  -1,  52
 long   67,  -3,  -1,  80,  51,  36,  -5,  -3,  -1,  66,  20,  65,  -3,  -1,   4
 long   64,  -1,  35,  50,  -9,  -7,  -3,  -1,  19,  49,  -1,   3,  48,  34,  -1
 long    2,  32,  -1,  18,  33,  17,  -3,  -1,   1,  16,   0
htab09:
 long  -63, -53, -41, -29, -19, -11,  -5,  -3,  -1,  85,  69,  53,  -1,  83,  -1
 long   84,   5,  -3,  -1,  68,  37,  -1,  82,  21,  -3,  -1,  81,  52,  -1,  67
 long   -1,  80,   4,  -7,  -3,  -1,  36,  66,  -1,  51,  64,  -1,  20,  65,  -5
 long   -3,  -1,  35,  50,  19,  -1,  49,  -1,   3,  48,  -5,  -3,  -1,  34,   2
 long   18,  -1,  33,  32,  -3,  -1,  17,   1,  -1,  16,   0
htab10:
 long -125,-121,-111, -83, -55, -35, -21, -13,  -7,  -3,  -1, 119, 103,  -1, 118
 long   87,  -3,  -1, 117, 102,  71,  -3,  -1, 116,  86,  -1, 101,  55,  -9,  -3
 long   -1, 115,  70,  -3,  -1,  85,  84,  99,  -1,  39, 114, -11,  -5,  -3,  -1
 long  100,   7, 112,  -1,  98,  -1,  69,  53,  -5,  -1,   6,  -1,  83,  68,  23
 long  -17,  -5,  -1, 113,  -1,  54,  38,  -5,  -3,  -1,  37,  82,  21,  -1,  81
 long   -1,  52,  67,  -3,  -1,  22,  97,  -1,  96,  -1,   5,  80, -19, -11,  -7
 long   -3,  -1,  36,  66,  -1,  51,   4,  -1,  20,  65,  -3,  -1,  64,  35,  -1
 long   50,   3,  -3,  -1,  19,  49,  -1,  48,  34,  -7,  -3,  -1,  18,  33,  -1
 long    2,  32,  17,  -1,   1,  16,   0
htab11:
 long -121,-113, -89, -59, -43, -27, -17,  -7,  -3,  -1, 119, 103,  -1, 118, 117
 long   -3,  -1, 102,  71,  -1, 116,  -1,  87,  85,  -5,  -3,  -1,  86, 101,  55
 long   -1, 115,  70,  -9,  -7,  -3,  -1,  69,  84,  -1,  53,  83,  39,  -1, 114
 long   -1, 100,   7,  -5,  -1, 113,  -1,  23, 112,  -3,  -1,  54,  99,  -1,  96
 long   -1,  68,  37, -13,  -7,  -5,  -3,  -1,  82,   5,  21,  98,  -3,  -1,  38
 long    6,  22,  -5,  -1,  97,  -1,  81,  52,  -5,  -1,  80,  -1,  67,  51,  -1
 long   36,  66, -15, -11,  -7,  -3,  -1,  20,  65,  -1,   4,  64,  -1,  35,  50
 long   -1,  19,  49,  -5,  -3,  -1,   3,  48,  34,  33,  -5,  -1,  18,  -1,   2
 long   32,  17,  -3,  -1,   1,  16,   0
htab12:
 long -115, -99, -73, -45, -27, -17,  -9,  -5,  -3,  -1, 119, 103, 118,  -1,  87
 long  117,  -3,  -1, 102,  71,  -1, 116, 101,  -3,  -1,  86,  55,  -3,  -1, 115
 long   85,  39,  -7,  -3,  -1, 114,  70,  -1, 100,  23,  -5,  -1, 113,  -1,   7
 long  112,  -1,  54,  99, -13,  -9,  -3,  -1,  69,  84,  -1,  68,  -1,   6,   5
 long   -1,  38,  98,  -5,  -1,  97,  -1,  22,  96,  -3,  -1,  53,  83,  -1,  37
 long   82, -17,  -7,  -3,  -1,  21,  81,  -1,  52,  67,  -5,  -3,  -1,  80,   4
 long   36,  -1,  66,  20,  -3,  -1,  51,  65,  -1,  35,  50, -11,  -7,  -5,  -3
 long   -1,  64,   3,  48,  19,  -1,  49,  34,  -1,  18,  33,  -7,  -5,  -3,  -1
 long    2,  32,   0,  17,  -1,   1,  16,   0
htab13:
 long -509,-503,-475,-405,-333,-265,-205,-153,-115, -83, -53, -35, -21, -13,  -9
 long   -7,  -5,  -3,  -1, 254, 252, 253, 237, 255,  -1, 239, 223,  -3,  -1, 238
 long  207,  -1, 222, 191,  -9,  -3,  -1, 251, 206,  -1, 220,  -1, 175, 233,  -1
 long  236, 221,  -9,  -5,  -3,  -1, 250, 205, 190,  -1, 235, 159,  -3,  -1, 249
 long  234,  -1, 189, 219, -17,  -9,  -3,  -1, 143, 248,  -1, 204,  -1, 174, 158
 long   -5,  -1, 142,  -1, 127, 126, 247,  -5,  -1, 218,  -1, 173, 188,  -3,  -1
 long  203, 246, 111, -15,  -7,  -3,  -1, 232,  95,  -1, 157, 217,  -3,  -1, 245
 long  231,  -1, 172, 187,  -9,  -3,  -1,  79, 244,  -3,  -1, 202, 230, 243,  -1
 long   63,  -1, 141, 216, -21,  -9,  -3,  -1,  47, 242,  -3,  -1, 110, 156,  15
 long   -5,  -3,  -1, 201,  94, 171,  -3,  -1, 125, 215,  78, -11,  -5,  -3,  -1
 long  200, 214,  62,  -1, 185,  -1, 155, 170,  -1,  31, 241, -23, -13,  -5,  -1
 long  240,  -1, 186, 229,  -3,  -1, 228, 140,  -1, 109, 227,  -5,  -1, 226,  -1
 long   46,  14,  -1,  30, 225, -15,  -7,  -3,  -1, 224,  93,  -1, 213, 124,  -3
 long   -1, 199,  77,  -1, 139, 184,  -7,  -3,  -1, 212, 154,  -1, 169, 108,  -1
 long  198,  61, -37, -21,  -9,  -5,  -3,  -1, 211, 123,  45,  -1, 210,  29,  -5
 long   -1, 183,  -1,  92, 197,  -3,  -1, 153, 122, 195,  -7,  -5,  -3,  -1, 167
 long  151,  75, 209,  -3,  -1,  13, 208,  -1, 138, 168, -11,  -7,  -3,  -1,  76
 long  196,  -1, 107, 182,  -1,  60,  44,  -3,  -1, 194,  91,  -3,  -1, 181, 137
 long   28, -43, -23, -11,  -5,  -1, 193,  -1, 152,  12,  -1, 192,  -1, 180, 106
 long   -5,  -3,  -1, 166, 121,  59,  -1, 179,  -1, 136,  90, -11,  -5,  -1,  43
 long   -1, 165, 105,  -1, 164,  -1, 120, 135,  -5,  -1, 148,  -1, 119, 118, 178
 long  -11,  -3,  -1,  27, 177,  -3,  -1,  11, 176,  -1, 150,  74,  -7,  -3,  -1
 long   58, 163,  -1,  89, 149,  -1,  42, 162, -47, -23,  -9,  -3,  -1,  26, 161
 long   -3,  -1,  10, 104, 160,  -5,  -3,  -1, 134,  73, 147,  -3,  -1,  57,  88
 long   -1, 133, 103,  -9,  -3,  -1,  41, 146,  -3,  -1,  87, 117,  56,  -5,  -1
 long  131,  -1, 102,  71,  -3,  -1, 116,  86,  -1, 101, 115, -11,  -3,  -1,  25
 long  145,  -3,  -1,   9, 144,  -1,  72, 132,  -7,  -5,  -1, 114,  -1,  70, 100
 long   40,  -1, 130,  24, -41, -27, -11,  -5,  -3,  -1,  55,  39,  23,  -1, 113
 long   -1,  85,   7,  -7,  -3,  -1, 112,  54,  -1,  99,  69,  -3,  -1,  84,  38
 long   -1,  98,  53,  -5,  -1, 129,  -1,   8, 128,  -3,  -1,  22,  97,  -1,   6
 long   96, -13,  -9,  -5,  -3,  -1,  83,  68,  37,  -1,  82,   5,  -1,  21,  81
 long   -7,  -3,  -1,  52,  67,  -1,  80,  36,  -3,  -1,  66,  51,  20, -19, -11
 long   -5,  -1,  65,  -1,   4,  64,  -3,  -1,  35,  50,  19,  -3,  -1,  49,   3
 long   -1,  48,  34,  -3,  -1,  18,  33,  -1,   2,  32,  -3,  -1,  17,   1,  16
 long    0
htab15:
 long -495,-445,-355,-263,-183,-115, -77, -43, -27, -13,  -7,  -3,  -1, 255, 239
 long   -1, 254, 223,  -1, 238,  -1, 253, 207,  -7,  -3,  -1, 252, 222,  -1, 237
 long  191,  -1, 251,  -1, 206, 236,  -7,  -3,  -1, 221, 175,  -1, 250, 190,  -3
 long   -1, 235, 205,  -1, 220, 159, -15,  -7,  -3,  -1, 249, 234,  -1, 189, 219
 long   -3,  -1, 143, 248,  -1, 204, 158,  -7,  -3,  -1, 233, 127,  -1, 247, 173
 long   -3,  -1, 218, 188,  -1, 111,  -1, 174,  15, -19, -11,  -3,  -1, 203, 246
 long   -3,  -1, 142, 232,  -1,  95, 157,  -3,  -1, 245, 126,  -1, 231, 172,  -9
 long   -3,  -1, 202, 187,  -3,  -1, 217, 141,  79,  -3,  -1, 244,  63,  -1, 243
 long  216, -33, -17,  -9,  -3,  -1, 230,  47,  -1, 242,  -1, 110, 240,  -3,  -1
 long   31, 241,  -1, 156, 201,  -7,  -3,  -1,  94, 171,  -1, 186, 229,  -3,  -1
 long  125, 215,  -1,  78, 228, -15,  -7,  -3,  -1, 140, 200,  -1,  62, 109,  -3
 long   -1, 214, 227,  -1, 155, 185,  -7,  -3,  -1,  46, 170,  -1, 226,  30,  -5
 long   -1, 225,  -1,  14, 224,  -1,  93, 213, -45, -25, -13,  -7,  -3,  -1, 124
 long  199,  -1,  77, 139,  -1, 212,  -1, 184, 154,  -7,  -3,  -1, 169, 108,  -1
 long  198,  61,  -1, 211, 210,  -9,  -5,  -3,  -1,  45,  13,  29,  -1, 123, 183
 long   -5,  -1, 209,  -1,  92, 208,  -1, 197, 138, -17,  -7,  -3,  -1, 168,  76
 long   -1, 196, 107,  -5,  -1, 182,  -1, 153,  12,  -1,  60, 195,  -9,  -3,  -1
 long  122, 167,  -1, 166,  -1, 192,  11,  -1, 194,  -1,  44,  91, -55, -29, -15
 long   -7,  -3,  -1, 181,  28,  -1, 137, 152,  -3,  -1, 193,  75,  -1, 180, 106
 long   -5,  -3,  -1,  59, 121, 179,  -3,  -1, 151, 136,  -1,  43,  90, -11,  -5
 long   -1, 178,  -1, 165,  27,  -1, 177,  -1, 176, 105,  -7,  -3,  -1, 150,  74
 long   -1, 164, 120,  -3,  -1, 135,  58, 163, -17,  -7,  -3,  -1,  89, 149,  -1
 long   42, 162,  -3,  -1,  26, 161,  -3,  -1,  10, 160, 104,  -7,  -3,  -1, 134
 long   73,  -1, 148,  57,  -5,  -1, 147,  -1, 119,   9,  -1,  88, 133, -53, -29
 long  -13,  -7,  -3,  -1,  41, 103,  -1, 118, 146,  -1, 145,  -1,  25, 144,  -7
 long   -3,  -1,  72, 132,  -1,  87, 117,  -3,  -1,  56, 131,  -1, 102,  71,  -7
 long   -3,  -1,  40, 130,  -1,  24, 129,  -7,  -3,  -1, 116,   8,  -1, 128,  86
 long   -3,  -1, 101,  55,  -1, 115,  70, -17,  -7,  -3,  -1,  39, 114,  -1, 100
 long   23,  -3,  -1,  85, 113,  -3,  -1,   7, 112,  54,  -7,  -3,  -1,  99,  69
 long   -1,  84,  38,  -3,  -1,  98,  22,  -3,  -1,   6,  96,  53, -33, -19,  -9
 long   -5,  -1,  97,  -1,  83,  68,  -1,  37,  82,  -3,  -1,  21,  81,  -3,  -1
 long    5,  80,  52,  -7,  -3,  -1,  67,  36,  -1,  66,  51,  -1,  65,  -1,  20
 long    4,  -9,  -3,  -1,  35,  50,  -3,  -1,  64,   3,  19,  -3,  -1,  49,  48
 long   34,  -9,  -7,  -3,  -1,  18,  33,  -1,   2,  32,  17,  -3,  -1,   1,  16
 long    0
htab16:
 long -509,-503,-461,-323,-103, -37, -27, -15,  -7,  -3,  -1, 239, 254,  -1, 223
 long  253,  -3,  -1, 207, 252,  -1, 191, 251,  -5,  -1, 175,  -1, 250, 159,  -3
 long   -1, 249, 248, 143,  -7,  -3,  -1, 127, 247,  -1, 111, 246, 255,  -9,  -5
 long   -3,  -1,  95, 245,  79,  -1, 244, 243, -53,  -1, 240,  -1,  63, -29, -19
 long  -13,  -7,  -5,  -1, 206,  -1, 236, 221, 222,  -1, 233,  -1, 234, 217,  -1
 long  238,  -1, 237, 235,  -3,  -1, 190, 205,  -3,  -1, 220, 219, 174, -11,  -5
 long   -1, 204,  -1, 173, 218,  -3,  -1, 126, 172, 202,  -5,  -3,  -1, 201, 125
 long   94, 189, 242, -93,  -5,  -3,  -1,  47,  15,  31,  -1, 241, -49, -25, -13
 long   -5,  -1, 158,  -1, 188, 203,  -3,  -1, 142, 232,  -1, 157, 231,  -7,  -3
 long   -1, 187, 141,  -1, 216, 110,  -1, 230, 156, -13,  -7,  -3,  -1, 171, 186
 long   -1, 229, 215,  -1,  78,  -1, 228, 140,  -3,  -1, 200,  62,  -1, 109,  -1
 long  214, 155, -19, -11,  -5,  -3,  -1, 185, 170, 225,  -1, 212,  -1, 184, 169
 long   -5,  -1, 123,  -1, 183, 208, 227,  -7,  -3,  -1,  14, 224,  -1,  93, 213
 long   -3,  -1, 124, 199,  -1,  77, 139, -75, -45, -27, -13,  -7,  -3,  -1, 154
 long  108,  -1, 198,  61,  -3,  -1,  92, 197,  13,  -7,  -3,  -1, 138, 168,  -1
 long  153,  76,  -3,  -1, 182, 122,  60, -11,  -5,  -3,  -1,  91, 137,  28,  -1
 long  192,  -1, 152, 121,  -1, 226,  -1,  46,  30, -15,  -7,  -3,  -1, 211,  45
 long   -1, 210, 209,  -5,  -1,  59,  -1, 151, 136,  29,  -7,  -3,  -1, 196, 107
 long   -1, 195, 167,  -1,  44,  -1, 194, 181, -23, -13,  -7,  -3,  -1, 193,  12
 long   -1,  75, 180,  -3,  -1, 106, 166, 179,  -5,  -3,  -1,  90, 165,  43,  -1
 long  178,  27, -13,  -5,  -1, 177,  -1,  11, 176,  -3,  -1, 105, 150,  -1,  74
 long  164,  -5,  -3,  -1, 120, 135, 163,  -3,  -1,  58,  89,  42, -97, -57, -33
 long  -19, -11,  -5,  -3,  -1, 149, 104, 161,  -3,  -1, 134, 119, 148,  -5,  -3
 long   -1,  73,  87, 103, 162,  -5,  -1,  26,  -1,  10, 160,  -3,  -1,  57, 147
 long   -1,  88, 133,  -9,  -3,  -1,  41, 146,  -3,  -1, 118,   9,  25,  -5,  -1
 long  145,  -1, 144,  72,  -3,  -1, 132, 117,  -1,  56, 131, -21, -11,  -5,  -3
 long   -1, 102,  40, 130,  -3,  -1,  71, 116,  24,  -3,  -1, 129, 128,  -3,  -1
 long    8,  86,  55,  -9,  -5,  -1, 115,  -1, 101,  70,  -1,  39, 114,  -5,  -3
 long   -1, 100,  85,   7,  23, -23, -13,  -5,  -1, 113,  -1, 112,  54,  -3,  -1
 long   99,  69,  -1,  84,  38,  -3,  -1,  98,  22,  -1,  97,  -1,   6,  96,  -9
 long   -5,  -1,  83,  -1,  53,  68,  -1,  37,  82,  -1,  81,  -1,  21,   5, -33
 long  -23, -13,  -7,  -3,  -1,  52,  67,  -1,  80,  36,  -3,  -1,  66,  51,  20
 long   -5,  -1,  65,  -1,   4,  64,  -1,  35,  50,  -3,  -1,  19,  49,  -3,  -1
 long    3,  48,  34,  -3,  -1,  18,  33,  -1,   2,  32,  -3,  -1,  17,   1,  16
 long    0
htab24:
 long -451,-117, -43, -25, -15,  -7,  -3,  -1, 239, 254,  -1, 223, 253,  -3,  -1
 long  207, 252,  -1, 191, 251,  -5,  -1, 250,  -1, 175, 159,  -1, 249, 248,  -9
 long   -5,  -3,  -1, 143, 127, 247,  -1, 111, 246,  -3,  -1,  95, 245,  -1,  79
 long  244, -71,  -7,  -3,  -1,  63, 243,  -1,  47, 242,  -5,  -1, 241,  -1,  31
 long  240, -25,  -9,  -1,  15,  -3,  -1, 238, 222,  -1, 237, 206,  -7,  -3,  -1
 long  236, 221,  -1, 190, 235,  -3,  -1, 205, 220,  -1, 174, 234, -15,  -7,  -3
 long   -1, 189, 219,  -1, 204, 158,  -3,  -1, 233, 173,  -1, 218, 188,  -7,  -3
 long   -1, 203, 142,  -1, 232, 157,  -3,  -1, 217, 126,  -1, 231, 172, 255,-235
 long -143, -77, -45, -25, -15,  -7,  -3,  -1, 202, 187,  -1, 141, 216,  -5,  -3
 long   -1,  14, 224,  13, 230,  -5,  -3,  -1, 110, 156, 201,  -1,  94, 186,  -9
 long   -5,  -1, 229,  -1, 171, 125,  -1, 215, 228,  -3,  -1, 140, 200,  -3,  -1
 long   78,  46,  62, -15,  -7,  -3,  -1, 109, 214,  -1, 227, 155,  -3,  -1, 185
 long  170,  -1, 226,  30,  -7,  -3,  -1, 225,  93,  -1, 213, 124,  -3,  -1, 199
 long   77,  -1, 139, 184, -31, -15,  -7,  -3,  -1, 212, 154,  -1, 169, 108,  -3
 long   -1, 198,  61,  -1, 211,  45,  -7,  -3,  -1, 210,  29,  -1, 123, 183,  -3
 long   -1, 209,  92,  -1, 197, 138, -17,  -7,  -3,  -1, 168, 153,  -1,  76, 196
 long   -3,  -1, 107, 182,  -3,  -1, 208,  12,  60,  -7,  -3,  -1, 195, 122,  -1
 long  167,  44,  -3,  -1, 194,  91,  -1, 181,  28, -57, -35, -19,  -7,  -3,  -1
 long  137, 152,  -1, 193,  75,  -5,  -3,  -1, 192,  11,  59,  -3,  -1, 176,  10
 long   26,  -5,  -1, 180,  -1, 106, 166,  -3,  -1, 121, 151,  -3,  -1, 160,   9
 long  144,  -9,  -3,  -1, 179, 136,  -3,  -1,  43,  90, 178,  -7,  -3,  -1, 165
 long   27,  -1, 177, 105,  -1, 150, 164, -17,  -9,  -5,  -3,  -1,  74, 120, 135
 long   -1,  58, 163,  -3,  -1,  89, 149,  -1,  42, 162,  -7,  -3,  -1, 161, 104
 long   -1, 134, 119,  -3,  -1,  73, 148,  -1,  57, 147, -63, -31, -15,  -7,  -3
 long   -1,  88, 133,  -1,  41, 103,  -3,  -1, 118, 146,  -1,  25, 145,  -7,  -3
 long   -1,  72, 132,  -1,  87, 117,  -3,  -1,  56, 131,  -1, 102,  40, -17,  -7
 long   -3,  -1, 130,  24,  -1,  71, 116,  -5,  -1, 129,  -1,   8, 128,  -1,  86
 long  101,  -7,  -5,  -1,  23,  -1,   7, 112, 115,  -3,  -1,  55,  39, 114, -15
 long   -7,  -3,  -1,  70, 100,  -1,  85, 113,  -3,  -1,  54,  99,  -1,  69,  84
 long   -7,  -3,  -1,  38,  98,  -1,  22,  97,  -5,  -3,  -1,   6,  96,  53,  -1
 long   83,  68, -51, -37, -23, -15,  -9,  -3,  -1,  37,  82,  -1,  21,  -1,   5
 long   80,  -1,  81,  -1,  52,  67,  -3,  -1,  36,  66,  -1,  51,  20,  -9,  -5
 long   -1,  65,  -1,   4,  64,  -1,  35,  50,  -1,  19,  49,  -7,  -5,  -3,  -1
 long    3,  48,  34,  18,  -1,  33,  -1,   2,  32,  -3,  -1,  17,   1,  -1,  16
 long    0
htaba:
 long  -29, -21, -13,  -7,  -3,  -1,  11,  15,  -1,  13,  14,  -3,  -1,   7,   5
 long    9,  -3,  -1,   6,   3,  -1,  10,  12,  -3,  -1,   2,   1,  -1,   4,   8
 long    0
htabb:
 long  -15,  -7,  -3,  -1,  15,  14,  -1,  13,  12,  -3,  -1,  11,  10,  -1,   9
 long    8,  -7,  -3,  -1,   7,   6,  -1,   5,   4,  -3,  -1,   3,   2,  -1,   1
 long    0

x_is_nonzero:	long 0
prev0:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 32*18
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//36 entries

prev1:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 32*18
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//36 entries

decoder_fraction:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 32*18
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//36 entries


output:		long 0, 0, 0, 0xC0FFEE, 0, 0, 0, 0
//out_alloc:		long 0
//temp_store:	long 0
//bitstream_p:	long 0x5a5a5a5a
				
				//576-378 longs = 32 * 6 + 6
y_reorder:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0
				

bb:				//channel 0, 2*512 floats
				//each row is 32 floats, 32 rows
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

				//channel 1, 2*512 floats
				//each row is 32 floats, 32 rows
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

//256 floats of 2^((i-210)/4)
quantab:
				float 1.57009245868378E-016, float 1.86716512307886E-16, float 2.22044604925031E-16, float 2.64057024024815E-16, float 3.14018491736755E-16, float 3.73433024615772E-16, float 4.44089209850063E-16, float 5.28114048049631E-16
				float 6.2803698347351E-16, float 7.46866049231544E-16, float 8.88178419700125E-16, float 1.05622809609926E-15, float 1.25607396694702E-15, float 1.49373209846309E-15, float 1.77635683940025E-15, float 2.11245619219852E-15
				float 2.51214793389404E-15, float 2.98746419692618E-15, float 3.5527136788005E-15, float 4.22491238439705E-15, float 5.02429586778808E-15, float 5.97492839385236E-15, float 7.105427357601E-15, float 8.4498247687941E-15
				float 1.00485917355762E-14, float 1.19498567877047E-14, float 1.4210854715202E-14, float 1.68996495375882E-14, float 2.00971834711523E-14, float 2.38997135754094E-14, float 2.8421709430404E-14, float 3.37992990751764E-14
				float 4.01943669423046E-14, float 4.77994271508188E-14, float 5.6843418860808E-14, float 6.75985981503528E-14, float 8.03887338846093E-14, float 9.55988543016377E-14, float 1.13686837721616E-13, float 1.35197196300706E-13
				float 1.60777467769219E-13, float 1.91197708603275E-13, float 2.27373675443232E-13, float 2.70394392601411E-13, float 3.21554935538437E-13, float 3.82395417206551E-13, float 4.54747350886464E-13, float 5.40788785202822E-13
				float 6.43109871076874E-13, float 7.64790834413102E-13, float 9.09494701772928E-13, float 1.08157757040564E-12, float 1.28621974215375E-12, float 1.5295816688262E-12, float 1.81898940354586E-12, float 2.16315514081129E-12
				float 2.5724394843075E-12, float 3.05916333765241E-12, float 3.63797880709171E-12, float 4.32631028162258E-12, float 5.14487896861499E-12, float 6.11832667530481E-12, float 7.27595761418343E-12, float 8.65262056324515E-12
				float 1.028975793723E-11, float 1.22366533506096E-11, float 1.45519152283669E-11, float 1.73052411264903E-11, float 2.057951587446E-11, float 2.44733067012192E-11, float 2.91038304567337E-11, float 3.46104822529806E-11
				float 4.115903174892E-11, float 4.89466134024385E-11, float 5.82076609134674E-11, float 6.92209645059612E-11, float 8.23180634978399E-11, float 9.7893226804877E-11, float 1.16415321826935E-10, float 1.38441929011922E-10
				float 1.6463612699568E-10, float 1.95786453609754E-10, float 2.3283064365387E-10, float 2.76883858023845E-10, float 3.2927225399136E-10, float 3.91572907219508E-10, float 4.65661287307739E-10, float 5.5376771604769E-10
				float 6.58544507982719E-10, float 7.83145814439016E-10, float 9.31322574615479E-10, float 1.10753543209538E-09, float 1.31708901596544E-09, float 1.56629162887803E-09, float 1.86264514923096E-09, float 2.21507086419076E-09
				float 2.63417803193088E-09, float 3.13258325775606E-09, float 3.72529029846191E-09, float 4.43014172838152E-09, float 5.26835606386175E-09, float 6.26516651551213E-09, float 7.45058059692383E-09, float 8.86028345676304E-09
				float 1.05367121277235E-08, float 1.25303330310243E-08, float 1.49011611938477E-08, float 1.77205669135261E-08, float 2.1073424255447E-08, float 2.50606660620485E-08, float 2.98023223876953E-08, float 3.54411338270522E-08
				float 4.2146848510894E-08, float 5.0121332124097E-08, float 5.96046447753906E-08, float 7.08822676541043E-08, float 8.42936970217881E-08, float 1.00242664248194E-07, float 1.19209289550781E-07, float 1.41764535308209E-07
				float 1.68587394043576E-07, float 2.00485328496388E-07, float 2.38418579101563E-07, float 2.83529070616417E-07, float 3.37174788087152E-07, float 4.00970656992776E-07, float 4.76837158203125E-07, float 5.67058141232834E-07
				float 6.74349576174304E-07, float 8.01941313985552E-07, float 9.5367431640625E-07, float 1.13411628246567E-06, float 1.34869915234861E-06, float 1.6038826279711E-06, float 1.9073486328125E-06, float 2.26823256493134E-06
				float 2.69739830469722E-06, float 3.20776525594221E-06, float 3.814697265625E-06, float 4.53646512986268E-06, float 5.39479660939444E-06, float 6.41553051188442E-06, float 7.62939453125E-06, float 9.07293025972535E-06
				float 1.07895932187889E-05, float 1.28310610237688E-05, float 0.0000152587890625, float 1.81458605194507E-05, float 2.15791864375777E-05, float 2.56621220475377E-05, float 0.000030517578125, float 3.62917210389014E-05
				float 4.31583728751555E-05, float 5.13242440950754E-05, float 0.00006103515625, float 7.25834420778028E-05, float 8.6316745750311E-05, float 0.000102648488190151, float 0.0001220703125, float 0.000145166884155606
				float 0.000172633491500622, float 0.000205296976380301, float 0.000244140625, float 0.000290333768311211, float 0.000345266983001244, float 0.000410593952760603, float 0.00048828125, float 0.000580667536622422
				float 0.000690533966002488, float 0.000821187905521206, float 0.0009765625, float 0.00116133507324484, float 0.00138106793200498, float 0.00164237581104241, float 0.001953125, float 0.00232267014648969
				float 0.00276213586400995, float 0.00328475162208482, float 0.00390625, float 0.00464534029297938, float 0.0055242717280199, float 0.00656950324416964, float 0.0078125, float 0.00929068058595876
				float 0.0110485434560398, float 0.0131390064883393, float 0.015625, float 0.0185813611719175, float 0.0220970869120796, float 0.0262780129766786, float 0.03125, float 0.037162722343835
				float 0.0441941738241592, float 0.0525560259533572, float 0.0625, float 0.0743254446876701, float 0.0883883476483184, float 0.105112051906714, float 0.125, float 0.14865088937534
				float 0.176776695296637, float 0.210224103813429, float 0.25, float 0.29730177875068, float 0.353553390593274, float 0.420448207626857, float 0.5, float 0.594603557501361
				float 0.707106781186548, float 0.840896415253715, float 1.0, float 1.18920711500272, float 1.4142135623731, float 1.68179283050743, float 2.0, float 2.37841423000544
				float 2.82842712474619, float 3.36358566101486, float 4.0, float 4.75682846001088, float 5.65685424949238, float 6.72717132202972, float 8.0, float 9.51365692002177
				float 11.3137084989848, float 13.4543426440594, float 16.0, float 19.0273138400435, float 22.6274169979695, float 26.9086852881189, float 32.0, float 38.0546276800871
				float 45.254833995939, float 53.8173705762377, float 64.0, float 76.1092553601742, float 90.5096679918781, float 107.634741152475, float 128.0, float 152.218510720348
				float 181.019335983756, float 215.269482304951, float 256.0, float 304.437021440697, float 362.038671967512, float 430.538964609902, float 512.0, float 608.874042881393
				float 724.077343935025, float 861.077929219804, float 1024.0, float 1217.74808576279, float 1448.15468787005, float 1722.15585843961, float 2048.0, float 2435.49617152557


//this is 8206 floats of i^(4/3) so comes last as the table is so large
pow43tab:
				float 0.0, float 1.0, float 2.51984209978975, float 4.32674871092223, float 6.3496042078728, float 8.54987973338348, float 10.9027235569928, float 13.3905182794067
				float 16.0, float 18.7207544074671, float 21.5443469003188, float 24.4637809962625, float 27.47314182128, float 30.5673509403698, float 33.7419916984532, float 36.993181114957
				float 40.3174735966359, float 43.71178704119, float 47.1733450957601, float 50.6996313257169, float 54.2883523318981, float 57.9374077040035, float 61.6448652744185, float 65.408940536586
				float 69.2279793747556, float 73.1004434553216, float 77.0248977785916, float 81.0, float 85.0244912125185, float 89.0971879448895, float 93.2169751786158, float 97.3828002241332
				float 101.593667325965, float 105.848632889862, float 110.146801243434, float 114.487320856601, float 118.869380960207, float 123.2922085109, float 127.755065458361, float 132.257246277552
				float 136.798075734136, float 141.376906855692, float 145.993119085231, float 150.646116596629, float 155.335326754347, float 160.060198702053, float 164.820202066734, float 169.614825766519
				float 174.443576911885, float 179.305979791126, float 184.201574932019, float 189.129918232576, float 194.090580154497, float 199.083144973717, float 204.107210082969, float 209.162385341876
				float 214.248292470508, float 219.364564482778, float 224.510845156412, float 229.686788536522, float 234.892058470132, float 240.126328169233, float 245.389279800185, float 250.680604097473
				float 256.0, float 261.347174308289, float 266.721841361064, float 272.12372272986, float 277.55254693038, float 283.008049149462, float 288.489970986599, float 293.998060209022
				float 299.532070519474, float 305.09176133583, float 310.676897581822, float 316.287249488156, float 321.922592403372, float 327.582706613855, float 333.267377172437, float 338.97639373507
				float 344.709550405101, float 350.4666455847, float 356.247481833026, float 362.051865730751, float 367.879607750583, float 373.730522133445, float 379.604426770021, float 385.501143087346
				float 391.420495940199, float 397.362313507024, float 403.326427190145, float 409.312671520063, float 415.320884063608, float 421.350905335765, float 427.402578714976, float 433.475750361762
				float 439.570269140479, float 445.685986544083, float 451.822756621728, float 457.980435909091, float 464.158883361278, float 470.357960288187, float 476.577530292236, float 482.81745920832
				float 489.077615045917, float 495.357867933236, float 501.658090063317, float 507.978155642004, float 514.317940837696, float 520.677323732817, float 527.056184276906, float 533.454404241292
				float 539.871867175251, float 546.308458363615, float 552.764064785746, float 559.238575075842, float 565.731879484504, float 572.243869841523, float 578.774439519834, float 585.323483400588
				float 591.890897839313, float 598.476580633093, float 605.08043098876, float 611.702349492036, float 618.342238077592, float 625.0, float 631.675539805537, float 638.368763304812
				float 645.079577546175, float 651.807890789904, float 658.553612483115, float 665.316653235384, float 672.096924795052, float 678.894340026194, float 685.708812886214, float 692.540258404062
				float 699.38859265904, float 706.253732760181, float 713.13559682618, float 720.03410396586, float 726.949174259154, float 733.880728738582, float 740.828689371215, float 747.792979041105
				float 754.773521532162, float 761.77024151147, float 768.78306451303, float 775.811916921899, float 782.856725958743, float 789.917419664754, float 796.993926886958, float 804.086177263863
				float 811.194101211471, float 818.317629909622, float 825.456695288666, float 832.611230016449, float 839.781167485616, float 846.966441801206, float 854.166987768535, float 861.382740881371
				float 868.61363731037, float 875.859613891782, float 883.12060811642, float 890.396558118868, float 897.687402666942, float 904.993081151382, float 912.313533575772, float 919.648700546688
				float 926.998523264056, float 934.362943511729, float 941.741903648259, float 949.135346597874, float 956.543215841652, float 963.965455408874, float 971.402009868565, float 978.852824321222
				float 986.317844390696, float 993.797016216264, float 1001.29028644485, float 1008.79760222342, float 1016.31891119151, float 1023.85416147395, float 1031.40330167367, float 1038.96628086471
				float 1046.54304858538, float 1054.13355483144, float 1061.73775004958, float 1069.35558513094, float 1076.9870114047, float 1084.63198063194, float 1092.29044499952, float 1099.96235711405
				float 1107.64766999609, float 1115.34633707436, float 1123.05831218011, float 1130.78354954155, float 1138.52200377849, float 1146.2736298969, float 1154.03838328379, float 1161.81621970199
				float 1169.60709528515, float 1177.41096653278, float 1185.22779030541, float 1193.05752381978, float 1200.9001246442, float 1208.75555069392, float 1216.62376022664, float 1224.50471183805
				float 1232.39836445747, float 1240.30467734359, float 1248.22361008026, float 1256.15512257234, float 1264.09917504166, float 1272.05572802302, float 1280.02474236027, float 1288.00617920244
				float 1296.0, float 1304.00616650107, float 1312.02464074781, float 1320.05538507279, float 1328.09836209549, float 1336.15353471877, float 1344.22086612546, float 1352.30031977505
				float 1360.3918594003, float 1368.49544900401, float 1376.61105285587, float 1384.73863548922, float 1392.87816169803, float 1401.02959653379, float 1409.19290530254, float 1417.36805356191
				float 1425.55500711823, float 1433.75373202364, float 1441.96419457327, float 1450.18636130253, float 1458.42019898429, float 1466.66567462628, float 1474.92275546839, float 1483.19140898008
				float 1491.47160285785, float 1499.76330502266, float 1508.06648361748, float 1516.38110700484, float 1524.7071437644, float 1533.04456269061, float 1541.39333279033, float 1549.75342328056
				float 1558.12480358613, float 1566.50744333751, float 1574.90131236859, float 1583.30638071448, float 1591.72261860941, float 1600.14999648459, float 1608.58848496618, float 1617.03805487317
				float 1625.49867721544, float 1633.97032319169, float 1642.45296418756, float 1650.94657177363, float 1659.45111770358, float 1667.96657391222, float 1676.49291251374, float 1685.0301057998
				float 1693.5781262378, float 1702.13694646903, float 1710.70653930698, float 1719.28687773559, float 1727.87793490753, float 1736.47968414256, float 1745.09209892583, float 1753.71515290626
				float 1762.34881989495, float 1770.99307386356, float 1779.64788894276, float 1788.31323942066, float 1796.98909974129, float 1805.67544450313, float 1814.37224845756, float 1823.07948650743
				float 1831.79713370561, float 1840.52516525354, float 1849.26355649986, float 1858.01228293896, float 1866.77132020965, float 1875.5406440938, float 1884.32023051497, float 1893.11005553712
				float 1901.9100953633, float 1910.72032633435, float 1919.54072492761, float 1928.37126775571, float 1937.21193156531, float 1946.06269323585, float 1954.92352977839, float 1963.79441833435
				float 1972.6753361744, float 1981.56626069726, float 1990.46716942853, float 1999.37804001961, float 2008.29885024651, float 2017.2295780088, float 2026.17020132848, float 2035.12069834892
				float 2044.08104733377, float 2053.05122666591, float 2062.03121484643, float 2071.02099049356, float 2080.0205323417, float 2089.02981924034, float 2098.04883015317, float 2107.077544157
				float 2116.11594044084, float 2125.16399830493, float 2134.2216971598, float 2143.28901652531, float 2152.36593602975, float 2161.4524354089, float 2170.54849450516, float 2179.65409326661
				float 2188.76921174617, float 2197.89383010069, float 2207.0279285901, float 2216.17148757658, float 2225.32448752368, float 2234.48690899548, float 2243.65873265581, float 2252.8399392674
				float 2262.03050969107, float 2271.23042488495, float 2280.43966590369, float 2289.65821389765, float 2298.88605011218, float 2308.12315588679, float 2317.36951265448, float 2326.6251019409
				float 2335.88990536369, float 2345.16390463171, float 2354.44708154432, float 2363.73941799068, float 2373.04089594902, float 2382.35149748597, float 2391.67120475586, float 2401.0
				float 2410.33786554607, float 2419.68478380738, float 2429.04073728227, float 2438.40570855342, float 2447.77968028719, float 2457.162635233, float 2466.55455622271, float 2475.95542616996
				float 2485.36522806955, float 2494.78394499685, float 2504.21156010717, float 2513.64805663518, float 2523.09341789427, float 2532.547627276, float 2542.01066824952, float 2551.48252436095
				float 2560.96317923284, float 2570.45261656362, float 2579.95082012698, float 2589.45777377137, float 2598.97346141945, float 2608.49786706748, float 2618.03097478488, float 2627.57276871363
				float 2637.12323306774, float 2646.68235213276, float 2656.25011026528, float 2665.82649189233, float 2675.41148151098, float 2685.00506368777, float 2694.60722305823, float 2704.21794432639
				float 2713.8372122643, float 2723.46501171153, float 2733.10132757471, float 2742.74614482705, float 2752.39944850786, float 2762.06122372211, float 2771.73145563994, float 2781.41012949624
				float 2791.09723059017, float 2800.79274428471, float 2810.49665600626, float 2820.20895124415, float 2829.92961555025, float 2839.65863453849, float 2849.39599388449, float 2859.14167932511
				float 2868.89567665801, float 2878.65797174128, float 2888.42855049302, float 2898.2073988909, float 2907.99450297178, float 2917.78984883134, float 2927.59342262364, float 2937.40521056073
				float 2947.22519891231, float 2957.05337400529, float 2966.88972222344, float 2976.73423000701, float 2986.58688385234, float 2996.44767031152, float 3006.31657599199, float 3016.19358755619
				float 3026.07869172121, float 3035.97187525841, float 3045.87312499309, float 3055.78242780412, float 3065.6997706236, float 3075.62514043653, float 3085.55852428042, float 3095.49990924503
				float 3105.44928247195, float 3115.40663115433, float 3125.37194253651, float 3135.34520391373, float 3145.32640263177, float 3155.31552608666, float 3165.31256172433, float 3175.31749704032
				float 3185.33031957947, float 3195.35101693557, float 3205.37957675111, float 3215.41598671693, float 3225.46023457193, float 3235.51230810279, float 3245.57219514366, float 3255.63988357583
				float 3265.71536132751, float 3275.79861637348, float 3285.88963673483, float 3295.98841047867, float 3306.09492571784, float 3316.20917061065, float 3326.33113336059, float 3336.46080221604
				float 3346.59816547002, float 3356.74321145993, float 3366.89592856723, float 3377.05630521722, float 3387.22432987878, float 3397.39999106408, float 3407.58327732831, float 3417.77417726949
				float 3427.97267952812, float 3438.17877278701, float 3448.39244577099, float 3458.61368724664, float 3468.84248602211, float 3479.0788309468, float 3489.32271091116, float 3499.57411484643
				float 3509.83303172445, float 3520.09945055732, float 3530.37336039728, float 3540.65475033639, float 3550.94360950635, float 3561.23992707826, float 3571.54369226235, float 3581.85489430783
				float 3592.17352250259, float 3602.49956617304, float 3612.83301468383, float 3623.17385743768, float 3633.52208387515, float 3643.8776834744, float 3654.24064575101, float 3664.61096025775
				float 3674.98861658436, float 3685.37360435735, float 3695.76591323983, float 3706.16553293122, float 3716.57245316714, float 3726.98666371913, float 3737.40815439449, float 3747.83691503608
				float 3758.27293552211, float 3768.71620576594, float 3779.16671571591, float 3789.62445535511, float 3800.08941470121, float 3810.56158380628, float 3821.04095275657, float 3831.52751167235
				float 3842.02125070772, float 3852.5221600504, float 3863.03022992157, float 3873.54545057569, float 3884.06781230031, float 3894.59730541589, float 3905.13392027563, float 3915.67764726527
				float 3926.22847680296, float 3936.78639933903, float 3947.35140535587, float 3957.92348536771, float 3968.5026299205, float 3979.08882959168, float 3989.68207499008, float 4000.28235675569
				float 4010.88966555956, float 4021.50399210357, float 4032.12532712029, float 4042.75366137287, float 4053.38898565479, float 4064.03129078976, float 4074.68056763155, float 4085.33680706382
				float 4096.0, float 4106.67013738307, float 4117.34721018548, float 4128.03120940893, float 4138.72212608427, float 4149.41995127133, float 4160.12467605876, float 4170.8362915639
				float 4181.55478893262, float 4192.28015933918, float 4203.01239398607, float 4213.75148410391, float 4224.49742095124, float 4235.25019581443, float 4246.00980000751, float 4256.77622487206
				float 4267.54946177703, float 4278.32950211864, float 4289.11633732022, float 4299.90995883207, float 4310.71035813135, float 4321.51752672191, float 4332.3314561342, float 4343.15213792509
				float 4353.97956367777, float 4364.81372500161, float 4375.65461353202, float 4386.50222093036, float 4397.35653888375, float 4408.21755910498, float 4419.0852733324, float 4429.95967332975
				float 4440.84075088607, float 4451.72849781556, float 4462.62290595746, float 4473.52396717592, float 4484.43167335991, float 4495.34601642306, float 4506.26698830355, float 4517.19458096401
				float 4528.12878639139, float 4539.06959659683, float 4550.01700361556, float 4560.97099950678, float 4571.93157635355, float 4582.89872626265, float 4593.8724413645, float 4604.85271381304
				float 4615.83953578558, float 4626.83289948276, float 4637.83279712836, float 4648.83922096925, float 4659.85216327526, float 4670.87161633905, float 4681.89757247604, float 4692.93002402428
				float 4703.96896334436, float 4715.01438281927, float 4726.06627485433, float 4737.12463187707, float 4748.18944633714, float 4759.26071070618, float 4770.33841747775, float 4781.4225591672
				float 4792.51312831159, float 4803.61011746956, float 4814.71351922129, float 4825.82332616831, float 4836.93953093351, float 4848.06212616094, float 4859.19110451576, float 4870.32645868418
				float 4881.46818137328, float 4892.61626531098, float 4903.77070324592, float 4914.93148794738, float 4926.09861220515, float 4937.2720688295, float 4948.45185065101, float 4959.63795052056
				float 4970.83036130915, float 4982.0290759079, float 4993.2340872279, float 5004.44538820012, float 5015.66297177535, float 5026.8868309241, float 5038.11695863651, float 5049.35334792227
				float 5060.59599181049, float 5071.8448833497, float 5083.10001560767, float 5094.3613816714, float 5105.62897464698, float 5116.90278765953, float 5128.18281385312, float 5139.46904639069
				float 5150.76147845395, float 5162.06010324329, float 5173.36491397775, float 5184.67590389486, float 5195.99306625063, float 5207.31639431944, float 5218.64588139394, float 5229.98152078502
				float 5241.32330582169, float 5252.67122985099, float 5264.02528623798, float 5275.3854683656, float 5286.75176963459, float 5298.12418346346, float 5309.5027032884, float 5320.88732256315
				float 5332.278034759, float 5343.67483336468, float 5355.07771188627, float 5366.48666384717, float 5377.90168278799, float 5389.32276226646, float 5400.74989585744, float 5412.18307715274
				float 5423.62229976112, float 5435.06755730822, float 5446.51884343643, float 5457.97615180489, float 5469.43947608936, float 5480.9088099822, float 5492.38414719226, float 5503.86548144485
				float 5515.35280648162, float 5526.84611606055, float 5538.34540395585, float 5549.85066395787, float 5561.3618898731, float 5572.87907552404, float 5584.40221474915, float 5595.9313014028
				float 5607.4663293552, float 5619.00729249233, float 5630.55418471587, float 5642.10699994313, float 5653.66573210702, float 5665.23037515594, float 5676.80092305377, float 5688.37736977973
				float 5699.95970932842, float 5711.54793570965, float 5723.14204294846, float 5734.74202508502, float 5746.34787617458, float 5757.9595902874, float 5769.5771615087, float 5781.20058393859
				float 5792.82985169202, float 5804.46495889872, float 5816.10589970311, float 5827.75266826431, float 5839.405258756, float 5851.06366536642, float 5862.72788229829, float 5874.39790376876
				float 5886.07372400932, float 5897.75533726581, float 5909.4427377983, float 5921.13591988105, float 5932.83487780249, float 5944.5396058651, float 5956.25009838543, float 5967.96634969396
				float 5979.68835413512, float 5991.4161060672, float 6003.1495998623, float 6014.88882990627, float 6026.63379059867, float 6038.3844763527, float 6050.14088159518, float 6061.90300076644
				float 6073.67082832033, float 6085.44435872413, float 6097.22358645849, float 6109.00850601742, float 6120.7991119082, float 6132.59539865135, float 6144.39736078055, float 6156.20499284265
				float 6168.01828939754, float 6179.83724501816, float 6191.66185429043, float 6203.4921118132, float 6215.3280121982, float 6227.16955006999, float 6239.01672006592, float 6250.86951683606
				float 6262.72793504319, float 6274.59196936271, float 6286.46161448261, float 6298.33686510343, float 6310.21771593822, float 6322.10416171245, float 6333.996197164, float 6345.89381704313
				float 6357.79701611238, float 6369.70578914656, float 6381.6201309327, float 6393.54003627001, float 6405.4654999698, float 6417.3965168555, float 6429.33308176253, float 6441.27518953835
				float 6453.22283504231, float 6465.17601314572, float 6477.13471873172, float 6489.09894669525, float 6501.06869194304, float 6513.04394939356, float 6525.02471397694, float 6537.01098063496
				float 6549.002744321, float 6561.0, float 6573.0027426484, float 6585.01096725413, float 6597.02466881654, float 6609.04384234637, float 6621.0684828657, float 6633.09858540794
				float 6645.13414501773, float 6657.17515675096, float 6669.22161567469, float 6681.27351686713, float 6693.3308554176, float 6705.39362642646, float 6717.46182500511, float 6729.53544627593
				float 6741.61448537223, float 6753.69893743826, float 6765.7887976291, float 6777.88406111066, float 6789.98472305967, float 6802.09077866356, float 6814.20222312052, float 6826.31905163938
				float 6838.44125943962, float 6850.56884175131, float 6862.70179381508, float 6874.8401108821, float 6886.983788214, float 6899.13282108287, float 6911.28720477122, float 6923.44693457192
				float 6935.61200578819, float 6947.78241373354, float 6959.95815373175, float 6972.13922111685, float 6984.32561123304, float 6996.51731943469, float 7008.71434108628, float 7020.91667156239
				float 7033.12430624767, float 7045.33724053675, float 7057.55546983427, float 7069.77898955481, float 7082.00779512287, float 7094.24188197283, float 7106.4812455489, float 7118.72588130513
				float 7130.97578470532, float 7143.23095122304, float 7155.49137634155, float 7167.7570555538, float 7180.02798436239, float 7192.30415827951, float 7204.58557282696, float 7216.87222353605
				float 7229.16410594764, float 7241.46121561205, float 7253.76354808905, float 7266.07109894784, float 7278.38386376699, float 7290.70183813443, float 7303.02501764742, float 7315.35339791249
				float 7327.68697454546, float 7340.02574317135, float 7352.36969942438, float 7364.71883894795, float 7377.0731573946, float 7389.43265042594, float 7401.79731371269, float 7414.16714293461
				float 7426.54213378044, float 7438.92228194795, float 7451.30758314384, float 7463.69803308372, float 7476.09362749212, float 7488.49436210243, float 7500.90023265686, float 7513.31123490645
				float 7525.72736461099, float 7538.14861753905, float 7550.57498946787, float 7563.00647618344, float 7575.44307348037, float 7587.88477716193, float 7600.33158303996, float 7612.78348693491
				float 7625.24048467578, float 7637.70257210006, float 7650.16974505377, float 7662.64199939136, float 7675.11933097575, float 7687.60173567824, float 7700.08920937854, float 7712.58174796471
				float 7725.07934733313, float 7737.58200338847, float 7750.08971204371, float 7762.60246922006, float 7775.12027084694, float 7787.64311286197, float 7800.17099121096, float 7812.70390184785
				float 7825.24184073468, float 7837.7848038416, float 7850.33278714682, float 7862.88578663658, float 7875.44379830516, float 7888.00681815478, float 7900.57484219568, float 7913.14786644599
				float 7925.72588693177, float 7938.30889968697, float 7950.8969007534, float 7963.48988618069, float 7976.0878520263, float 7988.69079435547, float 8001.29870924121, float 8013.91159276426
				float 8026.52944101307, float 8039.15225008379, float 8051.78001608023, float 8064.41273511384, float 8077.05040330368, float 8089.69301677642, float 8102.3405716663, float 8114.99306411507
				float 8127.65049027206, float 8140.31284629405, float 8152.98012834531, float 8165.65233259758, float 8178.32945523001, float 8191.01149242915, float 8203.69844038897, float 8216.39029531075
				float 8229.08705340314, float 8241.78871088211, float 8254.4952639709, float 8267.20670890002, float 8279.92304190726, float 8292.6442592376, float 8305.37035714323, float 8318.10133188354
				float 8330.83717972507, float 8343.57789694147, float 8356.32347981356, float 8369.0739246292, float 8381.82922768335, float 8394.58938527802, float 8407.35439372224, float 8420.12424933206
				float 8432.8989484305, float 8445.67848734755, float 8458.46286242016, float 8471.25206999218, float 8484.04610641438, float 8496.84496804441, float 8509.64865124676, float 8522.4571523928
				float 8535.27046786067, float 8548.08859403534, float 8560.91152730857, float 8573.73926407884, float 8586.5718007514, float 8599.40913373821, float 8612.25125945792, float 8625.09817433586
				float 8637.94987480402, float 8650.80635730104, float 8663.66761827216, float 8676.53365416922, float 8689.40446145066, float 8702.28003658146, float 8715.16037603314, float 8728.04547628375
				float 8740.93533381784, float 8753.82994512644, float 8766.72930670703, float 8779.63341506357, float 8792.54226670641, float 8805.45585815233, float 8818.37418592448, float 8831.29724655239
				float 8844.22503657194, float 8857.15755252533, float 8870.09479096108, float 8883.03674843403, float 8895.98342150525, float 8908.93480674211, float 8921.89090071819, float 8934.8517000133
				float 8947.81720121347, float 8960.7874009109, float 8973.76229570396, float 8986.74188219717, float 8999.72615700119, float 9012.71511673279, float 9025.70875801483, float 9038.70707747625
				float 9051.71007175207, float 9064.71773748333, float 9077.73007131712, float 9090.74706990652, float 9103.76872991062, float 9116.79504799447, float 9129.82602082908, float 9142.86164509142
				float 9155.90191746437, float 9168.94683463672, float 9181.99639330314, float 9195.05059016419, float 9208.10942192627, float 9221.17288530166, float 9234.24097700841, float 9247.31369377041
				float 9260.39103231734, float 9273.47298938465, float 9286.55956171354, float 9299.65074605098, float 9312.74653914962, float 9325.84693776787, float 9338.9519386698, float 9352.06153862517
				float 9365.17573440941, float 9378.29452280358, float 9391.41790059438, float 9404.54586457413, float 9417.67841154073, float 9430.81553829768, float 9443.95724165404, float 9457.10351842443
				float 9470.254365429, float 9483.40977949343, float 9496.5697574489, float 9509.73429613207, float 9522.90339238509, float 9536.07704305558, float 9549.25524499658, float 9562.43799506658
				float 9575.62529012948, float 9588.81712705457, float 9602.01350271655, float 9615.21441399546, float 9628.41985777673, float 9641.62983095109, float 9654.84433041464, float 9668.06335306877
				float 9681.28689582017, float 9694.5149555808, float 9707.74752926792, float 9720.98461380402, float 9734.22620611683, float 9747.47230313932, float 9760.72290180966, float 9773.97799907123
				float 9787.23759187258, float 9800.50167716743, float 9813.77025191467, float 9827.04331307831, float 9840.3208576275, float 9853.60288253651, float 9866.8893847847, float 9880.18036135651
				float 9893.47580924147, float 9906.77572543415, float 9920.08010693419, float 9933.38895074623, float 9946.70225387994, float 9960.02001335002, float 9973.34222617613, float 9986.66888938292
				float 10000.0, float 10013.3355550619, float 10026.6755516082, float 10040.0199866833, float 10053.3688573365, float 10066.7221606221, float 10080.0798935991, float 10093.4420533317
				float 10106.8086368886, float 10120.1796413436, float 10133.5550637751, float 10146.9349012666, float 10160.3191509062, float 10173.7078097869, float 10187.1008750065, float 10200.4983436674
				float 10213.900212877, float 10227.3064797472, float 10240.7171413949, float 10254.1321949415, float 10267.5516375131, float 10280.9754662408, float 10294.40367826, float 10307.8362707111
				float 10321.2732407388, float 10334.7145854928, float 10348.1603021272, float 10361.6103878009, float 10375.0648396772, float 10388.5236549243, float 10401.9868307146, float 10415.4543642254
				float 10428.9262526385, float 10442.40249314, float 10455.883082921, float 10469.3680191767, float 10482.857299107, float 10496.3509199164, float 10509.8488788137, float 10523.3511730122
				float 10536.8577997298, float 10550.3687561889, float 10563.8840396161, float 10577.4036472427, float 10590.9275763042, float 10604.4558240407, float 10617.9883876966, float 10631.5252645206
				float 10645.0664517661, float 10658.6119466906, float 10672.161746556, float 10685.7158486285, float 10699.2742501788, float 10712.8369484817, float 10726.4039408167, float 10739.9752244671
				float 10753.5507967208, float 10767.13065487, float 10780.7147962111, float 10794.3032180446, float 10807.8959176755, float 10821.4928924129, float 10835.0941395702, float 10848.699656465
				float 10862.3094404191, float 10875.9234887584, float 10889.5417988131, float 10903.1643679176, float 10916.7911934104, float 10930.4222726341, float 10944.0576029355, float 10957.6971816656
				float 10971.3410061794, float 10984.9890738362, float 10998.6413819991, float 11012.2979280357, float 11025.9587093172, float 11039.6237232193, float 11053.2929671215, float 11066.9664384075
				float 11080.644134465, float 11094.3260526856, float 11108.0121904651, float 11121.7025452033, float 11135.3971143039, float 11149.0958951746, float 11162.7988852271, float 11176.5060818773
				float 11190.2174825446, float 11203.9330846528, float 11217.6528856294, float 11231.3768829059, float 11245.1050739177, float 11258.8374561041, float 11272.5740269083, float 11286.3147837776
				float 11300.0597241629, float 11313.8088455191, float 11327.562145305, float 11341.3196209831, float 11355.08127002, float 11368.847089886, float 11382.6170780552, float 11396.3912320056
				float 11410.1695492189, float 11423.9520271807, float 11437.7386633803, float 11451.529455311, float 11465.3244004697, float 11479.123496357, float 11492.9267404773, float 11506.7341303389
				float 11520.5456634538, float 11534.3613373375, float 11548.1811495094, float 11562.0050974927, float 11575.8331788142, float 11589.6653910043, float 11603.5017315971, float 11617.3421981307
				float 11631.1867881465, float 11645.0354991896, float 11658.8883288089, float 11672.7452745569, float 11686.6063339897, float 11700.471504667, float 11714.3407841521, float 11728.214170012
				float 11742.0916598173, float 11755.9732511421, float 11769.8589415641, float 11783.7487286646, float 11797.6426100285, float 11811.5405832442, float 11825.4426459037, float 11839.3487956024
				float 11853.2590299394, float 11867.1733465173, float 11881.0917429422, float 11895.0142168235, float 11908.9407657744, float 11922.8713874115, float 11936.8060793548, float 11950.7448392279
				float 11964.6876646577, float 11978.6345532747, float 11992.5855027127, float 12006.5405106092, float 12020.4995746048, float 12034.4626923439, float 12048.4298614739, float 12062.401079646
				float 12076.3763445146, float 12090.3556537374, float 12104.3390049758, float 12118.3263958942, float 12132.3178241606, float 12146.3132874465, float 12160.3127834263, float 12174.3163097782
				float 12188.3238641835, float 12202.335444327, float 12216.3510478965, float 12230.3706725835, float 12244.3943160827, float 12258.4219760918, float 12272.4536503123, float 12286.4893364486
				float 12300.5290322085, float 12314.5727353031, float 12328.6204434467, float 12342.6721543569, float 12356.7278657546, float 12370.7875753639, float 12384.8512809121, float 12398.9189801296
				float 12412.9906707504, float 12427.0663505113, float 12441.1460171526, float 12455.2296684176, float 12469.3173020529, float 12483.4089158083, float 12497.5045074366, float 12511.6040746941
				float 12525.7076153399, float 12539.8151271364, float 12553.9266078493, float 12568.0420552473, float 12582.1614671021, float 12596.2848411887, float 12610.4121752853, float 12624.543467173
				float 12638.6787146361, float 12652.817915462, float 12666.9610674412, float 12681.1081683673, float 12695.259216037, float 12709.4142082499, float 12723.5731428088, float 12737.7360175197
				float 12751.9028301913, float 12766.0735786357, float 12780.2482606678, float 12794.4268741056, float 12808.6094167701, float 12822.7958864855, float 12836.9862810787, float 12851.1805983797
				float 12865.3788362218, float 12879.5809924409, float 12893.787064876, float 12907.9970513691, float 12922.2109497653, float 12936.4287579125, float 12950.6504736615, float 12964.8760948663
				float 12979.1056193835, float 12993.339045073, float 13007.5763697975, float 13021.8175914224, float 13036.0627078163, float 13050.3117168506, float 13064.5646163997, float 13078.8214043408
				float 13093.082078554, float 13107.3466369222, float 13121.6150773315, float 13135.8873976705, float 13150.1635958308, float 13164.4436697071, float 13178.7276171965, float 13193.0154361994
				float 13207.3071246186, float 13221.6026803603, float 13235.9021013329, float 13250.2053854481, float 13264.5125306202, float 13278.8235347664, float 13293.1383958067, float 13307.4571116637
				float 13321.7796802632, float 13336.1060995334, float 13350.4363674054, float 13364.7704818133, float 13379.1084406936, float 13393.4502419858, float 13407.7958836322, float 13422.1453635776
				float 13436.4986797699, float 13450.8558301593, float 13465.2168126993, float 13479.5816253455, float 13493.9502660568, float 13508.3227327944, float 13522.6990235223, float 13537.0791362075
				float 13551.4630688193, float 13565.8508193299, float 13580.2423857142, float 13594.6377659497, float 13609.0369580167, float 13623.4399598979, float 13637.8467695791, float 13652.2573850483
				float 13666.6718042966, float 13681.0900253173, float 13695.5120461067, float 13709.9378646635, float 13724.3674789893, float 13738.800887088, float 13753.2380869664, float 13767.6790766337
				float 13782.1238541019, float 13796.5724173855, float 13811.0247645017, float 13825.48089347, float 13839.9408023129, float 13854.4044890551, float 13868.8719517243, float 13883.3431883503
				float 13897.8181969659, float 13912.2969756062, float 13926.7795223088, float 13941.2658351142, float 13955.755912065, float 13970.2497512067, float 13984.7473505871, float 13999.2487082568
				float 14013.7538222685, float 14028.2626906779, float 14042.7753115428, float 14057.2916829239, float 14071.811802884, float 14086.3356694887, float 14100.863280806, float 14115.3946349063
				float 14129.9297298627, float 14144.4685637505, float 14159.0111346478, float 14173.5574406348, float 14188.1074797944, float 14202.6612502119, float 14217.2187499751, float 14231.7799771742
				float 14246.3449299019, float 14260.9136062532, float 14275.4860043256, float 14290.0621222191, float 14304.6419580362, float 14319.2255098815, float 14333.8127758622, float 14348.4037540881
				float 14362.9984426711, float 14377.5968397256, float 14392.1989433684, float 14406.8047517187, float 14421.4142628982, float 14436.0274750308, float 14450.6443862427, float 14465.2649946628
				float 14479.8892984221, float 14494.517295654, float 14509.1489844943, float 14523.7843630812, float 14538.423429555, float 14553.0661820588, float 14567.7126187375, float 14582.3627377388
				float 14597.0165372123, float 14611.6740153104, float 14626.3351701873, float 14641.0, float 14655.6685029074, float 14670.340677071, float 14685.0165206544, float 14699.6960318237
				float 14714.379208747, float 14729.066049595, float 14743.7565525404, float 14758.4507157584, float 14773.1485374264, float 14787.850015724, float 14802.5551488331, float 14817.263934938
				float 14831.9763722249, float 14846.6924588826, float 14861.4121931021, float 14876.1355730764, float 14890.8625970009, float 14905.5932630734, float 14920.3275694936, float 14935.0655144636
				float 14949.8070961877, float 14964.5523128724, float 14979.3011627264, float 14994.0536439607, float 15008.8097547884, float 15023.5694934248, float 15038.3328580874, float 15053.0998469959
				float 15067.8704583721, float 15082.6446904403, float 15097.4225414265, float 15112.2040095592, float 15126.989093069, float 15141.7777901886, float 15156.5700991529, float 15171.366018199
				float 15186.165545566, float 15200.9686794953, float 15215.7754182304, float 15230.5857600169, float 15245.3997031026, float 15260.2172457373, float 15275.0383861731, float 15289.863122664
				float 15304.6914534664, float 15319.5233768386, float 15334.3588910411, float 15349.1979943363, float 15364.0406849891, float 15378.8869612662, float 15393.7368214364, float 15408.5902637706
				float 15423.447286542, float 15438.3078880256, float 15453.1720664985, float 15468.0398202402, float 15482.9111475318, float 15497.7860466569, float 15512.6645159007, float 15527.5465535509
				float 15542.432157897, float 15557.3213272307, float 15572.2140598454, float 15587.1103540371, float 15602.0102081033, float 15616.9136203438, float 15631.8205890605, float 15646.7311125571
				float 15661.6451891395, float 15676.5628171156, float 15691.4839947951, float 15706.4087204901, float 15721.3369925142, float 15736.2688091836, float 15751.2041688159, float 15766.1430697311
				float 15781.0855102511, float 15796.0314886997, float 15810.9810034028, float 15825.9340526881, float 15840.8906348855, float 15855.8507483267, float 15870.8143913454, float 15885.7815622774
				float 15900.7522594602, float 15915.7264812336, float 15930.704225939, float 15945.68549192, float 15960.670277522, float 15975.6585810925, float 15990.6504009807, float 16005.645735538
				float 16020.6445831176, float 16035.6469420746, float 16050.652810766, float 16065.6621875508, float 16080.67507079, float 16095.6914588463, float 16110.7113500844, float 16125.7347428711
				float 16140.7616355747, float 16155.7920265657, float 16170.8259142166, float 16185.8632969013, float 16200.9041729962, float 16215.9485408791, float 16230.9963989299, float 16246.0477455304
				float 16261.1025790642, float 16276.1608979167, float 16291.2227004754, float 16306.2879851295, float 16321.35675027, float 16336.4289942899, float 16351.504715584, float 16366.5839125489
				float 16381.6665835831, float 16396.752727087, float 16411.8423414628, float 16426.9354251144, float 16442.0319764476, float 16457.1319938703, float 16472.2354757918, float 16487.3424206236
				float 16502.4528267786, float 16517.566692672, float 16532.6840167205, float 16547.8047973427, float 16562.9290329589, float 16578.0567219914, float 16593.1878628642, float 16608.322454003
				float 16623.4604938354, float 16638.6019807909, float 16653.7469133006, float 16668.8952897974, float 16684.047108716, float 16699.202368493, float 16714.3610675667, float 16729.5232043771
				float 16744.688777366, float 16759.857784977, float 16775.0302256555, float 16790.2060978485, float 16805.3854000049, float 16820.5681305753, float 16835.7542880121, float 16850.9438707694
				float 16866.136877303, float 16881.3333060705, float 16896.5331555312, float 16911.7364241463, float 16926.9431103783, float 16942.153212692, float 16957.3667295535, float 16972.5836594307
				float 16987.8040007933, float 17003.0277521128, float 17018.2549118622, float 17033.4854785163, float 17048.7194505516, float 17063.9568264464, float 17079.1976046805, float 17094.4417837356
				float 17109.689362095, float 17124.9403382436, float 17140.1947106681, float 17155.4524778569, float 17170.7136383, float 17185.9781904891, float 17201.2461329177, float 17216.5174640808
				float 17231.7921824752, float 17247.0702865991, float 17262.3517749528, float 17277.6366460379, float 17292.9248983579, float 17308.2165304176, float 17323.5115407239, float 17338.8099277851
				float 17354.1116901111, float 17369.4168262136, float 17384.7253346058, float 17400.0372138027, float 17415.3524623207, float 17430.6710786781, float 17445.9930613946, float 17461.3184089916
				float 17476.6471199923, float 17491.9791929212, float 17507.3146263046, float 17522.6534186704, float 17537.9955685482, float 17553.341074469, float 17568.6899349655, float 17584.0421485722
				float 17599.3977138248, float 17614.7566292609, float 17630.1188934196, float 17645.4845048417, float 17660.8534620694, float 17676.2257636465, float 17691.6014081186, float 17706.9803940327
				float 17722.3627199374, float 17737.7483843829, float 17753.137385921, float 17768.529723105, float 17783.9253944898, float 17799.3243986319, float 17814.7267340892, float 17830.1323994215
				float 17845.5413931898, float 17860.9537139568, float 17876.3693602868, float 17891.7883307455, float 17907.2106239004, float 17922.6362383203, float 17938.0651725755, float 17953.4974252382
				float 17968.9329948817, float 17984.3718800811, float 17999.814079413, float 18015.2595914554, float 18030.7084147879, float 18046.1605479917, float 18061.6159896495, float 18077.0747383453
				float 18092.5367926649, float 18108.0021511954, float 18123.4708125256, float 18138.9427752456, float 18154.4180379472, float 18169.8965992235, float 18185.3784576694, float 18200.8636118809
				float 18216.3520604558, float 18231.8438019932, float 18247.3388350939, float 18262.8371583599, float 18278.338770395, float 18293.8436698043, float 18309.3518551943, float 18324.8633251732
				float 18340.3780783504, float 18355.8961133371, float 18371.4174287456, float 18386.94202319, float 18402.4698952857, float 18418.0010436496, float 18433.5354668999, float 18449.0731636565
				float 18464.6141325406, float 18480.158372175, float 18495.7058811837, float 18511.2566581924, float 18526.810701828, float 18542.3680107192, float 18557.9285834957, float 18573.492418789
				float 18589.0595152318, float 18604.6298714583, float 18620.2034861042, float 18635.7803578066, float 18651.3604852039, float 18666.9438669361, float 18682.5305016445, float 18698.1203879718
				float 18713.7135245623, float 18729.3099100615, float 18744.9095431165, float 18760.5124223755, float 18776.1185464884, float 18791.7279141065, float 18807.3405238823, float 18822.9563744698
				float 18838.5754645245, float 18854.1977927031, float 18869.8233576639, float 18885.4521580663, float 18901.0841925715, float 18916.7194598416, float 18932.3579585406, float 18947.9996873334
				float 18963.6446448865, float 18979.2928298679, float 18994.9442409468, float 19010.5988767937, float 19026.2567360807, float 19041.917817481, float 19057.5821196695, float 19073.2496413222
				float 19088.9203811165, float 19104.5943377311, float 19120.2715098464, float 19135.9518961436, float 19151.6354953057, float 19167.322306017, float 19183.0123269628, float 19198.7055568301
				float 19214.4019943072, float 19230.1016380836, float 19245.8044868502, float 19261.5105392992, float 19277.2197941243, float 19292.9322500203, float 19308.6479056834, float 19324.3667598113
				float 19340.0888111028, float 19355.8140582581, float 19371.5424999788, float 19387.2741349676, float 19403.0089619288, float 19418.7469795678, float 19434.4881865915, float 19450.2325817078
				float 19465.9801636263, float 19481.7309310576, float 19497.4848827138, float 19513.2420173081, float 19529.0023335551, float 19544.7658301709, float 19560.5325058725, float 19576.3023593786
				float 19592.0753894088, float 19607.8515946842, float 19623.6309739273, float 19639.4135258616, float 19655.1992492121, float 19670.988142705, float 19686.7802050678, float 19702.5754350293
				float 19718.3738313194, float 19734.1753926696, float 19749.9801178124, float 19765.7880054816, float 19781.5990544123, float 19797.413263341, float 19813.2306310053, float 19829.051156144
				float 19844.8748374974, float 19860.7016738068, float 19876.531663815, float 19892.3648062658, float 19908.2010999044, float 19924.0405434773, float 19939.883135732, float 19955.7288754176
				float 19971.5777612841, float 19987.429792083, float 20003.2849665668, float 20019.1432834896, float 20035.0047416062, float 20050.8693396732, float 20066.7370764479, float 20082.6079506894
				float 20098.4819611574, float 20114.3591066134, float 20130.2393858197, float 20146.1227975401, float 20162.0093405394, float 20177.8990135837, float 20193.7918154405, float 20209.6877448782
				float 20225.5868006666, float 20241.4889815767, float 20257.3942863806, float 20273.3027138518, float 20289.2142627647, float 20305.1289318953, float 20321.0467200204, float 20336.9676259183
				float 20352.8916483684, float 20368.8187861511, float 20384.7490380483, float 20400.682402843, float 20416.6188793193, float 20432.5584662624, float 20448.501162459, float 20464.4469666966
				float 20480.3958777643, float 20496.347894452, float 20512.303015551, float 20528.2612398537, float 20544.2225661537, float 20560.1869932457, float 20576.1545199257, float 20592.1251449908
				float 20608.0988672391, float 20624.0756854702, float 20640.0555984846, float 20656.0386050841, float 20672.0247040716, float 20688.0138942511, float 20704.0061744279, float 20720.0015434084
				float 20736.0, float 20752.0015430115, float 20768.0061712526, float 20784.0138835344, float 20800.0246786689, float 20816.0385554695, float 20832.0555127505, float 20848.0755493275
				float 20864.0986640171, float 20880.1248556372, float 20896.1541230066, float 20912.1864649456, float 20928.2218802753, float 20944.2603678181, float 20960.3019263973, float 20976.3465548377
				float 20992.3942519649, float 21008.4450166058, float 21024.4988475883, float 21040.5557437416, float 21056.6157038958, float 21072.6787268822, float 21088.7448115332, float 21104.8139566825
				float 21120.8861611647, float 21136.9614238154, float 21153.0397434717, float 21169.1211189714, float 21185.2055491536, float 21201.2930328585, float 21217.3835689275, float 21233.4771562027
				float 21249.5737935278, float 21265.6734797474, float 21281.7762137069, float 21297.8819942533, float 21313.9908202344, float 21330.1026904991, float 21346.2176038973, float 21362.3355592803
				float 21378.4565555002, float 21394.5805914103, float 21410.707665865, float 21426.8377777196, float 21442.9709258306, float 21459.1071090558, float 21475.2463262536, float 21491.3885762839
				float 21507.5338580074, float 21523.6821702861, float 21539.8335119828, float 21555.9878819616, float 21572.1452790875, float 21588.3057022266, float 21604.4691502462, float 21620.6356220145
				float 21636.8051164008, float 21652.9776322755, float 21669.15316851, float 21685.3317239768, float 21701.5132975493, float 21717.6978881022, float 21733.8854945112, float 21750.0761156528
				float 21766.2697504047, float 21782.4663976459, float 21798.6660562559, float 21814.8687251158, float 21831.0744031073, float 21847.2830891135, float 21863.4947820182, float 21879.7094807064
				float 21895.9271840642, float 21912.1478909787, float 21928.3716003378, float 21944.5983110308, float 21960.8280219477, float 21977.0607319798, float 21993.2964400192, float 22009.5351449592
				float 22025.7768456939, float 22042.0215411187, float 22058.2692301298, float 22074.5199116244, float 22090.773584501, float 22107.0302476587, float 22123.289899998, float 22139.5525404202
				float 22155.8181678276, float 22172.0867811236, float 22188.3583792125, float 22204.6329609997, float 22220.9105253916, float 22237.1910712956, float 22253.47459762, float 22269.7611032741
				float 22286.0505871685, float 22302.3430482143, float 22318.638485324, float 22334.936897411, float 22351.2382833895, float 22367.5426421749, float 22383.8499726835, float 22400.1602738326
				float 22416.4735445406, float 22432.7897837266, float 22449.108990311, float 22465.431163215, float 22481.7563013607, float 22498.0844036715, float 22514.4154690715, float 22530.7494964858
				float 22547.0864848406, float 22563.4264330629, float 22579.7693400808, float 22596.1152048234, float 22612.4640262207, float 22628.8158032037, float 22645.1705347042, float 22661.5282196552
				float 22677.8888569906, float 22694.2524456452, float 22710.6189845547, float 22726.988472656, float 22743.3609088868, float 22759.7362921856, float 22776.1146214922, float 22792.495895747
				float 22808.8801138917, float 22825.2672748687, float 22841.6573776213, float 22858.0504210941, float 22874.4464042322, float 22890.8453259821, float 22907.2471852907, float 22923.6519811064
				float 22940.0597123782, float 22956.4703780561, float 22972.8839770911, float 22989.3005084352, float 23005.719971041, float 23022.1423638625, float 23038.5676858543, float 23054.9959359721
				float 23071.4271131724, float 23087.8612164127, float 23104.2982446515, float 23120.7381968481, float 23137.1810719629, float 23153.6268689569, float 23170.0755867923, float 23186.5272244321
				float 23202.9817808404, float 23219.4392549821, float 23235.8996458228, float 23252.3629523294, float 23268.8291734694, float 23285.2983082114, float 23301.7703555249, float 23318.2453143802
				float 23334.7231837487, float 23351.2039626024, float 23367.6876499145, float 23384.174244659, float 23400.6637458108, float 23417.1561523457, float 23433.6514632404, float 23450.1496774725
				float 23466.6507940205, float 23483.1548118638, float 23499.6617299828, float 23516.1715473585, float 23532.6842629732, float 23549.1998758098, float 23565.7183848522, float 23582.2397890851
				float 23598.7640874942, float 23615.291279066, float 23631.8213627881, float 23648.3543376486, float 23664.8902026368, float 23681.4289567427, float 23697.9705989574, float 23714.5151282727
				float 23731.0625436813, float 23747.6128441769, float 23764.1660287538, float 23780.7220964074, float 23797.2810461341, float 23813.8428769308, float 23830.4075877956, float 23846.9751777273
				float 23863.5456457256, float 23880.1189907912, float 23896.6952119253, float 23913.2743081305, float 23929.8562784098, float 23946.4411217674, float 23963.028837208, float 23979.6194237375
				float 23996.2128803626, float 24012.8092060906, float 24029.40839993, float 24046.0104608899, float 24062.6153879804, float 24079.2231802125, float 24095.8338365978, float 24112.4473561491
				float 24129.0637378797, float 24145.682980804, float 24162.3050839371, float 24178.9300462951, float 24195.5578668948, float 24212.1885447539, float 24228.822078891, float 24245.4584683254
				float 24262.0977120774, float 24278.7398091681, float 24295.3847586193, float 24312.0325594538, float 24328.6832106952, float 24345.3367113679, float 24361.9930604971, float 24378.652257109
				float 24395.3143002304, float 24411.9791888892, float 24428.6469221138, float 24445.3174989337, float 24461.9909183792, float 24478.6671794812, float 24495.3462812717, float 24512.0282227834
				float 24528.7130030498, float 24545.4006211053, float 24562.091075985, float 24578.7843667249, float 24595.4804923619, float 24612.1794519336, float 24628.8812444784, float 24645.5858690357
				float 24662.2933246453, float 24679.0036103484, float 24695.7167251865, float 24712.4326682022, float 24729.1514384388, float 24745.8730349404, float 24762.597456752, float 24779.3247029193
				float 24796.0547724889, float 24812.7876645081, float 24829.5233780251, float 24846.2619120888, float 24863.003265749, float 24879.7474380563, float 24896.494428062, float 24913.2442348183
				float 24929.9968573781, float 24946.7522947952, float 24963.5105461241, float 24980.2716104202, float 24997.0354867395, float 25013.8021741391, float 25030.5716716766, float 25047.3439784106
				float 25064.1190934002, float 25080.8970157057, float 25097.6777443878, float 25114.4612785082, float 25131.2476171294, float 25148.0367593145, float 25164.8287041276, float 25181.6234506334
				float 25198.4209978974, float 25215.2213449862, float 25232.0244909666, float 25248.8304349066, float 25265.639175875, float 25282.4507129411, float 25299.2650451751, float 25316.082171648
				float 25332.9020914317, float 25349.7248035985, float 25366.5503072219, float 25383.3786013759, float 25400.2096851353, float 25417.0435575757, float 25433.8802177735, float 25450.7196648058
				float 25467.5618977505, float 25484.4069156863, float 25501.2547176926, float 25518.1053028495, float 25534.9586702381, float 25551.8148189399, float 25568.6737480375, float 25585.535456614
				float 25602.3999437535, float 25619.2672085406, float 25636.1372500609, float 25653.0100674004, float 25669.8856596463, float 25686.7640258863, float 25703.6451652087, float 25720.5290767029
				float 25737.4157594589, float 25754.3052125672, float 25771.1974351195, float 25788.0924262079, float 25804.9901849253, float 25821.8907103655, float 25838.7940016229, float 25855.7000577927
				float 25872.6088779708, float 25889.5204612538, float 25906.4348067391, float 25923.3519135249, float 25940.2717807101, float 25957.1944073941, float 25974.1197926775, float 25991.0479356612
				float 26007.978835447, float 26024.9124911374, float 26041.8489018358, float 26058.7880666462, float 26075.7299846731, float 26092.6746550221, float 26109.6220767994, float 26126.5722491118
				float 26143.525171067, float 26160.4808417733, float 26177.4392603398, float 26194.4004258762, float 26211.3643374932, float 26228.3309943018, float 26245.300395414, float 26262.2725399426
				float 26279.2474270009, float 26296.225055703, float 26313.2054251637, float 26330.1885344985, float 26347.1743828238, float 26364.1629692563, float 26381.1542929139, float 26398.1483529148
				float 26415.1451483782, float 26432.1446784238, float 26449.1469421722, float 26466.1519387445, float 26483.1596672627, float 26500.1701268494, float 26517.1833166279, float 26534.1992357223
				float 26551.2178832572, float 26568.2392583581, float 26585.2633601512, float 26602.2901877632, float 26619.3197403217, float 26636.3520169549, float 26653.3870167917, float 26670.4247389618
				float 26687.4651825955, float 26704.5083468237, float 26721.5542307783, float 26738.6028335915, float 26755.6541543964, float 26772.7081923269, float 26789.7649465174, float 26806.8244161031
				float 26823.8866002198, float 26840.951498004, float 26858.0191085929, float 26875.0894311245, float 26892.1624647374, float 26909.2382085707, float 26926.3166617645, float 26943.3978234595
				float 26960.4816927968, float 26977.5682689186, float 26994.6575509674, float 27011.7495380867, float 27028.8442294205, float 27045.9416241135, float 27063.041721311, float 27080.1445201592
				float 27097.2500198047, float 27114.3582193951, float 27131.4691180782, float 27148.582715003, float 27165.6990093189, float 27182.8180001758, float 27199.9396867247, float 27217.0640681168
				float 27234.1911435044, float 27251.3209120402, float 27268.4533728776, float 27285.5885251707, float 27302.7263680743, float 27319.8669007437, float 27337.0101223352, float 27354.1560320054
				float 27371.3046289117, float 27388.4559122122, float 27405.6098810656, float 27422.7665346314, float 27439.9258720695, float 27457.0878925407, float 27474.2525952063, float 27491.4199792283
				float 27508.5900437694, float 27525.7627879929, float 27542.9382110628, float 27560.1163121437, float 27577.2970904009, float 27594.4805450002, float 27611.6666751084, float 27628.8554798925
				float 27646.0469585205, float 27663.2411101609, float 27680.4379339828, float 27697.6374291561, float 27714.8395948511, float 27732.0444302391, float 27749.2519344917, float 27766.4621067813
				float 27783.674946281, float 27800.8904521643, float 27818.1086236057, float 27835.32945978, float 27852.5529598628, float 27869.7791230303, float 27887.0079484595, float 27904.2394353277
				float 27921.4735828132, float 27938.7103900946, float 27955.9498563514, float 27973.1919807636, float 27990.4367625117, float 28007.6842007773, float 28024.934294742, float 28042.1870435886
				float 28059.4424465001, float 28076.7005026604, float 28093.9612112539, float 28111.2245714657, float 28128.4905824814, float 28145.7592434874, float 28163.0305536705, float 28180.3045122184
				float 28197.5811183192, float 28214.8603711617, float 28232.1422699354, float 28249.4268138302, float 28266.7140020369, float 28284.0038337467, float 28301.2963081516, float 28318.591424444
				float 28335.889181817, float 28353.1895794645, float 28370.4926165807, float 28387.7982923607, float 28405.1066060001, float 28422.4175566949, float 28439.7311436422, float 28457.0473660393
				float 28474.3662230841, float 28491.6877139755, float 28509.0118379126, float 28526.3385940953, float 28543.6679817241, float 28561.0, float 28578.3346481247, float 28595.6719253006
				float 28613.0118307305, float 28630.3543636179, float 28647.6995231669, float 28665.0473085823, float 28682.3977190693, float 28699.7507538338, float 28717.1064120824, float 28734.4646930221
				float 28751.8255958607, float 28769.1891198065, float 28786.5552640683, float 28803.9240278557, float 28821.2954103787, float 28838.6694108481, float 28856.0460284751, float 28873.4252624716
				float 28890.8071120501, float 28908.1915764237, float 28925.5786548059, float 28942.9683464111, float 28960.3606504541, float 28977.7555661502, float 28995.1530927156, float 29012.5532293668
				float 29029.955975321, float 29047.361329796, float 29064.7692920101, float 29082.1798611823, float 29099.5930365322, float 29117.0088172798, float 29134.4272026458, float 29151.8481918516
				float 29169.2717841189, float 29186.6979786703, float 29204.1267747287, float 29221.5581715178, float 29238.9921682617, float 29256.4287641853, float 29273.8679585137, float 29291.3097504731
				float 29308.7541392897, float 29326.2011241909, float 29343.650704404, float 29361.1028791575, float 29378.55764768, float 29396.015009201, float 29413.4749629503, float 29430.9375081585
				float 29448.4026440567, float 29465.8703698765, float 29483.3406848501, float 29500.8135882103, float 29518.2890791905, float 29535.7671570245, float 29553.2478209469, float 29570.7310701928
				float 29588.2169039977, float 29605.7053215979, float 29623.19632223, float 29640.6899051314, float 29658.18606954, float 29675.6848146942, float 29693.186139833, float 29710.690044196
				float 29728.1965270233, float 29745.7055875555, float 29763.217225034, float 29780.7314387004, float 29798.2482277972, float 29815.7675915672, float 29833.289529254, float 29850.8140401015
				float 29868.3411233544, float 29885.8707782577, float 29903.4030040571, float 29920.937799999, float 29938.47516533, float 29956.0150992975, float 29973.5576011494, float 29991.1026701341
				float 30008.6503055007, float 30026.2005064987, float 30043.7532723781, float 30061.3086023897, float 30078.8664957845, float 30096.4269518144, float 30113.9899697315, float 30131.5555487888
				float 30149.1236882395, float 30166.6943873376, float 30184.2676453376, float 30201.8434614944, float 30219.4218350636, float 30237.0027653013, float 30254.5862514641, float 30272.172292809
				float 30289.760888594, float 30307.3520380771, float 30324.9457405172, float 30342.5419951735, float 30360.140801306, float 30377.7421581749, float 30395.3460650414, float 30412.9525211667
				float 30430.5615258129, float 30448.1730782425, float 30465.7871777186, float 30483.4038235047, float 30501.0230148651, float 30518.6447510643, float 30536.2690313675, float 30553.8958550405
				float 30571.5252213495, float 30589.1571295613, float 30606.7915789432, float 30624.428568763, float 30642.068098289, float 30659.7101667903, float 30677.3547735361, float 30695.0019177964
				float 30712.6515988417, float 30730.3038159429, float 30747.9585683717, float 30765.6158553999, float 30783.2756763002, float 30800.9380303456, float 30818.6029168098, float 30836.2703349668
				float 30853.9402840914, float 30871.6127634585, float 30889.287772344, float 30906.965310024, float 30924.6453757753, float 30942.327968875, float 30960.0130886009, float 30977.7007342313
				float 30995.3909050449, float 31013.0836003211, float 31030.7788193396, float 31048.4765613808, float 31066.1768257255, float 31083.879611655, float 31101.5849184512, float 31119.2927453964
				float 31137.0030917736, float 31154.7159568662, float 31172.4313399579, float 31190.1492403333, float 31207.8696572772, float 31225.592590075, float 31243.3180380128, float 31261.0460003768
				float 31278.7764764542, float 31296.5094655322, float 31314.2449668989, float 31331.9829798427, float 31349.7235036526, float 31367.466537618, float 31385.2120810289, float 31402.9601331758
				float 31420.7106933496, float 31438.4637608418, float 31456.2193349444, float 31473.9774149497, float 31491.7380001509, float 31509.5010898414, float 31527.2666833151, float 31545.0347798664
				float 31562.8053787905, float 31580.5784793826, float 31598.3540809387, float 31616.1321827554, float 31633.9127841295, float 31651.6958843584, float 31669.4814827401, float 31687.2695785731
				float 31705.0601711561, float 31722.8532597887, float 31740.6488437708, float 31758.4469224026, float 31776.2474949851, float 31794.0505608196, float 31811.8561192081, float 31829.6641694528
				float 31847.4747108565, float 31865.2877427227, float 31883.103264355, float 31900.9212750579, float 31918.741774136, float 31936.5647608947, float 31954.3902346396, float 31972.218194677
				float 31990.0486403137, float 32007.8815708568, float 32025.716985614, float 32043.5548838934, float 32061.3952650038, float 32079.2381282542, float 32097.0834729543, float 32114.9312984141
				float 32132.7816039441, float 32150.6343888555, float 32168.4896524598, float 32186.3473940689, float 32204.2076129954, float 32222.0703085521, float 32239.9354800526, float 32257.8031268107
				float 32275.6732481408, float 32293.5458433577, float 32311.4209117769, float 32329.298452714, float 32347.1784654854, float 32365.0609494078, float 32382.9459037985, float 32400.833327975
				float 32418.7232212557, float 32436.6155829591, float 32454.5104124043, float 32472.4077089109, float 32490.307471799, float 32508.209700389, float 32526.1143940019, float 32544.0215519592
				float 32561.9311735827, float 32579.843258195, float 32597.7578051187, float 32615.6748136772, float 32633.5942831943, float 32651.5162129943, float 32669.4406024017, float 32687.3674507419
				float 32705.2967573403, float 32723.2285215231, float 32741.1627426169, float 32759.0994199487, float 32777.0385528459, float 32794.9801406365, float 32812.9241826488, float 32830.8706782117
				float 32848.8196266546, float 32866.7710273072, float 32884.7248794996, float 32902.6811825627, float 32920.6399358275, float 32938.6011386256, float 32956.5647902892, float 32974.5308901506
				float 32992.4994375429, float 33010.4704317995, float 33028.4438722542, float 33046.4197582413, float 33064.3980890957, float 33082.3788641526, float 33100.3620827476, float 33118.3477442169
				float 33136.335847897, float 33154.3263931251, float 33172.3193792385, float 33190.3148055752, float 33208.3126714736, float 33226.3129762724, float 33244.3157193111, float 33262.3208999293
				float 33280.3285174671, float 33298.3385712653, float 33316.3510606648, float 33334.3659850071, float 33352.3833436342, float 33370.4031358886, float 33388.425361113, float 33406.4500186507
				float 33424.4771078455, float 33442.5066280415, float 33460.5385785834, float 33478.5729588161, float 33496.6097680852, float 33514.6490057366, float 33532.6906711167, float 33550.7347635724
				float 33568.7812824507, float 33586.8302270996, float 33604.881596867, float 33622.9353911015, float 33640.9916091522, float 33659.0502503685, float 33677.1113141003, float 33695.1747996979
				float 33713.240706512, float 33731.3090338938, float 33749.379781195, float 33767.4529477675, float 33785.528532964, float 33803.6065361372, float 33821.6869566406, float 33839.7697938279
				float 33857.8550470534, float 33875.9427156717, float 33894.0327990379, float 33912.1252965074, float 33930.2202074363, float 33948.3175311809, float 33966.417267098, float 33984.5194145447
				float 34002.6239728789, float 34020.7309414585, float 34038.8403196421, float 34056.9521067885, float 34075.0663022573, float 34093.182905408, float 34111.301915601, float 34129.4233321969
				float 34147.5471545568, float 34165.6733820421, float 34183.8020140147, float 34201.933049837, float 34220.0664888718, float 34238.2023304821, float 34256.3405740317, float 34274.4812188845
				float 34292.624264405, float 34310.7697099579, float 34328.9175549087, float 34347.067798623, float 34365.220440467, float 34383.3754798071, float 34401.5329160103, float 34419.692748444
				float 34437.854976476, float 34456.0195994745, float 34474.1866168081, float 34492.3560278458, float 34510.5278319572, float 34528.702028512, float 34546.8786168807, float 34565.0575964338
				float 34583.2389665425, float 34601.4227265782, float 34619.6088759131, float 34637.7974139193, float 34655.9883399697, float 34674.1816534374, float 34692.3773536961, float 34710.5754401197
				float 34728.7759120826, float 34746.9787689597, float 34765.1840101261, float 34783.3916349575, float 34801.6016428301, float 34819.8140331201, float 34838.0288052045, float 34856.2459584605
				float 34874.4654922658, float 34892.6874059986, float 34910.9116990372, float 34929.1383707606, float 34947.367420548, float 34965.5988477793, float 34983.8326518344, float 35002.0688320939
				float 35020.3073879387, float 35038.5483187502, float 35056.79162391, float 35075.0373028003, float 35093.2853548035, float 35111.5357793027, float 35129.7885756811, float 35148.0437433225
				float 35166.301281611, float 35184.5611899311, float 35202.8234676678, float 35221.0881142064, float 35239.3551289326, float 35257.6245112325, float 35275.8962604926, float 35294.1703760999
				float 35312.4468574417, float 35330.7257039056, float 35349.0069148799, float 35367.2904897529, float 35385.5764279137, float 35403.8647287514, float 35422.1553916558, float 35440.448416017
				float 35458.7438012253, float 35477.0415466718, float 35495.3416517476, float 35513.6441158444, float 35531.9489383543, float 35550.2561186697, float 35568.5656561833, float 35586.8775502885
				float 35605.1918003788, float 35623.5084058483, float 35641.8273660912, float 35660.1486805025, float 35678.4723484772, float 35696.798369411, float 35715.1267426997, float 35733.4574677397
				float 35751.7905439277, float 35770.1259706607, float 35788.4637473364, float 35806.8038733526, float 35825.1463481075, float 35843.4911709997, float 35861.8383414284, float 35880.1878587929
				float 35898.539722493, float 35916.8939319289, float 35935.2504865011, float 35953.6093856107, float 35971.970628659, float 35990.3342150476, float 36008.7001441786, float 36027.0684154546
				float 36045.4390282784, float 36063.8119820532, float 36082.1872761826, float 36100.5649100707, float 36118.9448831218, float 36137.3271947407, float 36155.7118443324, float 36174.0988313026
				float 36192.4881550571, float 36210.8798150022, float 36229.2738105445, float 36247.670141091, float 36266.0688060492, float 36284.4698048267, float 36302.8731368319, float 36321.2788014731
				float 36339.6867981593, float 36358.0971262997, float 36376.509785304, float 36394.9247745823, float 36413.3420935448, float 36431.7617416024, float 36450.1837181663, float 36468.6080226479
				float 36487.034654459, float 36505.4636130121, float 36523.8948977196, float 36542.3285079946, float 36560.7644432504, float 36579.2027029008, float 36597.6432863599, float 36616.0861930422
				float 36634.5314223624, float 36652.9789737359, float 36671.4288465781, float 36689.8810403051, float 36708.3355543332, float 36726.7923880789, float 36745.2515409594, float 36763.7130123921
				float 36782.1768017948, float 36800.6429085856, float 36819.111332183, float 36837.5820720059, float 36856.0551274735, float 36874.5304980054, float 36893.0081830217, float 36911.4881819425
				float 36929.9704941887, float 36948.4551191812, float 36966.9420563415, float 36985.4313050914, float 37003.922864853, float 37022.4167350487, float 37040.9129151016, float 37059.4114044347
				float 37077.9122024716, float 37096.4153086364, float 37114.9207223532, float 37133.4284430469, float 37151.9384701423, float 37170.4508030648, float 37188.9654412402, float 37207.4823840946
				float 37226.0016310544, float 37244.5231815464, float 37263.0470349978, float 37281.5731908362, float 37300.1016484892, float 37318.6324073853, float 37337.1654669529, float 37355.7008266211
				float 37374.2384858191, float 37392.7784439765, float 37411.3207005234, float 37429.8652548901, float 37448.4121065072, float 37466.961254806, float 37485.5126992177, float 37504.0664391741
				float 37522.6224741074, float 37541.18080345, float 37559.7414266347, float 37578.3043430947, float 37596.8695522635, float 37615.4370535749, float 37634.0068464633, float 37652.5789303631
				float 37671.1533047092, float 37689.7299689369, float 37708.3089224819, float 37726.89016478, float 37745.4736952676, float 37764.0595133813, float 37782.6476185581, float 37801.2380102354
				float 37819.8306878509, float 37838.4256508425, float 37857.0228986487, float 37875.6224307082, float 37894.22424646, float 37912.8283453436, float 37931.4347267988, float 37950.0433902655
				float 37968.6543351843, float 37987.267560996, float 38005.8830671417, float 38024.5008530628, float 38043.1209182012, float 38061.743261999, float 38080.3678838987, float 38098.9947833432
				float 38117.6239597756, float 38136.2554126394, float 38154.8891413786, float 38173.5251454372, float 38192.1634242599, float 38210.8039772916, float 38229.4468039773, float 38248.0919037627
				float 38266.7392760937, float 38285.3889204165, float 38304.0408361776, float 38322.695022824, float 38341.3514798029, float 38360.0102065619, float 38378.6712025488, float 38397.334467212
				float 38416.0, float 38434.6678003617, float 38453.3378677464, float 38472.0102016036, float 38490.6848013833, float 38509.3616665358, float 38528.0407965116, float 38546.7221907615
				float 38565.405848737, float 38584.0917698896, float 38602.7799536711, float 38621.4703995339, float 38640.1631069305, float 38658.8580753138, float 38677.5553041371, float 38696.2547928539
				float 38714.9565409181, float 38733.660547784, float 38752.3668129061, float 38771.0753357394, float 38789.7861157389, float 38808.4991523604, float 38827.2144450596, float 38845.9319932927
				float 38864.6517965164, float 38883.3738541874, float 38902.0981657629, float 38920.8247307005, float 38939.5535484579, float 38958.2846184934, float 38977.0179402655, float 38995.7535132328
				float 39014.4913368547, float 39033.2314105905, float 39051.9737339001, float 39070.7183062435, float 39089.4651270812, float 39108.2141958739, float 39126.9655120828, float 39145.7190751693
				float 39164.474884595, float 39183.232939822, float 39201.9932403127, float 39220.7557855298, float 39239.5205749363, float 39258.2876079956, float 39277.0568841712, float 39295.8284029273
				float 39314.602163728, float 39333.378166038, float 39352.1564093223, float 39370.936893046, float 39389.7196166748, float 39408.5045796746, float 39427.2917815115, float 39446.0812216522
				float 39464.8728995634, float 39483.6668147123, float 39502.4629665664, float 39521.2613545935, float 39540.0619782618, float 39558.8648370396, float 39577.6699303957, float 39596.4772577991
				float 39615.2868187193, float 39634.0986126259, float 39652.912638989, float 39671.7288972788, float 39690.5473869661, float 39709.3681075217, float 39728.1910584169, float 39747.0162391233
				float 39765.8436491128, float 39784.6732878575, float 39803.5051548301, float 39822.3392495033, float 39841.1755713503, float 39860.0141198445, float 39878.8548944597, float 39897.6978946699
				float 39916.5431199496, float 39935.3905697734, float 39954.2402436163, float 39973.0921409537, float 39991.9462612611, float 40010.8026040146, float 40029.6611686902, float 40048.5219547647
				float 40067.3849617148, float 40086.2501890177, float 40105.1176361509, float 40123.9873025921, float 40142.8591878195, float 40161.7332913114, float 40180.6096125465, float 40199.4881510039
				float 40218.3689061629, float 40237.251877503, float 40256.1370645042, float 40275.0244666467, float 40293.914083411, float 40312.8059142781, float 40331.699958729, float 40350.5962162451
				float 40369.4946863083, float 40388.3953684005, float 40407.2982620042, float 40426.2033666019, float 40445.1106816767, float 40464.0202067118, float 40482.9319411908, float 40501.8458845974
				float 40520.762036416, float 40539.680396131, float 40558.6009632271, float 40577.5237371894, float 40596.4487175032, float 40615.3759036543, float 40634.3052951287, float 40653.2368914125
				float 40672.1706919923, float 40691.1066963551, float 40710.0449039879, float 40728.9853143782, float 40747.9279270139, float 40766.8727413829, float 40785.8197569737, float 40804.7689732747
				float 40823.7203897752, float 40842.6740059641, float 40861.6298213312, float 40880.5878353662, float 40899.5480475593, float 40918.5104574009, float 40937.4750643818, float 40956.4418679929
				float 40975.4108677255, float 40994.3820630713, float 41013.3554535222, float 41032.3310385704, float 41051.3088177084, float 41070.2887904289, float 41089.270956225, float 41108.2553145901
				float 41127.2418650179, float 41146.2306070023, float 41165.2215400375, float 41184.2146636182, float 41203.2099772391, float 41222.2074803953, float 41241.2071725823, float 41260.2090532958
				float 41279.2131220317, float 41298.2193782863, float 41317.2278215563, float 41336.2384513384, float 41355.2512671298, float 41374.266268428, float 41393.2834547307, float 41412.302825536
				float 41431.324380342, float 41450.3481186474, float 41469.3740399511, float 41488.4021437523, float 41507.4324295504, float 41526.4648968452, float 41545.4995451366, float 41564.5363739251
				float 41583.5753827111, float 41602.6165709957, float 41621.6599382799, float 41640.7054840652, float 41659.7532078534, float 41678.8031091465, float 41697.8551874468, float 41716.9094422569
				float 41735.9658730797, float 41755.0244794184, float 41774.0852607763, float 41793.1482166573, float 41812.2133465653, float 41831.2806500047, float 41850.35012648, float 41869.4217754961
				float 41888.4955965581, float 41907.5715891715, float 41926.649752842, float 41945.7300870755, float 41964.8125913783, float 41983.897265257, float 42002.9841082184, float 42022.0731197696
				float 42041.164299418, float 42060.2576466713, float 42079.3531610374, float 42098.4508420246, float 42117.5506891413, float 42136.6527018964, float 42155.7568797989, float 42174.8632223581
				float 42193.9717290838, float 42213.0823994857, float 42232.195233074, float 42251.3102293593, float 42270.4273878521, float 42289.5467080636, float 42308.6681895051, float 42327.791831688
				float 42346.9176341242, float 42366.0455963259, float 42385.1757178054, float 42404.3079980753, float 42423.4424366486, float 42442.5790330386, float 42461.7177867587, float 42480.8586973226
				float 42500.0017642444, float 42519.1469870384, float 42538.2943652193, float 42557.4438983017, float 42576.5955858009, float 42595.7494272322, float 42614.9054221114, float 42634.0635699544
				float 42653.2238702773, float 42672.3863225967, float 42691.5509264294, float 42710.7176812923, float 42729.8865867028, float 42749.0576421784, float 42768.2308472369, float 42787.4062013966
				float 42806.5837041757, float 42825.763355093, float 42844.9451536673, float 42864.1290994178, float 42883.315191864, float 42902.5034305256, float 42921.6938149227, float 42940.8863445754
				float 42960.0810190044, float 42979.2778377303, float 42998.4768002743, float 43017.6779061578, float 43036.8811549022, float 43056.0865460296, float 43075.294079062, float 43094.5037535218
				float 43113.7155689317, float 43132.9295248146, float 43152.1456206938, float 43171.3638560926, float 43190.5842305349, float 43209.8067435446, float 43229.031394646, float 43248.2581833636
				float 43267.4871092222, float 43286.7181717469, float 43305.9513704629, float 43325.1867048959, float 43344.4241745717, float 43363.6637790163, float 43382.9055177563, float 43402.1493903181
				float 43421.3953962288, float 43440.6435350154, float 43459.8938062053, float 43479.1462093264, float 43498.4007439064, float 43517.6574094736, float 43536.9162055565, float 43556.1771316838
				float 43575.4401873844, float 43594.7053721877, float 43613.9726856231, float 43633.2421272204, float 43652.5136965097, float 43671.7873930211, float 43691.0632162853, float 43710.341165833
				float 43729.6212411954, float 43748.9034419036, float 43768.1877674894, float 43787.4742174845, float 43806.7627914211, float 43826.0534888315, float 43845.3463092483, float 43864.6412522043
				float 43883.9383172328, float 43903.237503867, float 43922.5388116406, float 43941.8422400875, float 43961.1477887419, float 43980.4554571381, float 43999.7652448108, float 44019.077151295
				float 44038.3911761258, float 44057.7073188385, float 44077.025578969, float 44096.3459560531, float 44115.6684496271, float 44134.9930592273, float 44154.3197843905, float 44173.6486246535
				float 44192.9795795537, float 44212.3126486285, float 44231.6478314155, float 44250.9851274528, float 44270.3245362785, float 44289.6660574312, float 44309.0096904495, float 44328.3554348724
				float 44347.7032902391, float 44367.0532560891, float 44386.4053319621, float 44405.7595173981, float 44425.1158119374, float 44444.4742151203, float 44463.8347264877, float 44483.1973455805
				float 44502.5620719399, float 44521.9289051073, float 44541.2978446246, float 44560.6688900337, float 44580.0420408769, float 44599.4172966965, float 44618.7946570353, float 44638.1741214363
				float 44657.5556894426, float 44676.9393605979, float 44696.3251344457, float 44715.71301053, float 44735.1029883951, float 44754.4950675853, float 44773.8892476454, float 44793.2855281204
				float 44812.6839085554, float 44832.0843884958, float 44851.4869674874, float 44870.891645076, float 44890.2984208079, float 44909.7072942295, float 44929.1182648874, float 44948.5313323286
				float 44967.9464961001, float 44987.3637557495, float 45006.7831108243, float 45026.2045608725, float 45045.6281054421, float 45065.0537440816, float 45084.4814763395, float 45103.9113017648
				float 45123.3432199064, float 45142.7772303139, float 45162.2133325367, float 45181.6515261247, float 45201.091810628, float 45220.5341855969, float 45239.978650582, float 45259.425205134
				float 45278.8738488039, float 45298.3245811432, float 45317.7774017032, float 45337.2323100359, float 45356.689305693, float 45376.148388227, float 45395.6095571903, float 45415.0728121356
				float 45434.5381526158, float 45454.0055781843, float 45473.4750883944, float 45492.9466827998, float 45512.4203609544, float 45531.8961224124, float 45551.3739667282, float 45570.8538934564
				float 45590.3359021519, float 45609.8199923698, float 45629.3061636654, float 45648.7944155945, float 45668.2847477126, float 45687.777159576, float 45707.2716507409, float 45726.7682207639
				float 45746.2668692017, float 45765.7675956113, float 45785.27039955, float 45804.7752805753, float 45824.2822382448, float 45843.7912721166, float 45863.3023817487, float 45882.8155666997
				float 45902.3308265281, float 45921.8481607929, float 45941.3675690532, float 45960.8890508684, float 45980.4126057979, float 45999.9382334018, float 46019.4659332399, float 46038.9957048727
				float 46058.5275478606, float 46078.0614617643, float 46097.597446145, float 46117.1355005638, float 46136.6756245821, float 46156.2178177617, float 46175.7620796645, float 46195.3084098526
				float 46214.8568078883, float 46234.4072733344, float 46253.9598057537, float 46273.5144047092, float 46293.0710697643, float 46312.6298004825, float 46332.1905964275, float 46351.7534571634
				float 46371.3183822543, float 46390.8853712649, float 46410.4544237596, float 46430.0255393035, float 46449.5987174617, float 46469.1739577996, float 46488.7512598828, float 46508.3306232771
				float 46527.9120475485, float 46547.4955322635, float 46567.0810769884, float 46586.6686812901, float 46606.2583447354, float 46625.8500668917, float 46645.4438473264, float 46665.039685607
				float 46684.6375813015, float 46704.237533978, float 46723.8395432048, float 46743.4436085506, float 46763.049729584, float 46782.6579058741, float 46802.2681369902, float 46821.8804225016
				float 46841.4947619782, float 46861.1111549898, float 46880.7296011065, float 46900.3500998988, float 46919.9726509372, float 46939.5972537925, float 46959.2239080358, float 46978.8526132384
				float 46998.4833689717, float 47018.1161748074, float 47037.7510303176, float 47057.3879350742, float 47077.0268886498, float 47096.6678906169, float 47116.3109405484, float 47135.9560380173
				float 47155.6031825969, float 47175.2523738607, float 47194.9036113824, float 47214.5568947359, float 47234.2122234954, float 47253.8695972353, float 47273.5290155303, float 47293.190477955
				float 47312.8539840846, float 47332.5195334943, float 47352.1871257597, float 47371.8567604564, float 47391.5284371603, float 47411.2021554477, float 47430.8779148948, float 47450.5557150783
				float 47470.235555575, float 47489.9174359619, float 47509.6013558162, float 47529.2873147155, float 47548.9753122373, float 47568.6653479597, float 47588.3574214607, float 47608.0515323186
				float 47627.7476801121, float 47647.4458644198, float 47667.1460848209, float 47686.8483408945, float 47706.55263222, float 47726.258958377, float 47745.9673189456, float 47765.6777135056
				float 47785.3901416374, float 47805.1046029216, float 47824.8210969388, float 47844.53962327, float 47864.2601814964, float 47883.9827711994, float 47903.7073919604, float 47923.4340433614
				float 47943.1627249843, float 47962.8934364115, float 47982.6261772252, float 48002.3609470083, float 48022.0977453436, float 48041.8365718142, float 48061.5774260034, float 48081.3203074947
				float 48101.0652158718, float 48120.8121507188, float 48140.5611116198, float 48160.3120981591, float 48180.0651099213, float 48199.8201464913, float 48219.5772074541, float 48239.3362923948
				float 48259.097400899, float 48278.8605325523, float 48298.6256869406, float 48318.3928636499, float 48338.1620622665, float 48357.9332823769, float 48377.7065235679, float 48397.4817854263
				float 48417.2590675393, float 48437.0383694943, float 48456.8196908788, float 48476.6030312805, float 48496.3883902874, float 48516.1757674878, float 48535.96516247, float 48555.7565748227
				float 48575.5500041346, float 48595.3454499947, float 48615.1429119924, float 48634.942389717, float 48654.7438827582, float 48674.5473907059, float 48694.3529131501, float 48714.1604496811
				float 48733.9699998894, float 48753.7815633658, float 48773.595139701, float 48793.4107284862, float 48813.2283293128, float 48833.0479417722, float 48852.8695654562, float 48872.6931999567
				float 48892.5188448659, float 48912.3464997762, float 48932.17616428, float 48952.0078379702, float 48971.8415204397, float 48991.6772112817, float 49011.5149100896, float 49031.354616457
				float 49051.1963299777, float 49071.0400502456, float 49090.8857768551, float 49110.7335094004, float 49130.5832474763, float 49150.4349906775, float 49170.2887385991, float 49190.1444908362
				float 49210.0022469844, float 49229.8620066393, float 49249.7237693967, float 49269.5875348527, float 49289.4533026035, float 49309.3210722455, float 49329.1908433754, float 49349.0626155902
				float 49368.9363884868, float 49388.8121616625, float 49408.6899347148, float 49428.5697072413, float 49448.45147884, float 49468.3352491089, float 49488.2210176462, float 49508.1087840505
				float 49527.9985479205, float 49547.8903088549, float 49567.784066453, float 49587.679820314, float 49607.5775700373, float 49627.4773152227, float 49647.3790554701, float 49667.2827903795
				float 49687.1885195512, float 49707.0962425857, float 49727.0059590837, float 49746.9176686462, float 49766.8313708741, float 49786.7470653687, float 49806.6647517317, float 49826.5844295645
				float 49846.5060984692, float 49866.4297580478, float 49886.3554079026, float 49906.283047636, float 49926.2126768508, float 49946.1442951499, float 49966.0779021362, float 49986.0134974132
				float 50005.9510805841, float 50025.8906512528, float 50045.8322090231, float 50065.7757534991, float 50085.7212842849, float 50105.6688009852, float 50125.6183032044, float 50145.5697905476
				float 50165.5232626197, float 50185.4787190259, float 50205.4361593718, float 50225.3955832629, float 50245.3569903051, float 50265.3203801044, float 50285.2857522671, float 50305.2531063995
				float 50325.2224421083, float 50345.1937590003, float 50365.1670566825, float 50385.1423347621, float 50405.1195928465, float 50425.0988305432, float 50445.0800474601, float 50465.0632432052
				float 50485.0484173865, float 50505.0355696126, float 50525.0246994919, float 50545.0158066331, float 50565.0088906453, float 50585.0039511376, float 50605.0009877193, float 50625.0
				float 50645.0009875893, float 50665.0039500971, float 50685.0088871337, float 50705.0157983092, float 50725.0246832342, float 50745.0355415193, float 50765.0483727754, float 50785.0631766136
				float 50805.0799526452, float 50825.0987004815, float 50845.1194197342, float 50865.1421100152, float 50885.1667709365, float 50905.1934021103, float 50925.2220031489, float 50945.2525736651
				float 50965.2851132715, float 50985.3196215811, float 51005.3560982072, float 51025.394542763, float 51045.4349548621, float 51065.4773341182, float 51085.5216801454, float 51105.5679925575
				float 51125.6162709691, float 51145.6665149945, float 51165.7187242485, float 51185.7728983459, float 51205.8290369018, float 51225.8871395314, float 51245.9472058501, float 51266.0092354736
				float 51286.0732280177, float 51306.1391830984, float 51326.2071003319, float 51346.2769793345, float 51366.3488197228, float 51386.4226211135, float 51406.4983831237, float 51426.5761053703
				float 51446.6557874708, float 51466.7374290426, float 51486.8210297034, float 51506.906589071, float 51526.9941067636, float 51547.0835823994, float 51567.1750155967, float 51587.2684059743
				float 51607.3637531509, float 51627.4610567454, float 51647.5603163771, float 51667.6615316654, float 51687.7647022297, float 51707.8698276897, float 51727.9769076655, float 51748.0859417771
				float 51768.1969296447, float 51788.3098708888, float 51808.4247651302, float 51828.5416119895, float 51848.6604110879, float 51868.7811620465, float 51888.9038644867, float 51909.0285180302
				float 51929.1551222985, float 51949.2836769137, float 51969.4141814979, float 51989.5466356733, float 52009.6810390626, float 52029.8173912883, float 52049.9556919732, float 52070.0959407405
				float 52090.2381372133, float 52110.382281015, float 52130.5283717692, float 52150.6764090997, float 52170.8263926303, float 52190.9783219853, float 52211.1321967889, float 52231.2880166657
				float 52251.4457812401, float 52271.6054901373, float 52291.767142982, float 52311.9307393997, float 52332.0962790156, float 52352.2637614553, float 52372.4331863445, float 52392.6045533093
				float 52412.7778619757, float 52432.95311197, float 52453.1303029186, float 52473.3094344483, float 52493.4905061858, float 52513.6735177582, float 52533.8584687926, float 52554.0453589165
				float 52574.2341877573, float 52594.4249549427, float 52614.6176601008, float 52634.8123028596, float 52655.0088828472, float 52675.2073996923, float 52695.4078530233, float 52715.6102424691
				float 52735.8145676587, float 52756.0208282211, float 52776.2290237858, float 52796.4391539822, float 52816.6512184401, float 52836.8652167892, float 52857.0811486596, float 52877.2990136816
				float 52897.5188114854, float 52917.7405417018, float 52937.9642039614, float 52958.1897978951, float 52978.4173231341, float 52998.6467793095, float 53018.878166053, float 53039.111482996
				float 53059.3467297704, float 53079.5839060082, float 53099.8230113415, float 53120.0640454026, float 53140.3070078241, float 53160.5518982385, float 53180.7987162789, float 53201.0474615781
				float 53221.2981337694, float 53241.5507324862, float 53261.805257362, float 53282.0617080305, float 53302.3200841256, float 53322.5803852815, float 53342.8426111323, float 53363.1067613125
				float 53383.3728354566, float 53403.6408331995, float 53423.910754176, float 53444.1825980213, float 53464.4563643706, float 53484.7320528595, float 53505.0096631235, float 53525.2891947985
				float 53545.5706475204, float 53565.8540209253, float 53586.1393146497, float 53606.42652833, float 53626.7156616028, float 53647.006714105, float 53667.2996854736, float 53687.5945753457
				float 53707.8913833588, float 53728.1901091504, float 53748.4907523581, float 53768.7933126197, float 53789.0977895735, float 53809.4041828575, float 53829.7124921101, float 53850.0227169699
				float 53870.3348570756, float 53890.6489120661, float 53910.9648815804, float 53931.2827652577, float 53951.6025627376, float 53971.9242736595, float 53992.2478976631, float 54012.5734343885
				float 54032.9008834755, float 54053.2302445646, float 54073.5615172961, float 54093.8947013106, float 54114.2297962489, float 54134.5668017519, float 54154.9057174606, float 54175.2465430163
				float 54195.5892780605, float 54215.9339222348, float 54236.2804751808, float 54256.6289365406, float 54276.9793059563, float 54297.33158307, float 54317.6857675244, float 54338.0418589618
				float 54358.3998570252, float 54378.7597613575, float 54399.1215716017, float 54419.4852874011, float 54439.8509083992, float 54460.2184342396, float 54480.5878645661, float 54500.9591990225
				float 54521.332437253, float 54541.7075789019, float 54562.0846236136, float 54582.4635710326, float 54602.8444208039, float 54623.2271725722, float 54643.6118259828, float 54663.9983806808
				float 54684.3868363118, float 54704.7771925212, float 54725.1694489549, float 54745.5636052588, float 54765.9596610789, float 54786.3576160616, float 54806.7574698533, float 54827.1592221004
				float 54847.5628724499, float 54867.9684205486, float 54888.3758660435, float 54908.785208582, float 54929.1964478114, float 54949.6095833793, float 54970.0246149335, float 54990.4415421217
				float 55010.8603645922, float 55031.2810819931, float 55051.7036939727, float 55072.1282001798, float 55092.5546002629, float 55112.9828938709, float 55133.4130806529, float 55153.8451602581
				float 55174.2791323358, float 55194.7149965356, float 55215.1527525071, float 55235.5923999003, float 55256.0339383651, float 55276.4773675517, float 55296.9226871104, float 55317.3698966917
				float 55337.8189959463, float 55358.269984525, float 55378.7228620788, float 55399.1776282589, float 55419.6342827164, float 55440.092825103, float 55460.5532550702, float 55481.0155722698
				float 55501.4797763538, float 55521.9458669742, float 55542.4138437833, float 55562.8837064337, float 55583.3554545777, float 55603.8290878683, float 55624.3046059582, float 55644.7820085006
				float 55665.2612951488, float 55685.742465556, float 55706.2255193758, float 55726.7104562619, float 55747.1972758683, float 55767.6859778488, float 55788.1765618578, float 55808.6690275495
				float 55829.1633745785, float 55849.6596025993, float 55870.1577112669, float 55890.6577002361, float 55911.1595691622, float 55931.6633177004, float 55952.1689455062, float 55972.6764522351
				float 55993.1858375429, float 56013.6971010857, float 56034.2102425193, float 56054.7252615001, float 56075.2421576845, float 56095.760930729, float 56116.2815802903, float 56136.8041060254
				float 56157.3285075911, float 56177.8547846447, float 56198.3829368436, float 56218.9129638452, float 56239.4448653071, float 56259.9786408873, float 56280.5142902435, float 56301.051813034
				float 56321.5912089171, float 56342.1324775511, float 56362.6756185946, float 56383.2206317064, float 56403.7675165454, float 56424.3162727706, float 56444.8669000412, float 56465.4193980167
				float 56485.9737663564, float 56506.5300047201, float 56527.0881127676, float 56547.6480901589, float 56568.2099365541, float 56588.7736516135, float 56609.3392349976, float 56629.9066863669
				float 56650.4760053822, float 56671.0471917044, float 56691.6202449946, float 56712.195164914, float 56732.7719511239, float 56753.3506032858, float 56773.9311210616, float 56794.5135041128
				float 56815.0977521017, float 56835.6838646902, float 56856.2718415406, float 56876.8616823155, float 56897.4533866774, float 56918.046954289, float 56938.6423848133, float 56959.2396779133
				float 56979.8388332521, float 57000.4398504932, float 57021.0427293001, float 57041.6474693364, float 57062.2540702659, float 57082.8625317526, float 57103.4728534606, float 57124.0850350541
				float 57144.6990761977, float 57165.3149765557, float 57185.9327357931, float 57206.5523535746, float 57227.1738295653, float 57247.7971634303, float 57268.4223548349, float 57289.0494034447
				float 57309.6783089253, float 57330.3090709424, float 57350.9416891619, float 57371.57616325, float 57392.2124928728, float 57412.8506776968, float 57433.4907173884, float 57454.1326116144
				float 57474.7763600415, float 57495.4219623368, float 57516.0694181673, float 57536.7187272003, float 57557.3698891033, float 57578.0229035439, float 57598.6777701896, float 57619.3344887086
				float 57639.9930587686, float 57660.6534800379, float 57681.3157521849, float 57701.979874878, float 57722.6458477857, float 57743.313670577, float 57763.9833429206, float 57784.6548644856
				float 57805.3282349412, float 57826.0034539569, float 57846.680521202, float 57867.3594363463, float 57888.0401990595, float 57908.7228090116, float 57929.4072658727, float 57950.093569313
				float 57970.7817190029, float 57991.4717146129, float 58012.1635558138, float 58032.8572422762, float 58053.5527736713, float 58074.2501496701, float 58094.949369944, float 58115.6504341642
				float 58136.3533420024, float 58157.0580931303, float 58177.7646872197, float 58198.4731239426, float 58219.1834029713, float 58239.8955239778, float 58260.6094866348, float 58281.3252906148
				float 58302.0429355904, float 58322.7624212347, float 58343.4837472205, float 58364.2069132211, float 58384.9319189098, float 58405.6587639599, float 58426.3874480452, float 58447.1179708393
				float 58467.8503320162, float 58488.5845312499, float 58509.3205682145, float 58530.0584425843, float 58550.7981540339, float 58571.5397022379, float 58592.2830868709, float 58613.0283076079
				float 58633.775364124, float 58654.5242560943, float 58675.2749831941, float 58696.0275450989, float 58716.7819414843, float 58737.5381720262, float 58758.2962364003, float 58779.0561342827
				float 58799.8178653497, float 58820.5814292775, float 58841.3468257426, float 58862.1140544217, float 58882.8831149915, float 58903.6540071289, float 58924.4267305109, float 58945.2012848147
				float 58965.9776697177, float 58986.7558848973, float 59007.5359300311, float 59028.317804797, float 59049.1015088727, float 59069.8870419363, float 59090.674403666, float 59111.4635937402
				float 59132.2546118373, float 59153.0474576358, float 59173.8421308146, float 59194.6386310525, float 59215.4369580285, float 59236.2371114219, float 59257.0390909118, float 59277.8428961779
				float 59298.6485268996, float 59319.4559827567, float 59340.2652634291, float 59361.0763685967, float 59381.8892979398, float 59402.7040511386, float 59423.5206278735, float 59444.3390278251
				float 59465.1592506742, float 59485.9812961016, float 59506.8051637883, float 59527.6308534153, float 59548.458364664, float 59569.2876972159, float 59590.1188507523, float 59610.9518249551
				float 59631.786619506, float 59652.6232340871, float 59673.4616683803, float 59694.301922068, float 59715.1439948326, float 59735.9878863565, float 59756.8335963225, float 59777.6811244133
				float 59798.5304703118, float 59819.3816337012, float 59840.2346142646, float 59861.0894116854, float 59881.9460256471, float 59902.8044558333, float 59923.6647019277, float 59944.5267636144
				float 59965.3906405772, float 59986.2563325005, float 60007.1238390684, float 60027.9931599655, float 60048.8642948764, float 60069.7372434857, float 60090.6120054783, float 60111.4885805393
				float 60132.3669683537, float 60153.2471686069, float 60174.1291809842, float 60195.0130051712, float 60215.8986408535, float 60236.7860877171, float 60257.6753454477, float 60278.5664137317
				float 60299.459292255, float 60320.3539807042, float 60341.2504787658, float 60362.1487861262, float 60383.0489024724, float 60403.9508274912, float 60424.8545608697, float 60445.760102295
				float 60466.6674514545, float 60487.5766080356, float 60508.4875717259, float 60529.400342213, float 60550.3149191849, float 60571.2313023295, float 60592.149491335, float 60613.0694858896
				float 60633.9912856817, float 60654.9148903998, float 60675.8402997326, float 60696.7675133688, float 60717.6965309975, float 60738.6273523076, float 60759.5599769884, float 60780.4944047291
				float 60801.4306352193, float 60822.3686681486, float 60843.3085032066, float 60864.2501400832, float 60885.1935784685, float 60906.1388180525, float 60927.0858585256, float 60948.034699578
				float 60968.9853409004, float 60989.9377821834, float 61010.8920231179, float 61031.8480633946, float 61052.8059027048, float 61073.7655407395, float 61094.7269771901, float 61115.6902117481
				float 61136.6552441051, float 61157.6220739527, float 61178.5907009829, float 61199.5611248876, float 61220.533345359, float 61241.5073620892, float 61262.4831747707, float 61283.4607830959
				float 61304.4401867576, float 61325.4213854486, float 61346.4043788616, float 61367.3891666898, float 61388.3757486263, float 61409.3641243644, float 61430.3542935976, float 61451.3462560194
				float 61472.3400113235, float 61493.3355592038, float 61514.3328993541, float 61535.3320314687, float 61556.3329552416, float 61577.3356703673, float 61598.3401765402, float 61619.346473455
				float 61640.3545608063, float 61661.3644382891, float 61682.3761055983, float 61703.3895624291, float 61724.4048084767, float 61745.4218434365, float 61766.4406670041, float 61787.461278875
				float 61808.4836787451, float 61829.5078663102, float 61850.5338412664, float 61871.5616033099, float 61892.591152137, float 61913.622487444, float 61934.6556089275, float 61955.6905162843
				float 61976.727209211, float 61997.7656874047, float 62018.8059505625, float 62039.8479983814, float 62060.8918305588, float 62081.9374467923, float 62102.9848467793, float 62124.0340302176
				float 62145.084996805, float 62166.1377462394, float 62187.192278219, float 62208.248592442, float 62229.3066886067, float 62250.3665664117, float 62271.4282255554, float 62292.4916657366
				float 62313.5568866543, float 62334.6238880073, float 62355.6926694948, float 62376.763230816, float 62397.8355716703, float 62418.9096917571, float 62439.9855907762, float 62461.0632684272
				float 62482.1427244101, float 62503.2239584247, float 62524.3069701713, float 62545.39175935, float 62566.4783256614, float 62587.5666688058, float 62608.6567884839, float 62629.7486843964
				float 62650.8423562444, float 62671.9378037286, float 62693.0350265504, float 62714.1340244109, float 62735.2347970115, float 62756.3373440537, float 62777.4416652393, float 62798.5477602699
				float 62819.6556288474, float 62840.7652706738, float 62861.8766854513, float 62882.9898728822, float 62904.1048326688, float 62925.2215645136, float 62946.3400681193, float 62967.4603431887
				float 62988.5823894245, float 63009.7062065299, float 63030.831794208, float 63051.959152162, float 63073.0882800954, float 63094.2191777115, float 63115.3518447142, float 63136.486280807
				float 63157.6224856939, float 63178.760459079, float 63199.9002006662, float 63221.04171016, float 63242.1849872646, float 63263.3300316845, float 63284.4768431245, float 63305.6254212891
				float 63326.7757658834, float 63347.9278766123, float 63369.0817531808, float 63390.2373952943, float 63411.3948026581, float 63432.5539749777, float 63453.7149119587, float 63474.8776133068
				float 63496.0420787279, float 63517.208307928, float 63538.3763006131, float 63559.5460564895, float 63580.7175752635, float 63601.8908566416, float 63623.0659003304, float 63644.2427060365
				float 63665.4212734669, float 63686.6016023284, float 63707.7836923281, float 63728.9675431733, float 63750.1531545713, float 63771.3405262294, float 63792.5296578553, float 63813.7205491567
				float 63834.9131998412, float 63856.107609617, float 63877.3037781919, float 63898.5017052743, float 63919.7013905723, float 63940.9028337944, float 63962.1060346491, float 63983.3109928451
				float 64004.5177080911, float 64025.7261800961, float 64046.9364085689, float 64068.1483932189, float 64089.3621337552, float 64110.5776298872, float 64131.7948813244, float 64153.0138877764
				float 64174.234648953, float 64195.4571645639, float 64216.6814343193, float 64237.9074579291, float 64259.1352351036, float 64280.3647655532, float 64301.5960489882, float 64322.8290851192
				float 64344.063873657, float 64365.3004143124, float 64386.5387067962, float 64407.7787508196, float 64429.0205460937, float 64450.2640923298, float 64471.5093892393, float 64492.7564365337
				float 64514.0052339247, float 64535.255781124, float 64556.5080778436, float 64577.7621237954, float 64599.0179186915, float 64620.2754622442, float 64641.5347541658, float 64662.7957941689
				float 64684.0585819659, float 64705.3231172697, float 64726.589399793, float 64747.8574292488, float 64769.1272053501, float 64790.3987278102, float 64811.6719963424, float 64832.94701066
				float 64854.2237704766, float 64875.5022755058, float 64896.7825254615, float 64918.0645200574, float 64939.3482590077, float 64960.6337420264, float 64981.9209688278, float 65003.2099391262
				float 65024.5006526361, float 65045.7931090721, float 65067.0873081489, float 65088.3832495813, float 65109.6809330843, float 65130.9803583729, float 65152.2815251623, float 65173.5844331677
				float 65194.8890821047, float 65216.1954716887, float 65237.5036016353, float 65258.8134716604, float 65280.1250814797, float 65301.4384308092, float 65322.7535193652, float 65344.0703468637
				float 65365.3889130212, float 65386.709217554, float 65408.0312601787, float 65429.3550406121, float 65450.6805585708, float 65472.0078137719, float 65493.3368059324, float 65514.6675347693
				float 65536.0, float 65557.3342013418, float 65578.6701385122, float 65600.0078112288, float 65621.3472192093, float 65642.6883621716, float 65664.0312398336, float 65685.3758519134
				float 65706.7221981291, float 65728.0702781991, float 65749.4200918417, float 65770.7716387754, float 65792.1249187189, float 65813.479931391, float 65834.8366765105, float 65856.1951537963
				float 65877.5553629676, float 65898.9173037436, float 65920.2809758435, float 65941.6463789869, float 65963.0135128932, float 65984.3823772821, float 66005.7529718734, float 66027.125296387
				float 66048.4993505428, float 66069.875134061, float 66091.2526466618, float 66112.6318880656, float 66134.0128579928, float 66155.3955561639, float 66176.7799822996, float 66198.1661361208
				float 66219.5540173483, float 66240.9436257031, float 66262.3349609064, float 66283.7280226794, float 66305.1228107434, float 66326.51932482, float 66347.9175646307, float 66369.3175298972
				float 66390.7192203412, float 66412.1226356848, float 66433.5277756499, float 66454.9346399586, float 66476.3432283333, float 66497.7535404963, float 66519.16557617, float 66540.579335077
				float 66561.9948169401, float 66583.4120214821, float 66604.8309484257, float 66626.2515974942, float 66647.6739684106, float 66669.0980608982, float 66690.5238746804, float 66711.9514094806
				float 66733.3806650224, float 66754.8116410295, float 66776.2443372257, float 66797.678753335, float 66819.1148890813, float 66840.5527441889, float 66861.9923183819, float 66883.4336113847
				float 66904.8766229219, float 66926.3213527179, float 66947.7678004975, float 66969.2159659855, float 66990.6658489067, float 67012.1174489863, float 67033.5707659493, float 67055.025799521
				float 67076.4825494268, float 67097.9410153921, float 67119.4011971424, float 67140.8630944036, float 67162.3267069012, float 67183.7920343614, float 67205.25907651, float 67226.7278330732
				float 67248.1983037772, float 67269.6704883484, float 67291.1443865131, float 67312.6199979981, float 67334.0973225299, float 67355.5763598353, float 67377.0571096412, float 67398.5395716746
				float 67420.0237456626, float 67441.5096313323, float 67462.9972284112, float 67484.4865366267, float 67505.9775557062, float 67527.4702853775, float 67548.9647253683, float 67570.4608754064
				float 67591.9587352198, float 67613.4583045366, float 67634.959583085, float 67656.4625705933, float 67677.9672667899, float 67699.4736714033, float 67720.981784162, float 67742.4916047949
				float 67764.0031330308, float 67785.5163685986, float 67807.0313112273, float 67828.5479606462, float 67850.0663165844, float 67871.5863787714, float 67893.1081469366, float 67914.6316208096
				float 67936.1568001201, float 67957.683684598, float 67979.212273973, float 68000.7425679753, float 68022.2745663349, float 68043.8082687821, float 68065.3436750471, float 68086.8807848606
				float 68108.4195979529, float 68129.9601140548, float 68151.502332897, float 68173.0462542103, float 68194.5918777258, float 68216.1392031746, float 68237.6882302877, float 68259.2389587965
				float 68280.7913884325, float 68302.345518927, float 68323.9013500118, float 68345.4588814185, float 68367.0181128789, float 68388.579044125, float 68410.1416748888, float 68431.7060049025
				float 68453.2720338983, float 68474.8397616085, float 68496.4091877655, float 68517.9803121021, float 68539.5531343507, float 68561.1276542443, float 68582.7038715156, float 68604.2817858976
				float 68625.8613971235, float 68647.4427049264, float 68669.0257090396, float 68690.6104091965, float 68712.1968051307, float 68733.7848965756, float 68755.3746832651, float 68776.966164933
				float 68798.5593413131, float 68820.1542121396, float 68841.7507771465, float 68863.349036068, float 68884.9489886386, float 68906.5506345927, float 68928.1539736647, float 68949.7590055895
				float 68971.3657301016, float 68992.974146936, float 69014.5842558276, float 69036.1960565116, float 69057.809548723, float 69079.4247321972, float 69101.0416066695, float 69122.6601718755
				float 69144.2804275506, float 69165.9023734306, float 69187.5260092513, float 69209.1513347486, float 69230.7783496585, float 69252.407053717, float 69274.0374466604, float 69295.669528225
				float 69317.3032981472, float 69338.9387561635, float 69360.5759020105, float 69382.214735425, float 69403.8552561438, float 69425.4974639037, float 69447.1413584418, float 69468.7869394953
				float 69490.4342068014, float 69512.0831600974, float 69533.7337991207, float 69555.3861236089, float 69577.0401332997, float 69598.6958279307, float 69620.3532072398, float 69642.012270965
				float 69663.6730188443, float 69685.3354506158, float 69706.9995660178, float 69728.6653647887, float 69750.332846667, float 69772.0020113911, float 69793.6728586997, float 69815.3453883316
				float 69837.0196000257, float 69858.6954935209, float 69880.3730685562, float 69902.0523248709, float 69923.7332622042, float 69945.4158802955, float 69967.1001788842, float 69988.7861577099
				float 70010.4738165124, float 70032.1631550312, float 70053.8541730064, float 70075.5468701779, float 70097.2412462857, float 70118.9373010701, float 70140.6350342713, float 70162.3344456297
				float 70184.0355348857, float 70205.73830178, float 70227.4427460532, float 70249.1488674461, float 70270.8566656995, float 70292.5661405545, float 70314.2772917521, float 70335.9901190335
				float 70357.7046221399, float 70379.4208008128, float 70401.1386547936, float 70422.8581838239, float 70444.5793876453, float 70466.3022659997, float 70488.0268186289, float 70509.7530452749
				float 70531.4809456797, float 70553.2105195856, float 70574.9417667347, float 70596.6746868695, float 70618.4092797324, float 70640.1455450661, float 70661.8834826131, float 70683.6230921163
				float 70705.3643733184, float 70727.1073259625, float 70748.8519497917, float 70770.598244549, float 70792.3462099778, float 70814.0958458214, float 70835.8471518232, float 70857.6001277269
				float 70879.354773276, float 70901.1110882144, float 70922.8690722858, float 70944.6287252343, float 70966.3900468039, float 70988.1530367386, float 71009.9176947829, float 71031.6840206809
				float 71053.4520141772, float 71075.2216750162, float 71096.9930029427, float 71118.7659977013, float 71140.5406590369, float 71162.3169866943, float 71184.0949804187, float 71205.8746399552
				float 71227.655965049, float 71249.4389554453, float 71271.2236108896, float 71293.0099311275, float 71314.7979159045, float 71336.5875649663, float 71358.3788780588, float 71380.1718549278
				float 71401.9664953193, float 71423.7627989795, float 71445.5607656545, float 71467.3603950906, float 71489.1616870342, float 71510.9646412318, float 71532.76925743, float 71554.5755353754
				float 71576.3834748148, float 71598.193075495, float 71620.0043371631, float 71641.8172595662, float 71663.6318424512, float 71685.4480855656, float 71707.2659886566, float 71729.0855514718
				float 71750.9067737586, float 71772.7296552647, float 71794.5541957378, float 71816.3803949257, float 71838.2082525764, float 71860.037768438, float 71881.8689422584, float 71903.7017737859
				float 71925.5362627689, float 71947.3724089558, float 71969.2102120949, float 71991.049671935, float 72012.8907882247, float 72034.7335607128, float 72056.5779891482, float 72078.4240732798
				float 72100.2718128568, float 72122.1212076283, float 72143.9722573435, float 72165.8249617518, float 72187.6793206027, float 72209.5353336457, float 72231.3930006304, float 72253.2523213067
				float 72275.1132954242, float 72296.9759227329, float 72318.840202983, float 72340.7061359243, float 72362.5737213073, float 72384.4429588821, float 72406.3138483992, float 72428.186389609
				float 72450.0605822622, float 72471.9364261094, float 72493.8139209014, float 72515.6930663891, float 72537.5738623234, float 72559.4563084554, float 72581.3404045361, float 72603.226150317
				float 72625.1135455493, float 72647.0025899843, float 72668.8932833738, float 72690.7856254692, float 72712.6796160223, float 72734.5752547848, float 72756.4725415088, float 72778.3714759461
				float 72800.2720578489, float 72822.1742869694, float 72844.0781630597, float 72865.9836858723, float 72887.8908551596, float 72909.7996706742, float 72931.7101321687, float 72953.6222393959
				float 72975.5359921085, float 72997.4513900595, float 73019.368433002, float 73041.2871206889, float 73063.2074528736, float 73085.1294293093, float 73107.0530497494, float 73128.9783139473
				float 73150.9052216567, float 73172.8337726312, float 73194.7639666246, float 73216.6958033906, float 73238.6292826833, float 73260.5644042566, float 73282.5011678648, float 73304.4395732619
				float 73326.3796202023, float 73348.3213084405, float 73370.2646377308, float 73392.209607828, float 73414.1562184865, float 73436.1044694613, float 73458.0543605072, float 73480.0058913791
				float 73501.959061832, float 73523.9138716211, float 73545.8703205017, float 73567.8284082289, float 73589.7881345583, float 73611.7494992454, float 73633.7125020456, float 73655.6771427148
				float 73677.6434210085, float 73699.6113366829, float 73721.5808894937, float 73743.552079197, float 73765.524905549, float 73787.4993683059, float 73809.4754672239, float 73831.4532020596
				float 73853.4325725693, float 73875.4135785097, float 73897.3962196375, float 73919.3804957094, float 73941.3664064823, float 73963.3539517131, float 73985.343131159, float 74007.3339445769
				float 74029.3263917241, float 74051.320472358, float 74073.3161862359, float 74095.3135331153, float 74117.3125127538, float 74139.3131249091, float 74161.315369339, float 74183.3192458012
				float 74205.3247540537, float 74227.3318938546, float 74249.340664962, float 74271.351067134, float 74293.3631001291, float 74315.3767637054, float 74337.3920576217, float 74359.4089816363
				float 74381.427535508, float 74403.4477189955, float 74425.4695318577, float 74447.4929738534, float 74469.5180447417, float 74491.5447442817, float 74513.5730722325, float 74535.6030283536
				float 74557.6346124041, float 74579.6678241436, float 74601.7026633316, float 74623.7391297278, float 74645.7772230919, float 74667.8169431837, float 74689.8582897631, float 74711.9012625901
				float 74733.9458614247, float 74755.9920860272, float 74778.0399361578, float 74800.0894115768, float 74822.1405120447, float 74844.193237322, float 74866.2475871692, float 74888.3035613472
				float 74910.3611596166, float 74932.4203817384, float 74954.4812274735, float 74976.543696583, float 74998.6077888279, float 75020.6735039696, float 75042.7408417693, float 75064.8098019885
				float 75086.8803843885, float 75108.9525887311, float 75131.0264147778, float 75153.1018622905, float 75175.1789310309, float 75197.2576207609, float 75219.3379312427, float 75241.4198622382
				float 75263.5034135097, float 75285.5885848195, float 75307.6753759299, float 75329.7637866033, float 75351.8538166024, float 75373.9454656896, float 75396.0387336278, float 75418.1336201797
				float 75440.2301251082, float 75462.3282481764, float 75484.4279891471, float 75506.5293477837, float 75528.6323238492, float 75550.7369171071, float 75572.8431273207, float 75594.9509542536
				float 75617.0603976692, float 75639.1714573313, float 75661.2841330037, float 75683.3984244501, float 75705.5143314344, float 75727.6318537208, float 75749.7509910732, float 75771.8717432559
				float 75793.9941100331, float 75816.1180911692, float 75838.2436864286, float 75860.3708955759, float 75882.4997183756, float 75904.6301545924, float 75926.7622039912, float 75948.8958663368
				float 75971.0311413942, float 75993.1680289283, float 76015.3065287044, float 76037.4466404876, float 76059.5883640432, float 76081.7316991367, float 76103.8766455334, float 76126.0232029989
				float 76148.1713712989, float 76170.321150199, float 76192.4725394652, float 76214.6255388633, float 76236.7801481592, float 76258.936367119, float 76281.0941955089, float 76303.2536330951
				float 76325.414679644, float 76347.5773349219, float 76369.7415986952, float 76391.9074707307, float 76414.0749507949, float 76436.2440386546, float 76458.4147340766, float 76480.5870368278
				float 76502.7609466752, float 76524.9364633859, float 76547.1135867271, float 76569.2923164659, float 76591.4726523698, float 76613.6545942062, float 76635.8381417425, float 76658.0232947463
				float 76680.2100529854, float 76702.3984162273, float 76724.5883842401, float 76746.7799567916, float 76768.9731336499, float 76791.1679145829, float 76813.3642993589, float 76835.5622877462
				float 76857.761879513, float 76879.9630744278, float 76902.1658722591, float 76924.3702727755, float 76946.5762757457, float 76968.7838809384, float 76990.9930881225, float 77013.2038970669
				float 77035.4163075406, float 77057.6303193126, float 77079.8459321522, float 77102.0631458287, float 77124.2819601113, float 77146.5023747695, float 77168.7243895728, float 77190.9480042907
				float 77213.173218693, float 77235.4000325494, float 77257.6284456298, float 77279.858457704, float 77302.0900685421, float 77324.3232779142, float 77346.5580855904, float 77368.7944913409
				float 77391.0324949361, float 77413.2720961465, float 77435.5132947425, float 77457.7560904947, float 77480.0004831738, float 77502.2464725505, float 77524.4940583956, float 77546.7432404801
				float 77568.9940185749, float 77591.2463924512, float 77613.50036188, float 77635.7559266327, float 77658.0130864804, float 77680.2718411948, float 77702.5321905471, float 77724.794134309
				float 77747.0576722522, float 77769.3228041483, float 77791.5895297693, float 77813.8578488868, float 77836.1277612731, float 77858.3992667, float 77880.6723649398, float 77902.9470557646
				float 77925.2233389468, float 77947.5012142588, float 77969.7806814729, float 77992.0617403618, float 78014.3443906981, float 78036.6286322545, float 78058.9144648037, float 78081.2018881187
				float 78103.4909019724, float 78125.7815061378, float 78148.0737003881, float 78170.3674844963, float 78192.6628582359, float 78214.9598213802, float 78237.2583737025, float 78259.5585149765
				float 78281.8602449756, float 78304.1635634737, float 78326.4684702444, float 78348.7749650615, float 78371.0830476991, float 78393.3927179311, float 78415.7039755316, float 78438.0168202747
				float 78460.3312519347, float 78482.6472702859, float 78504.9648751027, float 78527.2840661596, float 78549.6048432312, float 78571.927206092, float 78594.2511545169, float 78616.5766882806
				float 78638.903807158, float 78661.232510924, float 78683.5627993538, float 78705.8946722224, float 78728.228129305, float 78750.5631703769, float 78772.8997952134, float 78795.2380035901
				float 78817.5777952824, float 78839.9191700659, float 78862.2621277164, float 78884.6066680094, float 78906.952790721, float 78929.3004956271, float 78951.6497825035, float 78974.0006511264
				float 78996.3531012719, float 79018.7071327163, float 79041.062745236, float 79063.4199386072, float 79085.7787126064, float 79108.1390670103, float 79130.5010015954, float 79152.8645161384
				float 79175.2296104162, float 79197.5962842055, float 79219.9645372834, float 79242.3343694269, float 79264.705780413, float 79287.0787700189, float 79309.453338022, float 79331.8294841995
				float 79354.2072083289, float 79376.5865101876, float 79398.9673895532, float 79421.3498462034, float 79443.733879916, float 79466.1194904686, float 79488.5066776392, float 79510.8954412058
				float 79533.2857809464, float 79555.6776966392, float 79578.0711880622, float 79600.4662549939, float 79622.8628972125, float 79645.2611144965, float 79667.6609066245, float 79690.0622733749
				float 79712.4652145265, float 79734.8697298579, float 79757.2758191481, float 79779.683482176, float 79802.0927187204, float 79824.5035285605, float 79846.9159114753, float 79869.3298672442
				float 79891.7453956463, float 79914.1624964612, float 79936.5811694681, float 79959.0014144466, float 79981.4232311763, float 80003.8466194369, float 80026.2715790081, float 80048.6981096698
				float 80071.1262112018, float 80093.5558833842, float 80115.9871259971, float 80138.4199388204, float 80160.8543216345, float 80183.2902742197, float 80205.7277963563, float 80228.1668878247
				float 80250.6075484055, float 80273.0497778793, float 80295.4935760268, float 80317.9389426287, float 80340.3858774657, float 80362.834380319, float 80385.2844509693, float 80407.7360891978
				float 80430.1892947856, float 80452.6440675139, float 80475.100407164, float 80497.5583135173, float 80520.0177863552, float 80542.4788254592, float 80564.9414306109, float 80587.405601592
				float 80609.8713381842, float 80632.3386401693, float 80654.8075073293, float 80677.2779394461, float 80699.7499363017, float 80722.2234976783, float 80744.698623358, float 80767.1753131232
				float 80789.6535667562, float 80812.1333840395, float 80834.6147647554, float 80857.0977086867, float 80879.5822156158, float 80902.0682853257, float 80924.5559175991, float 80947.0451122188
				float 80969.5358689679, float 80992.0281876293, float 81014.5220679861, float 81037.0175098216, float 81059.514512919, float 81082.0130770616, float 81104.5132020328, float 81127.0148876162
				float 81149.5181335952, float 81172.0229397535, float 81194.5293058748, float 81217.0372317429, float 81239.5467171416, float 81262.057761855, float 81284.5703656669, float 81307.0845283614
				float 81329.6002497228, float 81352.1175295352, float 81374.636367583, float 81397.1567636505, float 81419.6787175221, float 81442.2022289825, float 81464.7272978162, float 81487.2539238079
				float 81509.7821067424, float 81532.3118464044, float 81554.8431425789, float 81577.3759950508, float 81599.9104036053, float 81622.4463680273, float 81644.9838881022, float 81667.5229636152
				float 81690.0635943516, float 81712.6057800968, float 81735.1495206365, float 81757.694815756, float 81780.2416652411, float 81802.7900688774, float 81825.3400264508, float 81847.8915377472
				float 81870.4446025524, float 81892.9992206525, float 81915.5553918335, float 81938.1131158817, float 81960.6723925832, float 81983.2332217243, float 82005.7956030915, float 82028.3595364712
				float 82050.9250216499, float 82073.4920584142, float 82096.0606465508, float 82118.6307858464, float 82141.2024760879, float 82163.7757170621, float 82186.3505085559, float 82208.9268503566
				float 82231.504742251, float 82254.0841840266, float 82276.6651754704, float 82299.2477163699, float 82321.8318065123, float 82344.4174456853, float 82367.0046336763, float 82389.5933702731
				float 82412.1836552632, float 82434.7754884344, float 82457.3688695746, float 82479.9637984717, float 82502.5602749137, float 82525.1582986886, float 82547.7578695846, float 82570.3589873899
				float 82592.9616518927, float 82615.5658628814, float 82638.1716201444, float 82660.7789234703, float 82683.3877726475, float 82705.9981674647, float 82728.6101077107, float 82751.2235931741
				float 82773.8386236439, float 82796.455198909, float 82819.0733187584, float 82841.6929829812, float 82864.3141913664, float 82886.9369437034, float 82909.5612397813, float 82932.1870793896
				float 82954.8144623177, float 82977.4433883551, float 83000.0738572914, float 83022.7058689161, float 83045.3394230191, float 83067.9745193901, float 83090.611157819, float 83113.2493380956
				float 83135.8890600101, float 83158.5303233525, float 83181.1731279129, float 83203.8174734815, float 83226.4633598487, float 83249.1107868047, float 83271.7597541401, float 83294.4102616454
				float 83317.062309111, float 83339.7158963277, float 83362.3710230862, float 83385.0276891772, float 83407.6858943916, float 83430.3456385204, float 83453.0069213545, float 83475.669742685
				float 83498.3341023031, float 83521.0, float 83543.6674355669, float 83566.3364087952, float 83589.0069194764, float 83611.6789674019, float 83634.3525523632, float 83657.0276741522
				float 83679.7043325604, float 83702.3825273796, float 83725.0622584016, float 83747.7435254185, float 83770.4263282222, float 83793.1106666047, float 83815.7965403582, float 83838.4839492748
				float 83861.1728931469, float 83883.8633717668, float 83906.555384927, float 83929.2489324198, float 83951.9440140378, float 83974.6406295737, float 83997.3387788202, float 84020.0384615699
				float 84042.7396776159, float 84065.4424267508, float 84088.1467087679, float 84110.8525234599, float 84133.5598706202, float 84156.2687500418, float 84178.979161518, float 84201.6911048422
				float 84224.4045798077, float 84247.119586208, float 84269.8361238366, float 84292.5541924872, float 84315.2737919533, float 84337.9949220287, float 84360.7175825073, float 84383.4417731829
				float 84406.1674938495, float 84428.8947443011, float 84451.6235243317, float 84474.3538337355, float 84497.0856723068, float 84519.8190398399, float 84542.553936129, float 84565.2903609687
				float 84588.0283141534, float 84610.7677954777, float 84633.5088047363, float 84656.2513417238, float 84678.9954062351, float 84701.7409980649, float 84724.4881170083, float 84747.2367628601
				float 84769.9869354154, float 84792.7386344694, float 84815.4918598173, float 84838.2466112542, float 84861.0028885756, float 84883.7606915768, float 84906.5200200533, float 84929.2808738006
				float 84952.0432526143, float 84974.8071562902, float 84997.5725846238, float 85020.3395374111, float 85043.108014448, float 85065.8780155302, float 85088.649540454, float 85111.4225890153
				float 85134.1971610103, float 85156.9732562353, float 85179.7508744864, float 85202.5300155601, float 85225.3106792527, float 85248.0928653609, float 85270.876573681, float 85293.6618040098
				float 85316.448556144, float 85339.2368298802, float 85362.0266250154, float 85384.8179413464, float 85407.6107786701, float 85430.4051367837, float 85453.2010154842, float 85475.9984145689
				float 85498.7973338348, float 85521.5977730794, float 85544.3997320999, float 85567.2032106939, float 85590.0082086588, float 85612.8147257922, float 85635.6227618918, float 85658.4323167553
				float 85681.2433901803, float 85704.0559819649, float 85726.8700919068, float 85749.6857198041, float 85772.5028654548, float 85795.321528657, float 85818.1417092089, float 85840.9634069087
				float 85863.7866215548, float 85886.6113529455, float 85909.4376008792, float 85932.2653651546, float 85955.0946455701, float 85977.9254419244, float 86000.7577540163, float 86023.5915816444
				float 86046.4269246078, float 86069.2637827051, float 86092.1021557356, float 86114.9420434981, float 86137.7834457918, float 86160.6263624159, float 86183.4707931697, float 86206.3167378524
				float 86229.1641962634, float 86252.0131682022, float 86274.8636534683, float 86297.7156518613, float 86320.5691631807, float 86343.4241872264, float 86366.2807237981, float 86389.1387726957
				float 86411.998333719, float 86434.859406668, float 86457.7219913428, float 86480.5860875435, float 86503.4516950703, float 86526.3188137234, float 86549.187443303, float 86572.0575836097
				float 86594.9292344438, float 86617.8023956058, float 86640.6770668963, float 86663.5532481159, float 86686.4309390654, float 86709.3101395454, float 86732.190849357, float 86755.0730683008
				float 86777.956796178, float 86800.8420327894, float 86823.7287779364, float 86846.6170314199, float 86869.5067930412, float 86892.3980626016, float 86915.2908399025, float 86938.1851247453
				float 86961.0809169315, float 86983.9782162626, float 87006.8770225403, float 87029.7773355662, float 87052.6791551421, float 87075.5824810698, float 87098.4873131512, float 87121.3936511882
				float 87144.3014949829, float 87167.2108443373, float 87190.1216990535, float 87213.0340589339, float 87235.9479237805, float 87258.8632933958, float 87281.7801675822, float 87304.6985461422
				float 87327.6184288782, float 87350.5398155929, float 87373.4627060889, float 87396.3871001689, float 87419.3129976358, float 87442.2403982923, float 87465.1693019415, float 87488.0997083863
				float 87511.0316174297, float 87533.9650288749, float 87556.899942525, float 87579.8363581833, float 87602.774275653, float 87625.7136947376, float 87648.6546152405, float 87671.5970369652
				float 87694.5409597151, float 87717.4863832941, float 87740.4333075057, float 87763.3817321538, float 87786.3316570421, float 87809.2830819745, float 87832.2360067549, float 87855.1904311875
				float 87878.1463550762, float 87901.1037782251, float 87924.0627004386, float 87947.0231215209, float 87969.9850412763, float 87992.9484595091, float 88015.9133760239, float 88038.8797906252
				float 88061.8477031175, float 88084.8171133056, float 88107.7880209941, float 88130.7604259877, float 88153.7343280915, float 88176.7097271101, float 88199.6866228487, float 88222.6650151123
				float 88245.6449037059, float 88268.6262884347, float 88291.609169104, float 88314.5935455189, float 88337.5794174849, float 88360.5667848074, float 88383.5556472919, float 88406.5460047438
				float 88429.5378569688, float 88452.5312037726, float 88475.5260449609, float 88498.5223803394, float 88521.5202097141, float 88544.5195328909, float 88567.5203496756, float 88590.5226598745
				float 88613.5264632935, float 88636.5317597389, float 88659.5385490169, float 88682.5468309337, float 88705.5566052959, float 88728.5678719096, float 88751.5806305815, float 88774.5948811181
				float 88797.610623326, float 88820.6278570118, float 88843.6465819824, float 88866.6667980445, float 88889.6885050049, float 88912.7117026706, float 88935.7363908486, float 88958.7625693459
				float 88981.7902379696, float 89004.819396527, float 89027.8500448251, float 89050.8821826714, float 89073.9158098732, float 89096.9509262379, float 89119.987531573, float 89143.025625686
				float 89166.0652083846, float 89189.1062794764, float 89212.1488387691, float 89235.1928860706, float 89258.2384211887, float 89281.2854439313, float 89304.3339541064, float 89327.383951522
				float 89350.4354359863, float 89373.4884073074, float 89396.5428652935, float 89419.598809753, float 89442.6562404942, float 89465.7151573254, float 89488.7755600552, float 89511.8374484921
				float 89534.9008224448, float 89557.9656817217, float 89581.0320261318, float 89604.0998554837, float 89627.1691695864, float 89650.2399682487, float 89673.3122512795, float 89696.386018488
				float 89719.4612696832, float 89742.5380046743, float 89765.6162232704, float 89788.6959252808, float 89811.777110515, float 89834.8597787822, float 89857.943929892, float 89881.0295636538
				float 89904.1166798773, float 89927.205278372, float 89950.2953589477, float 89973.3869214142, float 89996.4799655813, float 90019.5744912588, float 90042.6704982567, float 90065.767986385
				float 90088.8669554538, float 90111.9674052733, float 90135.0693356535, float 90158.1727464048, float 90181.2776373374, float 90204.3840082618, float 90227.4918589884, float 90250.6011893276
				float 90273.71199909, float 90296.8242880863, float 90319.9380561271, float 90343.0533030232, float 90366.1700285853, float 90389.2882326243, float 90412.4079149511, float 90435.5290753768
				float 90458.6517137123, float 90481.7758297687, float 90504.9014233572, float 90528.0284942891, float 90551.1570423755, float 90574.2870674279, float 90597.4185692576, float 90620.5515476762
				float 90643.6860024951, float 90666.8219335259, float 90689.9593405802, float 90713.0982234698, float 90736.2385820064, float 90759.3804160018, float 90782.523725268, float 90805.6685096168
				float 90828.8147688602, float 90851.9625028104, float 90875.1117112795, float 90898.2623940795, float 90921.4145510228, float 90944.5681819217, float 90967.7232865886, float 90990.8798648357
				float 91014.0379164757, float 91037.1974413211, float 91060.3584391844, float 91083.5209098783, float 91106.6848532156, float 91129.850269009, float 91153.0171570714, float 91176.1855172156
				float 91199.3553492547, float 91222.5266530015, float 91245.6994282693, float 91268.873674871, float 91292.04939262, float 91315.2265813296, float 91338.4052408129, float 91361.5853708833
				float 91384.7669713543, float 91407.9500420395, float 91431.1345827522, float 91454.3205933063, float 91477.5080735152, float 91500.6970231927, float 91523.8874421527, float 91547.0793302089
				float 91570.2726871753, float 91593.4675128659, float 91616.6638070945, float 91639.8615696754, float 91663.0608004227, float 91686.2614991506, float 91709.4636656732, float 91732.667299805
				float 91755.8724013603, float 91779.0789701536, float 91802.2870059993, float 91825.4965087119, float 91848.7074781062, float 91871.9199139967, float 91895.1338161982, float 91918.3491845254
				float 91941.5660187933, float 91964.7843188166, float 91988.0040844105, float 92011.2253153898, float 92034.4480115697, float 92057.6721727653, float 92080.8977987918, float 92104.1248894644
				float 92127.3534445984, float 92150.5834640093, float 92173.8149475124, float 92197.0478949232, float 92220.2823060573, float 92243.5181807303, float 92266.7555187577, float 92289.9943199555
				float 92313.2345841392, float 92336.4763111248, float 92359.7195007281, float 92382.9641527651, float 92406.2102670518, float 92429.4578434042, float 92452.7068816385, float 92475.9573815708
				float 92499.2093430175, float 92522.4627657947, float 92545.7176497188, float 92568.9739946063, float 92592.2318002736, float 92615.4910665373, float 92638.7517932138, float 92662.01398012
				float 92685.2776270723, float 92708.5427338877, float 92731.8093003829, float 92755.0773263749, float 92778.3468116804, float 92801.6177561166, float 92824.8901595004, float 92848.164021649
				float 92871.4393423794, float 92894.716121509, float 92917.994358855, float 92941.2740542348, float 92964.5552074656, float 92987.837818365, float 93011.1218867504, float 93034.4074124395
				float 93057.6943952498, float 93080.9828349989, float 93104.2727315048, float 93127.564084585, float 93150.8568940575, float 93174.1511597401, float 93197.4468814509, float 93220.7440590078
				float 93244.0426922289, float 93267.3427809323, float 93290.6443249363, float 93313.9473240589, float 93337.2517781187, float 93360.5576869338, float 93383.8650503227, float 93407.1738681039
				float 93430.484140096, float 93453.7958661174, float 93477.1090459868, float 93500.4236795229, float 93523.7397665446, float 93547.0573068705, float 93570.3763003195, float 93593.6967467106
				float 93617.0186458627, float 93640.3419975949, float 93663.6668017262, float 93686.9930580759, float 93710.320766463, float 93733.6499267069, float 93756.9805386269, float 93780.3126020424
				float 93803.6461167726, float 93826.9810826373, float 93850.3174994558, float 93873.6553670479, float 93896.994685233, float 93920.3354538311, float 93943.6776726617, float 93967.0213415447
				float 93990.3664603001, float 94013.7130287476, float 94037.0610467074, float 94060.4105139995, float 94083.7614304439, float 94107.1137958609, float 94130.4676100705, float 94153.8228728932
				float 94177.1795841491, float 94200.5377436588, float 94223.8973512425, float 94247.2584067209, float 94270.6209099144, float 94293.9848606437, float 94317.3502587294, float 94340.7171039922
				float 94364.0853962529, float 94387.4551353324, float 94410.8263210514, float 94434.1989532309, float 94457.5730316919, float 94480.9485562555, float 94504.3255267427, float 94527.7039429747
				float 94551.0838047727, float 94574.465111958, float 94597.8478643519, float 94621.2320617758, float 94644.6177040511, float 94668.0047909993, float 94691.3933224419, float 94714.7832982005
				float 94738.1747180968, float 94761.5675819525, float 94784.9618895893, float 94808.3576408291, float 94831.7548354937, float 94855.1534734051, float 94878.5535543852, float 94901.9550782561
				float 94925.3580448398, float 94948.7624539585, float 94972.1683054345, float 94995.5755990899, float 95018.9843347471, float 95042.3945122284, float 95065.8061313563, float 95089.2191919532
				float 95112.6336938416, float 95136.0496368442, float 95159.4670207836, float 95182.8858454825, float 95206.3061107635, float 95229.7278164496, float 95253.1509623636, float 95276.5755483283
				float 95300.0015741668, float 95323.4290397021, float 95346.8579447572, float 95370.2882891552, float 95393.7200727194, float 95417.153295273, float 95440.5879566393, float 95464.0240566416
				float 95487.4615951033, float 95510.9005718479, float 95534.3409866989, float 95557.7828394798, float 95581.2261300143, float 95604.670858126, float 95628.1170236386, float 95651.564626376
				float 95675.0136661619, float 95698.4641428203, float 95721.9160561751, float 95745.3694060502, float 95768.8241922698, float 95792.2804146579, float 95815.7380730387, float 95839.1971672364
				float 95862.6576970752, float 95886.1196623795, float 95909.5830629737, float 95933.0478986821, float 95956.5141693293, float 95979.9818747397, float 96003.451014738, float 96026.9215891488
				float 96050.3935977968, float 96073.8670405067, float 96097.3419171034, float 96120.8182274116, float 96144.2959712564, float 96167.7751484626, float 96191.2557588552, float 96214.7378022594
				float 96238.2212785003, float 96261.706187403, float 96285.1925287927, float 96308.6803024948, float 96332.1695083345, float 96355.6601461373, float 96379.1522157286, float 96402.6457169339
				float 96426.1406495787, float 96449.6370134886, float 96473.1348084893, float 96496.6340344065, float 96520.134691066, float 96543.6367782935, float 96567.1402959149, float 96590.6452437562
				float 96614.1516216432, float 96637.6594294021, float 96661.168666859, float 96684.6793338398, float 96708.1914301709, float 96731.7049556784, float 96755.2199101887, float 96778.736293528
				float 96802.2541055228, float 96825.7733459996, float 96849.2940147847, float 96872.8161117049, float 96896.3396365866, float 96919.8645892565, float 96943.3909695414, float 96966.918777268
				float 96990.4480122631, float 97013.9786743535, float 97037.5107633663, float 97061.0442791283, float 97084.5792214667, float 97108.1155902084, float 97131.6533851806, float 97155.1926062105
				float 97178.7332531253, float 97202.2753257523, float 97225.8188239189, float 97249.3637474523, float 97272.9100961802, float 97296.4578699299, float 97320.0070685291, float 97343.5576918052
				float 97367.109739586, float 97390.6632116992, float 97414.2181079725, float 97437.7744282337, float 97461.3321723108, float 97484.8913400315, float 97508.4519312239, float 97532.013945716
				float 97555.5773833358, float 97579.1422439115, float 97602.7085272713, float 97626.2762332433, float 97649.8453616558, float 97673.4159123372, float 97696.9878851159, float 97720.5612798202
				float 97744.1360962787, float 97767.7123343199, float 97791.2899937723, float 97814.8690744647, float 97838.4495762257, float 97862.031498884, float 97885.6148422685, float 97909.1996062079
				float 97932.7857905312, float 97956.3733950673, float 97979.9624196453, float 98003.5528640941, float 98027.1447282429, float 98050.7380119208, float 98074.332714957, float 98097.9288371808
				float 98121.5263784215, float 98145.1253385085, float 98168.7257172711, float 98192.3275145388, float 98215.9307301411, float 98239.5353639077, float 98263.141415668, float 98286.7488852518
				float 98310.3577724888, float 98333.9680772088, float 98357.5797992415, float 98381.1929384169, float 98404.8074945648, float 98428.4234675152, float 98452.0408570983, float 98475.6596631439
				float 98499.2798854823, float 98522.9015239437, float 98546.5245783582, float 98570.1490485561, float 98593.7749343678, float 98617.4022356236, float 98641.0309521541, float 98664.6610837895
				float 98688.2926303606, float 98711.9255916978, float 98735.5599676318, float 98759.1957579933, float 98782.832962613, float 98806.4715813217, float 98830.1116139503, float 98853.7530603296
				float 98877.3959202905, float 98901.0401936641, float 98924.6858802814, float 98948.3329799734, float 98971.9814925714, float 98995.6314179065, float 99019.2827558098, float 99042.9355061129
				float 99066.5896686469, float 99090.2452432433, float 99113.9022297334, float 99137.5606279489, float 99161.2204377212, float 99184.8816588819, float 99208.5442912626, float 99232.2083346952
				float 99255.8737890112, float 99279.5406540426, float 99303.208929621, float 99326.8786155785, float 99350.549711747, float 99374.2222179584, float 99397.8961340449, float 99421.5714598384
				float 99445.2481951712, float 99468.9263398754, float 99492.6058937833, float 99516.2868567272, float 99539.9692285394, float 99563.6530090523, float 99587.3381980983, float 99611.02479551
				float 99634.7128011199, float 99658.4022147605, float 99682.0930362645, float 99705.7852654647, float 99729.4789021937, float 99753.1739462843, float 99776.8703975694, float 99800.5682558819
				float 99824.2675210547, float 99847.9681929208, float 99871.6702713132, float 99895.373756065, float 99919.0786470094, float 99942.7849439795, float 99966.4926468086, float 99990.20175533
				float 100013.912269377, float 100037.624188783, float 100061.337513381, float 100085.052243006, float 100108.768377489, float 100132.485916666, float 100156.20486037, float 100179.925208433
				float 100203.646960691, float 100227.370116977, float 100251.094677124, float 100274.820640967, float 100298.548008339, float 100322.276779075, float 100346.006953008, float 100369.738529973
				float 100393.471509803, float 100417.205892334, float 100440.941677398, float 100464.678864831, float 100488.417454466, float 100512.157446138, float 100535.898839682, float 100559.641634932
				float 100583.385831722, float 100607.131429887, float 100630.878429261, float 100654.62682968, float 100678.376630978, float 100702.12783299, float 100725.88043555, float 100749.634438493
				float 100773.389841655, float 100797.14664487, float 100820.904847973, float 100844.6644508, float 100868.425453184, float 100892.187854963, float 100915.95165597, float 100939.716856041
				float 100963.483455011, float 100987.251452716, float 101011.020848991, float 101034.791643672, float 101058.563836593, float 101082.337427591, float 101106.112416501, float 101129.888803158
				float 101153.666587399, float 101177.445769059, float 101201.226347974, float 101225.008323979, float 101248.791696911, float 101272.576466606, float 101296.362632899, float 101320.150195626
				float 101343.939154624, float 101367.729509729, float 101391.521260776, float 101415.314407602, float 101439.108950044, float 101462.904887937, float 101486.702221118, float 101510.500949424
				float 101534.30107269, float 101558.102590754, float 101581.905503451, float 101605.709810619, float 101629.515512094, float 101653.322607712, float 101677.131097311, float 101700.940980728
				float 101724.752257798, float 101748.564928359, float 101772.378992249, float 101796.194449303, float 101820.011299359, float 101843.829542254, float 101867.649177825, float 101891.47020591
				float 101915.292626345, float 101939.116438968, float 101962.941643615, float 101986.768240126, float 102010.596228335, float 102034.425608083, float 102058.256379205, float 102082.088541539
				float 102105.922094923, float 102129.757039195, float 102153.593374192, float 102177.431099752, float 102201.270215713, float 102225.110721912, float 102248.952618188, float 102272.795904378
				float 102296.64058032, float 102320.486645853, float 102344.334100814, float 102368.182945042, float 102392.033178375, float 102415.88480065, float 102439.737811707, float 102463.592211383
				float 102487.447999517, float 102511.305175947, float 102535.163740512, float 102559.02369305, float 102582.8850334, float 102606.7477614, float 102630.611876889, float 102654.477379705
				float 102678.344269688, float 102702.212546676, float 102726.082210508, float 102749.953261022, float 102773.825698059, float 102797.699521456, float 102821.574731052, float 102845.451326687
				float 102869.329308201, float 102893.208675431, float 102917.089428217, float 102940.971566398, float 102964.855089815, float 102988.739998305, float 103012.626291708, float 103036.513969865
				float 103060.403032614, float 103084.293479794, float 103108.185311246, float 103132.078526809, float 103155.973126322, float 103179.869109626, float 103203.76647656, float 103227.665226964
				float 103251.565360677, float 103275.46687754, float 103299.369777393, float 103323.274060075, float 103347.179725427, float 103371.086773288, float 103394.995203499, float 103418.9050159
				float 103442.816210332, float 103466.728786633, float 103490.642744646, float 103514.558084209, float 103538.474805164, float 103562.392907351, float 103586.31239061, float 103610.233254782
				float 103634.155499707, float 103658.079125227, float 103682.004131182, float 103705.930517412, float 103729.858283758, float 103753.787430062, float 103777.717956163, float 103801.649861904
				float 103825.583147124, float 103849.517811665, float 103873.453855368, float 103897.391278074, float 103921.330079624, float 103945.270259859, float 103969.211818621, float 103993.15475575
				float 104017.099071089, float 104041.044764478, float 104064.991835759, float 104088.940284773, float 104112.890111362, float 104136.841315367, float 104160.79389663, float 104184.747854993
				float 104208.703190297, float 104232.659902384, float 104256.617991096, float 104280.577456274, float 104304.538297761, float 104328.500515398, float 104352.464109027, float 104376.429078491
				float 104400.395423631, float 104424.363144289, float 104448.332240308, float 104472.30271153, float 104496.274557797, float 104520.247778951, float 104544.222374834, float 104568.19834529
				float 104592.175690159, float 104616.154409286, float 104640.134502512, float 104664.115969679, float 104688.098810631, float 104712.08302521, float 104736.068613259, float 104760.05557462
				float 104784.043909136, float 104808.03361665, float 104832.024697005, float 104856.017150044, float 104880.01097561, float 104904.006173545, float 104928.002743693, float 104952.000685897
				float 104976.0, float 105000.000685845, float 105024.002743275, float 105048.006172134, float 105072.010972265, float 105096.017143511, float 105120.024685715, float 105144.033598722
				float 105168.043882374, float 105192.055536516, float 105216.06856099, float 105240.08295564, float 105264.09872031, float 105288.115854844, float 105312.134359086, float 105336.154232878
				float 105360.175476066, float 105384.198088493, float 105408.222070002, float 105432.247420438, float 105456.274139645, float 105480.302227468, float 105504.331683749, float 105528.362508333
				float 105552.394701065, float 105576.428261788, float 105600.463190347, float 105624.499486586, float 105648.537150351, float 105672.576181484, float 105696.61657983, float 105720.658345235
				float 105744.701477542, float 105768.745976596, float 105792.791842242, float 105816.839074325, float 105840.887672688, float 105864.937637178, float 105888.988967638, float 105913.041663915
				float 105937.095725851, float 105961.151153293, float 105985.207946086, float 106009.266104074, float 106033.325627103, float 106057.386515017, float 106081.448767663, float 106105.512384884
				float 106129.577366527, float 106153.643712436, float 106177.711422458, float 106201.780496437, float 106225.850934218, float 106249.922735648, float 106273.995900572, float 106298.070428835
				float 106322.146320284, float 106346.223574762, float 106370.302192118, float 106394.382172195, float 106418.46351484, float 106442.546219898, float 106466.630287217, float 106490.71571664
				float 106514.802508015, float 106538.890661188, float 106562.980176004, float 106587.071052309, float 106611.16328995, float 106635.256888773, float 106659.351848624, float 106683.448169349
				float 106707.545850795, float 106731.644892808, float 106755.745295234, float 106779.84705792, float 106803.950180712, float 106828.054663457, float 106852.160506001, float 106876.267708191
				float 106900.376269874, float 106924.486190896, float 106948.597471104, float 106972.710110345, float 106996.824108466, float 107020.939465313, float 107045.056180733, float 107069.174254574
				float 107093.293686682, float 107117.414476904, float 107141.536625088, float 107165.66013108, float 107189.784994728, float 107213.91121588, float 107238.038794381, float 107262.16773008
				float 107286.298022823, float 107310.429672459, float 107334.562678835, float 107358.697041797, float 107382.832761195, float 107406.969836874, float 107431.108268683, float 107455.24805647
				float 107479.389200082, float 107503.531699366, float 107527.675554171, float 107551.820764345, float 107575.967329735, float 107600.115250189, float 107624.264525555, float 107648.415155681
				float 107672.567140415, float 107696.720479605, float 107720.8751731, float 107745.031220747, float 107769.188622394, float 107793.347377891, float 107817.507487084, float 107841.668949823
				float 107865.831765956, float 107889.995935331, float 107914.161457796, float 107938.328333201, float 107962.496561393, float 107986.666142222, float 108010.837075536, float 108035.009361183
				float 108059.182999012, float 108083.357988872, float 108107.534330613, float 108131.712024081, float 108155.891069127, float 108180.0714656, float 108204.253213348, float 108228.43631222
				float 108252.620762066, float 108276.806562734, float 108300.993714073, float 108325.182215934, float 108349.372068164, float 108373.563270614, float 108397.755823132, float 108421.949725567
				float 108446.144977771, float 108470.34157959, float 108494.539530876, float 108518.738831478, float 108542.939481244, float 108567.141480026, float 108591.344827671, float 108615.549524031
				float 108639.755568955, float 108663.962962292, float 108688.171703892, float 108712.381793605, float 108736.593231282, float 108760.806016771, float 108785.020149924, float 108809.235630589
				float 108833.452458617, float 108857.670633858, float 108881.890156163, float 108906.11102538, float 108930.333241362, float 108954.556803957, float 108978.781713016, float 109003.00796839
				float 109027.235569928, float 109051.464517482, float 109075.694810902, float 109099.926450037, float 109124.15943474, float 109148.39376486, float 109172.629440248, float 109196.866460754
				float 109221.10482623, float 109245.344536526, float 109269.585591493, float 109293.827990982, float 109318.071734843, float 109342.316822928, float 109366.563255087, float 109390.811031172
				float 109415.060151034, float 109439.310614523, float 109463.562421491, float 109487.815571789, float 109512.070065268, float 109536.325901779, float 109560.583081174, float 109584.841603304
				float 109609.101468021, float 109633.362675175, float 109657.625224619, float 109681.889116203, float 109706.15434978, float 109730.4209252, float 109754.688842316, float 109778.958100979
				float 109803.228701041, float 109827.500642354, float 109851.773924769, float 109876.048548138, float 109900.324512313, float 109924.601817146, float 109948.88046249, float 109973.160448195
				float 109997.441774114, float 110021.724440099, float 110046.008446002, float 110070.293791675, float 110094.580476971, float 110118.868501741, float 110143.157865839, float 110167.448569116
				float 110191.740611424, float 110216.033992616, float 110240.328712545, float 110264.624771063, float 110288.922168022, float 110313.220903276, float 110337.520976676, float 110361.822388075
				float 110386.125137326, float 110410.429224282, float 110434.734648795, float 110459.041410718, float 110483.349509905, float 110507.658946207, float 110531.969719478, float 110556.281829572
				float 110580.59527634, float 110604.910059635, float 110629.226179312, float 110653.543635223, float 110677.862427221, float 110702.18255516, float 110726.504018892, float 110750.826818271
				float 110775.150953151, float 110799.476423384, float 110823.803228824, float 110848.131369325, float 110872.46084474, float 110896.791654922, float 110921.123799726, float 110945.457279004
				float 110969.792092611, float 110994.1282404, float 111018.465722224, float 111042.804537938, float 111067.144687396, float 111091.48617045, float 111115.828986956, float 111140.173136767
				float 111164.518619737, float 111188.865435719, float 111213.213584569, float 111237.56306614, float 111261.913880286, float 111286.266026862, float 111310.619505721, float 111334.974316719
				float 111359.330459708, float 111383.687934544, float 111408.046741081, float 111432.406879173, float 111456.768348675, float 111481.131149441, float 111505.495281326, float 111529.860744184
				float 111554.22753787, float 111578.595662238, float 111602.965117144, float 111627.335902442, float 111651.708017986, float 111676.081463633, float 111700.456239235, float 111724.832344649
				float 111749.209779729, float 111773.58854433, float 111797.968638307, float 111822.350061515, float 111846.73281381, float 111871.116895046, float 111895.502305079, float 111919.889043764
				float 111944.277110955, float 111968.666506509, float 111993.05723028, float 112017.449282124, float 112041.842661897, float 112066.237369453, float 112090.633404649, float 112115.03076734
				float 112139.42945738, float 112163.829474627, float 112188.230818935, float 112212.633490161, float 112237.037488159, float 112261.442812787, float 112285.849463898, float 112310.25744135
				float 112334.666744998, float 112359.077374698, float 112383.489330307, float 112407.902611679, float 112432.317218671, float 112456.73315114, float 112481.15040894, float 112505.568991929
				float 112529.988899963, float 112554.410132897, float 112578.832690588, float 112603.256572893, float 112627.681779667, float 112652.108310767, float 112676.53616605, float 112700.965345371
				float 112725.395848588, float 112749.827675557, float 112774.260826134, float 112798.695300176, float 112823.13109754, float 112847.568218083, float 112872.00666166, float 112896.44642813
				float 112920.887517348, float 112945.329929172, float 112969.773663458, float 112994.218720064, float 113018.665098846, float 113043.112799661, float 113067.561822367, float 113092.012166819
				float 113116.463832877, float 113140.916820396, float 113165.371129234, float 113189.826759248, float 113214.283710296, float 113238.741982234, float 113263.20157492, float 113287.662488212
				float 113312.124721966, float 113336.588276041, float 113361.053150293, float 113385.519344581, float 113409.986858761, float 113434.455692692, float 113458.925846232, float 113483.397319237
				float 113507.870111565, float 113532.344223075, float 113556.819653624, float 113581.29640307, float 113605.774471271, float 113630.253858085, float 113654.734563369, float 113679.216586983
				float 113703.699928782, float 113728.184588627, float 113752.670566375, float 113777.157861884, float 113801.646475012, float 113826.136405617, float 113850.627653559, float 113875.120218694
				float 113899.614100882, float 113924.109299981, float 113948.605815849, float 113973.103648344, float 113997.602797326, float 114022.103262652, float 114046.605044182, float 114071.108141773
				float 114095.612555285, float 114120.118284576, float 114144.625329505, float 114169.133689931, float 114193.643365712, float 114218.154356708, float 114242.666662776, float 114267.180283777
				float 114291.695219569, float 114316.21147001, float 114340.729034961, float 114365.24791428, float 114389.768107826, float 114414.289615458, float 114438.812437036, float 114463.336572418
				float 114487.862021465, float 114512.388784034, float 114536.916859987, float 114561.446249181, float 114585.976951476, float 114610.508966733, float 114635.042294809, float 114659.576935565
				float 114684.112888861, float 114708.650154555, float 114733.188732508, float 114757.728622579, float 114782.269824628, float 114806.812338515, float 114831.356164099, float 114855.90130124
				float 114880.447749798, float 114904.995509633, float 114929.544580605, float 114954.094962574, float 114978.6466554, float 115003.199658942, float 115027.753973062, float 115052.309597618
				float 115076.866532472, float 115101.424777483, float 115125.984332512, float 115150.545197419, float 115175.107372063, float 115199.670856307, float 115224.235650009, float 115248.80175303
				float 115273.369165231, float 115297.937886473, float 115322.507916615, float 115347.079255518, float 115371.651903043, float 115396.225859051, float 115420.801123402, float 115445.377695957
				float 115469.955576577, float 115494.534765122, float 115519.115261453, float 115543.697065431, float 115568.280176918, float 115592.864595773, float 115617.450321858, float 115642.037355034
				float 115666.625695162, float 115691.215342103, float 115715.806295718, float 115740.398555869, float 115764.992122416, float 115789.58699522, float 115814.183174144, float 115838.780659047
				float 115863.379449793, float 115887.979546241, float 115912.580948254, float 115937.183655692, float 115961.787668418, float 115986.392986292, float 116010.999609177, float 116035.607536934
				float 116060.216769425, float 116084.827306511, float 116109.439148053, float 116134.052293915, float 116158.666743956, float 116183.282498041, float 116207.899556029, float 116232.517917783
				float 116257.137583165, float 116281.758552038, float 116306.380824262, float 116331.0043997, float 116355.629278213, float 116380.255459665, float 116404.882943918, float 116429.511730832
				float 116454.141820272, float 116478.773212098, float 116503.405906173, float 116528.03990236, float 116552.675200521, float 116577.311800518, float 116601.949702214, float 116626.58890547
				float 116651.229410151, float 116675.871216118, float 116700.514323233, float 116725.15873136, float 116749.804440361, float 116774.451450098, float 116799.099760435, float 116823.749371234
				float 116848.400282359, float 116873.052493671, float 116897.706005033, float 116922.36081631, float 116947.016927363, float 116971.674338055, float 116996.33304825, float 117020.993057811
				float 117045.6543666, float 117070.316974481, float 117094.980881317, float 117119.646086971, float 117144.312591306, float 117168.980394186, float 117193.649495474, float 117218.319895033
				float 117242.991592727, float 117267.664588419, float 117292.338881973, float 117317.014473251, float 117341.691362118, float 117366.369548437, float 117391.049032071, float 117415.729812885
				float 117440.411890742, float 117465.095265505, float 117489.779937038, float 117514.465905206, float 117539.153169872, float 117563.841730899, float 117588.531588152, float 117613.222741494
				float 117637.91519079, float 117662.608935903, float 117687.303976698, float 117712.000313039, float 117736.697944788, float 117761.396871812, float 117786.097093974, float 117810.798611137
				float 117835.501423167, float 117860.205529928, float 117884.910931283, float 117909.617627098, float 117934.325617236, float 117959.034901562, float 117983.745479941, float 118008.457352237
				float 118033.170518314, float 118057.884978037, float 118082.60073127, float 118107.317777879, float 118132.036117728, float 118156.755750681, float 118181.476676603, float 118206.19889536
				float 118230.922406815, float 118255.647210834, float 118280.373307282, float 118305.100696023, float 118329.829376922, float 118354.559349845, float 118379.290614656, float 118404.02317122
				float 118428.757019403, float 118453.49215907, float 118478.228590085, float 118502.966312314, float 118527.705325623, float 118552.445629876, float 118577.187224938, float 118601.930110676
				float 118626.674286954, float 118651.419753637, float 118676.166510592, float 118700.914557684, float 118725.663894778, float 118750.41452174, float 118775.166438435, float 118799.919644729
				float 118824.674140487, float 118849.429925576, float 118874.18699986, float 118898.945363207, float 118923.70501548, float 118948.465956548, float 118973.228186274, float 118997.991704525
				float 119022.756511167, float 119047.522606066, float 119072.289989088, float 119097.058660099, float 119121.828618965, float 119146.599865552, float 119171.372399727, float 119196.146221354
				float 119220.921330301, float 119245.697726434, float 119270.475409619, float 119295.254379723, float 119320.034636611, float 119344.816180151, float 119369.599010207, float 119394.383126648
				float 119419.168529339, float 119443.955218148, float 119468.743192939, float 119493.532453581, float 119518.32299994, float 119543.114831881, float 119567.907949273, float 119592.702351982
				float 119617.498039874, float 119642.295012816, float 119667.093270676, float 119691.892813319, float 119716.693640614, float 119741.495752426, float 119766.299148623, float 119791.103829071
				float 119815.909793639, float 119840.717042192, float 119865.525574598, float 119890.335390725, float 119915.146490438, float 119939.958873606, float 119964.772540096, float 119989.587489775
				float 120014.40372251, float 120039.221238168, float 120064.040036618, float 120088.860117726, float 120113.68148136, float 120138.504127387, float 120163.328055675, float 120188.153266091
				float 120212.979758503, float 120237.807532779, float 120262.636588786, float 120287.466926392, float 120312.298545464, float 120337.131445871, float 120361.96562748, float 120386.801090159
				float 120411.637833776, float 120436.475858198, float 120461.315163294, float 120486.155748932, float 120510.997614979, float 120535.840761304, float 120560.685187775, float 120585.530894259
				float 120610.377880625, float 120635.226146741, float 120660.075692475, float 120684.926517696, float 120709.778622271, float 120734.632006069, float 120759.486668959, float 120784.342610809
				float 120809.199831486, float 120834.05833086, float 120858.918108799, float 120883.779165171, float 120908.641499846, float 120933.505112691, float 120958.370003575, float 120983.236172367
				float 121008.103618935, float 121032.972343149, float 121057.842344876, float 121082.713623986, float 121107.586180348, float 121132.46001383, float 121157.335124301, float 121182.21151163
				float 121207.089175686, float 121231.968116338, float 121256.848333455, float 121281.729826906, float 121306.61259656, float 121331.496642287, float 121356.381963955, float 121381.268561433
				float 121406.156434591, float 121431.045583298, float 121455.936007423, float 121480.827706835, float 121505.720681405, float 121530.614931001, float 121555.510455492, float 121580.407254748
				float 121605.305328639, float 121630.204677034, float 121655.105299803, float 121680.007196815, float 121704.910367939, float 121729.814813046, float 121754.720532005, float 121779.627524686
				float 121804.535790959, float 121829.445330692, float 121854.356143757, float 121879.268230023, float 121904.181589359, float 121929.096221637, float 121954.012126725, float 121978.929304493
				float 122003.847754812, float 122028.767477552, float 122053.688472583, float 122078.610739775, float 122103.534278997, float 122128.459090121, float 122153.385173016, float 122178.312527552
				float 122203.241153601, float 122228.171051032, float 122253.102219715, float 122278.034659521, float 122302.96837032, float 122327.903351984, float 122352.839604381, float 122377.777127383
				float 122402.71592086, float 122427.655984683, float 122452.597318723, float 122477.539922849, float 122502.483796933, float 122527.428940846, float 122552.375354458, float 122577.323037639
				float 122602.271990262, float 122627.222212196, float 122652.173703312, float 122677.126463481, float 122702.080492575, float 122727.035790464, float 122751.992357019, float 122776.950192111
				float 122801.909295612, float 122826.869667392, float 122851.831307322, float 122876.794215274, float 122901.758391119, float 122926.723834728, float 122951.690545972, float 122976.658524723
				float 123001.627770852, float 123026.59828423, float 123051.570064729, float 123076.543112219, float 123101.517426574, float 123126.493007663, float 123151.469855359, float 123176.447969533
				float 123201.427350057, float 123226.407996802, float 123251.38990964, float 123276.373088442, float 123301.357533081, float 123326.343243428, float 123351.330219355, float 123376.318460733
				float 123401.307967435, float 123426.298739333, float 123451.290776297, float 123476.284078201, float 123501.278644917, float 123526.274476315, float 123551.271572269, float 123576.26993265
				float 123601.26955733, float 123626.270446182, float 123651.272599078, float 123676.276015889, float 123701.280696489, float 123726.286640749, float 123751.293848542, float 123776.30231974
				float 123801.312054216, float 123826.323051841, float 123851.335312488, float 123876.34883603, float 123901.36362234, float 123926.379671289, float 123951.39698275, float 123976.415556596
				float 124001.435392699, float 124026.456490933, float 124051.478851169, float 124076.502473281, float 124101.527357142, float 124126.553502623, float 124151.580909598, float 124176.60957794
				float 124201.639507521, float 124226.670698215, float 124251.703149894, float 124276.736862431, float 124301.7718357, float 124326.808069574, float 124351.845563924, float 124376.884318626
				float 124401.924333551, float 124426.965608573, float 124452.008143565, float 124477.0519384, float 124502.096992952, float 124527.143307094, float 124552.190880699, float 124577.23971364
				float 124602.289805792, float 124627.341157026, float 124652.393767218, float 124677.447636239, float 124702.502763965, float 124727.559150267, float 124752.616795021, float 124777.675698099
				float 124802.735859375, float 124827.797278723, float 124852.859956017, float 124877.92389113, float 124902.989083936, float 124928.055534308, float 124953.123242122, float 124978.192207249
				float 125003.262429566, float 125028.333908944, float 125053.406645259, float 125078.480638384, float 125103.555888193, float 125128.632394561, float 125153.710157361, float 125178.789176468
				float 125203.869451755, float 125228.950983097, float 125254.033770368, float 125279.117813443, float 125304.203112195, float 125329.289666499, float 125354.377476229, float 125379.46654126
				float 125404.556861466, float 125429.648436721, float 125454.7412669, float 125479.835351877, float 125504.930691527, float 125530.027285725, float 125555.125134345, float 125580.224237261
				float 125605.324594349, float 125630.426205483, float 125655.529070537, float 125680.633189387, float 125705.738561907, float 125730.845187972, float 125755.953067457, float 125781.062200236
				float 125806.172586185, float 125831.284225179, float 125856.397117092, float 125881.5112618, float 125906.626659177, float 125931.743309099, float 125956.86121144, float 125981.980366076
				float 126007.100772882, float 126032.222431734, float 126057.345342505, float 126082.469505072, float 126107.59491931, float 126132.721585094, float 126157.8495023, float 126182.978670802
				float 126208.109090477, float 126233.240761199, float 126258.373682844, float 126283.507855288, float 126308.643278406, float 126333.779952074, float 126358.917876167, float 126384.057050561
				float 126409.197475131, float 126434.339149753, float 126459.482074304, float 126484.626248658, float 126509.771672691, float 126534.91834628, float 126560.0662693, float 126585.215441626
				float 126610.365863136, float 126635.517533704, float 126660.670453207, float 126685.82462152, float 126710.98003852, float 126736.136704083, float 126761.294618084, float 126786.453780401
				float 126811.614190908, float 126836.775849483, float 126861.938756001, float 126887.102910339, float 126912.268312372, float 126937.434961978, float 126962.602859032, float 126987.772003411
				float 127012.942394992, float 127038.114033649, float 127063.286919261, float 127088.461051704, float 127113.636430854, float 127138.813056587, float 127163.99092878, float 127189.170047311
				float 127214.350412054, float 127239.532022888, float 127264.714879688, float 127289.898982332, float 127315.084330696, float 127340.270924657, float 127365.458764092, float 127390.647848878
				float 127415.838178891, float 127441.029754008, float 127466.222574107, float 127491.416639064, float 127516.611948757, float 127541.808503062, float 127567.006301856, float 127592.205345016
				float 127617.405632421, float 127642.607163946, float 127667.809939469, float 127693.013958867, float 127718.219222017, float 127743.425728797, float 127768.633479084, float 127793.842472755
				float 127819.052709687, float 127844.264189759, float 127869.476912847, float 127894.690878829, float 127919.906087582, float 127945.122538985, float 127970.340232913, float 127995.559169245
				float 128020.779347859, float 128046.000768632, float 128071.223431442, float 128096.447336167, float 128121.672482684, float 128146.89887087, float 128172.126500605, float 128197.355371765
				float 128222.585484228, float 128247.816837873, float 128273.049432577, float 128298.283268218, float 128323.518344674, float 128348.754661823, float 128373.992219543, float 128399.231017713
				float 128424.471056209, float 128449.712334911, float 128474.954853696, float 128500.198612443, float 128525.44361103, float 128550.689849335, float 128575.937327236, float 128601.186044612
				float 128626.436001341, float 128651.687197301, float 128676.93963237, float 128702.193306428, float 128727.448219352, float 128752.704371021, float 128777.961761314, float 128803.220390108
				float 128828.480257284, float 128853.741362718, float 128879.00370629, float 128904.267287878, float 128929.532107362, float 128954.798164619, float 128980.065459529, float 129005.33399197
				float 129030.603761821, float 129055.874768961, float 129081.147013269, float 129106.420494624, float 129131.695212904, float 129156.971167988, float 129182.248359756, float 129207.526788087
				float 129232.806452859, float 129258.087353951, float 129283.369491244, float 129308.652864615, float 129333.937473944, float 129359.22331911, float 129384.510399992, float 129409.79871647
				float 129435.088268423, float 129460.37905573, float 129485.67107827, float 129510.964335923, float 129536.258828569, float 129561.554556085, float 129586.851518354, float 129612.149715252
				float 129637.449146661, float 129662.749812459, float 129688.051712526, float 129713.354846742, float 129738.659214987, float 129763.964817139, float 129789.271653079, float 129814.579722687
				float 129839.889025841, float 129865.199562423, float 129890.511332311, float 129915.824335386, float 129941.138571527, float 129966.454040614, float 129991.770742528, float 130017.088677147
				float 130042.407844353, float 130067.728244025, float 130093.049876043, float 130118.372740287, float 130143.696836637, float 130169.022164974, float 130194.348725178, float 130219.676517128
				float 130245.005540705, float 130270.335795789, float 130295.667282261, float 130321.0, float 130346.333948887, float 130371.669128803, float 130397.005539628, float 130422.343181242
				float 130447.682053525, float 130473.022156358, float 130498.363489623, float 130523.706053198, float 130549.049846965, float 130574.394870804, float 130599.741124596, float 130625.088608221
				float 130650.437321561, float 130675.787264496, float 130701.138436906, float 130726.490838673, float 130751.844469677, float 130777.199329798, float 130802.555418919, float 130827.912736919
				float 130853.27128368, float 130878.631059082, float 130903.992063007, float 130929.354295336, float 130954.717755949, float 130980.082444727, float 131005.448361552, float 131030.815506305
				float 131056.183878866, float 131081.553479118, float 131106.924306941, float 131132.296362216, float 131157.669644825, float 131183.044154649, float 131208.419891569, float 131233.796855467
				float 131259.175046223, float 131284.55446372, float 131309.935107839, float 131335.316978461, float 131360.700075468, float 131386.084398741, float 131411.469948161, float 131436.856723611
				float 131462.244724972, float 131487.633952125, float 131513.024404953, float 131538.416083336, float 131563.808987157, float 131589.203116297, float 131614.598470638, float 131639.995050062
				float 131665.39285445, float 131690.791883685, float 131716.192137649, float 131741.593616222, float 131766.996319288, float 131792.400246728, float 131817.805398425, float 131843.211774259
				float 131868.619374114, float 131894.028197871, float 131919.438245412, float 131944.84951662, float 131970.262011377, float 131995.675729564, float 132021.090671065, float 132046.506835761
				float 132071.924223534, float 132097.342834268, float 132122.762667844, float 132148.183724144, float 132173.606003052, float 132199.029504448, float 132224.454228217, float 132249.88017424
				float 132275.3073424, float 132300.73573258, float 132326.165344661, float 132351.596178527, float 132377.02823406, float 132402.461511142, float 132427.896009658, float 132453.331729488
				float 132478.768670516, float 132504.206832625, float 132529.646215697, float 132555.086819616, float 132580.528644263, float 132605.971689523, float 132631.415955277, float 132656.861441409
				float 132682.308147802, float 132707.756074338, float 132733.205220901, float 132758.655587374, float 132784.107173639, float 132809.559979581, float 132835.014005081, float 132860.469250024
				float 132885.925714292, float 132911.383397768, float 132936.842300336, float 132962.30242188, float 132987.763762281, float 133013.226321424, float 133038.690099192, float 133064.155095469
				float 133089.621310137, float 133115.08874308, float 133140.557394182, float 133166.027263326, float 133191.498350395, float 133216.970655274, float 133242.444177846, float 133267.918917993
				float 133293.394875601, float 133318.872050552, float 133344.350442731, float 133369.83005202, float 133395.310878304, float 133420.792921467, float 133446.276181392, float 133471.760657963
				float 133497.246351064, float 133522.733260578, float 133548.22138639, float 133573.710728384, float 133599.201286444, float 133624.693060453, float 133650.186050295, float 133675.680255855
				float 133701.175677017, float 133726.672313664, float 133752.170165682, float 133777.669232953, float 133803.169515363, float 133828.671012795, float 133854.173725133, float 133879.677652263
				float 133905.182794067, float 133930.689150431, float 133956.196721239, float 133981.705506375, float 134007.215505724, float 134032.72671917, float 134058.239146597, float 134083.75278789
				float 134109.267642934, float 134134.783711612, float 134160.30099381, float 134185.819489413, float 134211.339198304, float 134236.860120368, float 134262.38225549, float 134287.905603556
				float 134313.430164448, float 134338.955938053, float 134364.482924255, float 134390.011122939, float 134415.54053399, float 134441.071157292, float 134466.60299273, float 134492.13604019
				float 134517.670299556, float 134543.205770713, float 134568.742453547, float 134594.280347942, float 134619.819453783, float 134645.359770955, float 134670.901299345, float 134696.444038835
				float 134721.987989313, float 134747.533150663, float 134773.079522769, float 134798.627105519, float 134824.175898796, float 134849.725902486, float 134875.277116474, float 134900.829540647
				float 134926.383174888, float 134951.938019084, float 134977.49407312, float 135003.051336881, float 135028.609810253, float 135054.169493121, float 135079.730385372, float 135105.29248689
				float 135130.855797561, float 135156.420317271, float 135181.986045905, float 135207.552983349, float 135233.121129489, float 135258.690484211, float 135284.2610474, float 135309.832818942
				float 135335.405798723, float 135360.979986628, float 135386.555382544, float 135412.131986357, float 135437.709797952, float 135463.288817215, float 135488.869044033, float 135514.450478291
				float 135540.033119875, float 135565.616968672, float 135591.202024567, float 135616.788287447, float 135642.375757197, float 135667.964433704, float 135693.554316855, float 135719.145406535
				float 135744.73770263, float 135770.331205027, float 135795.925913613, float 135821.521828272, float 135847.118948893, float 135872.71727536, float 135898.316807562, float 135923.917545383
				float 135949.519488711, float 135975.122637431, float 136000.726991431, float 136026.332550597, float 136051.939314816, float 136077.547283974, float 136103.156457957, float 136128.766836653
				float 136154.378419948, float 136179.991207729, float 136205.605199882, float 136231.220396295, float 136256.836796854, float 136282.454401445, float 136308.073209956, float 136333.693222274
				float 136359.314438285, float 136384.936857876, float 136410.560480935, float 136436.185307348, float 136461.811337002, float 136487.438569784, float 136513.067005581, float 136538.696644281
				float 136564.327485771, float 136589.959529937, float 136615.592776666, float 136641.227225847, float 136666.862877365, float 136692.499731109, float 136718.137786966, float 136743.777044822
				float 136769.417504565, float 136795.059166083, float 136820.702029263, float 136846.346093992, float 136871.991360158, float 136897.637827648, float 136923.285496349, float 136948.93436615
				float 136974.584436937, float 137000.235708598, float 137025.888181021, float 137051.541854093, float 137077.196727702, float 137102.852801736, float 137128.510076082, float 137154.168550628
				float 137179.828225261, float 137205.48909987, float 137231.151174343, float 137256.814448566, float 137282.478922428, float 137308.144595817, float 137333.81146862, float 137359.479540726
				float 137385.148812022, float 137410.819282397, float 137436.490951738, float 137462.163819934, float 137487.837886872, float 137513.513152441, float 137539.189616528, float 137564.867279022
				float 137590.546139811, float 137616.226198783, float 137641.907455827, float 137667.58991083, float 137693.27356368, float 137718.958414267, float 137744.644462478, float 137770.331708202
				float 137796.020151327, float 137821.709791741, float 137847.400629333, float 137873.092663991, float 137898.785895604, float 137924.48032406, float 137950.175949248, float 137975.872771057
				float 138001.570789374, float 138027.270004088, float 138052.970415089, float 138078.672022264, float 138104.374825502, float 138130.078824693, float 138155.784019724, float 138181.490410485
				float 138207.197996864, float 138232.906778751, float 138258.616756033, float 138284.327928599, float 138310.04029634, float 138335.753859143, float 138361.468616897, float 138387.184569492
				float 138412.901716817, float 138438.620058759, float 138464.339595209, float 138490.060326056, float 138515.782251188, float 138541.505370495, float 138567.229683865, float 138592.955191189
				float 138618.681892355, float 138644.409787252, float 138670.138875769, float 138695.869157797, float 138721.600633223, float 138747.333301938, float 138773.067163831, float 138798.802218791
				float 138824.538466708, float 138850.27590747, float 138876.014540968, float 138901.754367091, float 138927.495385728, float 138953.237596769, float 138978.981000103, float 139004.725595621
				float 139030.471383211, float 139056.218362763, float 139081.966534167, float 139107.715897312, float 139133.466452089, float 139159.218198387, float 139184.971136095, float 139210.725265104
				float 139236.480585303, float 139262.237096583, float 139287.994798832, float 139313.753691941, float 139339.513775799, float 139365.275050298, float 139391.037515326, float 139416.801170773
				float 139442.56601653, float 139468.332052487, float 139494.099278533, float 139519.867694559, float 139545.637300455, float 139571.408096111, float 139597.180081417, float 139622.953256263
				float 139648.72762054, float 139674.503174138, float 139700.279916946, float 139726.057848856, float 139751.836969757, float 139777.61727954, float 139803.398778096, float 139829.181465314
				float 139854.965341085, float 139880.7504053, float 139906.536657849, float 139932.324098622, float 139958.11272751, float 139983.902544404, float 140009.693549193, float 140035.48574177
				float 140061.279122023, float 140087.073689844, float 140112.869445124, float 140138.666387753, float 140164.464517622, float 140190.263834622, float 140216.064338643, float 140241.866029576
				float 140267.668907313, float 140293.472971743, float 140319.278222758, float 140345.084660248, float 140370.892284105, float 140396.701094219, float 140422.511090482, float 140448.322272784
				float 140474.134641017, float 140499.948195071, float 140525.762934838, float 140551.578860208, float 140577.395971073, float 140603.214267324, float 140629.033748851, float 140654.854415547
				float 140680.676267303, float 140706.499304009, float 140732.323525556, float 140758.148931838, float 140783.975522743, float 140809.803298164, float 140835.632257993, float 140861.46240212
				float 140887.293730437, float 140913.126242836, float 140938.959939207, float 140964.794819443, float 140990.630883435, float 141016.468131074, float 141042.306562252, float 141068.146176861
				float 141093.986974792, float 141119.828955936, float 141145.672120186, float 141171.516467434, float 141197.36199757, float 141223.208710487, float 141249.056606076, float 141274.905684229
				float 141300.755944838, float 141326.607387795, float 141352.460012992, float 141378.31382032, float 141404.168809671, float 141430.024980938, float 141455.882334013, float 141481.740868786
				float 141507.600585151, float 141533.461482999, float 141559.323562223, float 141585.186822714, float 141611.051264364, float 141636.916887067, float 141662.783690713, float 141688.651675195
				float 141714.520840405, float 141740.391186236, float 141766.26271258, float 141792.135419328, float 141818.009306374, float 141843.88437361, float 141869.760620927, float 141895.638048219
				float 141921.516655377, float 141947.396442295, float 141973.277408864, float 141999.159554978, float 142025.042880528, float 142050.927385407, float 142076.813069508, float 142102.699932723
				float 142128.587974944, float 142154.477196066, float 142180.367595979, float 142206.259174577, float 142232.151931753, float 142258.045867398, float 142283.940981407, float 142309.837273671
				float 142335.734744084, float 142361.633392538, float 142387.533218926, float 142413.434223141, float 142439.336405076, float 142465.239764624, float 142491.144301678, float 142517.05001613
				float 142542.956907874, float 142568.864976802, float 142594.774222808, float 142620.684645785, float 142646.596245626, float 142672.509022224, float 142698.422975472, float 142724.338105263
				float 142750.254411491, float 142776.171894048, float 142802.090552828, float 142828.010387724, float 142853.93139863, float 142879.853585438, float 142905.776948043, float 142931.701486336
				float 142957.627200213, float 142983.554089565, float 143009.482154287, float 143035.411394273, float 143061.341809414, float 143087.273399606, float 143113.206164741, float 143139.140104713
				float 143165.075219416, float 143191.011508742, float 143216.948972587, float 143242.887610843, float 143268.827423404, float 143294.768410164, float 143320.710571017, float 143346.653905856
				float 143372.598414574, float 143398.544097067, float 143424.490953227, float 143450.438982949, float 143476.388186125, float 143502.338562651, float 143528.29011242, float 143554.242835326
				float 143580.196731263, float 143606.151800125, float 143632.108041806, float 143658.0654562, float 143684.0240432, float 143709.983802702, float 143735.944734599, float 143761.906838785
				float 143787.870115155, float 143813.834563602, float 143839.800184021, float 143865.766976306, float 143891.734940351, float 143917.70407605, float 143943.674383299, float 143969.64586199
				float 143995.618512019, float 144021.59233328, float 144047.567325666, float 144073.543489074, float 144099.520823396, float 144125.499328528, float 144151.479004364, float 144177.459850798
				float 144203.441867725, float 144229.425055039, float 144255.409412636, float 144281.394940409, float 144307.381638253, float 144333.369506064, float 144359.358543735, float 144385.348751161
				float 144411.340128237, float 144437.332674858, float 144463.326390919, float 144489.321276313, float 144515.317330937, float 144541.314554685, float 144567.312947451, float 144593.312509131
				float 144619.31323962, float 144645.315138812, float 144671.318206603, float 144697.322442887, float 144723.327847559, float 144749.334420515, float 144775.342161649, float 144801.351070857
				float 144827.361148033, float 144853.372393073, float 144879.384805872, float 144905.398386325, float 144931.413134327, float 144957.429049774, float 144983.44613256, float 145009.464382582
				float 145035.483799733, float 145061.50438391, float 145087.526135008, float 145113.549052922, float 145139.573137548, float 145165.59838878, float 145191.624806515, float 145217.652390648
				float 145243.681141074, float 145269.711057689, float 145295.742140388, float 145321.774389067, float 145347.807803621, float 145373.842383946, float 145399.878129938, float 145425.915041492
				float 145451.953118504, float 145477.99236087, float 145504.032768485, float 145530.074341244, float 145556.117079045, float 145582.160981782, float 145608.206049351, float 145634.252281648
				float 145660.29967857, float 145686.348240011, float 145712.397965868, float 145738.448856036, float 145764.500910412, float 145790.554128892, float 145816.608511371, float 145842.664057745
				float 145868.720767911, float 145894.778641765, float 145920.837679202, float 145946.897880119, float 145972.959244412, float 145999.021771977, float 146025.08546271, float 146051.150316507
				float 146077.216333265, float 146103.28351288, float 146129.351855248, float 146155.421360265, float 146181.492027828, float 146207.563857833, float 146233.636850176, float 146259.711004754
				float 146285.786321463, float 146311.862800199, float 146337.94044086, float 146364.019243341, float 146390.099207539, float 146416.18033335, float 146442.262620671, float 146468.346069399
				float 146494.43067943, float 146520.516450661, float 146546.603382988, float 146572.691476308, float 146598.780730517, float 146624.871145514, float 146650.962721193, float 146677.055457452
				float 146703.149354187, float 146729.244411297, float 146755.340628676, float 146781.438006222, float 146807.536543832, float 146833.636241403, float 146859.737098832, float 146885.839116015
				float 146911.94229285, float 146938.046629234, float 146964.152125063, float 146990.258780234, float 147016.366594645, float 147042.475568193, float 147068.585700774, float 147094.696992287
				float 147120.809442627, float 147146.923051692, float 147173.03781938, float 147199.153745587, float 147225.270830212, float 147251.38907315, float 147277.508474299, float 147303.629033557
				float 147329.75075082, float 147355.873625987, float 147381.997658955, float 147408.12284962, float 147434.249197881, float 147460.376703634, float 147486.505366778, float 147512.63518721
				float 147538.766164826, float 147564.898299526, float 147591.031591206, float 147617.166039763, float 147643.301645096, float 147669.438407102, float 147695.576325679, float 147721.715400724
				float 147747.855632134, float 147773.997019809, float 147800.139563645, float 147826.28326354, float 147852.428119392, float 147878.574131099, float 147904.721298559, float 147930.869621669
				float 147957.019100327, float 147983.169734431, float 148009.321523879, float 148035.474468569, float 148061.628568399, float 148087.783823267, float 148113.94023307, float 148140.097797708
				float 148166.256517077, float 148192.416391077, float 148218.577419604, float 148244.739602558, float 148270.902939836, float 148297.067431337, float 148323.233076958, float 148349.399876597
				float 148375.567830154, float 148401.736937527, float 148427.907198612, float 148454.07861331, float 148480.251181518, float 148506.424903134, float 148532.599778057, float 148558.775806185
				float 148584.952987417, float 148611.13132165, float 148637.310808785, float 148663.491448718, float 148689.673241349, float 148715.856186575, float 148742.040284296, float 148768.22553441
				float 148794.411936816, float 148820.599491411, float 148846.788198096, float 148872.978056768, float 148899.169067326, float 148925.361229669, float 148951.554543695, float 148977.749009304
				float 149003.944626394, float 149030.141394863, float 149056.339314612, float 149082.538385537, float 149108.738607539, float 149134.939980516, float 149161.142504366, float 149187.34617899
				float 149213.551004286, float 149239.756980152, float 149265.964106489, float 149292.172383194, float 149318.381810166, float 149344.592387306, float 149370.804114512, float 149397.016991682
				float 149423.231018717, float 149449.446195515, float 149475.662521975, float 149501.879997997, float 149528.09862348, float 149554.318398322, float 149580.539322424, float 149606.761395685
				float 149632.984618003, float 149659.208989278, float 149685.43450941, float 149711.661178297, float 149737.88899584, float 149764.117961937, float 149790.348076488, float 149816.579339393
				float 149842.811750551, float 149869.045309861, float 149895.280017222, float 149921.515872535, float 149947.7528757, float 149973.991026614, float 150000.230325179, float 150026.470771293
				float 150052.712364857, float 150078.95510577, float 150105.198993932, float 150131.444029242, float 150157.6902116, float 150183.937540906, float 150210.18601706, float 150236.435639962
				float 150262.68640951, float 150288.938325606, float 150315.191388149, float 150341.445597038, float 150367.700952174, float 150393.957453457, float 150420.215100787, float 150446.473894063
				float 150472.733833186, float 150498.994918055, float 150525.257148571, float 150551.520524634, float 150577.785046144, float 150604.050713, float 150630.317525103, float 150656.585482354
				float 150682.854584652, float 150709.124831897, float 150735.39622399, float 150761.668760831, float 150787.942442319, float 150814.217268357, float 150840.493238843, float 150866.770353678
				float 150893.048612763, float 150919.328015997, float 150945.608563281, float 150971.890254516, float 150998.173089602, float 151024.45706844, float 151050.742190929, float 151077.02845697
				float 151103.315866465, float 151129.604419312, float 151155.894115414, float 151182.18495467, float 151208.476936982, float 151234.770062249, float 151261.064330372, float 151287.359741253
				float 151313.656294791, float 151339.953990887, float 151366.252829443, float 151392.552810359, float 151418.853933535, float 151445.156198873, float 151471.459606273, float 151497.764155637
				float 151524.069846864, float 151550.376679856, float 151576.684654514, float 151602.993770738, float 151629.304028431, float 151655.615427491, float 151681.927967822, float 151708.241649322
				float 151734.556471895, float 151760.87243544, float 151787.189539859, float 151813.507785052, float 151839.827170922, float 151866.147697368, float 151892.469364293, float 151918.792171597
				float 151945.116119182, float 151971.441206949, float 151997.767434799, float 152024.094802633, float 152050.423310352, float 152076.752957859, float 152103.083745053, float 152129.415671838
				float 152155.748738113, float 152182.082943781, float 152208.418288742, float 152234.754772899, float 152261.092396152, float 152287.431158403, float 152313.771059554, float 152340.112099507
				float 152366.454278161, float 152392.797595421, float 152419.142051186, float 152445.487645358, float 152471.834377839, float 152498.182248532, float 152524.531257336, float 152550.881404155
				float 152577.232688889, float 152603.585111441, float 152629.938671712, float 152656.293369605, float 152682.64920502, float 152709.00617786, float 152735.364288026, float 152761.72353542
				float 152788.083919945, float 152814.445441502, float 152840.808099993, float 152867.17189532, float 152893.536827385, float 152919.90289609, float 152946.270101337, float 152972.638443028
				float 152999.007921065, float 153025.37853535, float 153051.750285786, float 153078.123172273, float 153104.497194715, float 153130.872353014, float 153157.248647072, float 153183.62607679
				float 153210.004642072, float 153236.384342819, float 153262.765178934, float 153289.147150318, float 153315.530256875, float 153341.914498507, float 153368.299875116, float 153394.686386604
				float 153421.074032873, float 153447.462813827, float 153473.852729367, float 153500.243779396, float 153526.635963817, float 153553.029282532, float 153579.423735443, float 153605.819322453
				float 153632.216043465, float 153658.613898381, float 153685.012887103, float 153711.413009535, float 153737.814265579, float 153764.216655137, float 153790.620178113, float 153817.024834409
				float 153843.430623927, float 153869.837546571, float 153896.245602244, float 153922.654790847, float 153949.065112284, float 153975.476566458, float 154001.889153271, float 154028.302872627
				float 154054.717724428, float 154081.133708577, float 154107.550824977, float 154133.969073531, float 154160.388454142, float 154186.808966713, float 154213.230611148, float 154239.653387348
				float 154266.077295218, float 154292.502334659, float 154318.928505576, float 154345.355807871, float 154371.784241448, float 154398.21380621, float 154424.644502059, float 154451.0763289
				float 154477.509286634, float 154503.943375167, float 154530.3785944, float 154556.814944237, float 154583.252424581, float 154609.691035337, float 154636.130776406, float 154662.571647693
				float 154689.0136491, float 154715.456780532, float 154741.901041891, float 154768.346433082, float 154794.792954007, float 154821.24060457, float 154847.689384675, float 154874.139294224
				float 154900.590333123, float 154927.042501273, float 154953.495798579, float 154979.950224945, float 155006.405780274, float 155032.862464469, float 155059.320277435, float 155085.779219075
				float 155112.239289293, float 155138.700487992, float 155165.162815076, float 155191.62627045, float 155218.090854016, float 155244.556565679, float 155271.023405343, float 155297.491372911
				float 155323.960468287, float 155350.430691375, float 155376.902042079, float 155403.374520303, float 155429.848125952, float 155456.322858928, float 155482.798719136, float 155509.27570648
				float 155535.753820864, float 155562.233062192, float 155588.713430369, float 155615.194925297, float 155641.677546882, float 155668.161295028, float 155694.646169638, float 155721.132170617
				float 155747.619297869, float 155774.107551299, float 155800.59693081, float 155827.087436307, float 155853.579067694, float 155880.071824875, float 155906.565707755, float 155933.060716238
				float 155959.556850229, float 155986.054109632, float 156012.552494351, float 156039.05200429, float 156065.552639355, float 156092.054399449, float 156118.557284477, float 156145.061294344
				float 156171.566428955, float 156198.072688212, float 156224.580072023, float 156251.08858029, float 156277.598212918, float 156304.108969813, float 156330.620850878, float 156357.133856019
				float 156383.64798514, float 156410.163238145, float 156436.679614941, float 156463.19711543, float 156489.715739519, float 156516.235487112, float 156542.756358113, float 156569.278352428
				float 156595.801469961, float 156622.325710618, float 156648.851074303, float 156675.37756092, float 156701.905170376, float 156728.433902575, float 156754.963757422, float 156781.494734821
				float 156808.026834679, float 156834.5600569, float 156861.094401388, float 156887.62986805, float 156914.16645679, float 156940.704167513, float 156967.243000125, float 156993.78295453
				float 157020.324030635, float 157046.866228343, float 157073.40954756, float 157099.953988192, float 157126.499550144, float 157153.04623332, float 157179.594037627, float 157206.14296297
				float 157232.693009253, float 157259.244176383, float 157285.796464264, float 157312.349872802, float 157338.904401903, float 157365.460051472, float 157392.016821414, float 157418.574711635
				float 157445.13372204, float 157471.693852535, float 157498.255103026, float 157524.817473417, float 157551.380963615, float 157577.945573525, float 157604.511303053, float 157631.078152104
				float 157657.646120584, float 157684.215208399, float 157710.785415454, float 157737.356741656, float 157763.929186909, float 157790.50275112, float 157817.077434194, float 157843.653236037
				float 157870.230156555, float 157896.808195654, float 157923.38735324, float 157949.967629218, float 157976.549023495, float 158003.131535976, float 158029.715166567, float 158056.299915175
				float 158082.885781704, float 158109.472766062, float 158136.060868154, float 158162.650087886, float 158189.240425165, float 158215.831879896, float 158242.424451985, float 158269.018141339
				float 158295.612947864, float 158322.208871465, float 158348.805912049, float 158375.404069523, float 158402.003343792, float 158428.603734762, float 158455.205242341, float 158481.807866433
				float 158508.411606946, float 158535.016463786, float 158561.622436859, float 158588.229526071, float 158614.837731329, float 158641.447052539, float 158668.057489608, float 158694.669042442
				float 158721.281710947, float 158747.89549503, float 158774.510394597, float 158801.126409556, float 158827.743539811, float 158854.361785271, float 158880.981145841, float 158907.601621429
				float 158934.22321194, float 158960.845917281, float 158987.469737359, float 159014.094672081, float 159040.720721353, float 159067.347885082, float 159093.976163175, float 159120.605555539
				float 159147.236062079, float 159173.867682704, float 159200.500417319, float 159227.134265832, float 159253.769228149, float 159280.405304178, float 159307.042493825, float 159333.680796997
				float 159360.3202136, float 159386.960743543, float 159413.602386732, float 159440.245143073, float 159466.889012474, float 159493.533994842, float 159520.180090084, float 159546.827298107
				float 159573.475618818, float 159600.125052124, float 159626.775597932, float 159653.427256149, float 159680.080026683, float 159706.733909441, float 159733.388904329, float 159760.045011255
				float 159786.702230127, float 159813.360560851, float 159840.020003334, float 159866.680557485, float 159893.34222321, float 159920.005000417, float 159946.668889012, float 159973.333888904
				float 160000.0, float 160026.667222207, float 160053.335555432, float 160080.004999583, float 160106.675554568, float 160133.347220294, float 160160.019996668, float 160186.693883598
				float 160213.368880991, float 160240.044988755, float 160266.722206798, float 160293.400535027, float 160320.07997335, float 160346.760521674, float 160373.442179907, float 160400.124947957
				float 160426.808825732, float 160453.493813138, float 160480.179910084, float 160506.867116478, float 160533.555432227, float 160560.244857239, float 160586.935391422, float 160613.627034684
				float 160640.319786933, float 160667.013648076, float 160693.708618021, float 160720.404696676, float 160747.10188395, float 160773.800179749, float 160800.499583983, float 160827.200096559
				float 160853.901717384, float 160880.604446368, float 160907.308283417, float 160934.013228441, float 160960.719281347, float 160987.426442043, float 161014.134710437, float 161040.844086438
				float 161067.554569953, float 161094.266160891, float 161120.978859161, float 161147.692664669, float 161174.407577325, float 161201.123597036, float 161227.840723711, float 161254.558957259
				float 161281.278297586, float 161307.998744603, float 161334.720298217, float 161361.442958336, float 161388.166724869, float 161414.891597724, float 161441.61757681, float 161468.344662035
				float 161495.072853307, float 161521.802150536, float 161548.532553628, float 161575.264062494, float 161601.996677042, float 161628.730397179, float 161655.465222815, float 161682.201153858
				float 161708.938190218, float 161735.676331801, float 161762.415578518, float 161789.155930276, float 161815.897386984, float 161842.639948552, float 161869.383614887, float 161896.1283859
				float 161922.874261497, float 161949.621241588, float 161976.369326082, float 162003.118514888, float 162029.868807914, float 162056.62020507, float 162083.372706264, float 162110.126311405
				float 162136.881020402, float 162163.636833163, float 162190.393749599, float 162217.151769617, float 162243.910893127, float 162270.671120038, float 162297.432450259, float 162324.194883698
				float 162350.958420266, float 162377.72305987, float 162404.48880242, float 162431.255647825, float 162458.023595995, float 162484.792646838, float 162511.562800264, float 162538.334056181
				float 162565.1064145, float 162591.879875128, float 162618.654437976, float 162645.430102953, float 162672.206869967, float 162698.984738929, float 162725.763709747, float 162752.543782332
				float 162779.324956591, float 162806.107232435, float 162832.890609773, float 162859.675088515, float 162886.460668569, float 162913.247349846, float 162940.035132254, float 162966.824015704
				float 162993.614000104, float 163020.405085364, float 163047.197271395, float 163073.990558104, float 163100.784945403, float 163127.5804332, float 163154.377021405, float 163181.174709928
				float 163207.973498679, float 163234.773387566, float 163261.5743765, float 163288.376465391, float 163315.179654148, float 163341.98394268, float 163368.789330899, float 163395.595818713
				float 163422.403406032, float 163449.212092766, float 163476.021878825, float 163502.832764119, float 163529.644748557, float 163556.45783205, float 163583.272014508, float 163610.087295839
				float 163636.903675956, float 163663.721154766, float 163690.53973218, float 163717.359408109, float 163744.180182462, float 163771.00205515, float 163797.825026081, float 163824.649095168
				float 163851.474262318, float 163878.300527444, float 163905.127890454, float 163931.956351259, float 163958.785909769, float 163985.616565894, float 164012.448319545, float 164039.281170631
				float 164066.115119063, float 164092.950164752, float 164119.786307607, float 164146.623547539, float 164173.461884458, float 164200.301318274, float 164227.141848898, float 164253.98347624
				float 164280.82620021, float 164307.67002072, float 164334.514937679, float 164361.360950997, float 164388.208060586, float 164415.056266355, float 164441.905568216, float 164468.755966078
				float 164495.607459853, float 164522.46004945, float 164549.313734781, float 164576.168515756, float 164603.024392285, float 164629.88136428, float 164656.73943165, float 164683.598594307
				float 164710.458852161, float 164737.320205122, float 164764.182653103, float 164791.046196012, float 164817.910833762, float 164844.776566263, float 164871.643393425, float 164898.511315159
				float 164925.380331377, float 164952.250441989, float 164979.121646906, float 165005.993946038, float 165032.867339298, float 165059.741826595, float 165086.61740784, float 165113.494082945
				float 165140.371851821, float 165167.250714378, float 165194.130670527, float 165221.01172018, float 165247.893863248, float 165274.777099641, float 165301.661429271, float 165328.546852048
				float 165355.433367884, float 165382.320976691, float 165409.209678379, float 165436.099472858, float 165462.990360042, float 165489.88233984
