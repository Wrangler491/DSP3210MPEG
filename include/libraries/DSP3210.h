//**************************************************************************
//  DSP3210.h
//	Support routines for the DSP - header file
//	Copyright © Wrangler 2024
//
//**************************************************************************

#ifndef DSP3210_H
#define DSP3210_H



/* Defines for _DSP_routine */
//#define DSP_IMDCT		((ULONG) 1)
//#define DSP_antialias	((ULONG) 2)
//#define DSP_synthesis	((ULONG) 3)
//#define DSP_window_update ((ULONG) 4)
//#define bitalloc_DSP	((ULONG) 5)
#define DSP3210_volume		((ULONG) 1)
#define DSP3210_decodeMP2	((ULONG) 2)
#define DSP3210_decodeMP3	((ULONG) 3)


extern ULONG DSP_forcemono;
extern ULONG DSP_mono;
extern ULONG DSP_outbuffer0;
extern ULONG DSP_outbuffer1;
extern ULONG DSP_translate;
extern ULONG DSP_jsbound;
extern ULONG DSP_inbuf;
extern ULONG DSP_volR;
extern ULONG DSP_volL;
extern ULONG DSP_freq_div;
extern ULONG DSP_modext;
extern ULONG DSP_freq_idx;

extern ULONG DSP_routine;	//code for routine to jump to
extern volatile ULONG DSP_status;	//shows DSP status
extern ULONG DSP_intserver;
extern ULONG DSP_registers;

//Initialise the DSP
void DSP_init();

//Close down using the DSP
void DSP_exit();

//Trigger an interrupt on the DSP
//having cleared caches on the input data first
//input = address from which the DSP reads inputs
//inputlen = length of input in bytes
void DSP_int0(ULONG input, ULONG inputlen);
void DSP_int1();

//Wait for the DSP to signal ready
//output = address from which the DSP uses to store results
//outputlen = length of output in bytes
//returns 0 if DSP is ready, and clears cache of output area
//returns 1 if DSP busy after a reasonable period
int DSP_waitready(ULONG output, ULONG outputlen);

#endif