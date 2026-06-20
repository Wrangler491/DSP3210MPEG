
all: clean dsp3210mpeg.device

OBJS= device.o dsp3210mpeg.o DSP3210.o

dsp3210mpeg.device: mpeg-DSP-mp2.o mpeg-DSP-mp3.o $(OBJS)
	vlink $(OBJS) -mrel -nostdlib  -L$(VBCC_LIB) -L$(NDK_LIB) -lamiga -lm881 -ldebug -o dsp3210mpeg.device

device.o: device.asm

mpeg-DSP-mp2.o: mpeg-DSP-mp2.s

mpeg-DSP-mp3.o: mpeg-DSP-mp3.s

DSP3210.o: DSP3210.c

dsp3210mpeg.o: dsp3210mpeg.c

.c.o:
	vc +aos68k -O3 -cpu=68030 -fpu=68882 -I./include -I$(NDK_INC) -c $*.c

device.o:
	vasmm68k_mot -m68030 -Fhunk -I./include/devices -I$(NDK_INC)/../include_i -o $*.o $*.asm

.s.o:
	asm3210 -b -o $*.o $*.s

clean:
	rm -f $(OBJS) mpeg-DSP-mp2.o mpeg-DSP-mp3.o dsp3210mpeg.device