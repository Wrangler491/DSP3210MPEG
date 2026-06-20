
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

DSP_start:
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
DSP_volR:				long 0
DSP_volL:				long 0
DSP_freq_div:			long 0

DSP_routine:			long 0	//code for routine to jump to
DSP_status:				long 0	//shows DSP status
DSP_usage:				long 0
DSP_registers:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


//**********************************************************************
// Initialisation to set up vector table and wait for int
//
//**********************************************************************
DSP_code:
	r1 = AddressPR(DSP_location)
	r1 = *r1				//address of start of shared data area that M68K can also access
	r3 = AddressPR(DSP_data_address)
	*r3 = r1	//fill in the address

	r2 = AddressPR(RAM_start)	//first long to copy
	r3 = AddressPR(Cache_end)
	r1 = DSP3210_RAM1		//RAM1
Copyloop1:
	r4 = *r2++
	nop
	*r1++ = r4
	r2-r3
	if(lt) pcgoto Copyloop1	//copy the prog to RAM1
	nop


	r2 = AddressPR(DSP_codestart)	//first long to copy
	r3 = AddressPR(DSP_codeend)

Copyloop2:
	r4 = *r2++
	nop
	*r1++ = r4
	r2-r3
	if(le) pcgoto Copyloop2	//copy the prog to RAM0
	nop


	r1 = AddressPR(DSP_usage)
	r1 = *r1
	r2 = AddressPR(DSP_registers)
	r1 - r0
	if(eq) r1 = r2	//used as a dummy address
	r2 = r0 //*r1

	r3 = AddressPR(DSP_status)
	r4 = DSP3210_OK			//how else to get started?
	r22 = DSP3210_RAM1 + Vec_tab - RAM_start	//set our exception vector table pointer   
	*r3 = r4				//signal done

	r4 = (DSP3210_RAM1 + wait_routine - RAM_start)
	goto r4					//jump to on-chip "wait and count loop"
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


//**********************************************************************
// Exception vector table -- so we can redirect interrupts to our code
//
//**********************************************************************

Vec_tab:	
	if(true) pcgoto trap_reset	//reset
	nop
	if(true) pcgoto trap_1	//bus err
	nop
	if(true) pcgoto trap_illegal	//illegal instr
	*(reg_store - Vec_tab + 0xE00) = r10	//save r10
	if(true) pcgoto trap_3	//reserved
	nop
	if(true) pcgoto trap_4	//addr err
	nop
	if(true) pcgoto trap_5	//DAU over/underflow
	nop
	if(true) pcgoto trap_6	//NaN
	nop
	if(true) pcgoto trap_7	//reserved
	nop
	ireturn					//Int 0 v74
	nop
	if(true) pcgoto trap_8	//Timer
	nop
	if(true) pcgoto trap_9	//reserved
	nop
	if(true) pcgoto trap_A	//Boot ROM
	nop
	if(true) pcgoto trap_B	//reserved
	nop
	if(true) pcgoto trap_C	//reserved
	nop
	if(true) pcgoto trap_D	//reserved
	nop
	if(true) pcgoto int1	//Int 1
	emr = (short) r0			//mask further ints

//**********************************************************************
// Unhandled exceptions
//
//**********************************************************************

trap_unhandled:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r3 = r1 + (DSP_status - DSP_start)
	r4 = DSP3210_FAIL    
	nop    
	*r3 = r4				//signal Error
	waiti					//wait for an interrupt, except they're masked
	pcgoto .
	nop

trap_1:
	pcgoto trap_restart
	nop	//r4 = 1

trap_3:
	pcgoto trap_restart
	nop	//r4 = 3

trap_4:
	pcgoto trap_restart
	nop	//r4 = 4

trap_5:
	pcgoto trap_restart
	nop	//r4 = 5

trap_6:
	pcgoto trap_restart
	nop	//r4 = 6

trap_7:
	pcgoto trap_restart
	nop	//r4 = 7

trap_8:
	pcgoto trap_restart
	nop	//r4 = 8

trap_9:
	pcgoto trap_restart
	nop	//r4 = 9

trap_A:
	pcgoto trap_restart  
	nop	//r4 = 0xA

trap_B:
	pcgoto trap_restart   
	nop	//r4 = 0xB

trap_C:
	pcgoto trap_restart    
	nop	//r4 = 0xC

trap_D:
	pcgoto trap_restart   
	nop	//r4 = 0xD

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
	r10 = *(reg_store - Vec_tab + 0xE00)
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
	r4 = DSP3210_OK

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
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r1 = r1 + (DSP_registers - DSP_start)
	*r1++ = r2
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

	pcgoto trap_wait
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
	nop
	r3 = r1 + (DSP_status - DSP_start)    
	r4 = DSP3210_RUN    
	nop
	*r3 = r4				//signal started interrupt routine

Cache_end:
DSP_codestart:
	//Main entry point - identify routine to be called and call it
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r1 = r1 + (DSP_routine - DSP_start)
	r1 = *r1		//get code
	nop

	r1 - DSP3210_volume
	if(eq) pcgoto set_volume
	r1 - DSP3210_decodeMP2
	if(eq) pcgoto decodeMP2
	r1 - DSP3210_decodeMP3
	if(eq) pcgoto MPEG_exit	//###
	nop
	pcgoto MPEG_exit
	nop


MPEG_exit:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r3 = r1 + (DSP_status - DSP_start)
	r2 = DSP3210_READY
	nop
	*r3 = r2				//mark DSP as finished

	r1 = *0xE000
	r2 = *0xE004				//unstack registers used in waitloop

	r4 = (ushort24) 0x8000
	emr = (short) r4		//enable Int 1
	ireturn
	nop						//technically, not needed


set_volume:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	r2 = AddressPR(vol_multR)
	r1 = r1 + (DSP_volR - DSP_start)
	*r2++ = a0 = float32(*r1++)
	pcgoto MPEG_exit
	*r2++ = a0 = float32(*r1++)


	


decodeMP2:
	//On entry, expects the following to have been set:
	//	DSP_mono, DSP_translate, DSP_forcemono, DSP_jsbound, DSP_inbuf, DSP_outbuffer0 and 1
	//determine if 1 or 2 channels
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	nop
	r2 = r1 + (DSP_mono - DSP_start)
	r3 = *r2				//mono
	r4 = 2
	r3 - 0
	if(eq) pcgoto is_stereo
	nop
	r4 = 1
is_stereo:
	r3 = AddressPR(channels)
	*r3 = r4				//store channels

	//determine table pointers based on translate
	r2 = r1 + (DSP_translate - DSP_start)
	r3 = *r2				//translate
	r6 = r1 + (table_translate_sblimit - DSP_start)	//in fastram
	r3 = r3 << 2			//convert to long pointer
	r6 = r6 + r3			//pt to entry in table
	r5 = *r6				//get table entry
	r2 = AddressPR(sblimit)
	*r2 = r5				//store sblimit

	r6 = r1 + (table_translate_alloc - DSP_start)	//in fastram
	r6 = r6 + r3			//pr to alloc table entry
	r5 = *r6				//get entry as an offset
	r2 = r1 + (alloc0_bits0 - DSP_start)	//in fastram
	r5 = r5 + r2			//absolute address of allocation entry
	r2 = AddressPR(decoder_nbals)
	*r2 = r5				//store abs allocation table address in decoder_nbals

	r6 = r1 + (table_translate_quantizations - DSP_start)	//in fastram
	r6 = r6 + r3			//pr to alloc table entry
	r5 = *r6				//get entry as an offset
	r2 = r1 + (table_quantizations_01 - DSP_start)	//in fastram
	r5 = r5 + r2			//absolute address of quantization entry
	r2 = AddressPR(decoder_quantizations)
	*r2 = r5				//store table quantization address in decoder_quantizations

	//clear fraction
	r2 = r1 + (decoder_fraction - DSP_start)
	do 0, 2*32*3-1
		*r2++ = r0		//clear table

	//clear bb = 2 * 2 * 512 floats = 8k
	//r2 = r1 + (bb - DSP_start)
	//do 0, 2047
	//	*r2++ = r0
	

	//clear b_offset[ch]
	r2 = AddressPR(pcm_offset)
	*r2++ = r0						//clear pcm_offset
	//*r2   = r0						//and both b_offset[0] and [1] as shorts

	r2 = r1 + (DSP_freq_div - DSP_start)
	r2 = *r2
	r3 = AddressPR(freq_div)
	*r3 = r2
	r5 = 8
	r7 = 16
	r9 = 32
	r3 = AddressPR(pcm_count)
	//r2 - 4
	//if(eq) pcgoto pcmc_set
	//nop
	//r5 = 16

//pcmc_set:
	r2 - 2
	if(eq) r5 = r7
	r2 - 1
	if(eq) r5 = r9
	*r3 = r5

	//reset getbits
	r2 = AddressPR(getbits_temp)
	r3 = (ushort24)0x8000		//bit 15 set
	*r2 = r3
	r3 = r1 + (DSP_inbuf - DSP_start)
	r4 = *r3
	r2 = AddressPR(getbits_stream_p)
	*r2 = r4			//write inbuffer to getbits_stream_p

	//decode_scales
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = getbits_temp, fixed               *
	//* r4 = number of channels-1, fixed       *
	//* r5 = jsbound, fixed                    *
	//* r6 = decoder_bitalloc, updated         *
	//* r7 = current bs longword               *
	//* r8 = counter up to jsbound x channels  *
	//* r9 = decode_nbals ptr, updated         *
	//* r10 = number of bits for getbits       *
	//* r11 = bits read by getbits             *
	//* r12 = number of bits to read from bs   *
	//* r13 = jsbound - 1, updated             *
	//* r15 = jsbndxchans+2*(sblimit-jsbnd)    *
	//******************************************

	//getbits_init	
	r2 = r4				//ptr to inbuffer
	r3 = AddressPR(getbits_temp)

	//fetch bit allocation table
	r4 = AddressPR(channels)
	r4 = *r4			//number of channels
	r5 = r1 + (DSP_jsbound - DSP_start)
	r5 = *r5			//jsbound
	r9 = AddressPR(decoder_nbals)
	r9 = *r9			//nbals = ptr to allocation table
	r6 = r1 + (decoder_bitalloc - DSP_start)
	r7 = *r3			//current bitstream word
	r4 = r4 - 1			//channel counter
	r13 = r5 - 1		//jsbound limit
	if(lt) pcgoto jsb_zero
	r8 = r0				//r8 will end up counting jsbound x channels
	r14 = r4			//back up channel counter

	//loop until jsbound
sb_loop:
		r12 = *r9++			//nbal counter
		nop
		r12 = r12 - 1
		r4 = r14			//inner channel loop
sb_ch_loop:
			r10 = r12
			r11 = r0		//clear result		
			call AddressPR(getbits) (r18)
			r8 = r8 + 1		//inc count, latent instruction
			*r6++ = r11
			r4 = r4 - 1
			if(ge) pcgoto sb_ch_loop
			nop
		r13 = r13 - 1
		if(ge) pcgoto sb_loop
		nop

jsb_zero:
	r15 = r8			//retain r8 for channel x jsbound
	//loop until sblimit (for joint-stereo only)
	r13 = AddressPR(sblimit)
	r13 = *r13
	nop
	r4 = r13 - r5		//sblimit - jsbound
	if(le) pcgoto sb_loop1
	r4 = r4 - 1			//latent instruction

sb_ch_lp2:
		r12 = *r9++		//nbal counter
		r11 = r0		//clear result
		r10 = r12 - 1		
		call AddressPR(getbits) (r18)
		r15 = r15 + 2
		*r6++ = r11
		*r6++ = r11
	r4 = r4 - 1
	if(ge) pcgoto sb_ch_lp2
	nop

sb_loop1:
	//r7 = *r3		//current bitstream word
	//nop
	//long 0x88000000
	//r8  = jsbound x channels
	//r15 = jsbound x channels + 2*(sblimit-jsbound)

	//read scale factor selector information
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = getbits_temp, fixed               *
	//* r4 = decoder_scfsi, fixed              *
	//* r5 = jsbound, fixed                    *
	//* r6 = decoder_bitalloc, updated         *
	//* r7 = current bs longword               *
	//* r8 = counter up to jsbound x channels  *
	//* r9 = decode_scalefactor, updated       *
	//* r10 = number of bits for getbits =2    *
	//* r11 = bits read by getbits             *
	//* r12 = number of bits to read from bs   *
	//* r13 = jsbound - 1, updated             *
	//* r14 = counter                          *
	//* r15 = jsbndxchans+2*(sblimit-jsbnd)    *
	//******************************************

	r4 = r1 + (decoder_scfsi - DSP_start)
	r6 = r1 + (decoder_bitalloc - DSP_start)	
	r14 = r15 - 1

sf_loop0:
		r11 = *r6++
		nop
		r11 - r0
		if(eq) pcgoto skip_getbits
		r11 = r0
		call AddressPR(getbits) (r18)
		r10 = 2 - 1
skip_getbits:
	r14 = r14 - 1
	if(ge) pcgoto sf_loop0
	*r4++ = r11

	//fetch scale factors
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = getbits_temp, fixed               *
	//* r4 = decoder_scfsi, fixed              *
	//* r5 = jsbound, fixed                    *
	//* r6 = decoder_bitalloc, updated         *
	//* r7 = current bs longword               *
	//* r8 = scratch register, used            *
	//* r9 = decode_scalefactor, updated       *
	//* r10 = number of bits for getbits =6    *
	//* r11 = bits read by getbits             *
	//* r12 = number of bits to read from bs   *
	//* r13 = jsbound - 1, updated             *
	//* r14 = counter                          *
	//* r15 = jsbndxchans+2*(sblimit-jsbnd)    *
	//******************************************

	r4 = r1 + (decoder_scfsi - DSP_start)
	r9 = r1 + (decoder_scalefactor - DSP_start)
	r6 = r1 + (decoder_bitalloc - DSP_start)
	
	r14 = r15 - 1
sf_loop1:
		r11 = r0
		r8 = *r6++			//read from bitalloc
		nop
		r8 - r0
		if(eq) pcgoto sf_ba0
		r8 = *r4++			//read from scfsi and update pointer even if ba = 0 
		nop
		r8 - r0
		if(ne) pcgoto sf_c1
		r10 = 6 - 1
		call AddressPR(getbits) (r18)	//getbits all three
		r11 = r0
		*r9++ = r11
		r10 = 6 - 1
		call AddressPR(getbits) (r18)
		r11 = r0
		*r9++ = r11
		r10 = 6 - 1
		call AddressPR(getbits) (r18)
		r11 = r0
		pcgoto sf_resume
		nop
sf_c1:	r8 - 1
		if(ne) pcgoto sf_c2
		nop
		call AddressPR(getbits) (r18)	//getbits 1 + 3
		r11 = r0
		*r9++ = r11
		*r9++ = r11
		r10 = 6 - 1
		call AddressPR(getbits) (r18)
		r11 = r0
		pcgoto sf_resume
		nop
sf_c2:	r8 - 2
		if(ne) pcgoto sf_c3
		nop
		call AddressPR(getbits) (r18)	//getbits just one
		r11 = r0
sf_ba0:
		*r9++ = r11
		pcgoto sf_resume
		*r9++ = r11
sf_c3:	call AddressPR(getbits) (r18)	//getbits 1 + 2
		r11 = r0
		*r9++ = r11
		r10 = 6 - 1
		call AddressPR(getbits) (r18)
		r11 = r0
		*r9++ = r11
sf_resume:
	r14 = r14 - 1
	if(ge) pcgoto sf_loop1
	*r9++ = r11

	*r3 = r7							//save getbits temp lw
	//getbits_exit
	r11 = AddressPR(getbits_stream_p)
	*r11 = r2							//save inbuffer location

	//decoder_bitalloc aka bit_alloc and
	//decoder_scalefactor aka sca are now filled in

	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = decoder_bitalloc, updated         *
	//* r4 = decoder_fraction, updated         *
	//* r5 = jsbound, fixed                    *
	//* r6 = decoder_bitalloc, updated         *
	//* r7 = ????????                          *
	//* r8 = scratch register, used            *
	//* r9 = decode_scalefactor, updated       *
	//* r10 = ??????                           *
	//* r11 = ??????                           *
	//* r12 = number of bits to read from bs   *
	//* r13 = jsbound - 1, updated             *
	//* r14 = counter                          *
	//* r15 = jsbndxchans+2*(sblimit-jsbnd)    *
	//* r19 = ptr to scalefactor for part      *
	//******************************************

	r10 = 0										//part counter	

part_loop:
	r7 = 0										//granule counter
granule_loop:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	
	r11 = r10 + r10
	r11 = r11 + r11								//part*4
	r19 = r1 + (decoder_scalefactor - DSP_start)	//initialise sf ptr
	r19 = r19 + r11								//r19 = decoder_scalefactor + part as long
	r11 = AddressPR(loop_store)
	*r11++ = r7
	*r11   = r10
	
	//call sample decoder
	pcgoto decode_samples
	nop

decode_return:
	r11 = AddressPR(getbits_temp)
	*r11 = r7									//save current bs lw
	r11 = AddressPR(loop_store) + 2*4			//save r2,19 after r7,10
	*r11++ = r2
	*r11   = r19

	//call synthesis 
	pcgoto synthesis
	nop

synthesis_return:
	r11 = AddressPR(loop_store)					//pt to granule
	r7  = *r11++								//unstack regs
	r10 = *r11++
	r2  = *r11++
	r19 = *r11

	r7 = r7 + 1
	r7 - 4
	if(ne) pcgoto granule_loop
	nop
	
	r10 = r10 + 1
	r10 - 3
	if(ne) pcgoto part_loop
	nop

	pcgoto MPEG_exit
	nop


decode_samples:
	//******************************************
	//* Registers used:                        *
	//* r1 = DSP_start, fixed                  *
	//* r2 = inbuffer, updated                 *
	//* r3 = ptr to decoder_bitalloc (r0)      *
	//* r4 = ptr to decoder_fraction (r1)      *
	//* r5 = ptr to quantizations table (r2)   *
	//* r6 = count down from sblimit           *
	//* r7 = unread bits from bs               *
	//* r8 = channel counter                   *
	//* r9 = jsbound counter                   *
	//* r10 = number of bits to read from bs   *
	//* r11 = outbits from bs                  *
	//* r12 = ptr to decoder_old_samples       *
	//* r13 = table_bits                       *
	//* r14 = scratch                          *
	//* r15 = ptr modifier                     *
	//* r16 = ptr to read_cwbits               *
	//* r17 = ptr modifier                     *
	//* r18 = return address from call         *
	//* r19 = ptr to scalefactor for part      *
	//******************************************


	r15 = (short) 32*4				//step through subbands
	r3 = r1 + (decoder_bitalloc - DSP_start)
	r4 = r1 + (decoder_fraction- DSP_start)

	r5 = AddressPR(decoder_quantizations)
	r5 = *r5
	r6 = r1 + (indicator - DSP_start)
	*r6 = r5

	//set a to jsbound x 2
	r9 = r1 + (DSP_jsbound - DSP_start)
	r9 = *r9

	//read+decode samples from bitstream

	r6 = AddressPR(sblimit)
	r6 = *r6						//get sblimit
	r9 = r9 + r9					//jsbound x 2 

	r7 = AddressPR(getbits_temp)
	r7 = *r7
	
	r8 = AddressPR(channels)
	r8 = *r8						//channels
	r20 = (short) (-6*32*4 + 4)				//2 channels, reset for next gr
	r8 - 2
	if(eq) pcgoto ds_sb_loop
	nop
	r20 = (short) (-3*32*4 + 4)		//1 channel
ds_sb_loop:
	r6 = r6 - 1
	if(lt) pcgoto decode_return		//onto synthesis

	r8 = AddressPR(channels)
	r8 = *r8						//channels
	
ds_ch_loop:	
	//update joint-stereo counter and check bitalloc
	r13 = *r3++
	r9 = r9 - 1						//2xjsbound-=1
	r13 - r0
	if(ne) pcgoto ds_samples
	nop

	//fill with zeroes if bitalloc is 0
	*r4++r15 = r0
	*r4++r15 = r0
	*r4      = r0					//fill all 3 with 0 and reset r4
	pcgoto ds_scalefactor_adjust
	nop

ds_samples:
	//check if joint-stereo applies
	//
	//r9 & 0x8000
	//if(eq) pcgoto ds_no_joint
	r9 - r0
	if(pl) pcgoto ds_no_joint
	nop

	r9 & 1
	if(ne) pcgoto ds_no_joint
	nop
	r12 = AddressPR(decoder_old_samples)

	//copy old samples for joint-stereo
	*r4++r15 = a0 = *r12++
	*r4++r15 = a0 = *r12++
	*r4      = a0 = *r12
	pcgoto ds_scalefactor_adjust
	nop

ds_no_joint:
	//decode samples
	r12 = r13 + r13					//bits from bitalloc * 2
	r12 = r12 + r12					//bits from bitalloc * 4
	r12 = r5 + r12					//ptr to quant table
	r12 = *r12						//quantization
	r13 = r1 + (table_bits - DSP_start)
	r12 = r12 << 2					//lws
	r13 = r12 + r13					
	r10 = *r13						//bits

	r12 - r0						//quantization entry was 0
	if(eq) pcgoto ds_fetch_grouping
	r10 = r10 - 1					//adjust count as need 1 less in getbits
	r12 - 1*4
	if(eq) pcgoto ds_fetch_grouping
	nop
	r12 - 3*4
	if(eq) pcgoto ds_fetch_grouping	//jump if quantization =0,1,3 ie grouped
	nop
	
	r12 = r12 + r12					//long + float per entry
	r14 = r1 + (table_xm - DSP_start)
	r14 = r14 + r12					//pt into table_xm based on quantization
	r16 = *r14++					//x
	//r14 = r14 + 4
	r1 = r10						//save bit count
	r13 = AddressPR(read_cwbits)

	call AddressPR(getbits) (r18)
	r11 = r0
	r11 = r11 - r16					//bits - x
	*r13 = r11
	nop
	nop
	a1 = float32(*r13)				//bits - x as float
	nop
	nop
	*r4++r15 = a1 = a1 * *r14

	r10 = r1
	call AddressPR(getbits) (r18)
	r11 = r0
	r11 = r11 - r16					//bits - x
	*r13 = r11
	nop
	nop
	a1 = float32(*r13)				//bits - x as float
	nop
	nop
	*r4++r15 = a1 = a1 * *r14

	r10 = r1
	call AddressPR(getbits) (r18)
	r11 = r0
	r11 = r11 - r16					//bits - x
	*r13 = r11
	nop
	nop
	a1 = float32(*r13)				//bits - x as float
	nop
	nop
	*r4      = a1 = a1 * *r14

	r1 = AddressPR(DSP_data_address)
	r1 = *r1						//reset r1

	pcgoto ds_scalefactor_adjust
	nop


ds_fetch_grouping:

	call AddressPR(getbits) (r18)
	r11 = r0

	//remove greatest bit and check if accumulator should be 0.0 or -1.0

	r14 = r1 + (table_grouping - DSP_start)
	
	r14 = r14 + r12
	r14 = *r14 
	r12 = r1 + (table_grouping - DSP_start)
	r14 = r14 + r12					//ptr to table_quantization_group_(quant)

	r12 = r11 + r11
	r11 = r11 + r12					//3*bits read
	r11 = r11 << 2					//as long/float
	r14 = r14 + r11					//ptr to table_quantization_group_(quant)[cwbits]

	*r4++r15 = a0 = *r14++				//already DSP floats
	*r4++r15 = a0 = *r14++
	*r4      = a0 = *r14

ds_scalefactor_adjust:
	r17 = 3*4						//move on 3 scalefactors
	r4 = r4 - 32*2*4				//reset r4
	r13 = *r19++r17
	r12 = AddressPR(decoder_old_samples)

	*r12++ = a0 = *r4++r15			//copy samples to old samples for js
	*r12++ = a0 = *r4++r15
	*r12++ = a0 = *r4     

	r13 = r13 << 2					//count longs
	r4 = r4 - 32*2*4				//reset r4
	r12 = r1 + (table_multiple - DSP_start)
	r12 = r12 + r13
	r13 = r4

	*r4++r15 = a0 = *r12 * *r13++r15	//table_multiple x sample
	*r4++r15 = a0 = *r12 * *r13++r15	//table_multiple x sample
	*r4++r15 = a0 = *r12 * *r13			//table_multiple x sample
	//*r4++r15 = a0 = *r13++r15
	//*r4++r15 = a0 = *r13++r15
	//*r4++r15 = a0 = *r13

quick_exit:	
	r8 = r8 - 1
	if(ne) pcgoto ds_ch_loop
	nop
	r4 = r4 + r20					//reset to move onto next sb
	pcgoto ds_sb_loop
	r5 = r5 + 16*4					//move on quantizations table ptr


	//******************************************
	//* Registers used:                        *
	//* r2 = inbuffer, updated                 *
	//* r7 = short of unread bits from bs      *
	//* r10 = number of bits to read -1        *
	//* r11 = outbits from bs, 0 on entry      *
	//* r18 = return address from call         *
	//* All other regs preserved               *
	//******************************************

getbits:
	// b -> r7, n7 -> r10, r7 -> r2, a -> r11
	if(r10-- >= 0) pcgoto gb_loop_t1
	nop
	return (r18)
	nop
gb_loop_t1:
	r7 = (short)r7 + r7	//sets C and Z bits as necessary, r7 << 1
	if(ne) pcgoto gb_1	//doesn't affect flags
	nop					//doesn't affect flags
	r7 = (short)*r2++	//fetch next 16 bits, doesn't affect flags, except it does!
	r0 - r2				//dummy inst to set C
	r7 = (short)r7 <<< 1	//shift bits and append end marker from doubling r7
	//nop
gb_1:
	pcgoto getbits
	r11 = (long)r11 <<< 1	//get carry bit, set CC zero


synthesis:

	r10 = AddressPR(gr)
	*r10 = r0		//gr = 0

mpeg2dec_grloop:
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	r11 = *r10						//r11 = gr
	r4 = r1 + (decoder_fraction - DSP_start)
	r11 = r11 << (5+2)				//gr * MPA_SBLIMIT * 4 (float)
	r3 = AddressPR(fraction_ptr)
	r4 = r4 + r11					//mps->fraction[0][gr][0]
	*r3++ = r4
	*r3++ = r0						//channel 0 for now
	r5 = AddressPR(pcm_offset)
	r5 = *r5
	r4 = r1 + (DSP_outbuffer0 - DSP_start)
	r4 = *r4
	r5 = r5 << 1					//int16
	r4 = r4 + r5					//&pcm[0][pcm_offset]

	//r1 = AddressPR(DSP_data_address)
	//r1 = *r1
	//nop


	//r3 = r1 + (DSP_synthesis_mps - DSP_start)
	//r2 = *r3++		//r2 = MPA_STREAM *mps
	//r11 = *r10		//r11 = gr
	//r4 = r2 + 0x350C	//offset to mpegsub
	//r4 = *r4		//r4 = mpegsub

	//r11 = r11 << (5+2)	//gr * MPA_SBLIMIT * 4 (float)
	//*r3++ = r4		//store mps->mpegsub
	//r4 = *r3++		//fraction/fraction1
	
	//r5 = r1 + (DSP_synthesis_pcm_offset - DSP_start)
	//r4 = r4 + r11	//mps->fraction[0][gr][0]
	//*r3++ = r4		//store mps->fraction[0][gr][0]
	//*r3++ = r0		//channel 0 for now

	
	//r5 = *r5		//r5 = pcm_offset
	//r4 = r2 + 0x3384	//offset to mps->pcm[0]
	//r4 = *r4		//r4 = pcm[0]
	//r5 = r5 << 1	//int16
	//r4 = r4 + r5	//&mps->pcm[0][pcm_offset]

	//channel 0

	call AddressPR(MPEGSUBF_filter_band) (r19)
	*r3 = r4
	

	//r1 = AddressPR(DSP_data_address)
	//r1 = *r1
	//nop
	//r5 = r1 + (DSP_synthesis_mps - DSP_start)
	//r2 = *r5		//MPA_STREAM *mps
	//nop

	//r5 = r2 + 0x35F4	//offset to mps->force_mono
	//r5 = (short) *r5	
	//nop

	r5 = AddressPR(channels)		//skip second channel if mono or forcemono
	r5 = *r5
	r1 = AddressPR(DSP_data_address)
	r1 = *r1
	r5 - 1
	if(eq) pcgoto mpeg2_mono
	r5 = r1 + (DSP_forcemono - DSP_start)
	r5 = *r5
	nop
	r5 - 1
	if(eq) pcgoto mpeg2_mono
	
	

	//r5 - 0
	//if(ne) pcgoto mpeg2_mono
	//r5 = r2 + 0x35DA	//offset to mps->channels
	//r5 = (short) *r5
	//nop
	//r5 - 1
	//if(eq) pcgoto mpeg2_mono
	//nop

	//channel 1
	r3 = AddressPR(fraction_ptr)
	r4 = *r3
	r5 = 1
	r4 = r4 + 3*32*4				//mps->fraction[1][gr][0]
	*r3++ = r4
	*r3++ = r5						//channel 1
	r5 = AddressPR(pcm_offset)
	r5 = *r5
	r4 = r1 + (DSP_outbuffer1 - DSP_start)
	r4 = *r4
	r5 = r5 << 1					//int16
	r4 = r4 + r5					//&pcm[1][pcm_offset]

	//r3 = r1 + (DSP_synthesis_bandPtr - DSP_start)
	//r4 = *r3
	//r5 = 1
	//r4 = r4 + 3*32*4	//mps->fraction[1][gr][0]
	//*r3++ = r4
	//*r3++ = r5			//channel 1
	
	//r5 = r1 + (DSP_synthesis_pcm_offset - DSP_start)
	//r6 = *r3++		//dummy to advance r3
	//r5 = *r3--		//r5 = pcm_offset
	//r4 = r2 + 0x3384 + 4	//offset to mps->pcm[1]
	//r4 = *r4		//pcm[1]
	//r5 = r5 << 1	//int16
	//r4 = r4 + r5	//mps->pcm[1][pcm_offset]
	
	call AddressPR(MPEGSUBF_filter_band) (r19)
	*r3 = r4	

mpeg2_mono:

	//r1 = AddressPR(DSP_data_address)
	//r1 = *r1
	//nop
	//r5 = r1 + (DSP_synthesis_pcm_offset - DSP_start)
	//r4 = *r5		//r4 = pcm_offset
	//r3 = r1 + (DSP_synthesis_mps - DSP_start)
	//r2 = *r3		//r2 = mps
	//nop
	//r1 = r2 + 0x350C	//offset to mpegsub
	//r1 = *r1		//r1 = mpegsub
	//nop
	//r1 = r1 + 10256		//mpegsub->pcm_count
	//r1 = (short) *r1	//r1 = pcm_count
	//nop
	//r4 = r4 + r1	//r4 = pcm_offset+=pcm_count
	//*r5 = r4

	r5 = AddressPR(pcm_offset)
	r4 = *r5						//r4 = pcm_offset
	r1 = AddressPR(pcm_count)
	r1 = *r1				//r1 = pcm_count
	nop
	r4 = r4 + r1					//r4 = pcm_offset+=pcm_count
	*r5 = r4

	r10 = AddressPR(gr)
	r11 = *r10
	nop
	r11 = r11 + 1
	r11 - 3
	if(ne) pcgoto mpeg2dec_grloop
	*r10 = r11

	//pcm+=mps->mpegsub->pcm_count * 3 * channels;

	pcgoto synthesis_return
	nop


//There are four externally addressable routines:
//MPEGIMDCT_hybrid		- main decoder routine
//MPEGSUBF_antialias	- Apply the antialiasing butterflies on a granule
//MPEGSUBF_filter_band	- Apply the FAST synthesis filter to a sub band
//MPEGSUBF_window_band	- Window a sub band filtered sample

//25 instr to get here
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

		r1 = AddressPR(DSP_data_address)
		r1 = *r1
		r4 = AddressPR(b_offset)
		//r11 = r1 + (DSP_synthesis_mpegsub - DSP_start)
		//r11 = *r11
		//r2 = r1 + (DSP_synthesis_samples - DSP_start)

		r2 = AddressPR(pcm_out)
		r2 = *r2		//sample_buffer
		
		r5 = *r4++		//b_offset
		r1 = *r4		//filter_buffer = buf_ptr //derived

		//r3 = r11 + 10248

		//r8 = (short) *r3	//freq_div
		//r3 = r3 + 4
		//r6 = (short) *r3++	//w_begin
		//r7 = (short) *r3++	//w_width
		//r3 = (short) *r3	//j = pcm_count

		r3 = AddressPR(freq_div)
		r8 = *r3++			//freq_div
		r6 = *r3++			//w_begin
		r7 = *r3++			//w_width
		r3 = *r3			//pcm_count

		r11 = AddressPR(dewindow)
		r9 = r6 + r6
		r9 = r9 + r9	//w_begin * 4
		r9 = r11 + r9

		r3 = r3 - 1		//pre-dec pcm_count
		
		r6 = r6 + r5
		r6 = r6 & 15	//r6 = start

		r10 = r6 + r6
		r10 = r10 + r10
		r10 = r10 + r1	//r10 = buf1

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

		r8 = AddressPR(curr_chann)
		r8 = *r8
		r7 = AddressPR(vol_multR)	//volume multiplier
		r8 - r0
		if(eq) pcgoto right_chan
		nop
		r7 = AddressPR(vol_multL)
right_chan:

		//register usage:
		//buf0			r1
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
		r4 = AddressPR(zero)

		r11 = r11 - 1		//cnt1--
		if(mi) pcgoto winA
		r12	= r12 - 1		//cnt0--
		if(mi) pcgoto winB
		r5 = r11 - 1
		if(mi) pcgoto window_band2
		r6 = r12 - 1
		if(mi) pcgoto window_band2
		nop
		r16 = r16 + 4
		r15 = r15 + 4

winmain:
		a0 = *r4			//zero sum
		do 0, r5
			a0 = a0 + *r10++ * *r9++	//sum += *buf1++ * dewindow++
		a0 = a0 + *r10++r16 * *r9++		//buf1+=off1

		do 0, r6
			a0 = a0 + *r1++  * *r9++	//sum += *buf0++ * dewindow++
		a0 = a0 + *r1++r15  * *r9++		//buf0+=off0

		//STORE	
		//r10 = r10 + r16		//buf1+=off1
		//r1 = r1 + r15		
		
		r9 = r9 + r17		//dewindow+=offd		
		nop
		a0 = a0 * *r7
	
		r3 = r3 - 1
		if(ge) pcgoto winmain	//pcm_loops = j-- (address is sign-extended)
		//if(r3-- >= 0) pcgoto winmain	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store		

		pcgoto window_end
		nop
		

window_band2:		
		a0 = *r4			//zero sum
		do 0, r11
			a0 = a0 + *r10++ * *r9++	//sum += *buf1++ * dewindow++

		do 0, r12
			a0 = a0 + *r1++  * *r9++	//sum += *buf0++ * dewindow++

		//STORE
		r10 = r10 + r16		//buf1+=off1
		r1 = r1 + r15		//buf0+=off0
		a0 = a0 * *r7
		r9 = r9 + r17		//dewindow+=offd		
	
		r3 = r3 - 1
		if(ge) pcgoto window_band2	//pcm_loops = j-- (address is sign-extended)
		//if(r3-- >= 0) pcgoto window_band2	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store		

		pcgoto window_end
		nop

winA:
		a0 = *r4			//zero sum	
		do 0, r12
			a0 = a0 + *r1++ * *r9++	//sum += *buf0++ * dewindow++

		//STORE
		r10 = r10 + r16		//buf1+=off1
		r1 = r1 + r15		//buf0+=off0
		a0 = a0 * *r7
		r9 = r9 + r17		//dewindow+=offd
		
		r3 = r3 - 1
		if(ge) pcgoto winA	//pcm_loops = j-- (address is sign-extended)	
		//if(r3-- >= 0) pcgoto winA	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store	

		pcgoto window_end
		nop

winB:
		a0 = *r4			//zero sum
		do 0, r11
			a0 = a0 + *r10++ * *r9++	//sum += *buf1++ * dewindow++

		//STORE
		r10 = r10 + r16		//buf1+=off1
		r1 = r1 + r15		//buf0+=off0
		a0 = a0 * *r7
		r9 = r9 + r17		//dewindow+=offd		
	
		r3 = r3 - 1
		if(ge) pcgoto winB		//pcm_loops = j-- (address is sign-extended)
		//if(r3-- >= 0) pcgoto winB	//pcm_loops = j-- (address is sign-extended)
		*r2++ = a0 = int16(a0)	//round to int16 and store		

		//pcgoto MPEG_exit
		//nop

window_end:

		
		r1 = AddressPR(DSP_data_address)
		r1 = *r1

		r6 = AddressPR(b_offset)

		//r2 = r1 + (DSP_synthesis_channel - DSP_start)
		r2 = AddressPR(curr_chann)
		r2 = *r2			//channel number
		r3 = *r6			//b_offset
		//r11 = r1 + (DSP_synthesis_mpegsub - DSP_start)
		//r11 = *r11
		r11 = AddressPR(b_offset_ch)
		r3 = r3 - 1
		r3 = r3 & 15
		r2 & 1
		if(eq) pcgoto store_b_offset
		//r11 = r11 + 10244	//b_offset[0]
		//r11 = r11 + 2		//b_offset[1]
		nop
		r11 = r11 + 2

store_b_offset:
		

		return (r19)
		*r11 = (short)r3

MPEGSUBF_filter_band:
		//Apply the FAST synthesis filter to a sub band
		//Generate full frequency sample
		//inputs:
		//bandPtr (=fraction) (float *) samples
		//out_filter_buffer 0 (float *)	sy0
		//out_filter_buffer 1 (float *)	sy1
		//freq_div

		r1 = AddressPR(DSP_data_address)
		r1 = *r1	
		r4 = AddressPR(curr_chann)
		r5 = r1 + (bb - DSP_start)	//bb, default to bb[0][0]
		r2 = *r4--					//channel number, either 0 or 1
		r1 = *r4					//samples aka bandPtr aka fraction_ptr

		r13 = AddressPR(b_offset_ch)
		r2 & 1
		if(eq) pcgoto offset0
		r3 = (short) *r13++
		r5 = r5 + 4096				//bb[1][0]
		r3 = (short) *r13

		//r11 = r1 + (DSP_synthesis_mpegsub - DSP_start)
		//r11 = *r11
		//r4 = r1 + (DSP_synthesis_bandPtr - DSP_start)
		//r2 = r1 + (DSP_synthesis_channel - DSP_start)
		//r2 = *r2			//channel number
		//r1 = *r4			//samples aka bandPtr

		//r13 = r11 + 10244
		//r5 = r11			//bb, default to bb[0][0] = mpegsub
		//r2 & 1
		//if(eq) pcgoto offset0
		//r3 = (short)*r13++
		//r5 = r5 + 4096				//bb[1][0]
		//r3 = (short)*r13
		
offset0:
		//at this stage, r3 = b_offset[ch], r5 = bb[ch]
		r6 = AddressPR(b_offset)
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

		//r4 = r11 + 10248
		//r4 = (short)*r4		//freq_div
		r4 = AddressPR(freq_div)
		r4 = *r4			//freq_div

		r5 = r1				//x1
		r6 = r1 + 31*4		//x2
		r7 = AddressPR(p)	//d
		r13 = AddressPR(zero)	//###used??

		r4 - 4
		if(ne) pcgoto filter_band1
		nop

		do 0,7
			//*r7++ = a0 = dsp(*r5++)	//*d++ = *x1++
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

		r8 = AddressPR(p)	//  r8 = r9 would be quicker###
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

		pcgoto MPEGSUBF_window_band 
		*r9 = a0 = -*r5		//S1(16) = p[0]

filter_band1:
		r4 - 2
		if(ne) pcgoto filter_band2
		nop

		//r1 = samples
		//r2 = sy0
		//r3 = sy1
		//r4 = freq_div
		//r5 = x1
		//r6 = x2
		//r7 = d = p[0]
		//r13 = AddressPR(zero)

		do 0, 14
			//*r7++ = a0 = dsp(*r5++)
			*r7++ = a0 = *r5++

		//*r7   = a0 = dsp(*r5)
		*r7   = a0 = *r5

		pcgoto filterband3
		nop

filter_band2:
		//r5 = x1
		//r6 = x2
		//r7 = d = p[0]

		//do 5, 7
			//a0 = dsp(*r6--)				//*x2
			//a1 = dsp(*r5++)
			//a2 = dsp(*r6--)
			//*r7++ = a1 = a1 + a0	//*d++ = *x2-- + *x1++
			//a3 = dsp(*r5++)
			//*r7++ = a3 = a3 + a2

		do 0,15
			*r7++ = a0 = *r5++ + *r6--


filterband3:
		call AddressPR(sub_dct) (r18)
		r6 = AddressPR(temp_stack)	//set up stack for later

		//5 ADD
		r8 = r2				//sy0 = S0(0)
		r9 = r3				//sy1 = S1(0)
		r5 = AddressPR(p)	//p[0]
		r10 = r5 + 1*4		//p[1]
		r11 = r2 + 30*4*16	//S0(30)
		r12 = r5 + 13*4		//p[13]
		r13 = r5 + 15*4		//p[15]

		r15 = 2*4*16		//index S0 upwards
		r16 = (short) -2*4*16		//index S0 downwards
		r18 = (short) -2*4
		
		//a0 = *r12
		a0 = *r12 + *r13		//a0 = s0 = p[13]+p[15]
		*r8++r15 = a1 = *r10	//S0(0)= p[1]		r8 now S0(2)
		*r9++r15 = a1 = -*r10	//S1(0) = -p[1]		r9 now S1(2)

		r10 = r5 + 9*4		//p[9]
		*r8++r15  = a3 = a0 + *r10		//s = p[9] + s0, S0(2)  = s
		*r11++r16 = a3 = -a0 - *r10++r18	//S0(30) = -s, r10 now p[7]

		a1 = *r10++r18		//r10 now p[5]
		*r8++r15  = a1 = a1 + *r10	//S0(4)  = s
		*r11++r16 = a3 = -a1 - *r10	//S0(28) = -s

		r10 = r5 + 11*4		//p[11]
		*r8++r15  = a1 = a0 + *r10		//s = p[11] + s0, S0(6)  = s
		*r11++r16 = a3 = -a0 - *r10		//S0(26) = -s

		r14 = r5 + 3*4		//p[3]
		*r8++r15  = a1 = *r14	//s = p[3], S0(8)  = s
		*r11++r16 = a3 = -*r14	//S0(24) = -s

		a1 = *r10			//p[11]
		r10 = r5 + 15*4		//p[15]
		*r8++r15  = a2 = a1 + *r10		//s = p[11] + p[15], S0(10)  = s
		*r11++r16 = a3 = -a1 - *r10	//S0(22) = -s

		r14 = r5 + 7*4		//p[7]
		*r8++r15  = a1 = *r14	//s = p[7], S0(12)  = s
		*r11++r16 = a3 = -*r14	//S0(20) = -s

		*r8++r15  = a1 = *r10		//s = p[15], r10 now p[14]
		*r11++r16 = a1 = -*r10--	//S0(18) = -s


		//12 ADD
		r14 = r10 + 1*4		//p[15]
		r11 = r3 + 30*4*16	//S1(30)
		*r8 = r0			//S0(16) = 0
		
		a1 = *r10++r18		//p[14], r10 now p[12]
		a0 = a1 + a0		//s0 += p[14]
		a1 = a1 + *r10--	//r10 now p[11]
		a1 = a1 + *r14		//s1 = p[14] + p[12] + p[15]
		*r6++ = a1			//stack s1
		a2 = *r10--
		a2 = a2 + *r10--	//s2 = p[11] + p[10], r10 now p[9]

		*r9++r15 = a3 = -*r10 - a0	//S1(2) = -p[9] - s0
		*r11++r16 = a3=  -*r10 - a0

		r10 = r5 + 7*4		//p[7] 
		a3 = *r10--
		*r6-- = a3 = a3 + *r10--	//stack s3

		*r9++r15 = a1 = -a3 - *r10	//S1(4) = -p[5] - s3
		*r11++r16 = a1 = -a3 - *r10

		*r9++r15 = a1 = -a0 - a2	//S1(6) = -s0 - s2, a0 now spare
		*r11++r16 = a1 = -a0 - a2

		r10 = r5 + 2*4		//p[2] 
		a0 = *r10++

		*r9++r15 = 	a3 = -a0 - *r10	//S1(8) = -p[2] - p[3]
		*r11++r16 = a3 = -a0 - *r10++

		a1 = *r6++					//unstack s1
		*r9++r15 = a0 = -a1 - a2	//S1(10) = -s1 - s2, a2 now spare
		*r11++r16 = a0 = -a1 - a2

		*r9++r15 = a0 = -*r6 - *r10	//S1(12) = -s3 - p[4]
		*r11++r16 = a0 = -*r6-- - *r10

		r10 = r5 + 8*4		//p[8] 

		*r9++r15 = a0 = -a1 - *r10	//S1(14) = -s1 - p[8]
		*r11++r16 = a0 = -a1 - *r10

		*r9 = a0 = -*r5		//S1(16) = -p[0]

		r4 - 1
		if(gt) pcgoto filter_band9

		r5 = r1				//x1
		r9 = r1 + 31*4		//x2
		r7 = AddressPR(p)	//d
		r8 = AddressPR(cos1_64)

		//do 4, 15
		//start loop
		//a1 = dsp(*r9--)
		//a0 = dsp(*r5++)
		//nop
		//a1 = a1 * *r8
		//*r7++ = a1 = -a1 + a0 * *r8++
		//end loop

		do 1, 15
			a1 = *r9-- * *r8
			*r7++ = a1 = -a1 + *r5++ * *r8++


		call AddressPR(sub_dct) (r18)
		nop

		//12 ADD
		r8 = r2	+ 1*4*16	//sy0 = S0(1)
		r7 = r2 + 31*4*16	//sy0 = S0(31)
		r5 = AddressPR(p)	//p[0]
		r9 = r5 + 1*4		//p[1]
		r10 = r5 + 9*4		//p[9]
		r12 = r5 + 13*4		//p[13]
		r13 = r5 + 15*4		//p[15]

		r15 = 2*4*16		//index S0 upwards
		r16 = (short) -2*4*16		//index S0 downwards
		r17 = (short) -2*4 

		a0 = *r12 + *r13		//s0 = p[13] + p[15]
		a1 = a0 + *r10++r17		//tmp = s0 + p[9], r10 now p[7]
		*r8++r15 = a2 = a1 + *r9	//S0(1) = s = p[1] + tmp
		*r7++r16 = a2 = -a1 - *r9	//S0(31) =-s

		a2 = *r10++r17
		a2 = a2 + *r10			//s2 = p[7] + p[5]
		*r8++r15 = a3 = a2 + a1	//S0(3) = s2 + tmp
		*r7++r16 = a3 = -a2 - a1

		r10 = r5 + 11*4
		a1 = a0 + *r10				//tmp = s0 + p[11], a0 free
		*r6 = a0					//stack s0
		*r8++r15 = a3 = a1 + a2		//S0(5) = s2 + tmp
		*r7++r16 = a3 = -a1 - a2

		r10 = r5 + 3*4
		*r8++r15 = a2 = a1 + *r10	//S0(7) = tmp + p[3]
		*r7++r16 = a2 = -a1 - *r10
		
		r11 = r5 + 11*4
		a1 = *r11 + *r13			//s1 = p[11] + p[15]
		*r8++r15 = a0 = a1 + *r10	//S0(9) = s1 + p[3]
		*r7++r16 = a0 = -a1 - *r10

		r10 = r5 + 7*4
		*r8++r15 = a0 = a1 + *r10	//S0(11) = s1 + p[7]
		*r7++r16 = a0 = -a1 - *r10

		*r8++r15 = a0 = *r13 + *r10	//S0(13) = p[15] + p[7]
		*r7++r16 = a0 = -*r13 - *r10

		*r8++r15 = a0 = *r13		//S0(15) = p[15]
		*r7++r16 = a0 = -*r13

		//21 ADD
		r8 = r3	+ 1*4*16			//sy0 = S1(1)
		r9 = r3 + 31*4*16			//sy1 = S1(31)
		r10 = r5 + 14*4

		*r6++ = a0 = *r6 + *r10			//s0 += p[14], stack s0

		r10 = r5 + 6*4
		a3 = *r10++
		*r6-- = a3 = a3 + *r10			//s3 = p[6] + p[7], stack s3

		r10 = r5 + 1*4
		a1 = *r10
		r10 = r5 + 9*4
		a1 = a1 + *r10

		*r8++r15 = a2 = -a1 -a0		//S1(1) = -(p[1] + p[9] + s0)
		*r9++r16 = a2 = -a1 -a0

		r11 = r5 + 5*4
		a1 = a3 + a0
		a1 = a1 + *r11				//tmp = p[5] + s3 + s0

		*r8++r15 = a2 = -a1 - *r10	//S1(3) = -(tmp + p[9])
		*r9++r16 = a2 = -a1 - *r10++

		a2 = *r10++
		a2 = a2 + *r10++			//s2 = p[10] + p[11]

		*r8++r15 = a0 = -a2 - a1	//S1(5) = -(tmp + s2)
		*r9++r16 = a0 = -a2 - a1

		a0 = *r6					//unstack s0
		r11 = r5 + 2*4
		a1 = a2 + *r11++
		a1 = a1 + *r11++			//tmp = s2 + p[2] + p[3]
		
		*r8++r15 = a3 = -a1 - a0	//S1(7) = -(tmp + s0), s0 no longer used
		*r9++r16 = a3 = -a1 - a0

		a0 = *r10					//p[12]
		r11 = r5 + 14*4
		a0 = a0 + *r11++
		*r6++ = a0 = a0 + *r11		//a0 = s1 = p[12] + p[14] + p[15], stacked
		
		*r8++r15 = a3 = -a0 - a1	//S1(9) = -(tmp + s1)
		*r9++r16 = a3 = -a0 - a1

		r11 = r5 + 4*4
		a0 = *r6-- + *r11			//p[4], s3 no longer used
		a0 = a0 + *r6				//a0 = tmp = p[4] + s3 + s1
		
		*r8++r15 = a3 = -a0 - a2	//S1(11) = -(tmp + s2), s2 no longer used
		*r9++r16 = a3 = -a0 - a2

		r10 = r5 + 8*4
		*r8++r15 = a2 = -a0 - *r10	//S1(13) = -(tmp + p[8])
		*r9++r16 = a2 = -a0 - *r10

		a0 = *r5 + *r10
		*r8++r15 = a2 = -a0 - *r6	//S1(15) = -(p[0] + p[8] + s1)
		*r9++r16 = a2 = -a0 - *r6

filter_band9:
		pcgoto MPEGSUBF_window_band
		nop

sub_dct:
		//sub_dct

		//set up index regs
		r15 = 3*4
		r16 = 5*4
		r17 = 5*4

		r8 = AddressPR(pp)	//d1 = pp[0]
		r9 = r8 + 8*4		//d2 = pp[8]
		r10 = AddressPR(p)	//s1 = p[0]
		r11 = r10 + 16*4 - 1*4	//s2 = p[16-1] ie pre-decrement
		r12 = AddressPR(cos1_32)	//cos1_32

		do 5, 3
			a1 = *r10 - *r11
			*r8++ = a3 = *r10++ + *r11--
			a2 = *r10 - *r11
			*r9++ = a3 = a1 * *r12++
			*r8++ = a3 = *r10++ + *r11--
			*r9++ = a3 = a2 * *r12++

		r8 = AddressPR(p)	//d1 = p[0]
		r9 = r8 + 4*4		//d2 = p[4]
		r10 = AddressPR(pp)	//s1 = pp[0]
		r11 = r10 + 8*4 - 1*4	//s2 = pp[8-1] ie pre-decrement
		r12 = AddressPR(cos1_16)	//cos1_16

		a1 = *r10 - *r11
		*r8++ = a3 = *r10++ + *r11--
		a2 = *r10 - *r11
		*r9++ = a3 = a1 * *r12++
		*r8++ = a3 = *r10++ + *r11--
		*r9++ = a3 = a2 * *r12++
		a1 = *r10 - *r11
		*r8++ = a3 = *r10++ + *r11--
		a2 = *r10 - *r11
		*r9++ = a3 = a1 * *r12++
		*r8++r17 = a3 = *r10++r17 + *r11--
		*r9++r17 = a3 = a2 * *r12++

		r11 = r10 + 8*4 - 1*4	//s2 = pp[16-1] ie pre-decrement
		r12 = AddressPR(cos1_16)	//cos1_16

		do 5, 1
			a1 = *r10 - *r11
			*r8++ = a3 = *r10++ + *r11--
			a2 = *r10 - *r11
			*r9++ = a3 = a1 * *r12++
			*r8++ = a3 = *r10++ + *r11--
			*r9++ = a3 = a2 * *r12++

		r8 = AddressPR(pp)	//d1 = pp[0]
		r9 = r8 + 2*4		//d2 = pp[2]
		r10 = AddressPR(p)	//s1 = p[0]
		r11 = r10 + 4*4 - 1*4	//s2 = p[4-1] ie pre-decrement
		r12 = AddressPR(cos1_8)	//cos1_8

		do 5, 3
			a1 = *r10 - *r11
			*r8++ = a3 = *r10++ + *r11--
			a2 = *r10 - *r11
			*r9++ = a3 = a1 * *r12++
			*r8++r15 = a3 = *r10++r15 + *r11++r16
			*r9++r15 = a3 = a2 * *r12--

		r8 = AddressPR(p)	//d1 = p[0]
		r10 = AddressPR(pp)	//pp[0]
		r11 = r10 + 1*4		//pp[1]
		r12 = AddressPR(cos1_4)	//cos1_4
		a0 = *r12
		r15 = 2*4

		do 5, 3
			a1 = *r10 - *r11
			*r8++ = a3 = *r10++r15 + *r11++r15
			a2 = *r10 - *r11
			*r8++ = a3 = a1 * a0
			*r8++ = a3 = *r10++r15 + *r11++r15
			*r8++ = a3 = a2 * a0

		//end of sub_dct
		return (r18)
		nop


p:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//16 floats
pp:				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//16 floats

temp_stack:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0 ,0	//16 longs of stack

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
   
//clip_limits:	float 32767.0, -32768.0

               //pcm_loops[ freq_div ] = = (32 / freq_div) - 1
//pcm_loops:		long 0, 31, 15, 9, 7, 0

ret_addr:		long 0

DSP_data_address:	long 0

zero:			long 0

b_offset:		long 0, 0	//will store b_offset and buf_ptr

gr:				long 0

fraction_ptr:	long 0		//aka bandPtr
curr_chann:		long 0
pcm_out:		long 0

pcm_offset:		long 0

vol_multR:		float 32768.0
vol_multL:		float 32768.0


b_offset_ch:	short 0, 0	//b_offset[ch]
freq_div:		long 4
w_begin:		long 0		//quality = 2: 0; 1: 4; 0: 6
w_width:		long 16		//quality = 2: 16; 1: 8; 0: 4
pcm_count:		long 8		//32/freq_div
channels:		long 0
sblimit:		long 0

getbits_stream_p:	long 0
getbits_temp:		long 0

decoder_quantizations:	long 0		//address of quantizations table
decoder_nbals:	long 0		//address of alloc_bits table
decoder_old_samples:	long 0, 0, 0

loop_store:			long 0, 0, 0, 0, 0, 0
read_cwbits:		long 0
zero1:				float 0.0, -0.5

stack:			long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

DSP_codeend:

//The following constants and variables remain in FastRAM
decoder_bitalloc:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 2*32
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //4 rows

decoder_scfsi:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 2*32
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //4 rows

decoder_scalefactor: long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 2*32*3
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
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//12 entries

decoder_fraction:	long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 //16 2*32*3
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
					long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	//12 entries

//sampling grouping tables
table_grouping:
	long	table_quantization_group_0 - table_grouping
	long	table_quantization_group_1 - table_grouping
	long	0
	long	table_quantization_group_3 - table_grouping

table_quantization_group_0:
	float	-0.666667,-0.666667,-0.666667,0.00000,-0.666667,-0.666667,0.666667,-0.666667,-0.666667,-0.666667,0.00000,-0.666667
	float	0.00000,0.00000,-0.666667,0.666667,0.00000,-0.666667,-0.666667,0.666667,-0.666667,0.00000,0.666667,-0.666667
	float	0.666667,0.666667,-0.666667,-0.666667,-0.666667,0.00000,0.00000,-0.666667,0.00000,0.666667,-0.666667,0.00000
	float	-0.666667,0.00000,0.00000,0.00000,0.00000,0.00000,0.666667,0.00000,0.00000,-0.666667,0.666667,0.00000
	float	0.00000,0.666667,0.00000,0.666667,0.666667,0.00000,-0.666667,-0.666667,0.666667,0.00000,-0.666667,0.666667
	float	0.666667,-0.666667,0.666667,-0.666667,0.00000,0.666667,0.00000,0.00000,0.666667,0.666667,0.00000,0.666667
	float	-0.666667,0.666667,0.666667,0.00000,0.666667,0.666667,0.666667,0.666667,0.666667,-0.666667,-0.666667,-0.666667
	float	0.00000,-0.666667,-0.666667,0.666667,-0.666667,-0.666667,-0.666667,0.00000,-0.666667,0.00000,0.00000,-0.666667


table_quantization_group_1:
	float	-0.8,-0.8,-0.8,-0.4,-0.8,-0.8, 0.0,-0.8,-0.8, 0.4,-0.8,-0.8
	float	 0.8,-0.8,-0.8,-0.8,-0.4,-0.8,-0.4,-0.4,-0.8, 0.0,-0.4,-0.8
	float	 0.4,-0.4,-0.8, 0.8,-0.4,-0.8,-0.8, 0.0,-0.8,-0.4, 0.0,-0.8
	float	 0.0, 0.0,-0.8, 0.4, 0.0,-0.8, 0.8, 0.0,-0.8,-0.8, 0.4,-0.8
	float	-0.4, 0.4,-0.8, 0.0, 0.4,-0.8, 0.4, 0.4,-0.8, 0.8, 0.4,-0.8
	float	-0.8, 0.8,-0.8,-0.4, 0.8,-0.8, 0.0, 0.8,-0.8, 0.4, 0.8,-0.8
	float	 0.8, 0.8,-0.8,-0.8,-0.8,-0.4,-0.4,-0.8,-0.4, 0.0,-0.8,-0.4
	float	 0.4,-0.8,-0.4, 0.8,-0.8,-0.4,-0.8,-0.4,-0.4,-0.4,-0.4,-0.4
	float	 0.0,-0.4,-0.4, 0.4,-0.4,-0.4, 0.8,-0.4,-0.4,-0.8, 0.0,-0.4
	float	-0.4, 0.0,-0.4, 0.0, 0.0,-0.4, 0.4, 0.0,-0.4, 0.8, 0.0,-0.4
	float	-0.8, 0.4,-0.4,-0.4, 0.4,-0.4, 0.0, 0.4,-0.4, 0.4, 0.4,-0.4
	float	 0.8, 0.4,-0.4,-0.8, 0.8,-0.4,-0.4, 0.8,-0.4, 0.0, 0.8,-0.4
	float	 0.4, 0.8,-0.4, 0.8, 0.8,-0.4,-0.8,-0.8, 0.0,-0.4,-0.8, 0.0
	float	 0.0,-0.8, 0.0, 0.4,-0.8, 0.0, 0.8,-0.8, 0.0,-0.8,-0.4, 0.0
	float	-0.4,-0.4, 0.0, 0.0,-0.4, 0.0, 0.4,-0.4, 0.0, 0.8,-0.4, 0.0
	float	-0.8, 0.0, 0.0,-0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.0, 0.0
	float	 0.8, 0.0, 0.0,-0.8, 0.4, 0.0,-0.4, 0.4, 0.0, 0.0, 0.4, 0.0
	float	 0.4, 0.4, 0.0, 0.8, 0.4, 0.0,-0.8, 0.8, 0.0,-0.4, 0.8, 0.0
	float	 0.0, 0.8, 0.0, 0.4, 0.8, 0.0, 0.8, 0.8, 0.0,-0.8,-0.8, 0.4
	float	-0.4,-0.8, 0.4, 0.0,-0.8, 0.4, 0.4,-0.8, 0.4, 0.8,-0.8, 0.4
	float	-0.8,-0.4, 0.4,-0.4,-0.4, 0.4, 0.0,-0.4, 0.4, 0.4,-0.4, 0.4
	float	 0.8,-0.4, 0.4,-0.8, 0.0, 0.4,-0.4, 0.0, 0.4, 0.0, 0.0, 0.4
	float	 0.4, 0.0, 0.4, 0.8, 0.0, 0.4,-0.8, 0.4, 0.4,-0.4, 0.4, 0.4
	float	 0.0, 0.4, 0.4, 0.4, 0.4, 0.4, 0.8, 0.4, 0.4,-0.8, 0.8, 0.4
	float	-0.4, 0.8, 0.4, 0.0, 0.8, 0.4, 0.4, 0.8, 0.4, 0.8, 0.8, 0.4
	float	-0.8,-0.8, 0.8,-0.4,-0.8, 0.8, 0.0,-0.8, 0.8, 0.4,-0.8, 0.8
	float	 0.8,-0.8, 0.8,-0.8,-0.4, 0.8,-0.4,-0.4, 0.8, 0.0,-0.4, 0.8
	float	 0.4,-0.4, 0.8, 0.8,-0.4, 0.8,-0.8, 0.0, 0.8,-0.4, 0.0, 0.8
	float	 0.0, 0.0, 0.8, 0.4, 0.0, 0.8, 0.8, 0.0, 0.8,-0.8, 0.4, 0.8
	float	-0.4, 0.4, 0.8, 0.0, 0.4, 0.8, 0.4, 0.4, 0.8, 0.8, 0.4, 0.8
	float	-0.8, 0.8, 0.8,-0.4, 0.8, 0.8, 0.0, 0.8, 0.8, 0.4, 0.8, 0.8
	float	 0.8, 0.8, 0.8,-0.8,-0.8,-0.8,-0.4,-0.8,-0.8, 0.0,-0.8,-0.8	

table_quantization_group_3:

	float	-0.888889,-0.888889,-0.888889,-0.666666,-0.888889,-0.888889,-0.444444,-0.888889,-0.888889,-0.222222,-0.888889,-0.888889
	float	      0.0,-0.888889,-0.888889, 0.222222,-0.888889,-0.888889, 0.444444,-0.888889,-0.888889, 0.666667,-0.888889,-0.888889
	float	 0.888889,-0.888889,-0.888889,-0.888889,-0.666666,-0.888889,-0.666666,-0.666666,-0.888889,-0.444444,-0.666666,-0.888889
	float	-0.222222,-0.666666,-0.888889,      0.0,-0.666666,-0.888889, 0.222222,-0.666666,-0.888889, 0.444444,-0.666666,-0.888889
	float	 0.666667,-0.666666,-0.888889, 0.888889,-0.666666,-0.888889,-0.888889,-0.444444,-0.888889,-0.666666,-0.444444,-0.888889
	float	-0.444444,-0.444444,-0.888889,-0.222222,-0.444444,-0.888889,      0.0,-0.444444,-0.888889, 0.222222,-0.444444,-0.888889
	float	 0.444444,-0.444444,-0.888889, 0.666667,-0.444444,-0.888889, 0.888889,-0.444444,-0.888889,-0.888889,-0.222222,-0.888889
	float	-0.666666,-0.222222,-0.888889,-0.444444,-0.222222,-0.888889,-0.222222,-0.222222,-0.888889,      0.0,-0.222222,-0.888889
	float	 0.222222,-0.222222,-0.888889, 0.444444,-0.222222,-0.888889, 0.666667,-0.222222,-0.888889, 0.888889,-0.222222,-0.888889
	float	-0.888889,      0.0,-0.888889,-0.666666,      0.0,-0.888889,-0.444444,      0.0,-0.888889,-0.222222,      0.0,-0.888889
	float	      0.0,      0.0,-0.888889, 0.222222,      0.0,-0.888889, 0.444444,      0.0,-0.888889, 0.666667,      0.0,-0.888889
	float	 0.888889,      0.0,-0.888889,-0.888889, 0.222222,-0.888889,-0.666666, 0.222222,-0.888889,-0.444444, 0.222222,-0.888889
	float	-0.222222, 0.222222,-0.888889,      0.0, 0.222222,-0.888889, 0.222222, 0.222222,-0.888889, 0.444444, 0.222222,-0.888889
	float	 0.666667, 0.222222,-0.888889, 0.888889, 0.222222,-0.888889,-0.888889, 0.444444,-0.888889,-0.666666, 0.444444,-0.888889
	float	-0.444444, 0.444444,-0.888889,-0.222222, 0.444444,-0.888889,      0.0, 0.444444,-0.888889, 0.222222, 0.444444,-0.888889
	float	 0.444444, 0.444444,-0.888889, 0.666667, 0.444444,-0.888889, 0.888889, 0.444444,-0.888889,-0.888889, 0.666667,-0.888889
	float	-0.666666, 0.666667,-0.888889,-0.444444, 0.666667,-0.888889,-0.222222, 0.666667,-0.888889,      0.0, 0.666667,-0.888889
	float	 0.222222, 0.666667,-0.888889, 0.444444, 0.666667,-0.888889, 0.666667, 0.666667,-0.888889, 0.888889, 0.666667,-0.888889
	float	-0.888889, 0.888889,-0.888889,-0.666666, 0.888889,-0.888889,-0.444444, 0.888889,-0.888889,-0.222222, 0.888889,-0.888889
	float	      0.0, 0.888889,-0.888889, 0.222222, 0.888889,-0.888889, 0.444444, 0.888889,-0.888889, 0.666667, 0.888889,-0.888889
	float	 0.888889, 0.888889,-0.888889,-0.888889,-0.888889,-0.666666,-0.666666,-0.888889,-0.666666,-0.444444,-0.888889,-0.666666
	float	-0.222222,-0.888889,-0.666666,      0.0,-0.888889,-0.666666, 0.222222,-0.888889,-0.666666, 0.444444,-0.888889,-0.666666
	float	 0.666667,-0.888889,-0.666666, 0.888889,-0.888889,-0.666666,-0.888889,-0.666666,-0.666666,-0.666666,-0.666666,-0.666666
	float	-0.444444,-0.666666,-0.666666,-0.222222,-0.666666,-0.666666,      0.0,-0.666666,-0.666666, 0.222222,-0.666666,-0.666666
	float	 0.444444,-0.666666,-0.666666, 0.666667,-0.666666,-0.666666, 0.888889,-0.666666,-0.666666,-0.888889,-0.444444,-0.666666
	float	-0.666666,-0.444444,-0.666666,-0.444444,-0.444444,-0.666666,-0.222222,-0.444444,-0.666666,      0.0,-0.444444,-0.666666
	float	 0.222222,-0.444444,-0.666666, 0.444444,-0.444444,-0.666666, 0.666667,-0.444444,-0.666666, 0.888889,-0.444444,-0.666666
	float	-0.888889,-0.222222,-0.666666,-0.666666,-0.222222,-0.666666,-0.444444,-0.222222,-0.666666,-0.222222,-0.222222,-0.666666
	float	      0.0,-0.222222,-0.666666, 0.222222,-0.222222,-0.666666, 0.444444,-0.222222,-0.666666, 0.666667,-0.222222,-0.666666
	float	 0.888889,-0.222222,-0.666666,-0.888889,      0.0,-0.666666,-0.666666,      0.0,-0.666666,-0.444444,      0.0,-0.666666
	float	-0.222222,      0.0,-0.666666,      0.0,      0.0,-0.666666, 0.222222,      0.0,-0.666666, 0.444444,      0.0,-0.666666
	float	 0.666667,      0.0,-0.666666, 0.888889,      0.0,-0.666666,-0.888889, 0.222222,-0.666666,-0.666666, 0.222222,-0.666666
	float	-0.444444, 0.222222,-0.666666,-0.222222, 0.222222,-0.666666,      0.0, 0.222222,-0.666666, 0.222222, 0.222222,-0.666666
	float	 0.444444, 0.222222,-0.666666, 0.666667, 0.222222,-0.666666, 0.888889, 0.222222,-0.666666,-0.888889, 0.444444,-0.666666
	float	-0.666666, 0.444444,-0.666666,-0.444444, 0.444444,-0.666666,-0.222222, 0.444444,-0.666666,      0.0, 0.444444,-0.666666
	float	 0.222222, 0.444444,-0.666666, 0.444444, 0.444444,-0.666666, 0.666667, 0.444444,-0.666666, 0.888889, 0.444444,-0.666666
	float	-0.888889, 0.666667,-0.666666,-0.666666, 0.666667,-0.666666,-0.444444, 0.666667,-0.666666,-0.222222, 0.666667,-0.666666
	float	      0.0, 0.666667,-0.666666, 0.222222, 0.666667,-0.666666, 0.444444, 0.666667,-0.666666, 0.666667, 0.666667,-0.666666
	float	 0.888889, 0.666667,-0.666666,-0.888889, 0.888889,-0.666666,-0.666666, 0.888889,-0.666666,-0.444444, 0.888889,-0.666666
	float	-0.222222, 0.888889,-0.666666,      0.0, 0.888889,-0.666666, 0.222222, 0.888889,-0.666666, 0.444444, 0.888889,-0.666666
	float	 0.666667, 0.888889,-0.666666, 0.888889, 0.888889,-0.666666,-0.888889,-0.888889,-0.444444,-0.666666,-0.888889,-0.444444
	float	-0.444444,-0.888889,-0.444444,-0.222222,-0.888889,-0.444444,      0.0,-0.888889,-0.444444, 0.222222,-0.888889,-0.444444
	float	 0.444444,-0.888889,-0.444444, 0.666667,-0.888889,-0.444444, 0.888889,-0.888889,-0.444444,-0.888889,-0.666666,-0.444444
	float	-0.666666,-0.666666,-0.444444,-0.444444,-0.666666,-0.444444,-0.222222,-0.666666,-0.444444,      0.0,-0.666666,-0.444444
	float	 0.222222,-0.666666,-0.444444, 0.444444,-0.666666,-0.444444, 0.666667,-0.666666,-0.444444, 0.888889,-0.666666,-0.444444
	float	-0.888889,-0.444444,-0.444444,-0.666666,-0.444444,-0.444444,-0.444444,-0.444444,-0.444444,-0.222222,-0.444444,-0.444444
	float	      0.0,-0.444444,-0.444444, 0.222222,-0.444444,-0.444444, 0.444444,-0.444444,-0.444444, 0.666667,-0.444444,-0.444444
	float	 0.888889,-0.444444,-0.444444,-0.888889,-0.222222,-0.444444,-0.666666,-0.222222,-0.444444,-0.444444,-0.222222,-0.444444
	float	-0.222222,-0.222222,-0.444444,      0.0,-0.222222,-0.444444, 0.222222,-0.222222,-0.444444, 0.444444,-0.222222,-0.444444
	float	 0.666667,-0.222222,-0.444444, 0.888889,-0.222222,-0.444444,-0.888889,      0.0,-0.444444,-0.666666,      0.0,-0.444444
	float	-0.444444,      0.0,-0.444444,-0.222222,      0.0,-0.444444,      0.0,      0.0,-0.444444, 0.222222,      0.0,-0.444444
	float	 0.444444,      0.0,-0.444444, 0.666667,      0.0,-0.444444, 0.888889,      0.0,-0.444444,-0.888889, 0.222222,-0.444444
	float	-0.666666, 0.222222,-0.444444,-0.444444, 0.222222,-0.444444,-0.222222, 0.222222,-0.444444,      0.0, 0.222222,-0.444444
	float	 0.222222, 0.222222,-0.444444, 0.444444, 0.222222,-0.444444, 0.666667, 0.222222,-0.444444, 0.888889, 0.222222,-0.444444
	float	-0.888889, 0.444444,-0.444444,-0.666666, 0.444444,-0.444444,-0.444444, 0.444444,-0.444444,-0.222222, 0.444444,-0.444444
	float	      0.0, 0.444444,-0.444444, 0.222222, 0.444444,-0.444444, 0.444444, 0.444444,-0.444444, 0.666667, 0.444444,-0.444444
	float	 0.888889, 0.444444,-0.444444,-0.888889, 0.666667,-0.444444,-0.666666, 0.666667,-0.444444,-0.444444, 0.666667,-0.444444
	float	-0.222222, 0.666667,-0.444444,      0.0, 0.666667,-0.444444, 0.222222, 0.666667,-0.444444, 0.444444, 0.666667,-0.444444
	float	 0.666667, 0.666667,-0.444444, 0.888889, 0.666667,-0.444444,-0.888889, 0.888889,-0.444444,-0.666666, 0.888889,-0.444444
	float	-0.444444, 0.888889,-0.444444,-0.222222, 0.888889,-0.444444,      0.0, 0.888889,-0.444444, 0.222222, 0.888889,-0.444444
	float	 0.444444, 0.888889,-0.444444, 0.666667, 0.888889,-0.444444, 0.888889, 0.888889,-0.444444,-0.888889,-0.888889,-0.222222
	float	-0.666666,-0.888889,-0.222222,-0.444444,-0.888889,-0.222222,-0.222222,-0.888889,-0.222222,      0.0,-0.888889,-0.222222
	float	 0.222222,-0.888889,-0.222222, 0.444444,-0.888889,-0.222222, 0.666667,-0.888889,-0.222222, 0.888889,-0.888889,-0.222222
	float	-0.888889,-0.666666,-0.222222,-0.666666,-0.666666,-0.222222,-0.444444,-0.666666,-0.222222,-0.222222,-0.666666,-0.222222
	float	      0.0,-0.666666,-0.222222, 0.222222,-0.666666,-0.222222, 0.444444,-0.666666,-0.222222, 0.666667,-0.666666,-0.222222
	float	 0.888889,-0.666666,-0.222222,-0.888889,-0.444444,-0.222222,-0.666666,-0.444444,-0.222222,-0.444444,-0.444444,-0.222222
	float	-0.222222,-0.444444,-0.222222,      0.0,-0.444444,-0.222222, 0.222222,-0.444444,-0.222222, 0.444444,-0.444444,-0.222222
	float	 0.666667,-0.444444,-0.222222, 0.888889,-0.444444,-0.222222,-0.888889,-0.222222,-0.222222,-0.666666,-0.222222,-0.222222
	float	-0.444444,-0.222222,-0.222222,-0.222222,-0.222222,-0.222222,      0.0,-0.222222,-0.222222, 0.222222,-0.222222,-0.222222
	float	 0.444444,-0.222222,-0.222222, 0.666667,-0.222222,-0.222222, 0.888889,-0.222222,-0.222222,-0.888889,      0.0,-0.222222
	float	-0.666666,      0.0,-0.222222,-0.444444,      0.0,-0.222222,-0.222222,      0.0,-0.222222,      0.0,      0.0,-0.222222
	float	 0.222222,      0.0,-0.222222, 0.444444,      0.0,-0.222222, 0.666667,      0.0,-0.222222, 0.888889,      0.0,-0.222222
	float	-0.888889, 0.222222,-0.222222,-0.666666, 0.222222,-0.222222,-0.444444, 0.222222,-0.222222,-0.222222, 0.222222,-0.222222
	float	      0.0, 0.222222,-0.222222, 0.222222, 0.222222,-0.222222, 0.444444, 0.222222,-0.222222, 0.666667, 0.222222,-0.222222
	float	 0.888889, 0.222222,-0.222222,-0.888889, 0.444444,-0.222222,-0.666666, 0.444444,-0.222222,-0.444444, 0.444444,-0.222222
	float	-0.222222, 0.444444,-0.222222,      0.0, 0.444444,-0.222222, 0.222222, 0.444444,-0.222222, 0.444444, 0.444444,-0.222222
	float	 0.666667, 0.444444,-0.222222, 0.888889, 0.444444,-0.222222,-0.888889, 0.666667,-0.222222,-0.666666, 0.666667,-0.222222
	float	-0.444444, 0.666667,-0.222222,-0.222222, 0.666667,-0.222222,      0.0, 0.666667,-0.222222, 0.222222, 0.666667,-0.222222
	float	 0.444444, 0.666667,-0.222222, 0.666667, 0.666667,-0.222222, 0.888889, 0.666667,-0.222222,-0.888889, 0.888889,-0.222222
	float	-0.666666, 0.888889,-0.222222,-0.444444, 0.888889,-0.222222,-0.222222, 0.888889,-0.222222,      0.0, 0.888889,-0.222222
	float	 0.222222, 0.888889,-0.222222, 0.444444, 0.888889,-0.222222, 0.666667, 0.888889,-0.222222, 0.888889, 0.888889,-0.222222
	float	-0.888889,-0.888889,      0.0,-0.666666,-0.888889,      0.0,-0.444444,-0.888889,      0.0,-0.222222,-0.888889,      0.0
	float	      0.0,-0.888889,      0.0, 0.222222,-0.888889,      0.0, 0.444444,-0.888889,      0.0, 0.666667,-0.888889,      0.0
	float	 0.888889,-0.888889,      0.0,-0.888889,-0.666666,      0.0,-0.666666,-0.666666,      0.0,-0.444444,-0.666666,      0.0
	float	-0.222222,-0.666666,      0.0,      0.0,-0.666666,      0.0, 0.222222,-0.666666,      0.0, 0.444444,-0.666666,      0.0
	float	 0.666667,-0.666666,      0.0, 0.888889,-0.666666,      0.0,-0.888889,-0.444444,      0.0,-0.666666,-0.444444,      0.0
	float	-0.444444,-0.444444,      0.0,-0.222222,-0.444444,      0.0,      0.0,-0.444444,      0.0, 0.222222,-0.444444,      0.0
	float	 0.444444,-0.444444,      0.0, 0.666667,-0.444444,      0.0, 0.888889,-0.444444,      0.0,-0.888889,-0.222222,      0.0
	float	-0.666666,-0.222222,      0.0,-0.444444,-0.222222,      0.0,-0.222222,-0.222222,      0.0,      0.0,-0.222222,      0.0
	float	 0.222222,-0.222222,      0.0, 0.444444,-0.222222,      0.0, 0.666667,-0.222222,      0.0, 0.888889,-0.222222,      0.0
	float	-0.888889,      0.0,      0.0,-0.666666,      0.0,      0.0,-0.444444,      0.0,      0.0,-0.222222,      0.0,      0.0
	float	      0.0,      0.0,      0.0, 0.222222,      0.0,      0.0, 0.444444,      0.0,      0.0, 0.666667,      0.0,      0.0
	float	 0.888889,      0.0,      0.0,-0.888889, 0.222222,      0.0,-0.666666, 0.222222,      0.0,-0.444444, 0.222222,      0.0
	float	-0.222222, 0.222222,      0.0,      0.0, 0.222222,      0.0, 0.222222, 0.222222,      0.0, 0.444444, 0.222222,      0.0
	float	 0.666667, 0.222222,      0.0, 0.888889, 0.222222,      0.0,-0.888889, 0.444444,      0.0,-0.666666, 0.444444,      0.0
	float	-0.444444, 0.444444,      0.0,-0.222222, 0.444444,      0.0,      0.0, 0.444444,      0.0, 0.222222, 0.444444,      0.0
	float	 0.444444, 0.444444,      0.0, 0.666667, 0.444444,      0.0, 0.888889, 0.444444,      0.0,-0.888889, 0.666667,      0.0
	float	-0.666666, 0.666667,      0.0,-0.444444, 0.666667,      0.0,-0.222222, 0.666667,      0.0,      0.0, 0.666667,      0.0
	float	 0.222222, 0.666667,      0.0, 0.444444, 0.666667,      0.0, 0.666667, 0.666667,      0.0, 0.888889, 0.666667,      0.0
	float	-0.888889, 0.888889,      0.0,-0.666666, 0.888889,      0.0,-0.444444, 0.888889,      0.0,-0.222222, 0.888889,      0.0
	float	      0.0, 0.888889,      0.0, 0.222222, 0.888889,      0.0, 0.444444, 0.888889,      0.0, 0.666667, 0.888889,      0.0
	float	 0.888889, 0.888889,      0.0,-0.888889,-0.888889, 0.222222,-0.666666,-0.888889, 0.222222,-0.444444,-0.888889, 0.222222
	float	-0.222222,-0.888889, 0.222222,      0.0,-0.888889, 0.222222, 0.222222,-0.888889, 0.222222, 0.444444,-0.888889, 0.222222
	float	 0.666667,-0.888889, 0.222222, 0.888889,-0.888889, 0.222222,-0.888889,-0.666666, 0.222222,-0.666666,-0.666666, 0.222222
	float	-0.444444,-0.666666, 0.222222,-0.222222,-0.666666, 0.222222,      0.0,-0.666666, 0.222222, 0.222222,-0.666666, 0.222222
	float	 0.444444,-0.666666, 0.222222, 0.666667,-0.666666, 0.222222, 0.888889,-0.666666, 0.222222,-0.888889,-0.444444, 0.222222
	float	-0.666666,-0.444444, 0.222222,-0.444444,-0.444444, 0.222222,-0.222222,-0.444444, 0.222222,      0.0,-0.444444, 0.222222
	float	 0.222222,-0.444444, 0.222222, 0.444444,-0.444444, 0.222222, 0.666667,-0.444444, 0.222222, 0.888889,-0.444444, 0.222222
	float	-0.888889,-0.222222, 0.222222,-0.666666,-0.222222, 0.222222,-0.444444,-0.222222, 0.222222,-0.222222,-0.222222, 0.222222
	float	      0.0,-0.222222, 0.222222, 0.222222,-0.222222, 0.222222, 0.444444,-0.222222, 0.222222, 0.666667,-0.222222, 0.222222
	float	 0.888889,-0.222222, 0.222222,-0.888889,      0.0, 0.222222,-0.666666,      0.0, 0.222222,-0.444444,      0.0, 0.222222
	float	-0.222222,      0.0, 0.222222,      0.0,      0.0, 0.222222, 0.222222,      0.0, 0.222222, 0.444444,      0.0, 0.222222
	float	 0.666667,      0.0, 0.222222, 0.888889,      0.0, 0.222222,-0.888889, 0.222222, 0.222222,-0.666666, 0.222222, 0.222222
	float	-0.444444, 0.222222, 0.222222,-0.222222, 0.222222, 0.222222,      0.0, 0.222222, 0.222222, 0.222222, 0.222222, 0.222222
	float	 0.444444, 0.222222, 0.222222, 0.666667, 0.222222, 0.222222, 0.888889, 0.222222, 0.222222,-0.888889, 0.444444, 0.222222
	float	-0.666666, 0.444444, 0.222222,-0.444444, 0.444444, 0.222222,-0.222222, 0.444444, 0.222222,      0.0, 0.444444, 0.222222
	float	 0.222222, 0.444444, 0.222222, 0.444444, 0.444444, 0.222222, 0.666667, 0.444444, 0.222222, 0.888889, 0.444444, 0.222222
	float	-0.888889, 0.666667, 0.222222,-0.666666, 0.666667, 0.222222,-0.444444, 0.666667, 0.222222,-0.222222, 0.666667, 0.222222
	float	      0.0, 0.666667, 0.222222, 0.222222, 0.666667, 0.222222, 0.444444, 0.666667, 0.222222, 0.666667, 0.666667, 0.222222
	float	 0.888889, 0.666667, 0.222222,-0.888889, 0.888889, 0.222222,-0.666666, 0.888889, 0.222222,-0.444444, 0.888889, 0.222222
	float	-0.222222, 0.888889, 0.222222,      0.0, 0.888889, 0.222222, 0.222222, 0.888889, 0.222222, 0.444444, 0.888889, 0.222222
	float	 0.666667, 0.888889, 0.222222, 0.888889, 0.888889, 0.222222,-0.888889,-0.888889, 0.444444,-0.666666,-0.888889, 0.444444
	float	-0.444444,-0.888889, 0.444444,-0.222222,-0.888889, 0.444444,      0.0,-0.888889, 0.444444, 0.222222,-0.888889, 0.444444
	float	 0.444444,-0.888889, 0.444444, 0.666667,-0.888889, 0.444444, 0.888889,-0.888889, 0.444444,-0.888889,-0.666666, 0.444444
	float	-0.666666,-0.666666, 0.444444,-0.444444,-0.666666, 0.444444,-0.222222,-0.666666, 0.444444,      0.0,-0.666666, 0.444444
	float	 0.222222,-0.666666, 0.444444, 0.444444,-0.666666, 0.444444, 0.666667,-0.666666, 0.444444, 0.888889,-0.666666, 0.444444
	float	-0.888889,-0.444444, 0.444444,-0.666666,-0.444444, 0.444444,-0.444444,-0.444444, 0.444444,-0.222222,-0.444444, 0.444444
	float	      0.0,-0.444444, 0.444444, 0.222222,-0.444444, 0.444444, 0.444444,-0.444444, 0.444444, 0.666667,-0.444444, 0.444444
	float	 0.888889,-0.444444, 0.444444,-0.888889,-0.222222, 0.444444,-0.666666,-0.222222, 0.444444,-0.444444,-0.222222, 0.444444
	float	-0.222222,-0.222222, 0.444444,      0.0,-0.222222, 0.444444, 0.222222,-0.222222, 0.444444, 0.444444,-0.222222, 0.444444
	float	 0.666667,-0.222222, 0.444444, 0.888889,-0.222222, 0.444444,-0.888889,      0.0, 0.444444,-0.666666,      0.0, 0.444444
	float	-0.444444,      0.0, 0.444444,-0.222222,      0.0, 0.444444,      0.0,      0.0, 0.444444, 0.222222,      0.0, 0.444444
	float	 0.444444,      0.0, 0.444444, 0.666667,      0.0, 0.444444, 0.888889,      0.0, 0.444444,-0.888889, 0.222222, 0.444444
	float	-0.666666, 0.222222, 0.444444,-0.444444, 0.222222, 0.444444,-0.222222, 0.222222, 0.444444,      0.0, 0.222222, 0.444444
	float	 0.222222, 0.222222, 0.444444, 0.444444, 0.222222, 0.444444, 0.666667, 0.222222, 0.444444, 0.888889, 0.222222, 0.444444
	float	-0.888889, 0.444444, 0.444444,-0.666666, 0.444444, 0.444444,-0.444444, 0.444444, 0.444444,-0.222222, 0.444444, 0.444444
	float	      0.0, 0.444444, 0.444444, 0.222222, 0.444444, 0.444444, 0.444444, 0.444444, 0.444444, 0.666667, 0.444444, 0.444444
	float	 0.888889, 0.444444, 0.444444,-0.888889, 0.666667, 0.444444,-0.666666, 0.666667, 0.444444,-0.444444, 0.666667, 0.444444
	float	-0.222222, 0.666667, 0.444444,      0.0, 0.666667, 0.444444, 0.222222, 0.666667, 0.444444, 0.444444, 0.666667, 0.444444
	float	 0.666667, 0.666667, 0.444444, 0.888889, 0.666667, 0.444444,-0.888889, 0.888889, 0.444444,-0.666666, 0.888889, 0.444444
	float	-0.444444, 0.888889, 0.444444,-0.222222, 0.888889, 0.444444,      0.0, 0.888889, 0.444444, 0.222222, 0.888889, 0.444444
	float	 0.444444, 0.888889, 0.444444, 0.666667, 0.888889, 0.444444, 0.888889, 0.888889, 0.444444,-0.888889,-0.888889, 0.666667
	float	-0.666666,-0.888889, 0.666667,-0.444444,-0.888889, 0.666667,-0.222222,-0.888889, 0.666667,      0.0,-0.888889, 0.666667
	float	 0.222222,-0.888889, 0.666667, 0.444444,-0.888889, 0.666667, 0.666667,-0.888889, 0.666667, 0.888889,-0.888889, 0.666667
	float	-0.888889,-0.666666, 0.666667,-0.666666,-0.666666, 0.666667,-0.444444,-0.666666, 0.666667,-0.222222,-0.666666, 0.666667
	float	      0.0,-0.666666, 0.666667, 0.222222,-0.666666, 0.666667, 0.444444,-0.666666, 0.666667, 0.666667,-0.666666, 0.666667
	float	 0.888889,-0.666666, 0.666667,-0.888889,-0.444444, 0.666667,-0.666666,-0.444444, 0.666667,-0.444444,-0.444444, 0.666667
	float	-0.222222,-0.444444, 0.666667,      0.0,-0.444444, 0.666667, 0.222222,-0.444444, 0.666667, 0.444444,-0.444444, 0.666667
	float	 0.666667,-0.444444, 0.666667, 0.888889,-0.444444, 0.666667,-0.888889,-0.222222, 0.666667,-0.666666,-0.222222, 0.666667
	float	-0.444444,-0.222222, 0.666667,-0.222222,-0.222222, 0.666667,      0.0,-0.222222, 0.666667, 0.222222,-0.222222, 0.666667
	float	 0.444444,-0.222222, 0.666667, 0.666667,-0.222222, 0.666667, 0.888889,-0.222222, 0.666667,-0.888889,      0.0, 0.666667
	float	-0.666666,      0.0, 0.666667,-0.444444,      0.0, 0.666667,-0.222222,      0.0, 0.666667,      0.0,      0.0, 0.666667
	float	 0.222222,      0.0, 0.666667, 0.444444,      0.0, 0.666667, 0.666667,      0.0, 0.666667, 0.888889,      0.0, 0.666667
	float	-0.888889, 0.222222, 0.666667,-0.666666, 0.222222, 0.666667,-0.444444, 0.222222, 0.666667,-0.222222, 0.222222, 0.666667
	float	      0.0, 0.222222, 0.666667, 0.222222, 0.222222, 0.666667, 0.444444, 0.222222, 0.666667, 0.666667, 0.222222, 0.666667
	float	 0.888889, 0.222222, 0.666667,-0.888889, 0.444444, 0.666667,-0.666666, 0.444444, 0.666667,-0.444444, 0.444444, 0.666667
	float	-0.222222, 0.444444, 0.666667,      0.0, 0.444444, 0.666667, 0.222222, 0.444444, 0.666667, 0.444444, 0.444444, 0.666667
	float	 0.666667, 0.444444, 0.666667, 0.888889, 0.444444, 0.666667,-0.888889, 0.666667, 0.666667,-0.666666, 0.666667, 0.666667
	float	-0.444444, 0.666667, 0.666667,-0.222222, 0.666667, 0.666667,      0.0, 0.666667, 0.666667, 0.222222, 0.666667, 0.666667
	float	 0.444444, 0.666667, 0.666667, 0.666667, 0.666667, 0.666667, 0.888889, 0.666667, 0.666667,-0.888889, 0.888889, 0.666667
	float	-0.666666, 0.888889, 0.666667,-0.444444, 0.888889, 0.666667,-0.222222, 0.888889, 0.666667,      0.0, 0.888889, 0.666667
	float	 0.222222, 0.888889, 0.666667, 0.444444, 0.888889, 0.666667, 0.666667, 0.888889, 0.666667, 0.888889, 0.888889, 0.666667
	float	-0.888889,-0.888889, 0.888889,-0.666666,-0.888889, 0.888889,-0.444444,-0.888889, 0.888889,-0.222222,-0.888889, 0.888889
	float	      0.0,-0.888889, 0.888889, 0.222222,-0.888889, 0.888889, 0.444444,-0.888889, 0.888889, 0.666667,-0.888889, 0.888889
	float	 0.888889,-0.888889, 0.888889,-0.888889,-0.666666, 0.888889,-0.666666,-0.666666, 0.888889,-0.444444,-0.666666, 0.888889
	float	-0.222222,-0.666666, 0.888889,      0.0,-0.666666, 0.888889, 0.222222,-0.666666, 0.888889, 0.444444,-0.666666, 0.888889
	float	 0.666667,-0.666666, 0.888889, 0.888889,-0.666666, 0.888889,-0.888889,-0.444444, 0.888889,-0.666666,-0.444444, 0.888889
	float	-0.444444,-0.444444, 0.888889,-0.222222,-0.444444, 0.888889,      0.0,-0.444444, 0.888889, 0.222222,-0.444444, 0.888889
	float	 0.444444,-0.444444, 0.888889, 0.666667,-0.444444, 0.888889, 0.888889,-0.444444, 0.888889,-0.888889,-0.222222, 0.888889
	float	-0.666666,-0.222222, 0.888889,-0.444444,-0.222222, 0.888889,-0.222222,-0.222222, 0.888889,      0.0,-0.222222, 0.888889
	float	 0.222222,-0.222222, 0.888889, 0.444444,-0.222222, 0.888889, 0.666667,-0.222222, 0.888889, 0.888889,-0.222222, 0.888889
	float	-0.888889,      0.0, 0.888889,-0.666666,      0.0, 0.888889,-0.444444,      0.0, 0.888889,-0.222222,      0.0, 0.888889
	float	      0.0,      0.0, 0.888889, 0.222222,      0.0, 0.888889, 0.444444,      0.0, 0.888889, 0.666667,      0.0, 0.888889
	float	 0.888889,      0.0, 0.888889,-0.888889, 0.222222, 0.888889,-0.666666, 0.222222, 0.888889,-0.444444, 0.222222, 0.888889
	float	-0.222222, 0.222222, 0.888889,      0.0, 0.222222, 0.888889, 0.222222, 0.222222, 0.888889, 0.444444, 0.222222, 0.888889
	float	 0.666667, 0.222222, 0.888889, 0.888889, 0.222222, 0.888889,-0.888889, 0.444444, 0.888889,-0.666666, 0.444444, 0.888889
	float	-0.444444, 0.444444, 0.888889,-0.222222, 0.444444, 0.888889,      0.0, 0.444444, 0.888889, 0.222222, 0.444444, 0.888889
	float	 0.444444, 0.444444, 0.888889, 0.666667, 0.444444, 0.888889, 0.888889, 0.444444, 0.888889,-0.888889, 0.666667, 0.888889
	float	-0.666666, 0.666667, 0.888889,-0.444444, 0.666667, 0.888889,-0.222222, 0.666667, 0.888889,      0.0, 0.666667, 0.888889
	float	 0.222222, 0.666667, 0.888889, 0.444444, 0.666667, 0.888889, 0.666667, 0.666667, 0.888889, 0.888889, 0.666667, 0.888889
	float	-0.888889, 0.888889, 0.888889,-0.666666, 0.888889, 0.888889,-0.444444, 0.888889, 0.888889,-0.222222, 0.888889, 0.888889
	float	      0.0, 0.888889, 0.888889, 0.222222, 0.888889, 0.888889, 0.444444, 0.888889, 0.888889, 0.666667, 0.888889, 0.888889
	float	 0.888889, 0.888889, 0.888889,-0.888889,-0.888889,-0.888889,-0.666666,-0.888889,-0.888889,-0.444444,-0.888889,-0.888889
	float	-0.222222,-0.888889,-0.888889,      0.0,-0.888889,-0.888889, 0.222222,-0.888889,-0.888889, 0.444444,-0.888889,-0.888889
	float	 0.666667,-0.888889,-0.888889, 0.888889,-0.888889,-0.888889,-0.888889,-0.666666,-0.888889,-0.666666,-0.666666,-0.888889
	float	-0.444444,-0.666666,-0.888889,-0.222222,-0.666666,-0.888889,      0.0,-0.666666,-0.888889, 0.222222,-0.666666,-0.888889
	float	 0.444444,-0.666666,-0.888889, 0.666667,-0.666666,-0.888889, 0.888889,-0.666666,-0.888889,-0.888889,-0.444444,-0.888889
	float	-0.666666,-0.444444,-0.888889,-0.444444,-0.444444,-0.888889,-0.222222,-0.444444,-0.888889,      0.0,-0.444444,-0.888889
	float	 0.222222,-0.444444,-0.888889, 0.444444,-0.444444,-0.888889, 0.666667,-0.444444,-0.888889, 0.888889,-0.444444,-0.888889
	float	-0.888889,-0.222222,-0.888889,-0.666666,-0.222222,-0.888889,-0.444444,-0.222222,-0.888889,-0.222222,-0.222222,-0.888889
	float	      0.0,-0.222222,-0.888889, 0.222222,-0.222222,-0.888889, 0.444444,-0.222222,-0.888889, 0.666667,-0.222222,-0.888889
	float	 0.888889,-0.222222,-0.888889,-0.888889,      0.0,-0.888889,-0.666666,      0.0,-0.888889,-0.444444,      0.0,-0.888889
	float	-0.222222,      0.0,-0.888889,      0.0,      0.0,-0.888889, 0.222222,      0.0,-0.888889, 0.444444,      0.0,-0.888889
	float	 0.666667,      0.0,-0.888889, 0.888889,      0.0,-0.888889,-0.888889, 0.222222,-0.888889,-0.666666, 0.222222,-0.888889
	float	-0.444444, 0.222222,-0.888889,-0.222222, 0.222222,-0.888889,      0.0, 0.222222,-0.888889, 0.222222, 0.222222,-0.888889
	float	 0.444444, 0.222222,-0.888889, 0.666667, 0.222222,-0.888889, 0.888889, 0.222222,-0.888889,-0.888889, 0.444444,-0.888889
	float	-0.666666, 0.444444,-0.888889,-0.444444, 0.444444,-0.888889,-0.222222, 0.444444,-0.888889,      0.0, 0.444444,-0.888889
	float	 0.222222, 0.444444,-0.888889, 0.444444, 0.444444,-0.888889, 0.666667, 0.444444,-0.888889, 0.888889, 0.444444,-0.888889
	float	-0.888889, 0.666667,-0.888889,-0.666666, 0.666667,-0.888889,-0.444444, 0.666667,-0.888889,-0.222222, 0.666667,-0.888889
	float	      0.0, 0.666667,-0.888889, 0.222222, 0.666667,-0.888889, 0.444444, 0.666667,-0.888889, 0.666667, 0.666667,-0.888889
	float	 0.888889, 0.666667,-0.888889,-0.888889, 0.888889,-0.888889,-0.666666, 0.888889,-0.888889,-0.444444, 0.888889,-0.888889
	float	-0.222222, 0.888889,-0.888889,      0.0, 0.888889,-0.888889, 0.222222, 0.888889,-0.888889, 0.444444, 0.888889,-0.888889
	float	 0.666667, 0.888889,-0.888889, 0.888889, 0.888889,-0.888889,-0.888889,-0.888889,-0.666666,-0.666666,-0.888889,-0.666666
	float	-0.444444,-0.888889,-0.666666,-0.222222,-0.888889,-0.666666,      0.0,-0.888889,-0.666666, 0.222222,-0.888889,-0.666666
	float	 0.444444,-0.888889,-0.666666, 0.666667,-0.888889,-0.666666, 0.888889,-0.888889,-0.666666,-0.888889,-0.666666,-0.666666
	float	-0.666666,-0.666666,-0.666666,-0.444444,-0.666666,-0.666666,-0.222222,-0.666666,-0.666666,      0.0,-0.666666,-0.666666
	float	 0.222222,-0.666666,-0.666666, 0.444444,-0.666666,-0.666666, 0.666667,-0.666666,-0.666666, 0.888889,-0.666666,-0.666666
	float	-0.888889,-0.444444,-0.666666,-0.666666,-0.444444,-0.666666,-0.444444,-0.444444,-0.666666,-0.222222,-0.444444,-0.666666
	float	      0.0,-0.444444,-0.666666, 0.222222,-0.444444,-0.666666, 0.444444,-0.444444,-0.666666, 0.666667,-0.444444,-0.666666
	float	 0.888889,-0.444444,-0.666666,-0.888889,-0.222222,-0.666666,-0.666666,-0.222222,-0.666666,-0.444444,-0.222222,-0.666666
	float	-0.222222,-0.222222,-0.666666,      0.0,-0.222222,-0.666666, 0.222222,-0.222222,-0.666666, 0.444444,-0.222222,-0.666666
	float	 0.666667,-0.222222,-0.666666, 0.888889,-0.222222,-0.666666,-0.888889,      0.0,-0.666666,-0.666666,      0.0,-0.666666
	float	-0.444444,      0.0,-0.666666,-0.222222,      0.0,-0.666666,      0.0,      0.0,-0.666666, 0.222222,      0.0,-0.666666
	float	 0.444444,      0.0,-0.666666, 0.666667,      0.0,-0.666666, 0.888889,      0.0,-0.666666,-0.888889, 0.222222,-0.666666
	float	-0.666666, 0.222222,-0.666666,-0.444444, 0.222222,-0.666666,-0.222222, 0.222222,-0.666666,      0.0, 0.222222,-0.666666
	float	 0.222222, 0.222222,-0.666666, 0.444444, 0.222222,-0.666666, 0.666667, 0.222222,-0.666666, 0.888889, 0.222222,-0.666666
	float	-0.888889, 0.444444,-0.666666,-0.666666, 0.444444,-0.666666,-0.444444, 0.444444,-0.666666,-0.222222, 0.444444,-0.666666
	float	      0.0, 0.444444,-0.666666, 0.222222, 0.444444,-0.666666, 0.444444, 0.444444,-0.666666, 0.666667, 0.444444,-0.666666
	float	 0.888889, 0.444444,-0.666666,-0.888889, 0.666667,-0.666666,-0.666666, 0.666667,-0.666666,-0.444444, 0.666667,-0.666666
	float	-0.222222, 0.666667,-0.666666,      0.0, 0.666667,-0.666666, 0.222222, 0.666667,-0.666666, 0.444444, 0.666667,-0.666666
	float	 0.666667, 0.666667,-0.666666, 0.888889, 0.666667,-0.666666,-0.888889, 0.888889,-0.666666,-0.666666, 0.888889,-0.666666
	float	-0.444444, 0.888889,-0.666666,-0.222222, 0.888889,-0.666666,      0.0, 0.888889,-0.666666, 0.222222, 0.888889,-0.666666
	float	 0.444444, 0.888889,-0.666666, 0.666667, 0.888889,-0.666666, 0.888889, 0.888889,-0.666666,-0.888889,-0.888889,-0.444444
	float	-0.666666,-0.888889,-0.444444,-0.444444,-0.888889,-0.444444,-0.222222,-0.888889,-0.444444,      0.0,-0.888889,-0.444444
	float	 0.222222,-0.888889,-0.444444, 0.444444,-0.888889,-0.444444, 0.666667,-0.888889,-0.444444, 0.888889,-0.888889,-0.444444
	float	-0.888889,-0.666666,-0.444444,-0.666666,-0.666666,-0.444444,-0.444444,-0.666666,-0.444444,-0.222222,-0.666666,-0.444444
	float	      0.0,-0.666666,-0.444444, 0.222222,-0.666666,-0.444444, 0.444444,-0.666666,-0.444444, 0.666667,-0.666666,-0.444444
	float	 0.888889,-0.666666,-0.444444,-0.888889,-0.444444,-0.444444,-0.666666,-0.444444,-0.444444,-0.444444,-0.444444,-0.444444
	float	-0.222222,-0.444444,-0.444444,      0.0,-0.444444,-0.444444, 0.222222,-0.444444,-0.444444, 0.444444,-0.444444,-0.444444
	float	 0.666667,-0.444444,-0.444444, 0.888889,-0.444444,-0.444444,-0.888889,-0.222222,-0.444444,-0.666666,-0.222222,-0.444444
	float	-0.444444,-0.222222,-0.444444,-0.222222,-0.222222,-0.444444,      0.0,-0.222222,-0.444444, 0.222222,-0.222222,-0.444444
	float	 0.444444,-0.222222,-0.444444, 0.666667,-0.222222,-0.444444, 0.888889,-0.222222,-0.444444,-0.888889,      0.0,-0.444444
	float	-0.666666,      0.0,-0.444444,-0.444444,      0.0,-0.444444,-0.222222,      0.0,-0.444444,      0.0,      0.0,-0.444444
	float	 0.222222,      0.0,-0.444444, 0.444444,      0.0,-0.444444, 0.666667,      0.0,-0.444444, 0.888889,      0.0,-0.444444
	float	-0.888889, 0.222222,-0.444444,-0.666666, 0.222222,-0.444444,-0.444444, 0.222222,-0.444444,-0.222222, 0.222222,-0.444444
	float	      0.0, 0.222222,-0.444444, 0.222222, 0.222222,-0.444444, 0.444444, 0.222222,-0.444444, 0.666667, 0.222222,-0.444444
	float	 0.888889, 0.222222,-0.444444,-0.888889, 0.444444,-0.444444,-0.666666, 0.444444,-0.444444,-0.444444, 0.444444,-0.444444
	float	-0.222222, 0.444444,-0.444444,      0.0, 0.444444,-0.444444, 0.222222, 0.444444,-0.444444, 0.444444, 0.444444,-0.444444
	float	 0.666667, 0.444444,-0.444444, 0.888889, 0.444444,-0.444444,-0.888889, 0.666667,-0.444444,-0.666666, 0.666667,-0.444444
	float	-0.444444, 0.666667,-0.444444,-0.222222, 0.666667,-0.444444,      0.0, 0.666667,-0.444444, 0.222222, 0.666667,-0.444444
	float	 0.444444, 0.666667,-0.444444, 0.666667, 0.666667,-0.444444, 0.888889, 0.666667,-0.444444,-0.888889, 0.888889,-0.444444
	float	-0.666666, 0.888889,-0.444444,-0.444444, 0.888889,-0.444444,-0.222222, 0.888889,-0.444444,      0.0, 0.888889,-0.444444
	float	 0.222222, 0.888889,-0.444444, 0.444444, 0.888889,-0.444444, 0.666667, 0.888889,-0.444444, 0.888889, 0.888889,-0.444444
	float	-0.888889,-0.888889,-0.222222,-0.666666,-0.888889,-0.222222,-0.444444,-0.888889,-0.222222,-0.222222,-0.888889,-0.222222
	float	      0.0,-0.888889,-0.222222, 0.222222,-0.888889,-0.222222, 0.444444,-0.888889,-0.222222, 0.666667,-0.888889,-0.222222
	float	 0.888889,-0.888889,-0.222222,-0.888889,-0.666666,-0.222222,-0.666666,-0.666666,-0.222222,-0.444444,-0.666666,-0.222222
	float	-0.222222,-0.666666,-0.222222,      0.0,-0.666666,-0.222222, 0.222222,-0.666666,-0.222222, 0.444444,-0.666666,-0.222222
	float	 0.666667,-0.666666,-0.222222, 0.888889,-0.666666,-0.222222,-0.888889,-0.444444,-0.222222,-0.666666,-0.444444,-0.222222
	float	-0.444444,-0.444444,-0.222222,-0.222222,-0.444444,-0.222222,      0.0,-0.444444,-0.222222, 0.222222,-0.444444,-0.222222
	float	 0.444444,-0.444444,-0.222222, 0.666667,-0.444444,-0.222222, 0.888889,-0.444444,-0.222222,-0.888889,-0.222222,-0.222222
	float	-0.666666,-0.222222,-0.222222,-0.444444,-0.222222,-0.222222,-0.222222,-0.222222,-0.222222,      0.0,-0.222222,-0.222222
	float	 0.222222,-0.222222,-0.222222, 0.444444,-0.222222,-0.222222, 0.666667,-0.222222,-0.222222, 0.888889,-0.222222,-0.222222
	float	-0.888889,      0.0,-0.222222,-0.666666,      0.0,-0.222222,-0.444444,      0.0,-0.222222,-0.222222,      0.0,-0.222222
	float	      0.0,      0.0,-0.222222, 0.222222,      0.0,-0.222222, 0.444444,      0.0,-0.222222, 0.666667,      0.0,-0.222222
	float	 0.888889,      0.0,-0.222222,-0.888889, 0.222222,-0.222222,-0.666666, 0.222222,-0.222222,-0.444444, 0.222222,-0.222222
	float	-0.222222, 0.222222,-0.222222,      0.0, 0.222222,-0.222222, 0.222222, 0.222222,-0.222222, 0.444444, 0.222222,-0.222222




// Sampling tables
table_quantizations_01:
	long	 0, 0, 1, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
	long	 0, 0, 1, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0

table_quantizations_23:
	long	 0, 0, 2, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16
	long	 0, 0, 2, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16
	long	 0, 0, 2, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,16
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1, 2, 3, 4, 5,16, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	long	 0, 0, 1,16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0



table_xm:				//indexed by quantization
	long 0x1			//not used as grouped
	float 2.0			//not used as grouped
	long 0x3			//not used as grouped
	float 0.6666666667	//not used as grouped
	long 0x3
	float 0.2857142857
	long 0x7			//not used as grouped
	float 1.555555		//not used as grouped
	long 0x7
	float 0.1333333333
	long 0xf
	float 0.06451612903
	long 0x1f
	float 0.03174603175
	long 0x3f
	float 0.0157480315
	long 0x7f
	float 0.007843137255
	long 0xff
	float 0.003913894325
	long 0x1ff
	float 0.001955034213
	long 0x3ff
	float 0.0009770395701
	long 0x7ff
	float 0.0004884004884
	long 0xfff
	float 0.000244170431
	long 0x1fff
	float 0.0001220777635
	long 0x3fff
	float 0.00006103701895
	long 0x7fff
	float 0.00003051804379


table_multiple:
	float 1.99999976158142,		1.5874011516571,		1.25992107391357,		1.0
	float 0.793700456619262,	0.629960536956788,		0.5,					0.39685034751892
	float 0.314980268478394,	0.25,					0.198425054550171,		0.157490015029907
	float 0.125,				0.099212646484375,		0.0787451267242432,		0.0625
	float 0.0496063232421874,	0.039372444152832,		0.03125,				0.0248031616210938
	float 0.019686222076416,	0.015625,				0.0124015808105469,		0.009843111038208
	float 0.0078125,			0.00620079040527344,	0.00492167472839356,	0.00390625
	float 0.00310039520263672,	0.00246071815490722,	0.001953125,			0.00155019760131836
	float 0.00123047828674316,	0.0009765625,			0.00077509880065918,	0.000615119934082032
	float 0.00048828125,		0.00038743019104004,	0.000307559967041016,	0.000244140625
	float 0.00019383430480957,	0.000153779983520508,	0.0001220703125,		9.67979431152344E-05
	float 7.70092010498046E-05,	0.00006103515625,		4.83989715576172E-05,	3.83853912353516E-05
	float 0.000030517578125,	2.43186950683594E-05,	1.93119049072266E-05,	0.0000152587890625
	float 1.21593475341797E-05,	9.5367431640625E-06,	7.62939453125E-06,		5.96046447753906E-06
	float 4.76837158203124E-06,	3.814697265625E-06,		3.09944152832032E-06,	2.38418579101562E-06
	float 1.9073486328125E-06,	1.43051147460938E-06,	1.19209289550782E-06,	0.0

table_bits:
	long	5,7,3,10,4,5,6,7,8,9
	long	10,11,12,13,14,15,16

table_translate_quantizations:
	long	table_quantizations_23 - table_quantizations_01
	long	table_quantizations_23 - table_quantizations_01
	long	table_quantizations_01 - table_quantizations_01
	long	table_quantizations_01 - table_quantizations_01


table_translate_sblimit:	long	27,30,8,12
table_translate_alloc:
	long	alloc0_bits0 - alloc0_bits0
	long	alloc1_bits0 - alloc0_bits0
	long	alloc2_bits0 - alloc0_bits0
	long	alloc3_bits0 - alloc0_bits0
alloc0_bits0:						//sblimit=27
alloc1_bits0:						//sblimit=30
	long	4,4,4,4,4,4,4,4,4,4,4	// 11
	long	3,3,3,3,3,3,3,3,3,3,3,3	//+12
	long	2,2,2,2					//+04 = 27
	long	2,2,2					//+03 = 30
alloc2_bits0:						//sblimit=08
alloc3_bits0:						//sblimit=12
	long	4,4						// 02
	long	3,3,3,3,3,3				//+06 = 08
	long	3,3,3,3					//+04 = 12


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

output:		long 0, 0, 0, 0, 0, 0, 0, 0
out_alloc:		long 0
temp_store:	long 0
bitstream_p:	long 0x5a5a5a5a
bitstream:		long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
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
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


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


