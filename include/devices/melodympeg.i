	IFND DEVICES_MELODYMPEG_I
DEVICES_MELODYMPEG_I SET 1

**
** Melody MPEG device include file
**
**  $VER: melodympeg.i (13.01.98)
**
**  (C) Copyright 1998 Kato Development (Thorsten Hansen)
**


	IFND    EXEC_IO_I
	INCLUDE "exec/io.i"
	ENDC


MELODYMPEGNAME MACRO
	DC.B	'melodympeg.device',0
	ENDM

MEL1200MPEGNAME MACRO
	DC.B	'mel1200mpeg.device',0
	ENDM



**
** IOMPEGReq structure
**

    STRUCTURE	IOMPEGReq,IOSTD_SIZE

	; MPEG Specific Stuff
	UWORD	iomr_MPEGError		; Extended Error Information
	UBYTE	iomr_Version		; Must be set to 0 for this spec
	UBYTE	iomr_StreamType		; Type of stream to play
	ULONG	iomr_MPEGFlags		; Flags.  See below
	ULONG	iomr_Arg1
	ULONG	iomr_Arg2

	UWORD	iomr_PTSHigh            ; Bits 32-30 of this data's PTS
	UWORD	iomr_PTSMid		; Bits 29-15 of this data's PTS
	UWORD	iomr_PTSLow		; Bits 14-9  of this data's PTS

	; Private Device Information

	UWORD	iomr_Private0
	ULONG	iomr_Private1
	ULONG	iomr_Private2

	UWORD	iomr_Private3
	UWORD	iomr_Private4
	UWORD	iomr_Private5

	LABEL	IOMPEGReq_SIZE


**
** Handy equates
**
iomr_PauseMode          EQU	iomr_Arg1

**
** Defined Stream Types
**
MPEGSTREAM_AUDIO	EQU	2	; Raw Audio bitstream
MPEGSTREAM_SYSTEM	EQU	3	; ISO 1172 System Stream


**
** MPEG Error Values
**
MPEGERR_BAD_STATE	EQU	1	; Command is illegal for the current device state
MPEGERR_BAD_PARAMETER	EQU	2	; Some parameter was illegal
MPEGERR_CMD_FAILED	EQU	3	; Command failed

**
** Extended error values.
**
MPEGEXTERR_STREAM_MISMATCH	EQU	1	; Stream type not appropriate
MPEGEXTERR_MICROCODE_FAILURE	EQU	2	; MicroCode failed to respond
MPEGEXTERR_BAD_STREAM_TYPE	EQU	3	; Command is incompatible with current stream type


**
** Defined MPEG Flags (iomr_MPEGFlags)
**
	BITDEF  MPEG,VALID_PTS,31	; This piece of data has a valid PTS


*
* MPEG Device Commands
*
	DEVINIT

	DEVCMD	MPEGCMD_PLAY
	DEVCMD	MPEGCMD_PAUSE
	DEVCMD	MPEGCMD_SLOWMOTION	; Not supported
	DEVCMD	MPEGCMD_SINGLESTEP	; Not supported
	DEVCMD	MPEGCMD_SEARCH		; Not supported
	DEVCMD	MPEGCMD_RECORD		; Not supported
	DEVCMD	MPEGCMD_GETDEVINFO
	DEVCMD	MPEGCMD_SETWINDOW	; Not supported
	DEVCMD	MPEGCMD_SETBORDER	; Not supported
	DEVCMD	MPEGCMD_GETVIDEOPARAMS	; Not supported
	DEVCMD	MPEGCMD_SETVIDEOPARAMS	; Not supported
	DEVCMD	MPEGCMD_SETAUDIOPARAMS
	DEVCMD	MPEGCMD_PLAYLSN		; Not supported
	DEVCMD	MPEGCMD_SEEKLSN		; Not supported
	DEVCMD	MPEGCMD_READFRAMEYUV	; Not supported
*
* MelodyMPEG Extended Device Commands
*
	DEVCMD	MPEGCMD_END


**
** This structure is returned form a MPEGCMD_GETDEVINFO command. Use this
** to determine what the device driver is capable of doing.  Not all devices
** will support all commands/features.
**
  STRUCTURE	MPEGDevInfo,0
	UWORD	mdi_Version
	UWORD	mdi_Flags
	ULONG	mdi_BoardCapabilities
	STRUCT	mdi_BoardDesc,256
	LABEL	mdi_SIZE


  STRUCTURE	MPEGAudioParams,0
	UWORD	map_VolumeLeft		; Left Channel Volume (0=Mute, 65535=Loudest)
	UWORD	map_VolumeRight		; Right Channel Volume
	UWORD	map_StreamID		; MPEG Audio stream ID. ~0 for all streams
	LABEL	map_SIZE

**
** Board Capabilities
**
	BITDEF	MPEGC,PLAYAUDLAYER_I,8	; Can play audio layer I
	BITDEF	MPEGC,PLAYAUDLAYER_II,9	; Can play audio layer II
	BITDEF	MPEGC,PLAYAUDLAYER_III,10 ; Can play audio layer III
;	BITDEF	MPEGC,PLAYAUDIOBYPASS,15 ; Can play audio bypass
	BITDEF	MPEGC,PLAYRAWAUDIO,17	; Can play a raw audio stream
	BITDEF	MPEGC,PLAYSYSTEM,18	; Can play an ISO-1172 system stream



	ENDC	; MELODYMPEG.i

