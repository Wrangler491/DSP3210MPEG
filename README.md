# DSP3210MPEG
MPEG 1 Layer II and III decoder and player for AA3000+ Amigas

Requires 68030 or better CPU, DSP3210 on board, 2MB Fast RAM, Amiga OS 3.1 or higher

If you would like to support this development or drop me a thank you, please consider using Ko-Fi and making a donation via the Ko-Fi sponsorship link on this repository's main page

DSPMPEG implements mpeg.device using the DSP3210 found on the Amiga AA3000+.  It can decode and play MPEG 1 Layer II and Layer III files with some limitations.  Playback is via Paula in 14 bit stereo sound.

Notes
- The device operates with a frequency divisor of 1, 2 or 4, so an MPEG 1 Layer II file at 32 kHz can be played at 32, 16 or 8 kHz, respectively.  The default is a frequency divisor of 4 but the other options can be selected with an environment variable.  Certain combinations of bit rates and divisor will not be achievable, though
- Using an '030 CPU, a fast player is required and one that supports the mpeg.device standard.  AMPlifier is recommended

MPEG 1 Layer III limitations
- MPEG 1 Layer III files must be 112kbps or less and the frequency 32kHz (see below for how to do this)
- Layer III files require frequency divisor of 4
- Joint stereo not fully supported

Known bugs
- Fast forward and rewind are not currently functioning correctly in AMPlifier
- The wrapper for mpeg.devices to become MHI devices (mhimdev) does not function correctly
- Not tested yet on CPUs > 030

With thanks to Michael Henke and the source code for delfinampeg.device for Delfina DSP and Stephane Tavenard for MPEGA, both of which provided inspiration for this software

Converting bitrates and frequencies

I use ffmpeg on the PC for this, which you can run from the command line

To convert to mp2:

- ffmpeg -i [input file] -ar 48000 -ac 2 -ab 128000 -acodec mp2 [output file]

To convert to mp3 with 96kbps bitrate and 32kHz frequency:

- ffmpeg -i [input file] -ar 32000 -ac 2 -ab 96000 -acodec libmp3lame [output file]
