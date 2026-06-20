/*****************************************************************************

    dsp3210mpeg.device - mpeg.device for DSP3210 on Amiga AA3000(+) computers
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

// based on the framework of melodympeg.device
// (C) Copyright 1998-2000 Kato Development (Thorsten Hansen)
// and on delfinampeg.device Copyright (C) 2000-2003  Michael Henke

#include <stdlib.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/memory.h>
#include <exec/devices.h>
#include <exec/errors.h>
#include <exec/interrupts.h>
#include <devices/audio.h>
#include <dos/var.h>
#include <graphics/gfxbase.h>
#include <intuition/intuition.h>
#include <proto/intuition.h>
#include <clib/alib_protos.h>
#include <clib/graphics_protos.h>
#include "proto/Picasso96.h"

#include <libraries/DSP3210.h>
#include <libraries/MPEG.H>

#include <clib/debug_protos.h>
#include <clib/exec_protos.h>

//defines not included in Commodore's MPEG.H
#define MPEGCB_PLAYAUDLAYER_I	8	/* Can play audio layer I */
#define MPEGCB_PLAYAUDLAYER_II	9	/* Can play audio layer II */
#define MPEGCB_PLAYAUDLAYER_III	10	/* Can play audio layer III */
#define MPEGCB_PLAYAUDIOBYPASS	15	/* Can play audio bypass */

#define MPEGCF_PLAYAUDLAYER_I	(1L << MPEGCB_PLAYAUDLAYER_I)
#define MPEGCF_PLAYAUDLAYER_II	(1L << MPEGCB_PLAYAUDLAYER_II)
#define MPEGCF_PLAYAUDLAYER_III	(1L << MPEGCB_PLAYAUDLAYER_III)
#define MPEGCF_PLAYAUDIOBYPASS	(1L << MPEGCB_PLAYAUDIOBYPASS)


extern ULONG dspcode;

static int iter_count = 0;


extern char DevName;    

struct IOAudio     *AIOptr1[4],          /* Pointers to Audio IOBs      */
                   *AIOptr2[4],
                   *Aptr;
struct Message     *msg;              /* Msg, port and device for    */
struct MsgPort     *port,             /* driving audio               */
                   *port1,*port2;
       ULONG        device;
       UBYTE       *sbase;			   /* For sample memory allocation */
       ULONG        ssize;      /* and freeing                  */

       BYTE         oldpri,c;         /* Stuff for bumping priority */
	   ULONG         wakebit;             /* A wakeup mask             */
	   UBYTE		chans[4];

struct Task *task = NULL;
char *playtaskname = "DSP3210PlayTask";

struct GfxBase *GfxBase = NULL;
struct ExecBase *SysBase;
struct DosLibrary *DOSBase;
struct IntuitionBase *IntuitionBase = NULL;
struct Library *P96Base = NULL;

ULONG iteration;

ULONG mother_signal, daughter_signal;
struct Task *mother_task;
extern ULONG signr;


struct devunit
{
    struct Unit unit;
    ULONG   unitnum;
    struct List ioreqlist;
    struct IOMPEGReq *currioreq;
    UBYTE   *currpt;
    ULONG   currlen;
    ULONG   layer, freqidx, mono, firstheader;
    ULONG   volumeleft, volumeright, pause, initdsp_ok;
    BYTE    cleanup_flag, cleanup_count, pcm_flag, stop_flag;
	ULONG	mod_pcm, prg_mp2, prg_mp3;
    ULONG   intkey;
    UBYTE   framebuf[4096], bitresbuf[4096];
    UWORD   bitresoffset, bitresok, framebufstate;
    UWORD   framebufoffset, framebufleft, III_main_data_size;
    UWORD   dspcopysize, II_translate, II_jsbound, modext;
    UWORD   II_forcemono, III_forcemono, forcemono;
    ULONG   II_dacrate, III_dacrate, dacrate;
	ULONG	freq_div;
	UBYTE   *dspcopypt;
	struct Interrupt *DSPint2;
};

/* possible values for 'framebufstate' */
#define FBS_GETHEADER           0
#define FBS_GETFRAMEDATA        1
#define FBS_FILLED              2

#define PCM_NULL				0
#define PCM_EMPTY				1
#define PCM_FULL				2

#define MPG_MD_STEREO           0
#define MPG_MD_JOINT_STEREO     1
#define MPG_MD_DUAL_CHANNEL     2
#define MPG_MD_MONO             3
#define HDR_MPEG1               0xfff80000
#define HDR_CONSTANT            0xfffe0c00  /* layer, sampling frequency */

#define MAX_CHANNELS			2
#define PCM_SIZE			    1152 // Max samples per frame

void* C_initunit(ULONG unitnum);
ULONG C_expungeunit(struct devunit *unit);
void  C_setpause(struct devunit *unit, struct IOMPEGReq *iomr);
void  C_setvolume(struct devunit *unit, struct IOMPEGReq *iomr);
void  C_reset(struct devunit *unit);
void  C_flush(struct devunit *unit);
ULONG C_write(struct devunit *unit, struct IOMPEGReq *iomr);
static ULONG initDSP3210(struct devunit *unit);
static void  cleanupDSP3210(struct devunit *unit);

static LONG lev6_IntServer(__reg("a1") struct devunit *unit);
static LONG soft_IntServer(__reg("a1") struct devunit *unit);
static UWORD GetBits(UWORD num);
int play_task();
static void exit_cleanup( void );

static struct TagItem tagdone={TAG_DONE,0};
static ULONG volumeleft = 32768, volumeright = 32768;  /* default: 100% */
static UWORD *gb_pt=NULL, gb_buf=0, gb_num=0;

static const ULONG mpgfreq[4]={44100,48000,32000,0};
static const UWORD mpgbitrate[3][16]=
        { {0,32,64,96,128,160,192,224,256,288,320,352,384,416,448,0}, /* I */
          {0,32,48,56,64,80,96,112,128,160,192,224,256,320,384,0},   /* II */
          {0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0} }; /* III */
static const UBYTE mp2translate[3][2][16] =
        { { { 0,2,2,2,2,2,2,0,0,0,1,1,1,1,1,0 } ,    /* 44100 stereo */
            { 0,2,2,0,0,0,1,1,1,1,1,1,1,1,1,0 } } ,  /* 44100 mono   */
          { { 0,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0 } ,    /* 48000 stereo */
            { 0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0 } } ,  /* 48000 mono   */
          { { 0,3,3,3,3,3,3,0,0,0,1,1,1,1,1,0 } ,    /* 32000 stereo */
            { 0,3,3,0,0,0,1,1,1,1,1,1,1,1,1,0 } } }; /* 32000 mono   */
static const UBYTE mp2sblimit[4]={27,30,8,12};
static WORD *pcm[2][MAX_CHANNELS];
static struct devunit *u;
static UBYTE *inbuf;
ULONG clockrate;
int WBP96;
int AV31kHz;

//determine what graphics mode Workbench is running in (return 1 if P96, 2 is 31kHz, 0 15kHz, -1 error)
int workbench_displayID() {
	int is_P96 = 0;
	ULONG DisplayID;
	GfxBase = (struct GfxBase *)OpenLibrary("graphics.library",0L);
	if(!GfxBase) 
		return -1;			//failure
	
	if(GfxBase->DisplayFlags & PAL)
		clockrate = 3546895L;        // PAL clock
	else
		clockrate = 3579545L;        // NTSC clock

	if(GfxBase->LibNode.lib_Version >= 39) {			//KS3.0+
		IntuitionBase = (struct IntuitionBase *)OpenLibrary("intuition.library",0);
		if(!IntuitionBase) {
			CloseLibrary((struct Library *)GfxBase);
			return -1;
		}
		struct Screen *wb_screen = LockPubScreen("Workbench");

		if(wb_screen) {
			DisplayID = GetVPModeID(&wb_screen->ViewPort);

			if(DisplayID == VGA_MONITOR_ID || DisplayID == DBLPAL_MONITOR_ID || DisplayID == DBLNTSC_MONITOR_ID)
				is_P96 = 2;	//native 31kHz mode
			else {	//check P96
				P96Base = (struct Library *)OpenLibrary("Picasso96API.library",0);
				if(P96Base) {	
					is_P96 = p96GetModeIDAttr(DisplayID, P96IDA_ISP96);
					CloseLibrary((struct Library *)P96Base);
				}
			}
			UnlockPubScreen(NULL, wb_screen);
		}
		CloseLibrary((struct Library *)IntuitionBase);
	}

	CloseLibrary((struct Library *)GfxBase);
	return is_P96;
}


//save, check and set env var AmigaVideo
//0 no change to env var (already 31kHz), 1 needs reverting, -1 error 
int CheckAmigaVideo()
{
	UBYTE *varbuf;
	LONG  varlen, args[1] = {0};
	struct RDArgs *rdargs, *rdargs2;
	ULONG AV31;

	if((DOSBase = (struct DosLibrary*)OpenLibrary("dos.library",37)))
	{
		if((varbuf = AllocVec(1024,MEMF_PUBLIC|MEMF_CLEAR)))
		{
			if((varlen = GetVar("Picasso96/AmigaVideo",varbuf,1024,LV_VAR)) > 0)
			{
#ifdef DEBUG
				KPutStr("AmigaVideo var: '"); KPutStr(varbuf); KPutStr("'\n");
#endif
				if((rdargs = AllocDosObject(DOS_RDARGS,&tagdone)))
				{
					rdargs->RDA_Source.CS_Buffer = varbuf;
					rdargs->RDA_Source.CS_Length = varlen;
					rdargs->RDA_Source.CS_CurChr = 0;
					rdargs->RDA_Flags = RDAF_NOPROMPT;
					rdargs->RDA_DAList = 0;
					rdargs2 = ReadArgs("31kHz/S",args,rdargs);
					if(args[0]) AV31 = 0;		//already set for 31kHz AmigaVideo
					else AV31 = 1;				//env var exists but not set to 31kHz, so need to set it
					FreeArgs(rdargs2);
					FreeDosObject(DOS_RDARGS,rdargs);
				}
			} else {
				AV31 = 1;		//no env var, so need to set it
			}
			FreeVec(varbuf);
			if(AV31) {
				//set env var to 31kHz
				if((SetVar("Picasso96/AmigaVideo","31kHz",-1,LV_VAR | GVF_GLOBAL_ONLY)) == 0) {
					CloseLibrary((struct Library*)DOSBase);
					return -1;	//SetVar failed for some reason
				}
			}
			CloseLibrary((struct Library*)DOSBase);
			return AV31;
		}
		CloseLibrary((struct Library*)DOSBase);
	}
	return -1;	//error opening DOS library or no mem
}

//restore env var AmigaVideo
int RevertAmigaVideo(int AV31)
{
	int success = 0;
	if(!AV31) return 0;		//no change needed
	if((DOSBase = (struct DosLibrary*)OpenLibrary("dos.library",37)))
	{
		success = DeleteFile("env:Picasso96/AmigaVideo");
	} 
	else return -1;
	CloseLibrary((struct Library*)DOSBase);
	if(success)
		return 0;
	else
		return -1;
}

/** called by OpenDevice() **/
void*
C_initunit(ULONG unitnum)
{
    
#ifdef DEBUG
KPutStr("C_initunit\n");
#endif
	SysBase = (*((struct ExecBase **) 4));
    u=(struct devunit*)AllocVec(sizeof(struct devunit),MEMF_PUBLIC|MEMF_CLEAR);
    if(!u) return(NULL);

    u->unit.unit_MsgPort.mp_Node.ln_Type=NT_MSGPORT;
    u->unit.unit_MsgPort.mp_Node.ln_Name= &DevName;
    u->unit.unit_MsgPort.mp_Flags=PA_IGNORE;
    NewList(&u->unit.unit_MsgPort.mp_MsgList);
    u->unitnum=unitnum;
    u->volumeleft=volumeleft;
    u->volumeright=volumeright;
	u->freq_div = 4;			//default ###
    NewList(&u->ioreqlist);
    {
        UBYTE *varbuf;
        LONG  varlen, args[4]={0,0,0,0};
        struct RDArgs *rdargs, *rdargs2;
        
        if((DOSBase=(struct DosLibrary*)OpenLibrary("dos.library",37)))
        {
            if((varbuf=AllocVec(1024,MEMF_PUBLIC|MEMF_CLEAR)))
            {
                if((varlen=GetVar("DSP3210MPEG",varbuf,1024,LV_VAR))>0)
                {
#ifdef DEBUG
KPutStr("C_initunit part 3\n");
#endif
#ifdef DEBUG
KPutStr("DSP3210MPEG var: '"); KPutStr(varbuf); KPutStr("'\n");
#endif
                    if((rdargs=AllocDosObject(DOS_RDARGS,&tagdone)))
                    {
                        rdargs->RDA_Source.CS_Buffer=varbuf;
                        rdargs->RDA_Source.CS_Length=varlen;
                        rdargs->RDA_Source.CS_CurChr=0;
                        rdargs->RDA_Flags=RDAF_NOPROMPT;
                        rdargs->RDA_DAList=0;
                        rdargs2=ReadArgs("L2MONO/S,QUAL/S,HQUAL/S",args,rdargs);
                        if(args[0]) u->II_forcemono=1;
                        if(args[1]) u->freq_div = 2;
						if(args[2]) u->freq_div = 1;	//high quality trumps quality!
                        FreeArgs(rdargs2);
                        FreeDosObject(DOS_RDARGS,rdargs);
                    }
                }
                FreeVec(varbuf);
            }
            CloseLibrary((struct Library*)DOSBase);
        }
    }

	WBP96 = workbench_displayID();

#ifdef DEBUG
	KPutStr("C_initunit complete\n");
#endif
    return(u);
}



/** called by CloseDevice() **/
ULONG
C_expungeunit(struct devunit *u)
{
    ULONG unitnum=u->unitnum;
#ifdef DEBUG
KPutStr("C_expungeunit\n");
#endif
    C_flush(u);
    FreeVec(u);
	RevertAmigaVideo(AV31kHz);
    return(unitnum);
}



/** called by MPEGCMD_PAUSE **/
void
C_setpause(struct devunit *u, struct IOMPEGReq *iomr)
{
#ifdef DEBUG
KPutStr("C_setpause\n");
#endif
	if(u->pause && iomr->iomr_Arg1 == 0)		//unpause
	{
		u->pause = 0;
		Signal(task, 1L << daughter_signal);
		return;
	}
    u->pause = iomr->iomr_Arg1;
}



/** called by MPEGCMD_SETAUDIOPARAMS **/
void
C_setvolume(struct devunit *u, struct IOMPEGReq *iomr)
{
    struct MPEGAudioParams *ap;
#ifdef DEBUG
KPutStr("C_setvolume\n");
#endif
    ap=(struct MPEGAudioParams*)iomr->iomr_Req.io_Data;
    if(ap)
    {
		u->volumeleft  = volumeleft  = ap->map_VolumeLeft /2;	//scale to be 0-32768
		u->volumeright = volumeright = ap->map_VolumeRight /2;
		if(u->initdsp_ok)
		{
			*(ULONG *)DSP_volR			= (ULONG)volumeright;		//ch 0
			*(ULONG *)DSP_volL			= (ULONG)volumeleft;		//ch 1
			if(u->prg_mp2 == 1)
			{
				*(ULONG *)DSP_routine		= (ULONG)DSP3210_volume;
				DSP_int1();
				DSP_waitready(0,0);
			}
		}
    }
}



/** called by CMD_RESET **/
void
C_reset(struct devunit *u)
{
#ifdef DEBUG
KPutStr("C_reset--");
#endif
    u->volumeleft = u->volumeright = volumeleft = volumeright = 32768;
    u->pause=0;
    C_flush(u);
}



/** called by CMD_FLUSH **/
void
C_flush(struct devunit *u)
{
    struct IOMPEGReq *iomr;
#ifdef DEBUG
KPutStr("C_flush\n");
#endif
    cleanupDSP3210(u);
    u->currlen=0; u->currpt=NULL; 
    u->layer=u->freqidx=u->mono=u->firstheader=0;
    u->bitresoffset=u->bitresok=0;
    u->framebufstate=FBS_GETHEADER;
    if((iomr=u->currioreq))
    {
        iomr->iomr_Req.io_Error=IOERR_ABORTED;
        ReplyMsg(&iomr->iomr_Req.io_Message);
        u->currioreq=NULL;
    }
    while((iomr=(struct IOMPEGReq*)RemHead(&u->ioreqlist)))
    {
        iomr->iomr_Req.io_Error=IOERR_ABORTED;
        ReplyMsg(&iomr->iomr_Req.io_Message);
    }
}



/** called by CMD_WRITE **/
ULONG
C_write(struct devunit *u, struct IOMPEGReq *iomr)
{
#ifdef DEBUG
KPutStr("C_write\n");
#endif
    if( (iomr->iomr_Req.io_Length==0) ||
        (iomr->iomr_Req.io_Data==NULL) ||
        (iomr->iomr_StreamType!=MPEGSTREAM_AUDIO) )
    {
        iomr->iomr_Req.io_Error=MPEGERR_BAD_PARAMETER;
        return(1); /*ERROR*/
    }
    Disable();
    AddTail(&u->ioreqlist, (struct Node*)iomr);
    Enable();
#ifdef DEBUG
KPutStr("C_write...AddTail\n");
#endif
    /*even if initDSP3210() returns an error we must not return it  */
    /*here because the request is already queued in our ioreqlist.  */
    /*(the requests in ioreqlist will be replied by C_flush() later)*/
    if(!u->initdsp_ok) initDSP3210(u);
    return(0);
}



/** called by C_write() **/
static ULONG
initDSP3210(struct devunit *u)
{
	AV31kHz = 0;
    while(!u->firstheader)
    {
        ULONG header, i;
        UBYTE *pt, *ptmax;
#ifdef DEBUG
KPutStr("initDSP3210...firstheader\n");
#endif
        /** find frame header and extract some info: layer, freqidx, mono **/
        if(!u->currioreq)
        {
            if(!(u->currioreq=(struct IOMPEGReq*)RemHead(&u->ioreqlist))) return(1); /*ERROR*/
            u->currpt=u->currioreq->iomr_Req.io_Data;
            u->currlen=u->currioreq->iomr_Req.io_Length;
        }
        pt=u->currpt; ptmax=pt+u->currlen; header=0;
retry_firstheader:
        i=0;
        while(pt<ptmax)
        {
            header=(header<<8)|(ULONG)(*pt++);
            if( ((header&HDR_MPEG1)==HDR_MPEG1) &&  /*sync*/
                (((header>>17)&3)!=0) &&            /*layer!=4*/
                (((header>>17)&3)!=3) &&            /*layer!=1*/
                (((header>>12)&15)!=0) &&           /*bitrate!=0*/
                (((header>>12)&15)!=15) &&          /*bitrate!=15*/
                (((header>>10)&3)!=3)               /*freqidx!=3*/
              ) {i=1; break;} /*pattern match*/
        }
        if(i) /*found something!*/
        {
            /**check next header (for safer recognition!)**/
            i=((ULONG)mpgbitrate[3-((header>>17)&3)][(header>>12)&15]*144000)/mpgfreq[(header>>10)&3]+((header>>9)&1)-4;
            if((pt+i)>=(ptmax-4)) goto retry_firstheader; /*beyond this buffer!*/
            i=((ULONG)(*(pt+i))<<24)|((ULONG)(*(pt+i+1))<<16)|((ULONG)(*(pt+i+2))<<8)|(ULONG)(*(pt+i+3));
            if( ((i&HDR_CONSTANT)!=(header&HDR_CONSTANT)) ||
                (((i>>12)&15)==0) ||
                (((i>>12)&15)==15) ) goto retry_firstheader; /*header mismatch!*/
            /**now we are quite sure that it really is an MPEG frame header**/
            u->currpt=pt-4;
            u->currlen=ptmax-pt+4;
            u->firstheader=header;
            u->layer=4-((header>>17)&3);
            u->freqidx=(header>>10)&3;
            u->mono=( (((header>>6)&3)==MPG_MD_MONO) ? 1 : 0 );

            u->forcemono= u->layer==2 ? u->II_forcemono : u->III_forcemono;
            u->dacrate= u->layer==2 ? u->II_dacrate : u->III_dacrate;
        }
        else /*not found*/
        {
#ifdef DEBUG
KPutStr("initDSP3210...firstheader...MPEGERR_CMD_FAILED\n");
#endif
            u->currioreq->iomr_Req.io_Error=MPEGERR_CMD_FAILED;
            u->currioreq->iomr_MPEGError=MPEGEXTERR_STREAM_MISMATCH;
            ReplyMsg(&u->currioreq->iomr_Req.io_Message);
            u->currioreq=NULL; u->currpt=NULL; u->currlen=0;
        }
	}

	if(u->layer==2)
	{
		if(!u->prg_mp2)
		{
#ifdef DEBUG
			KPrintF("Starting mp2 decoder with freq_div %ld\n",u->freq_div);
#endif
			if(u->freq_div == 1) {
				switch(WBP96) {
				case -1:
					return 1;	//error with library opening etc

				case 1:
					//We are running a P96 RTG screen, so switch Amiga Video to 31kHz if not already
					AV31kHz = CheckAmigaVideo();	//attempt switch to 31kHz
					if(AV31kHz == -1) return 1;		//error with libs/allocmem
					break;

				case 2:
					//nothing to do as we are already set up for freq_div = 1
					break;

				default:
					u->freq_div = 2;	//force drop in replay speed as can't support 31kHz mode
					break;
				}
			}
			DSP_init(2);	//initialise DSP3210
			u->prg_mp2 = 1;
		}
	}

	else if(u->layer==3)
	{
		if(!u->prg_mp3)
		{
#ifdef DEBUG
			KPrintF("Starting mp3 decoder\n");
#endif
			DSP_init(3);	//initialise DSP3210
			u->prg_mp3 = 1;
		}
	} else return(1); /*ERROR: unsupported layer*/


    if(!u->mod_pcm)
    {
#ifdef DEBUG
KPutStr("initDSP3210...AddModule\n");
#endif

		u->pcm_flag = PCM_NULL;
		if((mother_signal = AllocSignal(-1)) == -1)
			//Houston, we have a problem - no more signals
			return(1);
		mother_task = FindTask(NULL);
		//create task here
		task = CreateTask(playtaskname, 21, (APTR)play_task, (ULONG)1024);
		
		Wait(1L << mother_signal);
		FreeSignal(mother_signal);		//daughter signal has been created
		u->stop_flag = 0;
		u->mod_pcm = 1;
    }

   u->initdsp_ok = 1;
#ifdef DEBUG
KPutStr("initDSP3210...ok\n");
#endif
    return(0);
}



/** called by C_flush() **/
static void
cleanupDSP3210(struct devunit *u)
{

#ifdef DEBUG
KPutStr("cleanupDSP3210\n");
#endif
    if(u->mod_pcm)
    {
        u->stop_flag = 1;		
		u->mod_pcm = 0;
    }
    u->initdsp_ok = 0;
}


/*-------------------------------------------*/
/* From here on runs in a separate play task */
/*-------------------------------------------*/

LONG ReadAndDecode(struct devunit *u)
{
	ULONG cachelen, output;
    if(/*(u->pause) ||*/ (u->framebufstate!=FBS_FILLED))
    {

    }
    else
    {  
		if(u->layer==2)
		{
			if(iteration) {
				if(DSP_waitready(((iteration & 1) == 0)?(ULONG)pcm[1][0]:(ULONG)pcm[0][0],PCM_SIZE * 4)) 			//wait for DSP to complete
					KPrintF("overwait\n");
			}

			CopyMem(u->dspcopypt, inbuf, u->dspcopysize);

			*(ULONG *)DSP_routine		= (ULONG)DSP3210_decodeMP2;
			*(ULONG *)DSP_mono			= (ULONG)u->mono;
			if((iteration & 1) == 0) {
				*(ULONG *)DSP_outbuffer0	= (ULONG)pcm[0][0];		//ch 0 even iterations to Bank 0
				*(ULONG *)DSP_outbuffer1	= (ULONG)pcm[0][1];		//ch 1
			} else {
				*(ULONG *)DSP_outbuffer0	= (ULONG)pcm[1][0];		//ch 0 odd iterations to Bank 1
				*(ULONG *)DSP_outbuffer1	= (ULONG)pcm[1][1];		//ch 1
			}
			*(ULONG *)DSP_translate		= (ULONG)u->II_translate;
			*(ULONG *)DSP_jsbound		= (ULONG)u->II_jsbound;
			*(ULONG *)DSP_inbuf			= (ULONG)inbuf;
			*(ULONG *)DSP_freq_div		= (ULONG)u->freq_div;

			DSP_int1();

			u->framebufstate=FBS_GETHEADER;
			u->pcm_flag = PCM_FULL;		//ie there is a waveform available
		}
        else if(u->layer==3  && u->bitresok)
		{
			if(iteration) {
				if(DSP_waitready(((iteration & 1) == 0)?(ULONG)pcm[1][0]:(ULONG)pcm[0][0],PCM_SIZE * 4)) 			//wait for DSP to complete
					KPrintF("overwait\n");
			}

			CopyMem(&u->bitresbuf[0], inbuf, (u->III_main_data_size+33));
			*(ULONG *)DSP_routine		= (ULONG)DSP3210_decodeMP3;
			*(ULONG *)DSP_mono			= (ULONG)u->mono;
			if((iteration & 1) == 0) {
				*(ULONG *)DSP_outbuffer0	= (ULONG)pcm[0][0];		//ch 0 even iterations to Bank 0
				*(ULONG *)DSP_outbuffer1	= (ULONG)pcm[0][1];		//ch 1
			} else {
				*(ULONG *)DSP_outbuffer0	= (ULONG)pcm[1][0];		//ch 0 odd iterations to Bank 1
				*(ULONG *)DSP_outbuffer1	= (ULONG)pcm[1][1];		//ch 1
			}
			*(ULONG *)DSP_inbuf			= (ULONG)inbuf;
			*(ULONG *)DSP_freq_div		= (ULONG)4;					//u->freq_div; hardcoded divisor!
			*(ULONG *)DSP_modext		= (ULONG)u->modext;
			*(ULONG *)DSP_freq_idx		= (ULONG)u->freqidx;

			DSP_int1();

			u->framebufstate=FBS_GETHEADER;
			u->pcm_flag = PCM_FULL;		//ie there is a waveform available
		}
    }

    if(u->framebufstate==FBS_GETHEADER)
    {
        /*find next valid frame header*/
        ULONG fh=u->firstheader&HDR_CONSTANT, ch=0;
        while( ((ch&HDR_CONSTANT)!=fh) ||   /*sync, layer, freqidx*/
               (((ch>>12)&15)==0) ||        /*bitrate!=0*/
               (((ch>>12)&15)==15) )        /*bitrate!=15*/
        {
            if(u->currioreq)
            {
                if(u->currlen)
                {
                    ch=(ch<<8)|(ULONG)(*u->currpt);
                    u->currpt++; u->currlen--;
                }
                else
                {
                    u->currioreq->iomr_Req.io_Actual=u->currioreq->iomr_Req.io_Length;
                    ReplyMsg(&u->currioreq->iomr_Req.io_Message);
                    u->currioreq=NULL; u->currpt=NULL; /*u->currlen=0;*/
                }
            }
            else
            {
                if(!(u->currioreq=(struct IOMPEGReq*)RemHead(&u->ioreqlist)))
                {
					u->stop_flag = 1;
                    ch=0; break; /*ERROR*/
                }
                u->currpt=u->currioreq->iomr_Req.io_Data;
                u->currlen=u->currioreq->iomr_Req.io_Length;
            }
        }
        if(ch) /*found it!*/
        {
            u->framebufoffset=0;
            u->framebufleft=((ULONG)mpgbitrate[u->layer-1][(ch>>12)&15]*144000)/mpgfreq[(ch>>10)&3]+((ch>>9)&1)-4;
            u->II_translate=mp2translate[u->freqidx][u->mono][(ch>>12)&15];
            if(((ch>>6)&3)==MPG_MD_JOINT_STEREO)
            {
                u->modext=(ch>>4)&3;
                u->II_jsbound=(u->modext<<2)+4;
            }
            else
            {
                u->modext=0;
                u->II_jsbound=mp2sblimit[u->II_translate];
            }
            u->dspcopysize=u->framebufleft; 
            u->dspcopypt= &u->framebuf[0];  
            if(!((ch>>16)&1))
            {
                u->dspcopysize-=2;			
                u->dspcopypt+=2;			
            }
            u->framebufstate=FBS_GETFRAMEDATA;
        }
    }

    if(u->framebufstate==FBS_GETFRAMEDATA)
    {
        /*fetch frame data*/
        while(u->framebufleft)
        {
            if(u->currioreq)
            {
                if(u->currlen)
                {
                    ULONG i=u->currlen;
                    if(u->framebufleft<i) i=u->framebufleft;
                    CopyMem(u->currpt, &u->framebuf[u->framebufoffset], i);
                    u->currpt+=i; u->currlen-=i;
                    u->framebufoffset+=i; u->framebufleft-=i;
                    if(u->framebufleft==0) u->framebufstate=FBS_FILLED;
                }
                else
                {
                    u->currioreq->iomr_Req.io_Actual=u->currioreq->iomr_Req.io_Length;
                    ReplyMsg(&u->currioreq->iomr_Req.io_Message);
                    u->currioreq=NULL; u->currpt=NULL; /*u->currlen=0;*/
                }
            }
            else
            {
                if(!(u->currioreq=(struct IOMPEGReq*)RemHead(&u->ioreqlist)))
                {
                    break; /*ERROR*/
                }
                u->currpt=u->currioreq->iomr_Req.io_Data;
                u->currlen=u->currioreq->iomr_Req.io_Length;
            }
        }
        if((u->framebufstate==FBS_FILLED) && (u->layer==3))
        {
            UWORD md;
            /**extract main data size**/
            gb_pt=(UWORD*)(u->dspcopypt+2); gb_num=0;
            if(u->mono)
            {
                GetBits(9+5+4-16);
                md=GetBits(12);
            }
            else
            {
                GetBits(9+3+8-16);
                md=GetBits(12);
                GetBits(59-12);
                md+=GetBits(12);
                GetBits(59-12);
                md+=GetBits(12);
            }
            GetBits(59-12);
            md+=GetBits(12);
            u->III_main_data_size=(md+7)>>3;
            /**bit reservoir handling**/
            {
                UWORD main_data_begin, i;
                UBYTE *p0, *p1;
                p1=u->dspcopypt;
                main_data_begin= (UWORD)(*p1)<<1 | (UWORD)(*(p1+1))>>7;
                /* copy side information */
                p0= &u->bitresbuf[0];
                for(i=32; i>0; i--) *p0++= *p1++;
                /* copy previous main_data */
                //p0++; /* &u->bitresbuf[33] */
                if(u->bitresoffset>=main_data_begin)
                {
                    u->bitresok=1;
                    p1=p0+u->bitresoffset-main_data_begin;
                    for(i=main_data_begin; i>0; i--) *p0++= *p1++;
                    u->bitresoffset=main_data_begin;
                }
                else
                {
                    u->bitresok=0; /* not enough data in reservoir */
                    p0+=u->bitresoffset;
                }
                /* copy current main_data */
                i=(u->mono) ? 17 : 32; /* side info length */
                p1=u->dspcopypt+i;    /* begin of main_data area */
                i=u->dspcopysize-i;   /* mainslots */
                u->bitresoffset+=i;
                for(; i>0; i--) *p0++= *p1++;
            }
        }
    }

    return 0;
}



static UWORD
GetBits(UWORD num)
{
    UWORD val=0;
    for(; num>0; num--)
    {
        if(gb_num==0)
        {
            gb_buf= *gb_pt++;
            gb_num= 16;
        }
        gb_num--;
        val+= val;
        val|= (gb_buf>>gb_num)&1;
    }
    return(val);
}

static void exit_cleanup( void )
{
	int i,j;
	if (daughter_signal) {
		FreeSignal(daughter_signal);
		daughter_signal = 0; }
	if (device == 0)
		CloseDevice((struct IORequest *)AIOptr1[0]);
	if (port1 != 0)
		DeletePort(port1);
	if (port2 != 0)
		DeletePort(port2);
	for(i=0; i<4; i++) {
		if (AIOptr1[i] != 0)
			FreeVec(AIOptr1[i]);
		if (AIOptr2[i] != 0)
			FreeVec(AIOptr2[i]);
	}

	if (sbase !=0) {
		FreeMem (sbase, ssize);
		sbase = NULL; }
	if (inbuf != NULL) {
		FreeVec(inbuf);
		inbuf = NULL; }
	for(j=0; j<2; j++) {
		for(i=0; i<2; i++) {
			if (pcm[j][i] != 0) {
				FreeVec(pcm[j][i]);
				pcm[j][i] = NULL; 
			}
		}
	}

	return;
}

void rprintf(float x1)
{
	ULONG intpart, floatpart;
	int i;
	float x = x1;

	if(x<0) {			//sort out negatives
		KPrintF("-");
		x= -1*x;
	}
	if(x>0x7fffffff) {
		KPrintF("large");	//really should take logs to work out exponent, then deduct to determine
							//mantissa
		return;
	}
	intpart = (ULONG)x;
	KPrintF("%ld.",intpart);
	x=x-(float)intpart;

	for(i=0; i<6; i++) {
		x = x * 10;
		floatpart = (ULONG)x;
		KPrintF("%ld",floatpart);
		x = x - (float)floatpart;
	}
	return;
}


//convert BE DSP float as int to BE IEEE float
float DSP_dsp2ieee(int f)
{
	int neg = 0;
	int m,e, eint;
	float res;
	int i;
	float d;
	
	if(!f) {
		KPrintF("0.000000 ");	
		return f;
	}

	if(f&0x80000000)
		neg = 1;

	e = f&0xFFL;
	m = (f>>8)&0x7FFFFF;

	if(!e) {
		KPrintF("0.000000 ");	
		return 0; //zero even if dirty zero

	}


	res = 0;
	d = 0.5;
	for(i=0; i<23; i++) {
		if(m & 0x400000)
			res += d;
		m = m << 1;
		m = m & 0x7FFFFF;
		d = d /2;
	}
	i = e - 128;
	if(i != 0) {
		if(i>0) {		
			eint = 1 << i;
			d = (float)eint;
		} else {
			eint = 1 << (-i);	
			d = 1/(float)eint;
		}
	} else d = 1.0;
	res = ((neg?-2:1)+res) * d;

	rprintf(res);
	KPrintF(" ");

	return res;
}



void output_pcm(WORD channels, WORD *pcmR, WORD *pcmL, LONG count)
/*---------------------------------------------------------------------------
   Ouput the current decoded PCM to a file
   Return 0 if Ok
*/
{
	//copy one stereo channel out as 8 bit bytes from 16 bit stream into buffer
	//so the number of bytes to be output is count 
	WORD byte_count;
	BYTE *word_ptrR, *word_ptrL;
	BYTE *byte_ptrRP, *byte_ptrRS;
	BYTE *byte_ptrLP, *byte_ptrLS;
	int i;
	

	byte_count = count;
	word_ptrR = (BYTE *)pcmR;		//ch 0
	word_ptrL = (BYTE *)pcmL;		//ch 1

	if(iteration == 0) {		//do nothing to allow DSP to double buffer
		iteration++;
		return;
	}

	if(iteration == 1) {
		//fill buffer 1
		byte_ptrRP = (BYTE *)AIOptr1[0]->ioa_Data;			//Primary R channel
		byte_ptrLP = (BYTE *)AIOptr1[1]->ioa_Data;			//Primary L channel
		byte_ptrRS = (BYTE *)AIOptr1[2]->ioa_Data;			//Secondary R channel
		byte_ptrLS = (BYTE *)AIOptr1[3]->ioa_Data;			//Secondary L channel
		while(byte_count--) {
			*byte_ptrRP++ = *word_ptrR;				//upper 8 bits
			*byte_ptrRS++ = *(word_ptrR + 1);		//lower 8 bits
			*byte_ptrLP++ = *word_ptrL;
			*byte_ptrLS++ = *(word_ptrL + 1);
			word_ptrR += 2;			//next upper byte of word
			word_ptrL += 2;
		}
		iteration++;
		return;
	}

	if(iteration == 2) {
		//fill buffer 2
		byte_ptrRP = (BYTE *)AIOptr2[0]->ioa_Data;
		byte_ptrLP = (BYTE *)AIOptr2[1]->ioa_Data;
		byte_ptrRS = (BYTE *)AIOptr2[2]->ioa_Data;
		byte_ptrLS = (BYTE *)AIOptr2[3]->ioa_Data;
		while(byte_count--) {
			*byte_ptrRP++ = *word_ptrR;
			*byte_ptrRS++ = *(word_ptrR + 1);
			*byte_ptrLP++ = *word_ptrL;
			*byte_ptrLS++ = *(word_ptrL + 1);
			word_ptrR += 2;			//next upper byte of word
			word_ptrL += 2;
		}
		
			//cue up first samples, both channels
			AIOptr1[0]->ioa_Length = count;	//cue up both samples
			AIOptr1[1]->ioa_Length = count;	//cue up both samples
			AIOptr1[2]->ioa_Length = count;
			AIOptr1[3]->ioa_Length = count;
			BeginIO((struct IORequest *)AIOptr1[0]);
			BeginIO((struct IORequest *)AIOptr1[1]);
			BeginIO((struct IORequest *)AIOptr1[2]);
			BeginIO((struct IORequest *)AIOptr1[3]);
		
			//cue up second samples, both channels
			AIOptr2[0]->ioa_Length = count;
			AIOptr2[1]->ioa_Length = count;
			AIOptr2[2]->ioa_Length = count;
			AIOptr2[3]->ioa_Length = count;
			BeginIO((struct IORequest *)AIOptr2[0]);
			BeginIO((struct IORequest *)AIOptr2[1]);
			BeginIO((struct IORequest *)AIOptr2[2]);
			BeginIO((struct IORequest *)AIOptr2[3]);
		
		iteration++;
		return;
	}


	if((iteration & 1) == 0) {
		//odd
		//wait buffer 2 played
		WaitIO((struct IORequest *)AIOptr2[0]);
		WaitIO((struct IORequest *)AIOptr2[1]);
		WaitIO((struct IORequest *)AIOptr2[2]);
		WaitIO((struct IORequest *)AIOptr2[3]);
		//fill buffer 2
		byte_ptrRP = (BYTE *)AIOptr2[0]->ioa_Data;
		byte_ptrLP = (BYTE *)AIOptr2[1]->ioa_Data;
		byte_ptrRS = (BYTE *)AIOptr2[2]->ioa_Data;
		byte_ptrLS = (BYTE *)AIOptr2[3]->ioa_Data;
		while(byte_count--) {
			*byte_ptrRP++ = *word_ptrR;
			*byte_ptrRS++ = *(word_ptrR + 1);
			*byte_ptrLP++ = *word_ptrL;
			*byte_ptrLS++ = *(word_ptrL + 1);
			word_ptrR += 2;			//next upper byte of word
			word_ptrL += 2;
		}
		
		//play buffer 2	
			AIOptr2[0]->ioa_Length = count;
			AIOptr2[1]->ioa_Length = count;
			AIOptr2[2]->ioa_Length = count;
			AIOptr2[3]->ioa_Length = count;
			BeginIO((struct IORequest *)AIOptr2[0]);
			BeginIO((struct IORequest *)AIOptr2[1]);
			BeginIO((struct IORequest *)AIOptr2[2]);
			BeginIO((struct IORequest *)AIOptr2[3]);
		

	} else {
		//even
		//wait buffer 1 played
		WaitIO((struct IORequest *)AIOptr1[0]);
		WaitIO((struct IORequest *)AIOptr1[1]);
		WaitIO((struct IORequest *)AIOptr1[2]);
		WaitIO((struct IORequest *)AIOptr1[3]);
		//fill buffer 1
		byte_ptrRP = (BYTE *)AIOptr1[0]->ioa_Data;
		byte_ptrLP = (BYTE *)AIOptr1[1]->ioa_Data;
		byte_ptrRS = (BYTE *)AIOptr1[2]->ioa_Data;
		byte_ptrLS = (BYTE *)AIOptr1[3]->ioa_Data;
		while(byte_count--) {
			*byte_ptrRP++ = *word_ptrR;
			*byte_ptrRS++ = *(word_ptrR + 1);
			*byte_ptrLP++ = *word_ptrL;
			*byte_ptrLS++ = *(word_ptrL + 1);
			word_ptrR += 2;			//next upper byte of word
			word_ptrL += 2;
		}
		
		//play buffer 1	
			AIOptr1[0]->ioa_Length = count;
			AIOptr1[1]->ioa_Length = count;
			AIOptr1[2]->ioa_Length = count;
			AIOptr1[3]->ioa_Length = count;
			BeginIO((struct IORequest *)AIOptr1[0]);
			BeginIO((struct IORequest *)AIOptr1[1]);
			BeginIO((struct IORequest *)AIOptr1[2]);
			BeginIO((struct IORequest *)AIOptr1[3]);
		
	}
	iteration++;

	return;
}

void filter_off(void) = "\tbset.b\t#1,$bfe001";
void filter_on(void)  = "\tbclr.b\t#1,$bfe001";

int play_task()
{
   WORD i, j;
   const LONG pcm_count = 1152 / u->freq_div;
   LONG index;
   WORD channels;
   int error;
   struct Device *audio = 0;

   ULONG speed;               /* Clock constant            */

   device=1L;
   iteration = 0;
   ssize = 102400;			//could make this 1152 * 8

   BPTR file;
   int dspf;
	float ieeef;
 
	//reserve space for pcm[2][2] buffers, each of size 1152 WORDS / freq_div
	//ie stereo channels and double buffered
   for(j=0; j<2; j++) {
	   for(i=0; i<MAX_CHANNELS; i++) {
		   pcm[j][i] = AllocVec(PCM_SIZE * sizeof(WORD), MEMF_FAST | MEMF_PUBLIC | MEMF_CLEAR);
		   if( !pcm[j][i] ) {
			   //fprintf( stderr, "Can't allocate PCM buffers\n" );
			   goto exit_route;
		   }
	   }
   }

   inbuf = (UBYTE *)AllocVec(1792, MEMF_FAST | MEMF_PUBLIC);
   if(!inbuf) goto exit_route;
    

	sbase = (UBYTE *)AllocMem( ssize , MEMF_CHIP | MEMF_CLEAR);
	if (!sbase) {
		goto exit_route;
    }

	/*----------------------------------*/
	/* Calculate playback sampling rate */
	/*----------------------------------*/
	speed = clockrate / (mpgfreq[u->freqidx] / u->freq_div);

	/*------------------------------------------------*/
	/* Allocate two audio I/O blocks for each channel */
	/*------------------------------------------------*/
	for(i=0; i<4; i++) {
		AIOptr1[i]=(struct IOAudio *)AllocVec( sizeof(struct IOAudio),MEMF_PUBLIC|MEMF_CLEAR);
		if (!AIOptr1[i]) {
			goto exit_route;
		}

		AIOptr2[i]=(struct IOAudio *)AllocVec( sizeof(struct IOAudio),MEMF_PUBLIC|MEMF_CLEAR);
		if (!AIOptr2[i]) {
			goto exit_route;
		}
	}

	/*----------------------*/
	/* Make two reply ports */
	/*----------------------*/

	port1=CreatePort(0,0);
	if (!port1) {
		goto exit_route;
	}

	port2=CreatePort(0,0);
	if (!port2) {
		goto exit_route;
	}

	/*---------------------------------------*/
	/* Open device and allocate all channels */
	/*---------------------------------------*/

	device = OpenDevice(AUDIONAME,0L,(struct IORequest *)AIOptr1[0],0L);
	if (device!=0) {
		goto exit_route;
	}

	audio = AIOptr1[0]->ioa_Request.io_Device;

	chans[0] = 1;
	chans[1] = 2;
	chans[2] = 4;
	chans[3] = 8;

	for(i=0; i<4; i++) {
		AIOptr1[i]->ioa_Request.io_Device					= audio;
		AIOptr1[i]->ioa_Request.io_Message.mn_ReplyPort		= port1;
		AIOptr1[i]->ioa_Request.io_Message.mn_Node.ln_Pri	= 127;  /* No stealing! */
		AIOptr1[i]->ioa_Request.io_Command					= ADCMD_ALLOCATE;
		AIOptr1[i]->ioa_Data								= (UBYTE *)&chans[i];
		AIOptr1[i]->ioa_Length								= 1;
		AIOptr1[i]->ioa_Request.io_Flags					= ADIOF_NOWAIT | IOF_QUICK;
		BeginIO((struct IORequest *)AIOptr1[i]);
		error = WaitIO((struct IORequest *)AIOptr1[i]);			//non-zero if error

		if(!(AIOptr1[i]->ioa_Request.io_Flags & IOF_QUICK))
			GetMsg(AIOptr1[i]->ioa_Request.io_Message.mn_ReplyPort);

		if(error)
		{
	        KPrintF ("Error claiming channel %ld\n", i); 
		}
	}

	if((daughter_signal = AllocSignal(-1)) == -1)
			//Houston, we have a problem - no more signals
		goto exit_route;
		
	Signal(mother_task, 1L << mother_signal);	//daughter signal created

	filter_off();

	
	/*-------------------------------------------*/
	/* Set Up Audio IO Blocks for Sample Playing */
	/*-------------------------------------------*/
	for(i=0; i<4; i++) {
		AIOptr1[i]->ioa_Request.io_Command   = CMD_WRITE;
		AIOptr1[i]->ioa_Request.io_Flags     = ADIOF_PERVOL;

		AIOptr1[i]->ioa_Volume = (i<2)?64:1;	//Volume high for primary chans, low for secondary

		AIOptr1[i]->ioa_Period = (UWORD)speed;	//Period
		AIOptr1[i]->ioa_Cycles = 1;				//Cycles


		*AIOptr2[i] = *AIOptr1[i];   /* Make sure we have the same allocation keys, */
		/* same channels selected and same flags       */
		/* (but different ports...)                    */

		AIOptr2[i]->ioa_Request.io_Message.mn_ReplyPort   = port2;

		AIOptr1[i]->ioa_Data = (UBYTE *)(sbase + 1152 * i);
		AIOptr2[i]->ioa_Data = (UBYTE *)(sbase + 1152 * (i + 4));
	}

	channels = 2;
	if(u->forcemono || u->mono) channels = 1;


	/*--------------------*/
	/* Initiate play loop */
	/*--------------------*/
	
   while(!u->stop_flag) {
	   if(u->pause) {
		   Wait(1L<<daughter_signal);		//wait for unpause
		   }
		ReadAndDecode(u);
		if(u->pcm_flag == PCM_FULL  && u->pause == 0) {
			if((iteration & 1) == 0)
				output_pcm(channels, pcm[1][0], pcm[1][1], pcm_count);	//even iterations play from Bank 1
			else
				output_pcm(channels, pcm[0][0], pcm[0][1], pcm_count);	//odd iterations play from Bank 0
			u->pcm_flag = PCM_EMPTY;
		}
   }


   if(iteration & 1) {
		//odd
		//wait buffer 2 played
		WaitIO((struct IORequest *)AIOptr2[0]);
		WaitIO((struct IORequest *)AIOptr2[1]);
		WaitIO((struct IORequest *)AIOptr2[2]);
		WaitIO((struct IORequest *)AIOptr2[3]);

		//wait buffer 1 played
		WaitIO((struct IORequest *)AIOptr1[0]);
		WaitIO((struct IORequest *)AIOptr1[1]);
		WaitIO((struct IORequest *)AIOptr1[2]);
		WaitIO((struct IORequest *)AIOptr1[3]);
   } else {

   		//even
		//wait buffer 1 played
		WaitIO((struct IORequest *)AIOptr1[0]);
		WaitIO((struct IORequest *)AIOptr1[1]);
		WaitIO((struct IORequest *)AIOptr1[2]);
		WaitIO((struct IORequest *)AIOptr1[3]);
		//wait buffer 2 played
		WaitIO((struct IORequest *)AIOptr2[0]);
		WaitIO((struct IORequest *)AIOptr2[1]);
		WaitIO((struct IORequest *)AIOptr2[2]);
		WaitIO((struct IORequest *)AIOptr2[3]);

   }

	filter_on();


   for(i=0; i<4; i++) {
		AIOptr1[i]->ioa_Request.io_Device					= audio;
		AIOptr1[i]->ioa_Request.io_Message.mn_ReplyPort		= port1;
		AIOptr1[i]->ioa_Request.io_Message.mn_Node.ln_Pri	= 127;  /* No stealing! */
		AIOptr1[i]->ioa_Request.io_Command					= ADCMD_FREE;
		AIOptr1[i]->ioa_Data								= (UBYTE *)&chans[i];
		AIOptr1[i]->ioa_Length								= 1;
		AIOptr1[i]->ioa_Request.io_Flags					= ADIOF_NOWAIT | IOF_QUICK;
		BeginIO((struct IORequest *)AIOptr1[i]);
		error = WaitIO((struct IORequest *)AIOptr1[i]);			//non-zero if error

		if(!(AIOptr1[i]->ioa_Request.io_Flags & IOF_QUICK))
			GetMsg(AIOptr1[i]->ioa_Request.io_Message.mn_ReplyPort);

		if(error)
		{
	        KPrintF ("Error freeing channel %ld\n", i); 
		}
	}

exit_route:
   exit_cleanup();
   Forbid();
   DeleteTask(task);
   Permit();
   return 1;
}

